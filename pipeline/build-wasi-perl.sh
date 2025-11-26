#!/bin/sh
set -e

PERL_VERSION="${PERL_VERSION:-5.42.0}"
URLPERL="https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz"
WASI_SDK_VERSION="${WASI_SDK_VERSION:-27}"
WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk}"
WASM_DIR="${WASM_DIR:-/build/wasm}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
REPO_DIR="${REPO_DIR:-/build/repo}"
NPROC="${NPROC:-$(nproc)}"

export PATH="$REPO_DIR/wasi-bin:$PATH"

mkdir -p "$WASM_DIR"
curl -fsSL "$URLPERL" | tar -xzf - --strip-components=1 --directory="$WASM_DIR"

sed "s|__STUBS_DIR__|$REPO_DIR/stubs|g" "$REPO_DIR/pipeline/hints-wasi.sh" > "$WASM_DIR/hints/wasi.sh"
cd "$WASM_DIR"

chmod u+w ./ext/File-Glob/bsd_glob.c
patch -p1 < "$REPO_DIR/patches/glob.patch"
chmod u-w ./ext/File-Glob/bsd_glob.c

chmod u+w ./pp_sys.c
patch -p1 < "$REPO_DIR/patches/stat.patch"
chmod u-w ./pp_sys.c

wasiconfigure sh ./Configure -sde \
    -Dinc_version_list=none \
    -Ddlsrc=none \
    -Dloclibpth='' \
    -Dglibpth='' \
    -Dlns='/bin/ln -sf' \
    -Dman1dir=none \
    -Dman3dir=none \
    -Dosname="wasi" \
    -Darchname="wasm32-wasi" \
    -Dosvers="wasi${WASI_SDK_VERSION}" \
    -Dmyuname="zeroperl" \
    -Dmyhostname='6over3.com' \
    -Dmydomain='6over3.com' \
    -Dperladmin=lena \
    -Dcc="wasic" \
    -Dld="wasic" \
    -Dar="${WASI_SDK_PATH}/bin/llvm-ar" \
    -Dranlib="${WASI_SDK_PATH}/bin/llvm-ranlib" \
    -Doptimize="-O2" \
    -Dlibs='-lm' \
    -Dhintfile=wasi \
    -Dhostperl="$NATIVE_DIR/miniperl" \
    -Dhostgenerate="$NATIVE_DIR/generate_uudmap" \
    -Dprefix="/zeroperl" \
    -Dsysroot="${WASI_SDK_PATH}/share/wasi-sysroot" \
    -Dstatic_ext="mro File/DosGlob File/Glob Sys/Hostname PerlIO/via PerlIO/mmap PerlIO/encoding attributes Unicode/Normalize Unicode/Collate re Digest/MD5 Digest/SHA Math/BigInt/FastCalc Data/Dumper I18N/Langinfo Time/Piece IO Hash/Util/FieldHash Hash/Util Filter/Util/Call Encode/Unicode Encode Encode/JP Encode/KR Encode/EBCDIC Encode/CN Encode/Symbol Encode/Byte Encode/TW Compress/Raw/Zlib Compress/Raw/Bzip2 MIME/Base64 Cwd List/Util Fcntl Opcode"

sed -i "s/d_perl_lc_all_uses_name_value_pairs='define'/d_perl_lc_all_uses_name_value_pairs='undef'/" config.sh
sed -i "s/d_perl_lc_all_separator='undef'/d_perl_lc_all_separator='define'/" config.sh
sed -i 's|^perl_lc_all_separator=.*|perl_lc_all_separator='"'"'";"'"'"'|' config.sh
sed -i "s/d_perl_lc_all_category_positions_init='undef'/d_perl_lc_all_category_positions_init='define'/" config.sh
sed -i "s/^perl_lc_all_category_positions_init=.*/perl_lc_all_category_positions_init='{ 0, 1, 2, 3, 4, 5 }'/" config.sh
sh ./Configure -S

ln -sf "$PWD/pod/perldelta.pod" .
ln -f "$PWD"/README.* .. 2>/dev/null || true
ln -sf "$NATIVE_DIR/generate_uudmap" generate_uudmap

wasimake make -j"$NPROC" utilities PERL="$NATIVE_DIR/miniperl"
wasimake make -j"$NPROC" RUN_PERL="$NATIVE_DIR/miniperl -Ilib -I."
wasimake make install
