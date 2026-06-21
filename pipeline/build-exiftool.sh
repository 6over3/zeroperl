#!/bin/sh
set -e

# Build ExifTool natively and install it into the native prefix.
# Also generates a "warmup" module list (the set of .pm files ExifTool
# loads at startup) which is used by the SFS builder to ensure those
# files are present in the embedded prefix.
# Finally strips signal handlers and runs perltidy to produce a
# minified exiftool.min.pl for size-sensitive builds.

EXIFTOOL_VERSION="${EXIFTOOL_VERSION:-13.55}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
REPO_DIR="${REPO_DIR:-/build/repo}"
PERL_VERSION="${PERL_VERSION:-5.42.2}"
EXIFTOOL_WARMUP_MODE="${EXIFTOOL_WARMUP_MODE:-curated}"
WARMUP_INC_OUT="${WARMUP_INC_OUT:-$REPO_DIR/gen/warmup-inc.txt}"

export PATH="$NATIVE_DIR/prefix/bin:$PATH"
PERL="$NATIVE_DIR/prefix/bin/perl"

# Use the GitHub tags tarball because exiftool.org only reliably serves the
# latest release tarball under the old naming scheme.
curl -fsSL "https://github.com/exiftool/exiftool/archive/refs/tags/${EXIFTOOL_VERSION}.tar.gz" | tar -xzf - -C /build
cd "/build/exiftool-${EXIFTOOL_VERSION}"
$PERL Makefile.PL
make

if [ "$EXIFTOOL_WARMUP_MODE" = "full" ]; then
    make test
fi

make install PREFIX="$NATIVE_DIR/prefix"

mkdir -p "$(dirname "$WARMUP_INC_OUT")"

"$PERL" -I"$NATIVE_DIR/prefix/lib/perl5/site_perl/$PERL_VERSION" -MImage::ExifTool -e '
    Image::ExifTool->new;
    print "$INC{$_}\n" for sort keys %INC;
' \
    | awk 'NF > 0' \
    | sed 's|\\|/|g' \
    | sort -u > "$WARMUP_INC_OUT"

cd "$REPO_DIR"
sed -i "/\$SIG{INT}\\s*=\\s*'SigInt';/d" "$NATIVE_DIR/prefix/bin/exiftool"
sed -i "/\$SIG{CONT}\\s*=\\s*'SigCont';/d" "$NATIVE_DIR/prefix/bin/exiftool"
perltidy --delete-block-comments --delete-side-comments --delete-pod \
    "$NATIVE_DIR/prefix/bin/exiftool" -o "$REPO_DIR/exiftool.min.pl"
