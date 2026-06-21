#!/bin/sh
set -e

REPO_DIR="${REPO_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
ZEROPERL_SHRINK="${ZEROPERL_SHRINK:-full}"

if [ "$ZEROPERL_SHRINK" = "off" ]; then
    echo "determinism check skipped: ZEROPERL_SHRINK=off"
    exit 0
fi

snapshot_file() {
    src="$1"
    dst="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
    else
        : > "$dst"
    fi
}

compare_file() {
    left="$1"
    right="$2"
    label="$3"
    if ! cmp -s "$left" "$right"; then
        echo "error: non-deterministic output for $label" >&2
        diff -u "$left" "$right" || true
        exit 1
    fi
}

run_regen() {
    REPO_DIR="$REPO_DIR" NATIVE_DIR="$NATIVE_DIR" ZEROPERL_SHRINK="$ZEROPERL_SHRINK" \
        "$REPO_DIR/tools/regen-wasm-shrink.sh"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

run_regen
snapshot_file "$REPO_DIR/gen/traced-files.txt" "$TMP_DIR/traced-files.a"
snapshot_file "$REPO_DIR/gen/xs-static-ext.txt" "$TMP_DIR/xs-static-ext.a"
snapshot_file "$REPO_DIR/gen/hints-static-ext.fragment" "$TMP_DIR/hints-static-ext.a"
snapshot_file "$REPO_DIR/gen/wasm-auto-libs.txt" "$TMP_DIR/wasm-auto-libs.a"
snapshot_file "$REPO_DIR/gen/xs_init.inc" "$TMP_DIR/xs-init.a"

run_regen
snapshot_file "$REPO_DIR/gen/traced-files.txt" "$TMP_DIR/traced-files.b"
snapshot_file "$REPO_DIR/gen/xs-static-ext.txt" "$TMP_DIR/xs-static-ext.b"
snapshot_file "$REPO_DIR/gen/hints-static-ext.fragment" "$TMP_DIR/hints-static-ext.b"
snapshot_file "$REPO_DIR/gen/wasm-auto-libs.txt" "$TMP_DIR/wasm-auto-libs.b"
snapshot_file "$REPO_DIR/gen/xs_init.inc" "$TMP_DIR/xs-init.b"

compare_file "$TMP_DIR/traced-files.a" "$TMP_DIR/traced-files.b" "gen/traced-files.txt"
compare_file "$TMP_DIR/xs-static-ext.a" "$TMP_DIR/xs-static-ext.b" "gen/xs-static-ext.txt"
compare_file "$TMP_DIR/hints-static-ext.a" "$TMP_DIR/hints-static-ext.b" "gen/hints-static-ext.fragment"
compare_file "$TMP_DIR/wasm-auto-libs.a" "$TMP_DIR/wasm-auto-libs.b" "gen/wasm-auto-libs.txt"
compare_file "$TMP_DIR/xs-init.a" "$TMP_DIR/xs-init.b" "gen/xs_init.inc"

echo "determinism check passed"
