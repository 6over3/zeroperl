#!/bin/sh
set -e

PERL_VERSION="${PERL_VERSION:-5.42.0}"
URLPERL="https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz"
WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk}"
WASM_DIR="${WASM_DIR:-/build/wasm}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
REPO_DIR="${REPO_DIR:-/build/repo}"
NPROC="${NPROC:-$(nproc)}"

export PATH="$REPO_DIR/wasi-bin:$PATH"

mkdir -p "$WASM_DIR"
curl -fsSL "$URLPERL" | tar -xzf - --strip-components=1 --directory="$WASM_DIR"

WASI_VERSION=$(cat "$WASI_SDK_PATH/VERSION" 2>/dev/null | tr -d '\n' || echo "unknown")

# Generate hints with path substitutions
sed -e "s|__STUBS_DIR__|$REPO_DIR/stubs|g" \
    -e "s|__WASI_SDK_PATH__|$WASI_SDK_PATH|g" \
    -e "s|__NATIVE_DIR__|$NATIVE_DIR|g" \
    -e "s|__WASI_SDK_VERSION__|wasi-sdk-$WASI_VERSION|g" \
    "$REPO_DIR/pipeline/hints-wasi.sh" > "$WASM_DIR/hints/wasi.sh"

cd "$WASM_DIR"

# Apply patches
chmod u+w ./ext/File-Glob/bsd_glob.c
patch -p1 < "$REPO_DIR/patches/glob.patch"
chmod u-w ./ext/File-Glob/bsd_glob.c

# Configure
wasiconfigure sh ./Configure -sde -Dhintfile=wasi

# Fix locale settings that Configure overrides
sed -i "s/d_perl_lc_all_uses_name_value_pairs='define'/d_perl_lc_all_uses_name_value_pairs='undef'/" config.sh
sed -i "s/d_perl_lc_all_separator='undef'/d_perl_lc_all_separator='define'/" config.sh
sed -i 's|^perl_lc_all_separator=.*|perl_lc_all_separator='"'"'";"'"'"'|' config.sh
sed -i "s/d_perl_lc_all_category_positions_init='undef'/d_perl_lc_all_category_positions_init='define'/" config.sh
sed -i "s/^perl_lc_all_category_positions_init=.*/perl_lc_all_category_positions_init='{ 0, 1, 2, 3, 4, 5 }'/" config.sh
sh ./Configure -S

# Setup symlinks
ln -sf "$PWD/pod/perldelta.pod" .
ln -f "$PWD"/README.* .. 2>/dev/null || true
ln -sf "$NATIVE_DIR/generate_uudmap" generate_uudmap

# Build
wasimake make -j"$NPROC" utilities PERL="$NATIVE_DIR/miniperl"
wasimake make -j"$NPROC" RUN_PERL="$NATIVE_DIR/miniperl -Ilib -I."
wasimake make install