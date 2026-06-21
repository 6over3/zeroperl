#!/bin/sh
set -e

ROOT="${1:-.}"
SMOKE_SRC="$ROOT/tests/smoke"
SMOKE_TMP="${TMPDIR:-/tmp}/zeroperl-smoke.$$"
LOG_FILE="$SMOKE_TMP/smoke.log"
MISSING_OUT="$ROOT/gen/wasm-missing-paths.txt"
PERSISTENT_LOG="$ROOT/gen/wasm-smoke.log"

cleanup() {
    rm -rf "$SMOKE_TMP"
}
trap cleanup EXIT INT TERM

find_perl_lib_base() {
    lib_root="$1"
    find "$lib_root" -mindepth 1 -maxdepth 1 -type d \
        | awk -F/ 'tolower($NF) ~ /^[0-9]+(\.[0-9]+)*$/ { print; exit }'
}

mkdir -p "$SMOKE_TMP" "$ROOT/gen"

if [ -f "/build/repo/exiftool.min.pl" ] && [ -d "/zeroperl/lib" ] && [ -x "/build/native/prefix/bin/perl" ]; then
    PERL_BIN="/build/native/prefix/bin/perl"
    EXIFTOOL_SCRIPT="/build/repo/exiftool.min.pl"
    PERL_LIB_BASE="$(find_perl_lib_base /zeroperl/lib)"
    USE_ARCH_LIB=1
elif [ -f "$ROOT/output/exiftool.min.pl" ] && [ -d "$ROOT/output/perl-wasi-prefix/lib" ]; then
    PERL_BIN="${PERL_BIN:-perl}"
    EXIFTOOL_SCRIPT="$ROOT/output/exiftool.min.pl"
    PERL_LIB_BASE="$(find_perl_lib_base "$ROOT/output/perl-wasi-prefix/lib")"
    PERL_SITE_BASE="$(find_perl_lib_base "$ROOT/output/perl-wasi-prefix/lib/site_perl" 2>/dev/null || true)"
    USE_ARCH_LIB=0
else
    echo "error: unsupported layout; expected either wasi build container layout or local output artifacts" >&2
    exit 1
fi

if [ -z "$PERL_LIB_BASE" ]; then
    echo "error: unable to locate perl lib version directory" >&2
    exit 1
fi

ARCH_LIB="$PERL_LIB_BASE/wasm32-wasi"
if [ "$USE_ARCH_LIB" -eq 1 ]; then
    if [ ! -d "$ARCH_LIB" ]; then
        echo "error: missing arch lib directory: $ARCH_LIB" >&2
        exit 1
    fi
fi

decode_b64() {
    src="$1"
    dst="$2"
    if base64 -D -i "$src" -o "$dst" >/dev/null 2>&1; then
        return 0
    fi
    base64 -d "$src" > "$dst"
}

decode_b64 "$SMOKE_SRC/sample.jpg.b64" "$SMOKE_TMP/sample.jpg"
decode_b64 "$SMOKE_SRC/sample.tiff.b64" "$SMOKE_TMP/sample.tiff"
cp "$SMOKE_SRC/sample.xmp" "$SMOKE_TMP/sample.xmp"

if [ "$USE_ARCH_LIB" -eq 1 ]; then
    PERL5LIB="$ARCH_LIB:$PERL_LIB_BASE"
else
    PERL5LIB="$PERL_LIB_BASE"
    if [ -n "${PERL_SITE_BASE:-}" ]; then
        PERL5LIB="$PERL_SITE_BASE:$PERL5LIB"
    fi
fi
export PERL5LIB

run_smoke_cmd() {
    if ! "$PERL_BIN" "$EXIFTOOL_SCRIPT" "$@" >>"$LOG_FILE" 2>&1; then
        return 1
    fi
    return 0
}

smoke_status=0
run_smoke_cmd -ver || smoke_status=1
run_smoke_cmd "$SMOKE_TMP/sample.jpg" || smoke_status=1
run_smoke_cmd "$SMOKE_TMP/sample.tiff" || smoke_status=1
run_smoke_cmd "$SMOKE_TMP/sample.jpg" "$SMOKE_TMP/sample.xmp" || smoke_status=1

perl "$ROOT/tools/extract-missing-paths.pl" "$LOG_FILE" "$MISSING_OUT"
cp "$LOG_FILE" "$PERSISTENT_LOG"

if [ "$smoke_status" -ne 0 ]; then
    echo "error: smoke command failure; see $PERSISTENT_LOG" >&2
    echo "--- smoke log follows ---" >&2
    cat "$PERSISTENT_LOG" >&2
    exit 1
fi

if [ -s "$MISSING_OUT" ]; then
    echo "error: missing Perl paths detected during smoke run:" >&2
    cat "$MISSING_OUT" >&2
    exit 1
fi

echo "Smoke run completed with no missing module paths"
