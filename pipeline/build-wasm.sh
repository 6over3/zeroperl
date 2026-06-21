#!/bin/sh
set -e

# Compile zeroperl stubs and link the final WASM binary.
#
# Pipeline position: runs after build-wasi-perl.sh.
# Builds the asyncify jump library, compiles zeroperl.c / stubs.c /
# sfs_runtime.c, generates xs_init.inc if missing, and links everything
# into zeroperl.wasm with wasm-opt post-processing (asyncify, strip, etc.).

PERL_VERSION="${PERL_VERSION:-5.42.2}"
PERL_MAJOR=$(echo "$PERL_VERSION" | cut -d. -f1)
PERL_MINOR=$(echo "$PERL_VERSION" | cut -d. -f2)

if [ "$PERL_MAJOR" -lt 5 ] || { [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -lt 16 ]; }; then
    echo "error: Perl $PERL_VERSION is not supported. Minimum supported version is 5.16.3." >&2
    exit 1
fi

# -DNO_MATHOMS exists in 5.20+
if [ "$PERL_MAJOR" -gt 5 ] || { [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -ge 20 ]; }; then
    NO_MATHOMS="-DNO_MATHOMS"
else
    NO_MATHOMS=""
fi

WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk}"
WASM_DIR="${WASM_DIR:-/build/wasm}"
REPO_DIR="${REPO_DIR:-/build/repo}"
STACK_SIZE="${STACK_SIZE:-8388608}"
INITIAL_MEMORY="${INITIAL_MEMORY:-33554432}"
ASYNCIFY="${ASYNCIFY:-true}"
ZEROPERL_SHRINK="${ZEROPERL_SHRINK:-off}"
ZEROPERL_SFS_COMPRESS="${ZEROPERL_SFS_COMPRESS:-}"
ZEROPERL_EMBED_PREFIX="${ZEROPERL_EMBED_PREFIX:-true}"

if [ -z "$ZEROPERL_SFS_COMPRESS" ]; then
    if [ "$ZEROPERL_SHRINK" = "full" ]; then
        ZEROPERL_SFS_COMPRESS="true"
    else
        ZEROPERL_SFS_COMPRESS="false"
    fi
fi

# Nothing to compress when prefix is not embedded
if [ "$ZEROPERL_EMBED_PREFIX" = "false" ]; then
    ZEROPERL_SFS_COMPRESS="false"
fi

export PATH="$REPO_DIR/wasi-bin:$PATH"

# wasm-opt is invoked automatically by wasic during linking.  We swap in a
# no-op stub so that LTO/link happen quickly; the real wasm-opt pass runs
# later after asyncify instrumentation.
mv /opt/binaryen/bin/wasm-opt /opt/binaryen/bin/wasm-opt-real
cp "$REPO_DIR/tools/wasm-opt" /opt/binaryen/bin/wasm-opt
chmod +x /opt/binaryen/bin/wasm-opt

# ---------------------------------------------------------------------------
# Compile asyncify jump stubs into a static library.
# ---------------------------------------------------------------------------
cd "$REPO_DIR/stubs"
wasic -flto -O3 -c machine.c -o machine.o
wasic -flto -O3 -c runtime.c -o runtime.o
wasic -flto -O3 -c setjmp.c -o setjmp.o
wasic -flto -O3 -c machine_core.S -o machine_core.o
wasic -flto -O3 -c setjmp_core.S -o setjmp_core.o
"${WASI_SDK_PATH}/bin/llvm-ar" crs libasyncjmp.a \
    machine.o runtime.o setjmp.o machine_core.o setjmp_core.o

# ---------------------------------------------------------------------------
# Copy zeroperl main file and generate xs_init.inc if needed.
# ---------------------------------------------------------------------------
cd "$WASM_DIR"
cp "$REPO_DIR/stubs/zeroperl.c" .

# xs_init.inc lists the static XS extensions to bootstrap.  For non-full
# shrink builds it is generated on-the-fly from the .a files in lib/auto.
# emit-wasm-xs-bundle.pl is the single source of truth for xs_init.inc generation.
if [ ! -f "$REPO_DIR/gen/xs_init.inc" ]; then
    ALL_EXTS_FILE=$(mktemp)
    find lib/auto -name '*.a' -not -name 'DynaLoader.a' | \
        sed 's|^lib/auto/||; s|/[^/]*\.a$||' | sort -u > "$ALL_EXTS_FILE"
    if [ -s "$ALL_EXTS_FILE" ]; then
        perl "$REPO_DIR/tools/emit-wasm-xs-bundle.pl" \
            --native-prefix "$WASM_DIR" \
            --static-ext-file "$ALL_EXTS_FILE" \
            --baseline-file "$ALL_EXTS_FILE" \
            --hints-out "$REPO_DIR/gen/hints-static-ext.fragment" \
            --libs-out "$REPO_DIR/gen/wasm-auto-libs.txt" \
            --xs-init-out "$REPO_DIR/gen/xs_init.inc"
    fi
    rm -f "$ALL_EXTS_FILE"
fi

# ---------------------------------------------------------------------------
# Compile zeroperl and stub objects.
# ---------------------------------------------------------------------------
CFLAGS="-c -O3 -flto $NO_MATHOMS -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_GETPID \
-D_GNU_SOURCE -D_POSIX_C_SOURCE -DBIG_TIME -Wno-implicit-function-declaration \
-Wno-null-pointer-arithmetic -Wno-incomplete-setjmp-declaration -Wno-incompatible-library-redeclaration \
-Wno-int-conversion -D_WASI_EMULATED_SIGNAL \
-include /opt/wasi-sdk/share/wasi-sysroot/include/wasm32-wasi/fcntl.h \
-I$REPO_DIR/gen -I$REPO_DIR/stubs -I. -cxx-isystem /opt/wasi-sdk/share/wasi-sysroot/include"

if [ -f "$REPO_DIR/gen/xs_init.inc" ]; then
    CFLAGS="$CFLAGS -DZEROPERL_USE_GENERATED_XS_INIT"
fi
if [ "$ZEROPERL_SFS_COMPRESS" = "true" ]; then
    CFLAGS="$CFLAGS -DZEROPERL_SFS_COMPRESS"
fi
wasic $CFLAGS zeroperl.c -o zeroperl.o
wasic $CFLAGS "$REPO_DIR/stubs/stubs.c" -o stubs.o
wasic $CFLAGS "$REPO_DIR/stubs/sfs_runtime.c" -o sfs_runtime.o
wasic $CFLAGS "$REPO_DIR/stubs/sfs_compression.c" -o sfs_compression.o

# zeroperl_data.c contains the embedded SFS blob; compile at -O0 so the
# linker does not strip the data section.
CFLAGS_DATA="-c -O0 -std=c23 \
-I$REPO_DIR/gen -I$REPO_DIR/stubs -I. -cxx-isystem /opt/wasi-sdk/share/wasi-sysroot/include"
wasic $CFLAGS_DATA "$REPO_DIR/gen/zeroperl_data.c" -o zeroperl_data.o

GENERATED_AUTO_LIBS=""
# Discover .a files dynamically so the list matches what was actually built
# for the target Perl version.
DEFAULT_AUTO_LIBS=$(find lib/auto -name '*.a' -not -name 'DynaLoader.a' | sort | tr '\n' ' ')
if [ "$ZEROPERL_SHRINK" = "full" ] && [ -f "$REPO_DIR/gen/wasm-auto-libs.txt" ]; then
    GENERATED_AUTO_LIBS=$(tr '\n' ' ' < "$REPO_DIR/gen/wasm-auto-libs.txt")
fi
AUTO_LIBS="${GENERATED_AUTO_LIBS:-$DEFAULT_AUTO_LIBS}"

wasic \
    -o zeroperl_reactor.wasm \
    -flto -g \
    -mexec-model=reactor \
    -z stack-size="$STACK_SIZE" -Wl,--initial-memory="$INITIAL_MEMORY" \
    -static \
    -Wl,--no-entry \
    -Wl,--stack-first \
    -Wl,--export-dynamic \
    -Wl,--export=__stack_pointer \
    -Wl,--export=__memory_base \
    -Wl,--export=__table_base \
    -Wl,--export=malloc \
    -Wl,--export=free \
    $NO_MATHOMS \
    -D_WASI_EMULATED_PROCESS_CLOCKS -lwasi-emulated-process-clocks \
    -D_WASI_EMULATED_GETPID -lwasi-emulated-getpid \
    -D_GNU_SOURCE -D_POSIX_C_SOURCE \
    -DBIG_TIME \
    -D_WASI_EMULATED_SIGNAL -lwasi-emulated-signal \
    -lwasi-emulated-mman \
    -Wl,--strip-all \
    zeroperl.o stubs.o sfs_runtime.o sfs_compression.o zeroperl_data.o \
    -Wl,--whole-archive "$REPO_DIR/stubs/libasyncjmp.a" -Wl,--no-whole-archive \
    -Wl,--whole-archive libperl.a -Wl,--no-whole-archive \
    -Wl,--wrap=fopen -Wl,--wrap=open -Wl,--wrap=close -Wl,--wrap=read \
    -Wl,--wrap=lseek -Wl,--wrap=stat -Wl,--wrap=fstat \
    $AUTO_LIBS \
    $(cat ext.libs) \
    -lz -lbz2 -llz4 \
    -lm -lwasi-emulated-signal -lwasi-emulated-getpid \
    -lwasi-emulated-process-clocks -lwasi-emulated-mman \
    -ferror-limit=0

# ---------------------------------------------------------------------------
# Link the final reactor WASM, then run wasm-opt (asyncify + strip).
# ---------------------------------------------------------------------------

# Restore real wasm-opt for asyncify pass
mv /opt/binaryen/bin/wasm-opt-real /opt/binaryen/bin/wasm-opt

if [ "$ASYNCIFY" = "true" ]; then
    wasm-opt zeroperl_reactor.wasm -O3 --strip-debug --enable-bulk-memory \
        --enable-nontrapping-float-to-int --asyncify \
        --pass-arg=asyncify-imports@wasi_snapshot_preview1.fd_read,env.call_host_function \
        ${WASM_OPT_FLAGS} \
        -o zeroperl.wasm
else
    wasm-opt zeroperl_reactor.wasm --strip-debug --enable-bulk-memory \
        --enable-nontrapping-float-to-int --asyncify \
        --pass-arg=asyncify-ignore-imports \
        ${WASM_OPT_FLAGS} \
        -o zeroperl.wasm
fi

# Strip empty name section that wamrc cannot parse
python3 -c "
import sys
data = open('zeroperl.wasm', 'rb').read()
# Custom name section: id=0x00, then LEB size, then 0x04 'name'
marker = b'\x00\x05\x04name'
idx = data.rfind(marker)
if idx > 0 and idx + len(marker) == len(data):
    open('zeroperl.wasm', 'wb').write(data[:idx])
    print(f'Stripped {len(marker)}-byte empty name section')
"
