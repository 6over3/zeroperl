#!/bin/sh
# Cross-compile zlib and bzip2 for WASI, install into the WASI sysroot.
set -e

WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk}"
SYSROOT="$WASI_SDK_PATH/share/wasi-sysroot"
LIBDIR="$SYSROOT/lib/wasm32-wasi"
INCDIR="$SYSROOT/include"
CC="$WASI_SDK_PATH/bin/clang"
AR="$WASI_SDK_PATH/bin/llvm-ar"
RANLIB="$WASI_SDK_PATH/bin/llvm-ranlib"
CFLAGS="--target=wasm32-wasi --sysroot=$SYSROOT -O3 -w"

ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
BZIP2_VERSION="${BZIP2_VERSION:-1.0.8}"

WORK="/tmp/wasi-libs"
mkdir -p "$WORK"

# --- zlib ---
echo "Building zlib $ZLIB_VERSION for WASI..."
cd "$WORK"
curl -fsSL "https://www.zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz" | tar -xzf -
cd "zlib-${ZLIB_VERSION}"

CC="$CC" CFLAGS="$CFLAGS" AR="$AR" RANLIB="$RANLIB" \
    ./configure --static --prefix="$SYSROOT" --libdir="$LIBDIR"
make -j"$(nproc)" libz.a
make install

# --- bzip2 ---
echo "Building bzip2 $BZIP2_VERSION for WASI..."
cd "$WORK"
curl -fsSL "https://sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz" | tar -xzf -
cd "bzip2-${BZIP2_VERSION}"

make -j"$(nproc)" libbz2.a \
    CC="$CC $CFLAGS" \
    AR="$AR" \
    RANLIB="$RANLIB"
cp libbz2.a "$LIBDIR/"
cp bzlib.h "$INCDIR/"

rm -rf "$WORK"
echo "zlib and bzip2 installed into $SYSROOT"
