#!/usr/bin/env bash
#
# test.sh -- smoke test for the sw-as24 relaunch saga.
#
# Asserts that sw-as24 (self-hosted) produces the same machine code
# as cor24-run (the vendored Rust reference) for tests/smoke/nop.s.
# That input is a single `nop`, which encodes to one byte: 0x00.
#
# Pipeline:
#   1. Reference bytes: cor24-run --assemble tests/smoke/nop.s
#                                 build/ref.bin build/ref.lst
#      Produces a raw .bin with the Rust assembler's output.
#   2. Candidate bytes: cor24-run --load-binary build/sw-as24.bin@0
#                                 --entry 0
#                                 -u "<nop.s>\x04"
#                                 --speed 0 -n <max>
#      sw-as24 emits its output as hex-encoded ASCII on UART TX
#      (see src/sw-as24.s header for why). We parse cor24-run's
#      `UART output: ` summary line, strip the banner, and decode
#      the hex via scripts/hex2bin.sh -> build/candidate.bin.
#   3. Compare build/ref.bin with build/candidate.bin; exit with
#      the diff's return code.
#
# Usage: ./scripts/test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ACTIVE_ENV="$REPO_ROOT/vendor/active.env"
if [ ! -f "$ACTIVE_ENV" ]; then
    echo "error: $ACTIVE_ENV not found" >&2
    exit 4
fi
# shellcheck source=/dev/null
. "$ACTIVE_ENV"

COR24_RUN="$REPO_ROOT/vendor/sw-em24/${SW_EM24_VERSION:?}/bin/cor24-run"
HEX2BIN="$SCRIPT_DIR/hex2bin.sh"
SW_AS24_BIN="$REPO_ROOT/build/sw-as24.bin"
INPUT="$REPO_ROOT/tests/smoke/nop.s"
BUILD_DIR="$REPO_ROOT/build"
REF_BIN="$BUILD_DIR/ref.bin"
REF_LST="$BUILD_DIR/ref.lst"
CAND_BIN="$BUILD_DIR/candidate.bin"
CAND_RAW="$BUILD_DIR/candidate.raw"

if [ ! -x "$COR24_RUN" ]; then
    echo "error: cor24-run not found at $COR24_RUN" >&2
    echo "hint: run 'just vendor-fetch' first" >&2
    exit 1
fi
if [ ! -f "$SW_AS24_BIN" ]; then
    echo "error: $SW_AS24_BIN not found" >&2
    echo "hint: run 'just build' first" >&2
    exit 1
fi
if [ ! -f "$INPUT" ]; then
    echo "error: $INPUT not found" >&2
    exit 1
fi
if [ ! -x "$HEX2BIN" ]; then
    echo "error: $HEX2BIN not found or not executable" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"

# --- Step 1: reference bytes via cor24-run --assemble ---------------------

echo "[1/3] reference: cor24-run --assemble $INPUT"
"$COR24_RUN" --assemble "$INPUT" "$REF_BIN" "$REF_LST" >/dev/null
echo "      $(wc -c <"$REF_BIN") byte(s) -> $REF_BIN"

# --- Step 2: candidate bytes via sw-as24 ----------------------------------
#
# Feed nop.s over UART RX (with 0x04 EOT terminator so sw-as24's
# read loop terminates cleanly). cor24-run prints the captured TX
# bytes on a single summary line:
#     UART output: S00
# where 'S' is sw-as24's startup banner (one byte) and the remainder
# is the hex-encoded machine code output.

echo "[2/3] candidate: cor24-run --load-binary sw-as24.bin@0 -u '<nop.s>'"
INPUT_TEXT="$(cat "$INPUT")"$'\x04'
CAND_FULL="$("$COR24_RUN" \
    --load-binary "$SW_AS24_BIN@0" --entry 0 \
    -u "$INPUT_TEXT" --speed 0 -n 1000000 2>&1 \
    | awk '/^UART output: / { sub(/^UART output: /, ""); print; exit }')"

if [ -z "$CAND_FULL" ]; then
    echo "error: no 'UART output: ' line in cor24-run output" >&2
    exit 1
fi
echo "      raw UART text: '$CAND_FULL'"

# Strip the banner. Currently sw-as24 emits a one-character banner
# 'S'; strip one leading char. If the banner grows, this strip must
# match. (Later sagas may move to framing markers.)
CAND_HEX="${CAND_FULL#?}"
printf '%s' "$CAND_HEX" > "$CAND_RAW"
"$HEX2BIN" < "$CAND_RAW" > "$CAND_BIN"
echo "      hex: '$CAND_HEX' -> $(wc -c <"$CAND_BIN") byte(s) -> $CAND_BIN"

# --- Step 3: byte-identical compare ---------------------------------------

echo "[3/3] diff $REF_BIN $CAND_BIN"
if diff -q "$REF_BIN" "$CAND_BIN" >/dev/null; then
    echo "smoke test PASS"
    exit 0
else
    echo "smoke test FAIL -- byte output differs" >&2
    echo "reference:" >&2
    od -An -v -tx1 "$REF_BIN" >&2
    echo "candidate:" >&2
    od -An -v -tx1 "$CAND_BIN" >&2
    exit 1
fi
