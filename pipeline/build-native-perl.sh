#!/bin/sh
set -e

PERL_VERSION="${PERL_VERSION:-5.42.0}"
URLPERL="https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
NPROC="${NPROC:-$(nproc)}"

mkdir -p "$NATIVE_DIR"
curl -fsSL "$URLPERL" | tar -xzf - --strip-components=1 --directory="$NATIVE_DIR"

cd "$NATIVE_DIR"
sh +x ./Configure \
    -sde \
    -Dman1dir=none \
    -Dman3dir=none \
    -Dprefix="$NATIVE_DIR/prefix" \
    -Dusedevel \
    -Uversiononly \
    -Dlibs="-lpthread -ldl -lm -lc -lz" \
    -Dstatic_ext="mro Devel/Peek File/DosGlob File/Glob Sys/Syslog Sys/Hostname PerlIO/via PerlIO/mmap PerlIO/encoding B attributes Unicode/Normalize Unicode/Collate threads threads/shared IPC/SysV re Digest/MD5 Digest/SHA SDBM_File Math/BigInt/FastCalc Data/Dumper I18N/Langinfo Time/HiRes Time/Piece IO Socket Hash/Util/FieldHash Hash/Util Filter/Util/Call POSIX Encode/Unicode Encode Encode/JP Encode/KR Encode/EBCDIC Encode/CN Encode/Symbol Encode/Byte Encode/TW Compress/Raw/Zlib Compress/Raw/Bzip2 MIME/Base64 Cwd Storable List/Util Fcntl Opcode"

make -j"$NPROC"
make install

export PATH="$NATIVE_DIR/prefix/bin:$PATH"
echo "yes" | cpan App::cpanminus
cpanm Perl::Tidy
