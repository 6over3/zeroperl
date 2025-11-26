#!/bin/sh
set -e

EXIFTOOL_VERSION="${EXIFTOOL_VERSION:-13.42}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
REPO_DIR="${REPO_DIR:-/build/repo}"

export PATH="$NATIVE_DIR/prefix/bin:$PATH"
PERL="$NATIVE_DIR/prefix/bin/perl"

curl -fsSL "https://www.exiftool.org/Image-ExifTool-${EXIFTOOL_VERSION}.tar.gz" | tar -xzf - -C /build
cd "/build/Image-ExifTool-${EXIFTOOL_VERSION}"
$PERL Makefile.PL
make
make install PREFIX="$NATIVE_DIR/prefix"

cd "$REPO_DIR"
sed -i "/\$SIG{INT}\\s*=\\s*'SigInt';/d" "$NATIVE_DIR/prefix/bin/exiftool"
sed -i "/\$SIG{CONT}\\s*=\\s*'SigCont';/d" "$NATIVE_DIR/prefix/bin/exiftool"
perltidy --delete-block-comments --delete-side-comments --delete-pod \
    "$NATIVE_DIR/prefix/bin/exiftool" -o "$REPO_DIR/exiftool.min.pl"
