#!/bin/sh
set -e

REPO_DIR="${REPO_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
PERL_VERSION="${PERL_VERSION:-5.42.2}"

ENV_FILE="$REPO_DIR/tools/wasm-shrink.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"
ZEROPERL_SHRINK="${ZEROPERL_SHRINK:-off}"
# TRACE_ENTRY_SCRIPT="${TRACE_ENTRY_SCRIPT:-exiftool.min.pl}"
# TRACE_USE_MODULE="${TRACE_USE_MODULE:-Image::ExifTool}"
BUILD_EXIFTOOL="${BUILD_EXIFTOOL:-false}"
if [ "$BUILD_EXIFTOOL" = "true" ]; then
    TRACE_ENTRY_SCRIPT="${TRACE_ENTRY_SCRIPT:-exiftool.min.pl}"
    TRACE_USE_MODULE="${TRACE_USE_MODULE:-Image::ExifTool}"
else
    TRACE_ENTRY_SCRIPT="${TRACE_ENTRY_SCRIPT:-}"
    TRACE_USE_MODULE="${TRACE_USE_MODULE:-}"
fi
TRACE_EXPLICIT_PACKAGES="${TRACE_EXPLICIT_PACKAGES:-}"
TRACE_ALLOWLIST="${TRACE_ALLOWLIST:-gen/extra-paths-allowlist.txt}"
TRACE_WARMUP_INC="${TRACE_WARMUP_INC:-gen/warmup-inc.txt}"
TRACE_MISSING_REPORT="${TRACE_MISSING_REPORT:-gen/wasm-missing-paths.txt}"
TRACE_ENTRY_ARGS="${TRACE_ENTRY_ARGS:--ver}"
TRACE_EXPAND_EXPLICIT_PACKAGE_TREES="${TRACE_EXPAND_EXPLICIT_PACKAGE_TREES:-true}"
TRACE_EXPAND_DEPENDENCY_PACKAGE_TREES="${TRACE_EXPAND_DEPENDENCY_PACKAGE_TREES:-true}"
EXIFTOOL_WARMUP_MODE="${EXIFTOOL_WARMUP_MODE:-curated}"

export EXIFTOOL_WARMUP_MODE

mkdir -p "$REPO_DIR/gen"
[ -f "$REPO_DIR/${TRACE_ALLOWLIST}" ] || : > "$REPO_DIR/${TRACE_ALLOWLIST}"
[ -f "$REPO_DIR/${TRACE_WARMUP_INC}" ] || : > "$REPO_DIR/${TRACE_WARMUP_INC}"
[ -f "$REPO_DIR/${TRACE_MISSING_REPORT}" ] || : > "$REPO_DIR/${TRACE_MISSING_REPORT}"

if [ "$ZEROPERL_SHRINK" = "off" ]; then
    exit 0
fi

SITE_PERL_ROOT="$NATIVE_DIR/prefix/lib/perl5/site_perl/$PERL_VERSION"
ENTRY_SCRIPT="$REPO_DIR/$TRACE_ENTRY_SCRIPT"

#set -- perl "$REPO_DIR/tools/trace-zeroperl-deps.pl" \
set -- "$NATIVE_DIR/prefix/bin/perl" "$REPO_DIR/tools/trace-zeroperl-deps.pl" \
    --native-prefix "$NATIVE_DIR/prefix" \
    --perl-version "$PERL_VERSION" \
    --site-perl-root "$SITE_PERL_ROOT" \
    --output "$REPO_DIR/gen/traced-files.txt" \
    --xs-output "$REPO_DIR/gen/xs-static-ext.txt" \
    --allowlist "$REPO_DIR/$TRACE_ALLOWLIST" \
    --warmup-file "$REPO_DIR/$TRACE_WARMUP_INC" \
    --entry-arg "$TRACE_ENTRY_ARGS" \
    --entry-script "$ENTRY_SCRIPT"

for module in $(printf '%s' "$TRACE_USE_MODULE" | tr ',' ' '); do
    [ -n "$module" ] || continue
    set -- "$@" --use "$module"
done

for module in $(printf '%s' "$TRACE_EXPLICIT_PACKAGES" | tr ',' ' '); do
    [ -n "$module" ] || continue
    set -- "$@" --explicit-package "$module"
done

if [ "$TRACE_EXPAND_EXPLICIT_PACKAGE_TREES" = "true" ]; then
    set -- "$@" --expand-explicit-package-trees
else
    set -- "$@" --no-expand-explicit-package-trees
fi

if [ "$TRACE_EXPAND_DEPENDENCY_PACKAGE_TREES" = "true" ]; then
    set -- "$@" --expand-dependency-package-trees
else
    set -- "$@" --no-expand-dependency-package-trees
fi

"$@"

if [ ! -s "$REPO_DIR/gen/traced-files.txt" ]; then
    echo "error: expected non-empty traced file output" >&2
    exit 1
fi

if [ "$ZEROPERL_SHRINK" = "full" ]; then
    # Filter baseline to only include extensions that have native archives
    FILTERED_BASELINE=$(mktemp)
    while IFS= read -r ext; do
        [ -n "$ext" ] || continue
        if find "$NATIVE_DIR/prefix" -path "*/auto/$ext/*.a" 2>/dev/null | grep -q .; then
            echo "$ext" >> "$FILTERED_BASELINE"
        else
            echo "note: skipping $ext from baseline (no native archive for $PERL_VERSION)"
        fi
    done < "$REPO_DIR/tools/wasm-xs-kernel.txt"

    perl "$REPO_DIR/tools/emit-wasm-xs-bundle.pl" \
        --native-prefix "$NATIVE_DIR/prefix" \
        --static-ext-file "$REPO_DIR/gen/xs-static-ext.txt" \
        --baseline-file "$FILTERED_BASELINE" \
        --hints-out "$REPO_DIR/gen/hints-static-ext.fragment" \
        --libs-out "$REPO_DIR/gen/wasm-auto-libs.txt" \
        --xs-init-out "$REPO_DIR/gen/xs_init.inc"
    rm -f "$FILTERED_BASELINE"

    if [ ! -s "$REPO_DIR/gen/hints-static-ext.fragment" ] || \
       [ ! -s "$REPO_DIR/gen/wasm-auto-libs.txt" ] || \
       [ ! -s "$REPO_DIR/gen/xs_init.inc" ]; then
        echo "error: expected non-empty full shrink outputs (hints/libs/xs_init)" >&2
        exit 1
    fi
fi
