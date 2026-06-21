#!/bin/sh
set -e

# Post-process the installed Perl prefix (/zeroperl) for embedding into
# the WASM binary as a Single File System (SFS).
#
# Pipeline position: runs after build-wasi-perl.sh and optionally
# build-exiftool.sh.
# Tasks:
#   - Copy ExifTool site-lib files into the prefix (if built)
#   - Strip binaries, .so, .a, .pod, and headers
#   - Remove dead code via delete.js (tools/delete.txt manifest)
#   - Restore unicore/Heavy.pl for Perl < 5.18 if needed
#   - Install File::Glob shim if missing
#   - Strip unicore tables for full-shrink builds
#   - Run perltidy over all .pm/.pl files (optional TRIM step)
#   - Generate the SFS header (zeroperl.h) via sfs.js

PERL_VERSION="${PERL_VERSION:-5.42.2}"
BUILD_EXIFTOOL="${BUILD_EXIFTOOL:-true}"
TRIM="${TRIM:-true}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
REPO_DIR="${REPO_DIR:-/build/repo}"
NPROC="${NPROC:-$(nproc)}"
ZEROPERL_SHRINK="${ZEROPERL_SHRINK:-off}"
ZEROPERL_SFS_COMPRESS="${ZEROPERL_SFS_COMPRESS:-}"
ZEROPERL_EMBED_PREFIX="${ZEROPERL_EMBED_PREFIX:-true}"

if [ -z "$ZEROPERL_SFS_COMPRESS" ]; then
    if [ "$ZEROPERL_SHRINK" = "full" ]; then
        ZEROPERL_SFS_COMPRESS="true"
    else
        ZEROPERL_SFS_COMPRESS="false"
    fi
fi

rm -rf /zeroperl/bin
find /zeroperl -type f \( -name "*.so" -o -name "*.a" -o -name "*.ld" -o -name "*.pod" -o -name "*.h" -o -executable \) -delete

copy_traced_site_files() {
    list_file="$1"
    site_root="$2"
    while IFS= read -r relpath; do
        [ -n "$relpath" ] || continue
        case "$relpath" in
            "lib/$PERL_VERSION/wasm32-wasi/"*)
                src_rel=${relpath#lib/$PERL_VERSION/wasm32-wasi/}
                src_path="$site_root/$src_rel"
                dst_path="/zeroperl/$relpath"
                [ -f "$src_path" ] || continue
                mkdir -p "$(dirname "$dst_path")"
                cp "$src_path" "$dst_path"
                ;;
        esac
    done < "$list_file"
}

if [ "$BUILD_EXIFTOOL" = "true" ]; then
    SITE_PERL="$NATIVE_DIR/prefix/lib/perl5/site_perl/$PERL_VERSION"
    mkdir -p "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/File"
    mkdir -p "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/Image"
    if [ "$ZEROPERL_SHRINK" = "off" ]; then
        cp -R "$SITE_PERL/File/"* "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/File/" 2>/dev/null || true
        cp -R "$SITE_PERL/Image/"* "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/Image/"
    else
        if [ ! -s "$REPO_DIR/gen/traced-files.txt" ]; then
            echo "error: missing or empty traced file list: $REPO_DIR/gen/traced-files.txt" >&2
            exit 1
        fi
        rm -rf "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/File" "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/Image"
        mkdir -p "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/File" "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/Image"
        copy_traced_site_files "$REPO_DIR/gen/traced-files.txt" "$SITE_PERL"
    fi
fi

node "$REPO_DIR/tools/delete.js" "$REPO_DIR/tools/delete.txt" /zeroperl "$PERL_VERSION"

# unicore/Heavy.pl is required by utf8_heavy.pl -> constant.pm on Perl < 5.18.
# delete.js removes the entire unicore directory, but Heavy.pl must be
# restored for versions where it shipped in core.
# Perl 5.18+ restructured unicore and no longer has Heavy.pl.
PERL_MAJOR=$(echo "$PERL_VERSION" | cut -d. -f1)
PERL_MINOR=$(echo "$PERL_VERSION" | cut -d. -f2)
if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -lt 18 ]; then
    HEAVY_SRC="$WASM_DIR/lib/$PERL_VERSION/unicore/Heavy.pl"
    if [ -f "$HEAVY_SRC" ]; then
        mkdir -p "/zeroperl/lib/$PERL_VERSION/unicore"
        cp "$HEAVY_SRC" "/zeroperl/lib/$PERL_VERSION/unicore/Heavy.pl"
        echo "Restored unicore/Heavy.pl for Perl $PERL_VERSION"
    fi
fi

if [ -f "$REPO_DIR/tools/file-glob-shim.pm" ] && \
   [ ! -f "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/File/Glob.pm" ] && \
   [ ! -f "/zeroperl/lib/$PERL_VERSION/File/Glob.pm" ]; then
    mkdir -p "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/File"
    cp "$REPO_DIR/tools/file-glob-shim.pm" \
       "/zeroperl/lib/$PERL_VERSION/wasm32-wasi/File/Glob.pm"
fi

if [ "$ZEROPERL_SHRINK" = "full" ] && [ -x "$REPO_DIR/tools/unicore-strip.pl" ]; then
    perl "$REPO_DIR/tools/unicore-strip.pl" "/zeroperl/lib/$PERL_VERSION"
fi

if [ "$TRIM" = "true" ]; then
    export PATH="$NATIVE_DIR/prefix/bin:$PATH"
    find /zeroperl -type f \( -name '*.pl' -o -name '*.pm' \) -exec chmod u+w {} \;
    SKIP_FILE="$REPO_DIR/tools/perltidy-skip.txt"
    TIDY_LIST="$(mktemp)"
    find /zeroperl -type f \( -name '*.pl' -o -name '*.pm' \) | sort > "$TIDY_LIST"
    while IFS= read -r file; do
        rel="${file#/zeroperl/}"
        skip=""
        if [ -f "$SKIP_FILE" ]; then
            while IFS= read -r pattern; do
                case "$pattern" in
                    ''|\#*) continue ;;
                esac
                case "$rel" in
                    $pattern) skip=1; break ;;
                esac
            done < "$SKIP_FILE"
        fi
        [ -z "$skip" ] || continue
        if ! perltidy --noprofile --mangle --delete-all-comments \
            --backup-and-modify-in-place --backup-file-extension='/' "$file"; then
            echo "error: perltidy failed for $file" >&2
            rm -f "$TIDY_LIST"
            exit 1
        fi
    done < "$TIDY_LIST"
    rm -f "$TIDY_LIST"
fi

mkdir -p "$REPO_DIR/gen"

if [ "$ZEROPERL_EMBED_PREFIX" = "false" ]; then
    echo "ZEROPERL_EMBED_PREFIX=false: generating empty SFS (no embedded prefix)"
    node "$REPO_DIR/tools/sfs.js" --empty -o "$REPO_DIR/gen/zeroperl.h" --prefix /zeroperl
    exit 0
fi

SFS_COMPRESS_FLAG=""
if [ "$ZEROPERL_SFS_COMPRESS" = "true" ]; then
    SFS_COMPRESS_FLAG="--compress"
fi
node "$REPO_DIR/tools/sfs.js" -i /zeroperl -o "$REPO_DIR/gen/zeroperl.h" --prefix /zeroperl $SFS_COMPRESS_FLAG
