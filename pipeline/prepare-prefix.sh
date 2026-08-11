#!/bin/sh
set -e

PERL_VERSION="${PERL_VERSION:-5.42.0}"
BUILD_EXIFTOOL="${BUILD_EXIFTOOL:-true}"
TRIM="${TRIM:-true}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
REPO_DIR="${REPO_DIR:-/build/repo}"
NPROC="${NPROC:-$(nproc)}"

rm -rf /zeroperl/bin

find /zeroperl -type f \( \
    -name '*.so' \
    -o -name '*.a' \
    -o -name '*.ld' \
    -o -name '*.pod' \
    -o -name '*.h' \
    -o -executable \
\) -delete

mkdir -p /zeroperl/bin

if [ "$BUILD_EXIFTOOL" = "true" ]; then
    SITE_PERL="$NATIVE_DIR/prefix/lib/perl5/site_perl/$PERL_VERSION"

    mkdir -p /zeroperl/bin/lib/File
    mkdir -p /zeroperl/bin/lib/Image

    cp "$NATIVE_DIR/prefix/bin/exiftool" /zeroperl/bin/exiftool
    chmod +x /zeroperl/bin/exiftool

    cp -R "$SITE_PERL/File/"* /zeroperl/bin/lib/File/ 2>/dev/null || true
    cp -R "$SITE_PERL/Image/"* /zeroperl/bin/lib/Image/
fi

node "$REPO_DIR/tools/delete.js" \
    "$REPO_DIR/tools/delete.txt" \
    /zeroperl \
    "$PERL_VERSION"

if [ "$TRIM" = "true" ]; then
    export PATH="$NATIVE_DIR/prefix/bin:$PATH"

    find /zeroperl -type f \( -name '*.pl' -o -name '*.pm' \) \
        -exec chmod u+w {} \;

    find /zeroperl -type f \( -name '*.pl' -o -name '*.pm' \) -print0 |
        xargs -0 -P "$NPROC" -I {} sh -c \
        "perltidy --delete-block-comments --delete-side-comments --delete-pod --backup-and-modify-in-place --backup-file-extension='/' '{}'"
fi

mkdir -p "$REPO_DIR/gen"

node "$REPO_DIR/tools/sfs.js" \
    -i /zeroperl \
    -o "$REPO_DIR/gen/zeroperl.h" \
    --prefix /zeroperl
