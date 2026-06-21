# Dockerfile for building zeroperl - Perl compiled to WebAssembly
#
# Usage:
#   docker build -t zeroperl .
#   docker run --rm -v $(pwd)/output:/output zeroperl cp -r /artifacts/. /output/
#
# Quick iteration on zeroperl.c/stubs (uses cached wasi-perl stage):
#   docker build --target final -t zeroperl .

FROM debian:trixie-slim AS base

ARG TARGETPLATFORM
ARG WASI_SDK_VERSION=27
ARG BINARYEN_VERSION=129
ARG ZLIB_VERSION=1.3.2

ENV WASI_SDK_VERSION=${WASI_SDK_VERSION} \
    WASI_SDK_PATH=/opt/wasi-sdk

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl xz-utils zlib1g-dev libbz2-dev liblz4-dev lz4 ca-certificates \
    clang llvm lld nodejs npm patch perl python3 perltidy \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(uname -m) && \
    case "${TARGETPLATFORM:-linux/$ARCH}" in \
        linux/arm64*|linux/aarch64*) WASI_ARCH="arm64"; BIN_ARCH="aarch64" ;; \
        *) WASI_ARCH="x86_64"; BIN_ARCH="x86_64" ;; \
    esac && \
    mkdir -p /opt/wasi-sdk /opt/binaryen && \
    curl -fsSL "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION}/wasi-sdk-${WASI_SDK_VERSION}.0-${WASI_ARCH}-linux.tar.gz" \
        | tar -xzf - --strip-components=1 -C /opt/wasi-sdk && \
    curl -fsSL "https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-${BIN_ARCH}-linux.tar.gz" \
        | tar -xzf - --strip-components=1 -C /opt/binaryen && \
    find /opt/wasi-sdk/share/wasi-sysroot/ -name "setjmp.h" -delete

ENV PATH="/opt/binaryen/bin:${PATH}"

COPY pipeline/build-wasi-libs.sh /build/repo/pipeline/
RUN chmod +x /build/repo/pipeline/build-wasi-libs.sh && \
    ZLIB_VERSION="${ZLIB_VERSION}" /build/repo/pipeline/build-wasi-libs.sh

RUN mkdir -p /zeroperl


FROM base AS native-perl

ARG PERL_VERSION=5.42.2
ARG EXIFTOOL_VERSION=13.55
ARG BUILD_EXIFTOOL=true
ARG EXIFTOOL_WARMUP_MODE=curated

ENV PERL_VERSION=${PERL_VERSION} \
    EXIFTOOL_VERSION=${EXIFTOOL_VERSION} \
    BUILD_EXIFTOOL=${BUILD_EXIFTOOL} \
    EXIFTOOL_WARMUP_MODE=${EXIFTOOL_WARMUP_MODE} \
    NATIVE_DIR=/build/native \
    REPO_DIR=/build/repo

COPY pipeline/build-native-perl.sh pipeline/build-exiftool.sh /build/repo/pipeline/
RUN chmod +x /build/repo/pipeline/*.sh

RUN /build/repo/pipeline/build-native-perl.sh
RUN if [ "${BUILD_EXIFTOOL}" = "true" ]; then /build/repo/pipeline/build-exiftool.sh; fi


FROM native-perl AS wasi-perl

ARG TRIM=true
ARG ZEROPERL_SHRINK=off
ARG ZEROPERL_SFS_COMPRESS=
ARG ZEROPERL_EMBED_PREFIX=true
ARG PERL_VERSION

ENV PERL_VERSION=${PERL_VERSION} \
    BUILD_EXIFTOOL=${BUILD_EXIFTOOL} \
    TRIM=${TRIM} \
    ZEROPERL_SHRINK=${ZEROPERL_SHRINK} \
    ZEROPERL_SFS_COMPRESS=${ZEROPERL_SFS_COMPRESS} \
    ZEROPERL_EMBED_PREFIX=${ZEROPERL_EMBED_PREFIX} \
    WASM_DIR=/build/wasm

# Copy package files first for npm cache layer
# zeroperl-ts must be present because tools/package.json references it via file:../zeroperl-ts
COPY zeroperl-ts/ /build/repo/zeroperl-ts/
COPY tools/package.json tools/package-lock.json /build/repo/tools/
RUN cd /build/repo/tools && npm ci

# Copy remaining source (separate COPY per dir to preserve directory structure)
COPY wasi-bin/ /build/repo/wasi-bin/
COPY pipeline/ /build/repo/pipeline/
COPY patches/ /build/repo/patches/
COPY stubs/ /build/repo/stubs/
COPY tools/ /build/repo/tools/
COPY tests/smoke/ /build/repo/tests/smoke/
COPY tests/sfs/ /build/repo/tests/sfs/
RUN chmod +x /build/repo/wasi-bin/* /build/repo/pipeline/*.sh \
    /build/repo/tools/*.sh /build/repo/tools/*.pl && \
    mkdir -p /build/repo/gen

RUN mv /opt/binaryen/bin/wasm-opt /opt/binaryen/bin/wasm-opt-real && \
    cp /build/repo/tools/wasm-opt /opt/binaryen/bin/wasm-opt && \
    chmod +x /opt/binaryen/bin/wasm-opt

RUN /build/repo/tools/regen-wasm-shrink.sh

RUN /build/repo/pipeline/build-wasi-perl.sh

RUN mv /opt/binaryen/bin/wasm-opt-real /opt/binaryen/bin/wasm-opt

RUN /build/repo/pipeline/prepare-prefix.sh

RUN node /build/repo/tests/sfs/test-generator.js

RUN make -C /build/repo/tests/sfs test-sfs

RUN if [ "$BUILD_EXIFTOOL" = "true" ]; then /build/repo/tools/wasm-smoke.sh /build/repo; fi


FROM wasi-perl AS final

ARG STACK_SIZE=8388608
ARG INITIAL_MEMORY=33554432
ARG ASYNCIFY=true
ARG WASM_OPT_FLAGS=""
ARG ZEROPERL_EMBED_PREFIX=true

ENV STACK_SIZE=${STACK_SIZE} \
    INITIAL_MEMORY=${INITIAL_MEMORY} \
    ASYNCIFY=${ASYNCIFY} \
    WASM_OPT_FLAGS=${WASM_OPT_FLAGS} \
    ZEROPERL_EMBED_PREFIX=${ZEROPERL_EMBED_PREFIX}

COPY stubs/ /build/repo/stubs/

RUN /build/repo/pipeline/build-wasm.sh

RUN if [ "${ZEROPERL_EMBED_PREFIX}" = "true" ]; then \
      exiftool_arg=""; \
      if [ "${BUILD_EXIFTOOL}" = "true" ]; then exiftool_arg="/build/repo/exiftool.min.pl"; fi; \
      node /build/repo/tools/wasm-smoke.mjs /build/wasm/zeroperl.wasm ${exiftool_arg}; \
    fi

RUN mkdir -p /artifacts && \
    cp /build/wasm/config.h /build/wasm/zeroperl.wasm /build/wasm/zeroperl_reactor.wasm /artifacts/ && \
    cp -r /zeroperl /artifacts/perl-wasi-prefix && \
    [ "${BUILD_EXIFTOOL}" = "true" ] && [ -f /build/repo/exiftool.min.pl ] && \
        cp /build/repo/exiftool.min.pl /artifacts/ || true


FROM debian:trixie-slim
COPY --from=final /artifacts /artifacts
