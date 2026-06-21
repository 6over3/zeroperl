#!/bin/sh
set -e

# Cross-compile zlib, bzip2, and lz4 for wasm32-wasi and install them into
# the WASI sysroot so that Perl's Compress::Raw::Zlib, Compress::Raw::Bzip2,
# and the SFS compression layer can link against them.

WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk}"
SYSROOT="$WASI_SDK_PATH/share/wasi-sysroot"
LIBDIR="$SYSROOT/lib/wasm32-wasi"
INCDIR="$SYSROOT/include"
CC="$WASI_SDK_PATH/bin/clang"
AR="$WASI_SDK_PATH/bin/llvm-ar"
RANLIB="$WASI_SDK_PATH/bin/llvm-ranlib"
CFLAGS="--target=wasm32-wasi --sysroot=$SYSROOT -O3 -w"

ZLIB_VERSION="${ZLIB_VERSION:-1.3.2}"
BZIP2_VERSION="${BZIP2_VERSION:-1.0.8}"
LZ4_VERSION="${LZ4_VERSION:-1.10.0}"

WORK="/tmp/wasi-libs"
mkdir -p "$WORK"

# --- zlib ---
echo "Building zlib $ZLIB_VERSION for WASI..."
cd "$WORK"
curl -fsSL "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" | tar -xzf -
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

# --- lz4 ---
echo "Building lz4 $LZ4_VERSION for WASI..."
cd "$WORK"
curl -fsSL "https://github.com/lz4/lz4/archive/refs/tags/v${LZ4_VERSION}.tar.gz" | tar -xzf -
cd "lz4-${LZ4_VERSION}"

make -j"$(nproc)" -C lib liblz4.a \
    CC="$CC $CFLAGS" \
    AR="$AR" \
    RANLIB="$RANLIB"
cp lib/liblz4.a "$LIBDIR/"
cp lib/lz4.h lib/lz4frame.h lib/lz4hc.h "$INCDIR/"

rm -rf "$WORK"
echo "zlib, bzip2, and lz4 installed into $SYSROOT"
