# as24 Output Formats

The reference assemblers produce four distinct output formats.
sw-as24 must emit at least one of them (load-and-go `.lgo` is
the most natural choice for on-device self-hosting) and should
be able to emit a matching listing for debugging.

## 1. Load-and-go (`.lgo`) — as24.c default

The default output of `as24.c` (invoked without `-l`, `-c`, or
`-S`). Plain ASCII, one record per line, newline-terminated.

### 1.1 Record types

| Prefix | Form | Meaning |
|--------|------|---------|
| `L`    | `Laaaaaa<hex…>` | Load: place bytes starting at address `aaaaaa` |
| `G`    | `Gaaaaaa` | Go: begin execution at address `aaaaaa` |

- `aaaaaa` — 6 uppercase hex digits, the 24-bit target address
  (`printf("%06X", …)`).
- `<hex…>` — sequence of 2-digit hex bytes, no separators, in
  the order they appear in memory. Each byte renders as
  `"%02X"` (uppercase).

### 1.2 Structure

1. One `L` record for every assembled instruction, directive
   with emitted bytes (`.byte`, `.word`), and common block.
   Records appear in source order within their section; all
   `.text` bytes come first, then `.data`, then `.bss`.
2. One `G` record at the end **if and only if** a symbol named
   `start` is defined. The `G` address is that symbol's value.

### 1.3 Example

Assembling:

```asm
        .text
        lc      r0, 5
        bra     .
```

produces (assuming the assembler places text at 0):

```
L000000440500
```

(opcode `0x44` = `lc r0, imm8`, `0x05` = literal 5, then
`bra .` encoded as `0x13 0xfe` — the displacement −2 wraps to
`0xFE` sign-extended to 8 bits.) If a `start:` label is defined
at `0x000000`, a `G000000` line follows.

### 1.4 Notes

- Lowercase hex is *not* emitted by as24.c. Monitor/loader
  implementations should still accept lowercase on input as a
  courtesy.
- The format is UART-friendly: every byte is printable ASCII,
  so it survives 7-bit serial links and does not collide with
  `cor24-run`'s null-filtering behaviour (which strips `0x00`
  bytes from TX observations). See `docs/utility.md` for the
  `sw-hexload` sketch that turns `.lgo` back into bytes in
  memory on the target.

## 2. Listing (`.lst`) — as24.c `-l`

Human-readable assembly listing. Produced by
`as24.c -l < source.s > out.lst`.

### 2.1 Line shape

For an instruction:

```
aaaaaa bb bb bb bb     mnemonic operands            ; original comment
```

- `aaaaaa` — 6 lowercase hex digits, the byte address
  (`printf("%06x", …)`).
- Up to four `bb` byte columns, each lowercase 2-digit hex,
  space-separated; short instructions pad the unused columns
  with three spaces.
- Five spaces of padding.
- The disassembled mnemonic (from the same `instab[]` used to
  encode), with `\t` between mnemonic and operands.
- If the source line had a `;` comment, it is copied to the
  output starting at column 48.

For a label:

```
label_name:
```

on its own line. Blank line inserted before a label that
follows an instruction.

For `.byte`:

```
aaaaaa bb
aaa+1  bb
…
```

one line per byte. For `.word` and data symbol references:

```
aaaaaa bb bb bb
```

one line per 24-bit word.

For a location-counter bump (`. = . + N`) or `.comm`:

```
aaaaaa
```

(the address at that point, no bytes emitted).

The listing ends with a single line `aaaaaa` holding the final
location counter.

### 2.2 Tab handling

as24.c calls `untabify()` on every listing line before output,
expanding `\t` to spaces on 8-column tab stops. The column
positions are therefore stable; sw-as24 should reproduce the
expanded form exactly if byte-identical listings are needed
(currently they aren't — byte-identity is defined on `.bin` /
`.lgo` only).

## 3. Object file (`.obj`) — as24.c `-c`

Linkable object for the historical `ld24` linker. One record
per line, space-separated fields.

| Prefix | Fields | Meaning |
|--------|--------|---------|
| `D section name` | | Define local symbol (label) at current location in section |
| `G section name` | | Define global symbol |
| `C section name size` | | Declare common block |
| `A section size` | | Advance location counter (from `. = . + N`) |
| `B section bb bb …` | | Raw bytes into section |
| `R section bb bb bb name mode` | | Relocatable reference: patch a 24-bit word at current position with `name`'s value. `mode` 0 = data, 1 = code |
| `X section bb bb bb name mode` | | External reference (unresolved, left to linker) |
| `S -1` | | End of object |

Section numbers: 0 = `.text`, 1 = `.data`, 2 = `.bss`.

### 3.1 Notes

- `B` records carry one section's bytes broken up by the
  original instruction forms — they are *not* consolidated.
- `R` vs `X`: if the symbol is visible in the current
  translation unit it's `R` (local relocation); otherwise `X`
  (external to be resolved at link time).
- sw-as24 is **not required** to emit `.obj`. The self-hosted
  flow will likely skip linking entirely and emit `.lgo`
  directly.

## 4. Assembler-source roundtrip (`.s`) — as24.c `-S`

`as24.c -S` pretty-prints the internal form list as plain
assembler source — the input assembler after any `-O`
transformations are applied. Useful for inspecting optimizer
output but not a build artifact. sw-as24 need not implement.

## 5. Raw binary (`.bin`) — cor24-run convention (NOT as24.c)

The current bootstrap flow uses `cor24-run --assemble` which
produces a raw binary image (no record prefixes, no addresses,
just bytes) plus a companion `.lst`. This format is a
cor24-run-specific convention; it is **not** emitted by
makerlisp's as24.c, which defaults to `.lgo`.

Today `scripts/build.sh` expects `.bin` + `.lst` from
cor24-run. If the bootstrap toolchain is switched to
sw-cor24-x-assembler, the new CLI should either:

- Emit the same raw `.bin` + `.lst` pair (simplest, preserves
  the existing oracle shape); or
- Emit `.lgo` and update `scripts/build.sh` + `scripts/test.sh`
  to diff `.lgo` against the as24.c reference. This is closer
  to what the FPGA target will consume but changes the oracle.

Pick one before writing the new CLI. The smoke test
(`tests/smoke/nop.s`) currently relies on byte-for-byte equality
of the `.bin` output between cor24-run and sw-as24; if the
output format changes, the test harness changes with it.

## 6. Self-host target format

For the on-device self-hosted flow, sw-as24 should emit `.lgo`
over UART by default:

- Every byte is printable ASCII — safe over the hex-ASCII TX
  filter that `cor24-run` uses in observation mode (see
  `docs/architecture.md`).
- A paired on-device monitor/loader (`sw-hexload` sketch in
  `docs/utility.md`) can consume `.lgo` directly into memory
  and transfer control via the `G` record.
- No linker is required — the assembler emits fully-resolved
  absolute addresses, matching as24.c default behaviour when
  no `-c` is given.

The raw `.bin` form remains useful as a regression artifact
(diff against cor24-run), but is not the target output for the
self-hosted flow.

## 7. Provenance

- `.lgo` format: `as24.c:lgoput()` (lines 928–976).
- `.lst` format: `as24.c:lstput()` (lines 980–1110).
- `.obj` format: `as24.c:objput()` (lines 1249–1312).
- `.s` roundtrip: `as24.c:asmput()` (lines 1113–1246).
- `.bin`: not in as24.c — defined by `cor24-run --assemble` in
  the Rust tree. The format is trivially "bytes in file order";
  see cor24-run source for the exact entry.
