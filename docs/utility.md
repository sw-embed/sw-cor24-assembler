# Utility — Device-side hex-to-binary loader

**Status:** Forward-looking design sketch (not in the Relaunch saga)
**Scope:** Long-lived reference. Updated as the companion utility
becomes concrete in later sagas.

## Why a utility at all?

`sw-as24` emits its machine-code output as printable hex ASCII on
UART TX (two characters per byte). `docs/design.md` §"Why
hex-encoded UART output" covers the drivers: transport robustness,
human-debuggability, and a sidestep of cor24-run's 0x00 display
filter. That encoding choice is great for *observation* and for
*shipping bytes over a text channel*, but a text string is not
executable. Something has to turn `"FF"` back into the byte
`0xFF` before the CPU can branch to it.

During development today, the something is `scripts/hex2bin.sh` —
a host-side shell script that wraps `xxd -r -p`. That works when
a developer is driving from a laptop with `cor24-run` and UART,
but it assumes there *is* a host. Once COR24 hardware is
self-hosted (a monitor with a shell, a resident editor, a
scripting language), the host disappears. The decoder has to
move on-device.

## The pair

```
   sw-as24               (future) hex-loader
      |                           |
      v                           v
   +------+   UART / pipe    +----------+   raw bytes   +---------+
   | src  | ---------------> |  decode  | ------------> | memory  |
   | .s   |  "FF" "00" ...   |   "FF"   |   0xFF ...    |  buffer |
   +------+                  |  -> 0xFF |               +---------+
                             +----------+                    |
                                                     (jmp to start addr)
```

Two programs, same data, two stages:

| Stage            | Input               | Output                        | Where it runs                |
| ---------------- | ------------------- | ----------------------------- | ---------------------------- |
| sw-as24          | `.s` text on UART   | hex-ASCII stream on UART      | COR24 (cross-assembled today, self-hosted later) |
| hex-loader       | hex-ASCII stream    | bytes in memory at `&dest`    | COR24 (always on-device)     |
| (optional) exec  | bytes at `&dest`    | control transfer              | COR24                        |

The hex-loader is also usable standalone: any program or user that
can type or paste hex on UART can have those bytes appear in memory
at a chosen address. That pattern — paste-to-execute — is a
classical monitor feature on small systems (e.g., ROM monitors on
1970s/80s microcomputers), so the utility earns its keep beyond
the sw-as24 pairing.

## Device-side vs host-side

```
  +----------------- dev loop (today) -----------------+
  |                                                    |
  |  laptop                  COR24 (emulator/FPGA)     |
  |  ------                  ---------------------     |
  |  vi src/foo.s  --UART->  sw-as24  --UART->  laptop |
  |  scripts/hex2bin.sh <----                          |
  |  cor24-run --load-binary foo.bin@addr --entry addr |
  |                                                    |
  +----------------------------------------------------+

  +-------------- self-hosted loop (future) ------------+
  |                                                     |
  |  COR24 (single machine, no host)                    |
  |  -----------------------------                      |
  |  yocto-ed foo.s                                     |
  |  monitor: run sw-as24 < foo.s | sw-hexload @ 0x8000 |
  |  monitor: go 0x8000                                 |
  |                                                     |
  +-----------------------------------------------------+
```

Same data flow. The laptop's role evaporates once the monitor and
the device-side utility are in place.

## Proposed shape

**Name (TBD):** `sw-hexload`. Source `src/sw-hexload.s`. Binary
`build/sw-hexload.bin`. Naming follows the ecosystem's `sw-` prefix
and the Unix-ish `hexload` verb.

**Inputs:**
- UART RX: hex-ASCII stream. Two chars per byte, any case,
  tolerant of whitespace (space, tab, CR, LF) between pairs.
- Destination address: how to receive this is an open question;
  options in §"Open questions".

**Output:**
- A contiguous byte sequence starting at the destination address.
- Terminator semantics TBD: could be an explicit sentinel char
  (e.g., `.` or `!`), an EOT (0x04), or a length prefix. A
  sentinel keeps the stream purely character-oriented.

**Non-goals (at least for first landing):**
- Checksums / framing (Intel HEX, S-record). Nice to have, not
  required for the self-hosting loop. Later saga.
- Multi-segment loads (non-contiguous regions). The first version
  handles one address range.
- Relocations. The sw-as24 output is already absolute-addressed;
  the loader just stores bytes verbatim.
- Automatic branch-to-dest after load. A separate monitor
  command (`go <addr>`) performs the transfer; keeping them
  orthogonal is safer and matches the Unix-pipeline model.

## Sketch (not final)

```
; src/sw-hexload.s (draft)
;
; Read hex-ASCII from UART RX until sentinel '.', decode each
; pair into a byte, store at consecutive memory addresses starting
; at $dest. Report the final length on UART TX so the caller knows
; how many bytes landed.
;
; Entry: r0 = destination address (abs24)
; Exit : r0 = number of bytes written
;        halts via self-branch or `jmp (r1)` return depending on
;        monitor calling convention (TBD).

; pseudo-code outline -- exact register assignment pinned when
; this lands:
;
;   dest_ptr := r0
;   count    := 0
;   loop:
;     high_nibble <- getc
;     if high_nibble == '.': goto done
;     if high_nibble is whitespace: loop
;     low_nibble  <- getc
;     byte := hex_pair_to_byte(high_nibble, low_nibble)
;     mem[dest_ptr] := byte
;     dest_ptr += 1
;     count    += 1
;     goto loop
;   done:
;     r0 := count
;     return
```

The `hex_pair_to_byte` helper is the real work: an ASCII digit
`'0'..'9'` maps to `0..9`, `'A'..'F'`/`'a'..'f'` to `10..15`. No
table needed; straight arithmetic + range checks.

Interestingly, sw-as24 will need the *inverse* helper — byte-to-hex
— once it emits more than the two literals in saga 1. The two
helpers are duals; they can share bit-fiddling primitives even if
they live in different programs.

## Open questions

- **Q1. How does the loader receive its destination address?**
  Options: a UART preamble ("@addr\n<hex>.\n"), a compiled-in
  default overridden by monitor patch, or a subroutine calling
  convention where the monitor passes the address in a register.
  The subroutine form is cleanest once the monitor exists.

- **Q2. Terminator semantics.** Sentinel char, EOT (0x04), length
  prefix, or a monitor-level EOF on the UART stream? Sentinel
  keeps the utility usable standalone from a human paste; length
  prefix is machine-friendlier. May support both.

- **Q3. Error reporting.** What if the stream contains an invalid
  hex digit, or an odd number of digits, or runs past a safe
  memory range? Three-tier story probably: error code in r0,
  sentinel byte on UART, and partial-state left intact so the
  monitor can inspect.

- **Q4. Relationship to a future host-monitor ABI.** Once
  `sw-cor24-monitor` exists (per the umbrella README under
  "Native tools"), sw-hexload may be a monitor built-in, a
  loadable utility, or a subroutine callable via a service
  vector. Decision deferred to the monitor saga.

## Where this fits in the saga plan

`sw-hexload` is **not** in the Relaunch saga (saga 1). The relaunch
delivers scaffolding + a nop-only sw-as24 with host-side `hex2bin.sh`.

A plausible home for `sw-hexload` is immediately after
`sw-cor24-monitor` gains enough surface to host utilities — see
`docs/plan.md` §"11. Hosting-model decision" and the subsequent
sagas. The exact saga # will be pinned when the monitor work
becomes current.

Until then, this document stands as the north-star design for the
pair (assembler + loader). It exists now so later sagas don't
re-derive the rationale from scratch.
