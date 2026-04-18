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
#   2. Candidate bytes: cor24-run --run build/sw-as24.bin
#                                 -u "$(cat tests/smoke/nop.s)$'\x04'"
#                                 --speed 0 -n <max>
#      UART output is parsed from stdout and decoded to raw bytes.
#   3. Compare build/ref.bin with build/candidate.bin; exit with
#      the diff's return code.
#
# Usage: ./scripts/test.sh
#
# STATUS: step 007 delivers this harness; the exact UART-output
# decoding depends on cor24-run's output format, which can only be
# pinned when a vendored cor24-run exists in this worktree. See
# the "TBD on first live run" block below.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Load vendored tool versions -------------------------------------------

ACTIVE_ENV="$REPO_ROOT/vendor/active.env"
if [ ! -f "$ACTIVE_ENV" ]; then
    echo "error: $ACTIVE_ENV not found" >&2
    exit 4
fi
# shellcheck source=/dev/null
. "$ACTIVE_ENV"

# --- Resolve tools and artifacts -------------------------------------------

COR24_RUN="$REPO_ROOT/vendor/sw-em24/${SW_EM24_VERSION:?}/bin/cor24-run"
SW_AS24_BIN="$REPO_ROOT/build/sw-as24.bin"
INPUT="$REPO_ROOT/tests/smoke/nop.s"
BUILD_DIR="$REPO_ROOT/build"
REF_BIN="$BUILD_DIR/ref.bin"
REF_LST="$BUILD_DIR/ref.lst"
CAND_BIN="$BUILD_DIR/candidate.bin"

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

mkdir -p "$BUILD_DIR"

# --- Step 1: reference bytes via cor24-run --assemble ---------------------

echo "[1/3] reference: cor24-run --assemble $INPUT"
"$COR24_RUN" --assemble "$INPUT" "$REF_BIN" "$REF_LST"
echo "      $(wc -c <"$REF_BIN") byte(s) -> $REF_BIN"

# --- Step 2: candidate bytes via sw-as24 ----------------------------------

# TBD on first live run: the exact cor24-run flag surface for feeding
# .s input over UART and capturing the program's emitted bytes into a
# file (vs. a text-prefixed stdout stream) has to be pinned by
# reading `cor24-run --help` on a populated vendor. Best-guess based
# on sibling-repo usage (sw-cor24-ocaml, sw-cor24-forth):
#
#   --run BIN    -- load and execute a binary program
#   -u INPUT     -- feed INPUT (followed by 0x04 EOT) on UART RX
#   --speed 0    -- run at max speed
#   -n MAX       -- max instructions before halt
#
# Capturing the emitted byte stream is the open question. If
# cor24-run has a --uart-out <file> (or similar) flag that writes
# raw bytes straight to disk, use it:
#
#   "$COR24_RUN" --run "$SW_AS24_BIN" \
#       -u "$(cat "$INPUT")"$'\x04' --speed 0 -n 1000000 \
#       --uart-out "$CAND_BIN"
#
# Otherwise the fallback is to parse stdout: each byte appears as a
# line prefixed `UART output: `; drop the prefix and reinterpret.
# A text-oriented UART capture will mangle 0x00 on many terminals,
# so the --uart-out form is strongly preferred once confirmed.

echo "[2/3] candidate: cor24-run --run $SW_AS24_BIN"
INPUT_TEXT="$(cat "$INPUT")"$'\x04'
# First attempt: raw-UART-to-file flag (to be confirmed).
if "$COR24_RUN" --help 2>&1 | grep -q -- '--uart-out'; then
    "$COR24_RUN" --run "$SW_AS24_BIN" \
        -u "$INPUT_TEXT" --speed 0 -n 1000000 \
        --uart-out "$CAND_BIN"
else
    # Fallback: parse stdout. Each captured byte is assumed to be on
    # its own line after the `UART output: ` prefix; this is a
    # placeholder that will need adjustment once the real output
    # format is observed.
    "$COR24_RUN" --run "$SW_AS24_BIN" \
        -u "$INPUT_TEXT" --speed 0 -n 1000000 2>&1 \
        | awk '/^UART output: / { sub(/^UART output: /, ""); printf "%s", $0 }' \
        > "$CAND_BIN"
fi
echo "      $(wc -c <"$CAND_BIN") byte(s) -> $CAND_BIN"

# --- Step 3: byte-identical compare ---------------------------------------

echo "[3/3] diff $REF_BIN $CAND_BIN"
if diff -q "$REF_BIN" "$CAND_BIN" >/dev/null; then
    echo "smoke test PASS"
    exit 0
else
    echo "smoke test FAIL -- byte output differs" >&2
    echo "reference:" >&2
    od -An -tx1 "$REF_BIN" >&2
    echo "candidate:" >&2
    od -An -tx1 "$CAND_BIN" >&2
    exit 1
fi
