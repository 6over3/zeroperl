#!/bin/sh
set -e

# Build a native (host-architecture) Perl in /build/native.
# This native perl is used during cross-compilation as hostperl/miniperl
# and to run generate_uudmap.  It also provides a CPAN client for
# installing Module::ScanDeps and any other build-time dependencies.

PERL_VERSION="${PERL_VERSION:-5.42.2}"
URLPERL="https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
NPROC="${NPROC:-$(nproc)}"

mkdir -p "$NATIVE_DIR"
curl -fsSL "$URLPERL" | tar -xzf - --strip-components=1 --directory="$NATIVE_DIR"

# perl build variables
PERL_MAJOR=$(echo "$PERL_VERSION" | cut -d. -f1)
PERL_MINOR=$(echo "$PERL_VERSION" | cut -d. -f2)

if [ "$PERL_MAJOR" -lt 5 ] || { [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -lt 16 ]; }; then
    echo "error: Perl $PERL_VERSION is not supported. Minimum supported version is 5.16.3." >&2
    exit 1
fi

PERL_OPTIMIZE="-Oz"
PERL_LIBS="-lm -lcrypt"

cd "$NATIVE_DIR"


# Build the static extension list based on Perl version.
# Some extensions don't exist or are pure-Perl (no XS) in older Perl.
# The native build needs a working perl with enough extensions to run
# perltidy and Module::ScanDeps — it doesn't need every extension.

# POSIX is needed by version.pm's pure-Perl fallback (vpp.pm)
# Minimum supported version is 5.16.3; all extensions below are available.
# 5.22+ removed Unicode::Normalize XS (it's pure-Perl now)
#
# NOTE: 're' is excluded for 5.38.x. It copies regcomp.c/regcomp_invlist.c
# into its own build, duplicating symbols from libperl.a when statically linked.
# Other versions build 're' as a shared library (no conflict).
if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -eq 38 ]; then
    NATIVE_STATIC_EXT="mro File/Glob Sys/Hostname PerlIO/via PerlIO/encoding attributes Digest/MD5 Digest/SHA Math/BigInt/FastCalc Data/Dumper I18N/Langinfo Time/HiRes IO Hash/Util Filter/Util/Call Encode Compress/Raw/Zlib Compress/Raw/Bzip2 MIME/Base64 Cwd List/Util Fcntl Opcode POSIX Devel/Peek Sys/Syslog B IPC/SysV Socket Storable Hash/Util/FieldHash Time/Piece Unicode/Collate Encode/Unicode Encode/JP Encode/KR Encode/EBCDIC Encode/CN Encode/Symbol Encode/Byte Encode/TW PerlIO/mmap"
else
    NATIVE_STATIC_EXT="re mro File/Glob Sys/Hostname PerlIO/via PerlIO/encoding attributes Digest/MD5 Digest/SHA Math/BigInt/FastCalc Data/Dumper I18N/Langinfo Time/HiRes IO Hash/Util Filter/Util/Call Encode Compress/Raw/Zlib Compress/Raw/Bzip2 MIME/Base64 Cwd List/Util Fcntl Opcode POSIX Devel/Peek Sys/Syslog B IPC/SysV Socket Storable Hash/Util/FieldHash Time/Piece Unicode/Collate Encode/Unicode Encode/JP Encode/KR Encode/EBCDIC Encode/CN Encode/Symbol Encode/Byte Encode/TW PerlIO/mmap"
fi
if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -le 18 ]; then
    NATIVE_STATIC_EXT="Unicode/Normalize $NATIVE_STATIC_EXT"
fi

sh +x ./Configure \
    -sde \
    -Dprefix="$NATIVE_DIR/prefix" \
    -Dusedevel \
    -Uversiononly \
    -Dstatic_ext="$NATIVE_STATIC_EXT" \
    -Duselargefiles \
    -Uuse64bitint \
    -Uusethreads \
    -Uuseithreads \
    -Uusemultiplicity \
    -Uusesfio \
    -Uuseshrplib \
    -Dcc="$PERL_CC" \
    -Doptimize="$PERL_OPTIMIZE" \
    -Dlibs="$PERL_LIBS" \
    -Uusevendorprefix \
    -Uman1dir \
    -Uman3dir \
    -Usiteman1dir \
    -Usiteman3dir \
    -Duseperlio \

make -j"$NPROC"
make install

export PATH="$NATIVE_DIR/prefix/bin:$PATH"

export PERL_MM_USE_DEFAULT=1

# Install Module::ScanDeps: use older version for 5.18 and earlier (latest requires List::Util 1.33+)
if [ "$PERL_MAJOR" -lt 5 ] || { [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -le 18 ]; }; then
    # Old cpan clients (e.g. v1.9800 in 5.16.3) don't support -T and fail to
    # resolve AUTHOR/Dist-Version to .tar.gz, so install manually.
    curl -fsSL "https://cpan.metacpan.org/authors/id/R/RS/RSCHUPP/Module-ScanDeps-1.31.tar.gz" | tar -xzf - -C /tmp
    cd /tmp/Module-ScanDeps-1.31
    "$NATIVE_DIR/prefix/bin/perl" Makefile.PL
    make
    make install
    cd -
    rm -rf /tmp/Module-ScanDeps-1.31
else
    cpan -T Module::ScanDeps
fi

# Verify installation; fail the build if the module is missing
"$NATIVE_DIR/prefix/bin/perl" -MModule::ScanDeps -e1 || {
    echo "error: Module::ScanDeps is not installed" >&2
    exit 1
}
