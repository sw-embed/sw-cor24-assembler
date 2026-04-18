#!/usr/bin/env bash
#
# build.sh -- Assemble src/sw-as24.s into build/sw-as24.bin using
# the vendored cor24-run. Also emits a listing (build/sw-as24.lst)
# for debugging.
#
# cor24-run --assemble takes three positional arguments: the input
# .s file, the output .bin file, and the output .lst file. That
# invocation is the one the sw-cor24-ocaml build.sh uses and is the
# reference for this project.
#
# Usage: ./scripts/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Load vendored tool versions -------------------------------------------

ACTIVE_ENV="$REPO_ROOT/vendor/active.env"
if [ ! -f "$ACTIVE_ENV" ]; then
    echo "error: $ACTIVE_ENV not found" >&2
    echo "hint: ensure vendor/ is initialised (step 003-vendor-manifest)" >&2
    exit 4
fi
# shellcheck source=/dev/null
. "$ACTIVE_ENV"

# --- Resolve cor24-run -----------------------------------------------------

COR24_RUN="$REPO_ROOT/vendor/sw-em24/${SW_EM24_VERSION:?SW_EM24_VERSION unset}/bin/cor24-run"
if [ ! -x "$COR24_RUN" ]; then
    echo "error: cor24-run not found at $COR24_RUN" >&2
    echo "hint: run 'just vendor-fetch' to materialise it from the" >&2
    echo "      sibling sw-cor24-emulator repo" >&2
    exit 1
fi

# --- Paths -----------------------------------------------------------------

SRC="$REPO_ROOT/src/sw-as24.s"
BUILD_DIR="$REPO_ROOT/build"
BIN="$BUILD_DIR/sw-as24.bin"
LST="$BUILD_DIR/sw-as24.lst"

if [ ! -f "$SRC" ]; then
    echo "error: $SRC not found" >&2
    echo "hint: step 008-sw-as24-skeleton writes this file" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"

# --- Assemble -------------------------------------------------------------

echo "assembling $SRC"
echo "  -> $BIN"
echo "  -> $LST"
"$COR24_RUN" --assemble "$SRC" "$BIN" "$LST"
echo "build: done"
