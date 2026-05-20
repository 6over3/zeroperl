#!/bin/sh
set -e

WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk}"
WASM_DIR="${WASM_DIR:-/build/wasm}"
REPO_DIR="${REPO_DIR:-/build/repo}"
STACK_SIZE="${STACK_SIZE:-8388608}"
INITIAL_MEMORY="${INITIAL_MEMORY:-33554432}"
ASYNCIFY="${ASYNCIFY:-true}"
ENABLE_HOST_CALLBACKS="${ENABLE_HOST_CALLBACKS:-false}"

if [ "$ENABLE_HOST_CALLBACKS" = "true" ]; then
    HOST_CALLBACKS_DEFINE=1
    ASYNCIFY_IMPORTS="wasi_snapshot_preview1.fd_read,env.call_host_function"
else
    HOST_CALLBACKS_DEFINE=0
    ASYNCIFY_IMPORTS="wasi_snapshot_preview1.fd_read"
fi

export PATH="$REPO_DIR/wasi-bin:$PATH"

# Use fake wasm-opt during compile/link to prevent post-link optimization
mv /opt/binaryen/bin/wasm-opt /opt/binaryen/bin/wasm-opt-real
cp "$REPO_DIR/tools/wasm-opt" /opt/binaryen/bin/wasm-opt
chmod +x /opt/binaryen/bin/wasm-opt

cd "$REPO_DIR/stubs"
wasic -flto -O3 -c machine.c -o machine.o
wasic -flto -O3 -c runtime.c -o runtime.o
wasic -flto -O3 -c setjmp.c -o setjmp.o
wasic -flto -O3 -c machine_core.S -o machine_core.o
wasic -flto -O3 -c setjmp_core.S -o setjmp_core.o
"${WASI_SDK_PATH}/bin/llvm-ar" crs libasyncjmp.a \
    machine.o runtime.o setjmp.o machine_core.o setjmp_core.o

cd "$WASM_DIR"
cp "$REPO_DIR/stubs/zeroperl.c" .

CFLAGS="-c -O3 -flto -DNO_MATHOMS -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_GETPID \
-D_GNU_SOURCE -D_POSIX_C_SOURCE -DBIG_TIME -Wno-implicit-function-declaration \
-Wno-null-pointer-arithmetic -Wno-incomplete-setjmp-declaration -Wno-incompatible-library-redeclaration \
-Wno-int-conversion -D_WASI_EMULATED_SIGNAL \
-DZEROPERL_ENABLE_HOST_CALLBACKS=$HOST_CALLBACKS_DEFINE \
-include /opt/wasi-sdk/share/wasi-sysroot/include/wasm32-wasi/fcntl.h \
-I. -I$REPO_DIR/stubs -I$REPO_DIR/gen -cxx-isystem /opt/wasi-sdk/share/wasi-sysroot/include"

wasic $CFLAGS zeroperl.c -o zeroperl.o
wasic $CFLAGS "$REPO_DIR/stubs/zeroperl_main.c" -o zeroperl_main.o
wasic $CFLAGS "$REPO_DIR/stubs/stubs.c" -o stubs.o

CFLAGS_DATA="-c -O0 -std=c23 \
-I. -I$REPO_DIR/stubs -I$REPO_DIR/gen -cxx-isystem /opt/wasi-sdk/share/wasi-sysroot/include"
wasic $CFLAGS_DATA "$REPO_DIR/gen/zeroperl_data.c" -o zeroperl_data.o

link_zeroperl() {
    OUTPUT="$1"
    shift

    wasic \
    -o "$OUTPUT" \
    -flto -g \
    "$@" \
    -z stack-size="$STACK_SIZE" -Wl,--initial-memory="$INITIAL_MEMORY" \
    -static \
    -DNO_MATHOMS \
    -D_WASI_EMULATED_PROCESS_CLOCKS -lwasi-emulated-process-clocks \
    -D_WASI_EMULATED_GETPID -lwasi-emulated-getpid \
    -D_GNU_SOURCE -D_POSIX_C_SOURCE \
    -DBIG_TIME \
    -D_WASI_EMULATED_SIGNAL -lwasi-emulated-signal \
    -lwasi-emulated-mman \
    -Wl,--strip-all \
    -Wl,--whole-archive "$REPO_DIR/stubs/libasyncjmp.a" -Wl,--no-whole-archive \
    -Wl,--whole-archive libperl.a -Wl,--no-whole-archive \
    -Wl,--wrap=fopen -Wl,--wrap=open -Wl,--wrap=close -Wl,--wrap=read \
    -Wl,--wrap=lseek -Wl,--wrap=stat -Wl,--wrap=fstat \
    lib/auto/File/Glob/Glob.a \
    lib/auto/Sys/Hostname/Hostname.a \
    lib/auto/PerlIO/via/via.a \
    lib/auto/PerlIO/mmap/mmap.a \
    lib/auto/PerlIO/encoding/encoding.a \
    lib/auto/attributes/attributes.a \
    lib/auto/Unicode/Normalize/Normalize.a \
    lib/auto/Unicode/Collate/Collate.a \
    lib/auto/re/re.a \
    lib/auto/Digest/MD5/MD5.a \
    lib/auto/Digest/SHA/SHA.a \
    lib/auto/Math/BigInt/FastCalc/FastCalc.a \
    lib/auto/Data/Dumper/Dumper.a \
    lib/auto/I18N/Langinfo/Langinfo.a \
    lib/auto/Time/Piece/Piece.a \
    lib/auto/IO/IO.a \
    lib/auto/Hash/Util/FieldHash/FieldHash.a \
    lib/auto/Hash/Util/Util.a \
    lib/auto/Filter/Util/Call/Call.a \
    lib/auto/Encode/Unicode/Unicode.a \
    lib/auto/Encode/Encode.a \
    lib/auto/Encode/JP/JP.a \
    lib/auto/Encode/KR/KR.a \
    lib/auto/Encode/EBCDIC/EBCDIC.a \
    lib/auto/Encode/CN/CN.a \
    lib/auto/Encode/Symbol/Symbol.a \
    lib/auto/Encode/Byte/Byte.a \
    lib/auto/Encode/TW/TW.a \
    lib/auto/Compress/Raw/Zlib/Zlib.a \
    lib/auto/Compress/Raw/Bzip2/Bzip2.a \
    lib/auto/MIME/Base64/Base64.a \
    lib/auto/Cwd/Cwd.a \
    lib/auto/List/Util/Util.a \
    lib/auto/Fcntl/Fcntl.a \
    lib/auto/Opcode/Opcode.a \
    lib/auto/Time/HiRes/HiRes.a \
    $(cat ext.libs) \
    -lz -lbz2 \
    -lm -lwasi-emulated-signal -lwasi-emulated-getpid \
    -lwasi-emulated-process-clocks -lwasi-emulated-mman \
    -ferror-limit=0
}

link_zeroperl zeroperl_reactor.wasm \
    -mexec-model=reactor \
    -Wl,--no-entry \
    -Wl,--stack-first \
    -Wl,--export-dynamic \
    -Wl,--export=__stack_pointer \
    -Wl,--export=__memory_base \
    -Wl,--export=__table_base \
    -Wl,--export=malloc \
    -Wl,--export=free \
    zeroperl.o stubs.o zeroperl_data.o

link_zeroperl zeroperl_command_base.wasm \
    -Wl,--stack-first \
    zeroperl_main.o zeroperl.o stubs.o zeroperl_data.o

# Restore real wasm-opt for asyncify pass
mv /opt/binaryen/bin/wasm-opt-real /opt/binaryen/bin/wasm-opt

if [ "$ASYNCIFY" = "true" ]; then
    wasm-opt zeroperl_reactor.wasm -O3 --strip-debug --enable-bulk-memory \
        --enable-nontrapping-float-to-int --asyncify \
        --pass-arg=asyncify-imports@$ASYNCIFY_IMPORTS \
        ${WASM_OPT_FLAGS} \
        -o zeroperl.wasm
    wasm-opt zeroperl_command_base.wasm -O3 --strip-debug --enable-bulk-memory \
        --enable-nontrapping-float-to-int --asyncify \
        --pass-arg=asyncify-imports@$ASYNCIFY_IMPORTS \
        ${WASM_OPT_FLAGS} \
        -o zeroperl_command.wasm
else
    wasm-opt zeroperl_reactor.wasm --strip-debug --enable-bulk-memory \
        --enable-nontrapping-float-to-int --asyncify \
        --pass-arg=asyncify-ignore-imports \
        ${WASM_OPT_FLAGS} \
        -o zeroperl.wasm
    wasm-opt zeroperl_command_base.wasm --strip-debug --enable-bulk-memory \
        --enable-nontrapping-float-to-int --asyncify \
        --pass-arg=asyncify-ignore-imports \
        ${WASM_OPT_FLAGS} \
        -o zeroperl_command.wasm
fi

# Strip empty name section that wamrc cannot parse
python3 -c "
import sys
# Custom name section: id=0x00, then LEB size, then 0x04 'name'
marker = b'\x00\x05\x04name'
for filename in ('zeroperl.wasm', 'zeroperl_command.wasm'):
    data = open(filename, 'rb').read()
    idx = data.rfind(marker)
    if idx > 0 and idx + len(marker) == len(data):
        open(filename, 'wb').write(data[:idx])
        print(f'Stripped {len(marker)}-byte empty name section from {filename}')
"
