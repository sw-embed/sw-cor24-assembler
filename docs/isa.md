# COR24 ISA Reference

Repo-local reference for the instruction set that sw-as24 targets.
Authoritative for this project. Derived from primary sources
listed at the bottom; kept in this repo so the self-hosted
assembler is not dependent on any sibling repo being checked out.

## 1. Overview

COR24 is a 24-bit C-Oriented RISC architecture.

- 24-bit data path (registers, ALU, addresses)
- 8 architectural registers: 3 general-purpose (r0, r1, r2) +
  5 special (fp, sp, z, iv, ir)
- Single condition flag `c` (1 bit)
- Variable-length instructions: 1, 2, or 4 bytes
- 16 MB address space (physical memory is a small subset)
- Little-endian byte order
- Memory-mapped I/O

## 2. Registers

The architecture has **eight** registers. Only the three
general-purpose registers carry an `r` prefix; the five
special-purpose registers have their own names and are never
referred to as `r3`, `r4`, etc. in source or documentation.

| Name | Role | Notes |
|------|------|-------|
| `r0` | GP, return value | Forth W |
| `r1` | GP, link register | `jal` always saves return addr here |
| `r2` | GP | Forth IP |
| `fp` | Frame pointer | Only base reg for EBR stack indexing. Not an ALU dest, not readable by `mov` |
| `sp` | Stack pointer | Grows downward. Init `0xFEEC00`. Only `add sp, imm8` and `sub sp, imm24` may target it. Not a load/store base; cannot be pushed |
| `z`  | Hardwired zero | Source operand only (e.g. `ceq r0, z`). Cannot be written. `mov ra, z` reads the `c` flag: `ra = c ? 1 : 0` |
| `iv` | Interrupt vector | CPU jumps here on interrupt. Set via `mov iv, r0`. Not readable, not pushable |
| `ir` | Interrupt return | CPU saves PC here on interrupt entry. `jmp (ir)` returns and clears interrupt-in-service. The `la ir, imm24` encoding slot is repurposed as `jmp imm24` |
| PC   | Program counter | 24-bit, not architecturally visible except via `jal` |
| `c`  | Condition flag | 1 bit; set by compare instructions, read by branches |

The decode ROM addresses registers with a 3-bit selector. These
selector values (0..7) are an *internal encoding* and must not
leak into user-facing names. For reference, the selector values
are: `r0`=0, `r1`=1, `r2`=2, `fp`=3, `sp`=4, `z`=5, `iv`=6,
`ir`=7. Tools that display the selector should render the name,
not the number.

### Register capability matrix

| Name | Load dest | ALU dest | push/pop | Base reg |
|------|-----------|----------|----------|----------|
| `r0` | yes | yes | yes | yes |
| `r1` | yes | yes | yes | yes |
| `r2` | yes | yes | yes | yes |
| `fp` | no  | no  | yes | yes (only EBR stack indexing) |
| `sp` | no  | no  | no  | no  |
| `z`  | no  | no  | no  | no  |
| `iv` | no  | no  | no  | no  |
| `ir` | no  | no  | no  | no  |

## 3. Memory Map

| Region | Start | End | Size | Type | Notes |
|--------|-------|-----|------|------|-------|
| SRAM | `0x000000` | `0x0FFFFF` | 1 MB | RAM | Code, data, heap. Reset vector at `0x000000` |
| Unmapped | `0x100000` | `0xFEDFFF` | ~14 MB | — | Reads return 0 |
| EBR | `0xFEE000` | `0xFEFFFF` | 8 KB window | RAM (stack) | Embedded Block RAM. 3 KB populated on MachXO. Stack grows down from `0xFEEC00` |
| LED/Switch | `0xFF0000` | `0xFF0000` | 1 byte | I/O | Bit 0: write = LED D2, read = button S2 |
| UART | `0xFF0100` | `0xFF0101` | 2 bytes | I/O | Data + status |

### I/O registers

| Name | Address | Size | R/W | Description |
|------|---------|------|-----|-------------|
| IO_LEDSWDAT | `0xFF0000` | 1 | R/W | Bit 0 write = LED D2 on; read = button S2 state |
| IO_INTENABLE | `0xFF0010` | 1 | R/W | Bit 0 = UART RX interrupt enable |
| IO_UARTDATA | `0xFF0100` | 1 | R/W | Write = transmit byte. Read = receive byte (auto-acks RX) |
| IO_UARTSTAT | `0xFF0101` | 1 | R | Bit 0: RX ready. Bit 1: CTS. Bit 2: RX overflow. Bit 7: TX busy |

### Reset and interrupt

- **Reset vector:** `0x000000`. CPU begins execution at the first
  byte of SRAM. (A historical note: earlier documentation in
  `cor24-rs/docs/isa-reference.md` lists reset at `0xFEE000`; the
  web-demos data set, which mirrors the current FPGA bitstream,
  says `0x000000`. Treat web-demos as current.)
- **Interrupt entry:** on interrupt, CPU saves PC in `ir` and
  jumps to the address in `iv` (equivalent to an implicit
  `jal ir, (iv)`). Interrupts are latched until software handles
  them.
- **Interrupt return:** `jmp (ir)` both returns to the saved PC
  and clears the interrupt-in-service latch.
- **Halt:** byte `0x00` at address `0x000000` halts the CPU. At
  any other address, byte `0x00` decodes as `add r0, r0`. There
  is no dedicated `halt` mnemonic in the hardware — it is a
  side-effect of this reset-vector encoding.
- **Self-branch halt:** `bra .` (branch to self, displacement 0)
  also halts because it pins the PC.

## 4. Instruction Set

34 distinct mnemonics across 11 categories. Encoded as 1-, 2-,
or 4-byte instructions. The first byte is always looked up in
the 256-entry decode ROM, which maps it to
`(opcode, ra, rb)` — see §6 for the full byte-level table.

### Arithmetic

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `add` | `ra, rb` | 1 | `ra = ra + rb` (24-bit wrap) |
| `add` | `ra, imm8` | 2 | `ra = ra + sign_ext(imm8)`. Dest: r0, r1, r2, sp |
| `sub` | `ra, rb` | 1 | `ra = ra - rb` (24-bit wrap) |
| `sub` | `sp, imm24` | 4 | `sp = sp - imm24` (stack frame alloc) |
| `mul` | `ra, rb` | 1 | `ra = ra * rb` (low 24 bits, no overflow) |

### Logical

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `and` | `ra, rb` | 1 | `ra = ra & rb` |
| `or`  | `ra, rb` | 1 | `ra = ra \| rb` |
| `xor` | `ra, rb` | 1 | `ra = ra ^ rb` |

### Shift

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `shl` | `ra, rb` | 1 | `ra = ra << (rb & 0x1F)`, masked to 24 bits |
| `sra` | `ra, rb` | 1 | `ra = (signed)ra >> (rb & 0x1F)`, sign preserved |
| `srl` | `ra, rb` | 1 | `ra = ra >> (rb & 0x1F)`, zero fill |

### Comparison (sets `c`)

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `ceq` | `ra, rb` | 1 | `c = (ra == rb)`. Use `rb = z` to test zero |
| `cls` | `ra, rb` | 1 | `c = (signed)ra < (signed)rb`. Use `rb = z` to test sign |
| `clu` | `ra, rb` | 1 | `c = ra < rb` (unsigned). Use `ra = z` to test flag |

### Load

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `la`  | `ra, imm24` | 4 | `ra = imm24`. `ra = ir` form encodes `jmp imm24` |
| `lc`  | `ra, imm8` | 2 | `ra = sign_ext(imm8)`. Dest: r0, r1, r2 |
| `lcu` | `ra, imm8` | 2 | `ra = zero_ext(imm8)`. Dest: r0, r1, r2 |
| `lb`  | `ra, disp(rb)` | 2 | `ra = sign_ext(Mem[rb + disp])` |
| `lbu` | `ra, disp(rb)` | 2 | `ra = zero_ext(Mem[rb + disp])` |
| `lw`  | `ra, disp(rb)` | 2 | `ra = Mem24[rb + disp]` (3 bytes) |
| `sxt` | `ra, rb` | 1 | `ra = sign_ext(rb & 0xFF)` |
| `zxt` | `ra, rb` | 1 | `ra = rb & 0xFF` |

### Store

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `sb` | `ra, disp(rb)` | 2 | `Mem[rb + disp] = ra & 0xFF` |
| `sw` | `ra, disp(rb)` | 2 | `Mem24[rb + disp] = ra` (3 bytes) |

### Branch (PC-relative, signed 8-bit)

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `bra` | `disp` | 2 | `PC = PC_after + sign_ext(disp)`. `bra .` halts |
| `brt` | `disp` | 2 | if `c`: `PC = PC_after + sign_ext(disp)` else fall through |
| `brf` | `disp` | 2 | if `!c`: `PC = PC_after + sign_ext(disp)` else fall through |

`PC_after` is the address of the instruction *following* the
branch. The displacement range is −128…+127 bytes from that
point. Assembler rewrites out-of-range branches — see §5.5.

### Call / Return (register-indirect)

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `jal` | `r1, (rb)` | 1 | `r1 = PC + 1; PC = rb`. Target: r0, r1, r2 |
| `jmp` | `(ra)` | 1 | `PC = ra`. `jmp (ir)` also clears interrupt-in-service |
| `jmp` | `imm24` | 4 | Assembler synthesizes as `la ir, imm24` (see §6) |

### Stack

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `push` | `ra` | 1 | `sp -= 3; Mem24[sp] = ra`. Pushable: r0, r1, r2, fp |
| `pop`  | `ra` | 1 | `ra = Mem24[sp]; sp += 3`. Poppable: r0, r1, r2, fp |

Stack grows downward. Each slot is 3 bytes (one 24-bit word).

### Move

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `mov` | `ra, rb` | 1 | `ra = rb`. Special case `rb = z`: `ra = c ? 1 : 0` |

Not all register pairs are legal. The decode ROM enumerates the
valid combinations; see §6.

### Miscellaneous

| Mnemonic | Form | Size | Description |
|----------|------|------|-------------|
| `nop` | — | 1 | Byte `0xFF`; advances PC by 1 |

`nop` was added to the hardware after the makerlisp `as24.c`
reference was cut, so older material (including `as24.c`'s
`instab[]`) omits it. Treat the web-demos ISA data as current.

`halt` is not a mnemonic — see §3 (Reset and interrupt).

## 5. Addressing Modes

Seven modes, listed by the syntax the assembler accepts.

| Mode | Syntax | Example | Used by |
|------|--------|---------|---------|
| Register | `ra, rb` | `add r0, r1` | Most ALU, logical, shift, compare, move |
| Immediate 8 | `ra, imm8` | `add r0, 42` | `add ra,imm8`, `lc`, `lcu`, branch |
| Immediate 24 | `ra, imm24` | `la r0, 0x123456` | `la`, `sub sp, imm24`, synthesized `jmp imm24` |
| Base + displacement | `ra, disp(rb)` | `lw r0, 3(fp)` | `lb`, `lbu`, `lw`, `sb`, `sw`. Base reg: r0, r1, r2, fp |
| Register indirect | `(ra)` | `jmp (r1)` | `jmp`, `jal` |
| PC-relative | `disp` | `bra loop` | `bra`, `brt`, `brf` |
| Implicit stack | `ra` | `push r0` | `push`, `pop` |

### 5.5 Branch-too-far rewriting

Branch instructions are 2 bytes with an 8-bit signed
displacement. When a branch target is more than ±127 bytes from
`PC_after`, the assembler rewrites:

- Unconditional `bra label` → `jmp label` (4 bytes, absolute
  encoding via `la ir, label` opcode slot `0xC7`).
- Conditional `brt label` / `brf label` → reverse the sense,
  branch around an inserted `jmp label`.

This is a pass performed until no more rewrites are needed; see
`as24.c:fixbra()` for the reference algorithm.

## 6. Encoding (decode ROM)

The first byte of every instruction is looked up in a 256-entry
ROM, producing `(opcode, ra, rb)` as a 12-bit value:

```
bits 10..6 : opcode (5-bit abstract)
bits  5..3 : ra (3-bit register selector)
bits  2..0 : rb (3-bit register selector)
```

Register selector values are hardware-internal and map to the
architectural names as listed in §2. They must not appear as
tokens in the assembly source.

Invalid entries decode to `0xFFF`. The hardware source is
`dis_rom.v` in the COR24-TB FPGA project. x-assembler's
`extract_decode_rom.py` extracts it; as24.c carries an
equivalent hand-maintained table (`instab[]`). The two MUST
agree.

### Full byte-level mapping (from as24.c `instab`)

Single-byte instructions (register-only):

| Byte | Mnemonic form | | Byte | Mnemonic form | | Byte | Mnemonic form |
|------|---------------|-|------|---------------|-|------|---------------|
| `0x00` | `add r0, r0` | | `0x2D` | `lb r0, o8(r1)` | | `0x67` | `mov iv, r0` |
| `0x01` | `add r0, r1` | | `0x2E` | `lb r0, o8(r2)` | | `0x68` | `jmp (ir)` |
| `0x02` | `add r0, r2` | | `0x2F` | `lb r0, o8(fp)` | | `0x69` | `mov sp, fp` |
| `0x03` | `add r1, r0` | | `0x30..0x37` | `lb r1/r2, o8(r0/1/2/fp)` | | `0x6A..0x72` | `mul ra, rb` (9 combos) |
| `0x04` | `add r1, r1` | | `0x38..0x43` | `lbu r0/1/2, o8(r0/1/2/fp)` | | `0x73..0x78` | `or ra, rb` (6 combos, no r,r) |
| `0x05` | `add r1, r2` | | `0x44` | `lc r0, i8` | | `0x79..0x7C` | `pop r0/r1/r2/fp` |
| `0x06` | `add r2, r0` | | `0x45` | `lc r1, i8` | | `0x7D..0x80` | `push r0/r1/r2/fp` |
| `0x07` | `add r2, r1` | | `0x46` | `lc r2, i8` | | `0x81..0x89` | `sb ra, o8(rb)` |
| `0x08` | `add r2, r2` | | `0x47` | `lcu r0, u8` | | `0x8A..0x8F` | `shl ra, rb` |
| `0x0D..0x12` | `and ra, rb` | | `0x48` | `lcu r1, u8` | | `0x90..0x95` | `sra ra, rb` |
| `0x16..0x18` | `ceq ra, rb` | | `0x49` | `lcu r2, u8` | | `0x96..0x9B` | `srl ra, rb` |
| `0x19..0x1E` | `cls ra, rb` | | `0x4A..0x55` | `lw ra, o8(rb)` | | `0x9C..0xA1` | `sub ra, rb` |
| `0x1F..0x24` | `clu ra, rb` | | `0x56..0x61` | `mov ra, rb` + `add ra, fp` + `mov ra, sp` | | `0xA3..0xAE` | `sw ra, o8(rb)` |
| `0x25` | `jal r1, (r0)` | | `0x62..0x64` | `mov r0/r1/r2, c` | | `0xAF..0xB7` | `sxt ra, rb` |
| `0x26..0x28` | `jmp (r0/r1/r2)` | | `0x65` | `mov fp, sp` | | `0xB8..0xBD` | `xor ra, rb` |
| `0xBE..0xC6` | `zxt ra, rb` | | `0x66` | `mov sp, r0` | | `0xD1..0xD2` | `jal r1, (r1/r2)` |

Two-byte instructions (first byte + 8-bit immediate/displacement):

| Byte | Form |
|------|------|
| `0x09` | `add r0, imm8` |
| `0x0A` | `add r1, imm8` |
| `0x0B` | `add r2, imm8` |
| `0x0C` | `add sp, imm8` |
| `0x13` | `bra disp8` |
| `0x14` | `brf disp8` |
| `0x15` | `brt disp8` |
| `0x2C..0x43` | `lb / lbu ra, disp8(rb)` |
| `0x44..0x49` | `lc / lcu ra, imm8` |
| `0x4A..0x55` | `lw ra, disp8(rb)` |
| `0x81..0x89` | `sb ra, disp8(rb)` |
| `0xA3..0xAE` | `sw ra, disp8(rb)` |

Four-byte instructions (first byte + 24-bit immediate, little-endian):

| Byte | Form |
|------|------|
| `0x29` | `la r0, imm24` |
| `0x2A` | `la r1, imm24` |
| `0x2B` | `la r2, imm24` |
| `0xA2` | `sub sp, imm24` |
| `0xC7` | `jmp imm24` (encoded as `la ir, imm24`) |

Compare-with-zero forms (1 byte each, added to the instab after
`0xC7` to preserve backwards compatibility):

| Byte | Form |
|------|------|
| `0xC8..0xCA` | `ceq r0/r1/r2, z` |
| `0xCB..0xCD` | `cls r0/r1/r2, z` |
| `0xCE..0xD0` | `clu z, r0/r1/r2` |

Byte `0xFF` is the canonical `nop` — **added after the makerlisp
as24.c reference was published**, so it does not appear in the
as24.c `instab[]`. Current hardware (web-demos data and the
updated decode ROM) decode `0xFF` as a 1-byte nop that advances
PC. sw-as24 must emit and accept it; older materials will not
mention it. Other bytes not listed above decode to `0xFFF`
(invalid) in the ROM.

For the complete verbatim table, see the `instab[]` array in
`cor24-rs/docs/research/asld24/as24.c` (lines 114–340). sw-as24
should generate an equivalent in-ROM lookup structure; exact
binary encoding is defined by the hardware decode ROM and is the
one invariant the assembler must preserve.

## 7. Calling Convention

- **Arguments:** pushed right-to-left before the call. Callee
  accesses them at `fp+3`, `fp+6`, `fp+9`, …
- **Return value:** in `r0`.
- **Link register:** `jal` always writes `PC+1` to `r1`. Callee
  typically pushes `r1` to the stack alongside `fp`.
- **Frame pointer:** `fp` points to the saved caller `fp`.
  Locals are at negative offsets from `fp`.
- **Frame setup:** `push fp` / `mov fp, sp` / `sub sp, N`.
  Teardown: `mov sp, fp` / `pop fp` / `jmp (r1)`.
- **Caller-saved:** `r0`, `r1`, `r2`. Callee may use freely.
  Caller must save across calls if needed.
- **Callee-saved:** `fp`. Callee must preserve.

### Stack frame layout

```
higher addr
+-------------------+
| arg 2             |  fp + 6
| arg 1             |  fp + 3
+-------------------+
| saved fp (caller) |  fp + 0
| saved r1 (ret PC) |  fp - 3   ; actually saved by callee push sequence
| local 1           |  fp - 6
| local 2           |  fp - 9
| ...               |
+-------------------+  sp
lower addr
```

The exact push order in the prologue determines the offsets.
See §4.4 of cor24-rs/docs/isa-reference.md and the `fib.s`
example in `cor24-rs/docs/research/asld24/fib.s` for the
reference sequence.

## 8. Provenance

Primary sources, in decreasing authority:

1. `dis_rom.v` — FPGA decode ROM (Verilog). Byte-level ground
   truth. Extracted by
   `sw-cor24-x-assembler/scripts/extract_decode_rom.py`.
2. `cor24-rs/docs/research/asld24/as24.c` `instab[]` — the
   makerlisp clean-room reference assembler. Hand-maintained
   table; must agree with (1).
3. `web-sw-cor24-demos/src/data/isa/*.rs` — human-facing
   summaries (34 mnemonics, addressing modes, memory map, I/O,
   calling convention). Current as of the web demos site.
4. `sw-cor24-x-assembler/src/assembler.rs` plus its
   `cpu::encode` dependency — Rust encoder derived from (1).

Older material (use with care — predates the `0xFF` nop addition
and may disagree on details like the reset vector):

- `cor24-rs/docs/isa-reference.md` — predates the web-demos
  ISA data; opcode column is inaccurate.
- `cor24-rs/docs/research/asld24/as24.c` `instab[]` — predates
  nop; 211 entries, stops at `0xD2`.
- `cor24-rs/docs/research/asld24/{fib.s, sieve.s}` — working
  examples; useful for tone-and-style but not specification.

## 9. Open Questions

- The `la ra, ir`-slot encoding for `jmp imm24` (byte `0xC7`) is
  a historical oddity. Confirm sw-as24 emits it identically to
  as24.c's `fixbra()` path before claiming byte-identity.
- `mov ra, z` (condition-flag read) is documented inconsistently
  across sources. The as24.c instab lists `mov r0/r1/r2, c`
  slots (`0x62..0x64`), not a generic `mov ra, z`. Treat the
  `z`-source form as an assembler alias for the `c` form until
  the hardware ROM is inspected.
- The decode ROM has 8 register selector slots. Only five of
  them (selector 0..5 = `r0`, `r1`, `r2`, `fp`, `sp`, `z`)
  appear in general-purpose operand positions; `iv` and `ir`
  (selectors 6 and 7) are accessible only through specific
  instructions (`mov iv, r0`, `jmp (ir)`, `la ir, imm24`). The
  assembler language never exposes selectors as names: never
  write `r3..r7` in source or docs — use the proper name
  (`fp`, `sp`, `z`, `iv`, `ir`) everywhere. Confirm the
  selector-to-name mapping against `dis_rom.v` before final
  sign-off.
