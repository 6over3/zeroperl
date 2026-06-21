#!/usr/bin/env bash
# End-to-end build: container build → artifacts.

set -euo pipefail

# Detect platform: Apple Containers on macOS, Docker elsewhere
if command -v container >/dev/null 2>&1; then
  CONTAINER_CMD="container"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "Error: neither 'container' (Apple Containers) nor 'docker' found" >&2
  exit 1
fi

show_help() {
  cat <<'EOF'
Usage: ./build.sh run [shrink-mode]

End-to-end build: container build → artifact extract.

Arguments:
  run              Required to execute the build (prevents accidental runs)
  shrink-mode      Optional: off or full (default: off)

Environment variables:
  PERL_VERSION         Perl version to build (default: 5.42.2)
  EXIFTOOL_VERSION     ExifTool version (default: 13.55)
  ZLIB_VERSION         zlib version (default: 1.3.2)
  ZEROPERL_NO_CACHE    Pass --no-cache to container build (default: false)
  ZEROPERL_EMBED_PREFIX Embed @INC prefix in wasm (default: true)
  CONTAINER_BUILD_MEMORY Memory limit for container builder (default: 5G)

Examples:
  ./build.sh run              # Build with defaults
  ./build.sh run full         # Build with full shrink mode
  BUILD_EXIFTOOL=false ./build.sh run off  # Perl-only build
EOF
}

if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_help
  exit 0
fi

if [ "$1" != "run" ]; then
  echo "Error: first argument must be 'run'. Use -h for help." >&2
  exit 1
fi

shift

if [ "$#" -gt 1 ]; then
  echo "usage: $0 run [shrink-mode]" >&2
  exit 1
fi

ZEROPERL_SHRINK="${1:-off}"
ZEROPERL_SFS_COMPRESS="${ZEROPERL_SFS_COMPRESS:-}"
PERL_VERSION="${PERL_VERSION:-5.42.2}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.2}"
EXIFTOOL_VERSION="${EXIFTOOL_VERSION:-13.55}"
ZEROPERL_NO_CACHE="${ZEROPERL_NO_CACHE:-false}"
ZEROPERL_EMBED_PREFIX="${ZEROPERL_EMBED_PREFIX:-true}"
echo ZEROPERL_NO_CACHE = $ZEROPERL_NO_CACHE
echo ZEROPERL_EMBED_PREFIX = $ZEROPERL_EMBED_PREFIX

if [ -z "${ZEROPERL_SFS_COMPRESS}" ]; then
  if [ "${ZEROPERL_SHRINK}" = "full" ]; then
    ZEROPERL_SFS_COMPRESS="true"
  else
    ZEROPERL_SFS_COMPRESS="false"
  fi
fi

# wasm-opt flags: GUFA only for full shrink; other optimizations always present.
WASM_OPT_FLAGS='--generate-global-effects --low-memory-unused -Oz --enable-bulk-memory --enable-sign-ext --enable-reference-types --enable-multivalue --disable-extended-const --strip-producers'
if [ "${ZEROPERL_SHRINK}" = "full" ]; then
  WASM_OPT_FLAGS="--gufa ${WASM_OPT_FLAGS}"
fi

# Optional: container builder RAM. See README / container build --help.
CONTAINER_BUILD_MEMORY="${CONTAINER_BUILD_MEMORY:-5G}"
BUILD_MEM=()
if [ -n "${CONTAINER_BUILD_MEMORY}" ]; then
  BUILD_MEM=(--memory "${CONTAINER_BUILD_MEMORY}")
fi

CONTAINER_BUILD_PARAMETERS=""
if [ $ZEROPERL_NO_CACHE == "true" ]; then
	CONTAINER_BUILD_PARAMETERS="--no-cache"
fi
echo CONTAINER_BUILD_PARAMETERS =  $CONTAINER_BUILD_PARAMETERS

${CONTAINER_CMD} build \
  ${BUILD_MEM[@]+"${BUILD_MEM[@]}"} \
  --build-arg "PERL_VERSION=${PERL_VERSION}" \
  --build-arg "BUILD_EXIFTOOL=${BUILD_EXIFTOOL:-true}" \
  --build-arg "EXIFTOOL_VERSION=${EXIFTOOL_VERSION}" \
  --build-arg "ZLIB_VERSION=${ZLIB_VERSION}" \
  --build-arg "WASM_OPT_FLAGS=${WASM_OPT_FLAGS}" \
  --build-arg "ZEROPERL_SHRINK=${ZEROPERL_SHRINK}" \
  --build-arg "ZEROPERL_SFS_COMPRESS=${ZEROPERL_SFS_COMPRESS}" \
  --build-arg "ZEROPERL_EMBED_PREFIX=${ZEROPERL_EMBED_PREFIX}" \
  $CONTAINER_BUILD_PARAMETERS \
  -t zeroperl \
  .

rm -rf output > /dev/null
mkdir -p output

mkdir -p "${PWD}/output"
${CONTAINER_CMD} run --rm zeroperl:latest sh -c 'cd /artifacts && tar cf - .' | tar xf - -C "${PWD}/output"

# Core smoke test: wasm-smoke.mjs runs core + core-mod (+ ExifTool if available)
if [ "${ZEROPERL_EMBED_PREFIX}" = "true" ]; then
    node tools/wasm-smoke.mjs output/zeroperl.wasm
else
    node tools/wasm-smoke.mjs output/zeroperl.wasm output/perl-wasi-prefix
fi

echo "Done"
