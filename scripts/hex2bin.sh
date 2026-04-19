#!/usr/bin/env bash
#
# hex2bin.sh -- decode hex-encoded ASCII text on stdin to raw bytes
# on stdout.
#
# sw-as24 emits its machine-code output as hex text (two ASCII
# characters per byte) because cor24-run's UART TX observation
# paths silently drop 0x00. Using printable hex chars sidesteps
# that filter; this script is the host-side inverse.
#
# Input: ASCII hex digits, any case, ignoring whitespace.
# Output: raw bytes (1 byte per 2 hex chars).
#
# Usage:
#   echo -n "00FF" | ./scripts/hex2bin.sh > out.bin
#   cor24-run ... | ./scripts/hex2bin.sh > out.bin

set -euo pipefail

# xxd -r -p reverses a plain hex dump (no address/ascii columns,
# tolerant of whitespace). All major distros ship xxd in vim-common.
xxd -r -p
