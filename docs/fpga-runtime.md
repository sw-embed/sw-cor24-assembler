# COR24 FPGA Runtime Environment

The target environment sw-as24 runs in once it is self-hosted.
Most of this is inherited from the COR24 FPGA reference board
(MachXO, via the COR24-TB testbench). Known facts are in §1–§4;
remaining decisions for sw-as24 specifically are in §5.

## 1. Memory

See `docs/isa.md` §3 for the full map. For runtime purposes the
key points are:

- **SRAM** `0x000000`..`0x0FFFFF` (1 MB). All code and data
  live here. Programs are loaded at `0x000000` by default.
- **EBR** `0xFEE000`..`0xFEFFFF` (8 KB window, 3 KB populated
  on MachXO). Fast on-chip RAM used as the system stack. `sp`
  initializes to `0xFEEC00` and grows downward.
- **I/O** at `0xFF0000`..`0xFF0101`. See §2.

## 2. UART

- **Data register:** `IO_UARTDATA` at `0xFF0100` (R/W). Write
  transmits one byte. Read retrieves one received byte and
  auto-acknowledges RX.
- **Status register:** `IO_UARTSTAT` at `0xFF0101` (read-only).
  - Bit 0: RX ready (a byte is available to read)
  - Bit 1: CTS (clear-to-send from the host)
  - Bit 2: RX overflow (received byte lost)
  - Bit 7: TX busy (do not write while set)
- **Interrupt:** `IO_INTENABLE` at `0xFF0010` bit 0 enables a
  UART RX interrupt. On interrupt, CPU saves PC in `ir` and
  jumps to the address in `iv`.

### UART TX discipline

`cor24-run` (both the emulator and its observation mode) filters
out `0x00` bytes from the TX stream to avoid terminating
captures. Programs that need to emit arbitrary binary data
therefore emit **hex-ASCII**: two printable hex digits per byte.
The as24.c `.lgo` format is already hex-ASCII and safe to emit
directly over UART without any encoding wrapper.

## 3. Reset and Boot

- **Reset vector:** `0x000000`. CPU begins execution at the
  first byte of SRAM after reset.
- **Halt:** byte `0x00` at address `0x000000` halts the CPU.
  At any other address `0x00` decodes as `add r0, r0`.
- **`bra .` halt:** a branch to self pins the PC and halts the
  CPU for all practical purposes.

## 3.5 Loading Model (emulator, and inherited for FPGA)

`cor24-run` already implements the multi-binary co-loading
pattern that the self-hosted toolchain should mirror. See
`sw-cor24-script`'s `docs/examples/editor-demo.sh` for a
complete worked example of sws launching swye.

### 3.5.1 Building at a non-zero base address

`cor24-run --assemble <src.s> <out.bin> <out.lst> --base-addr
<addr>` assembles with labels resolved at `addr`, so the
program can be loaded anywhere in SRAM (not only `0x000000`).
sw-cor24-x-assembler has the same facility via
`Assembler::assemble_at(src, base_address)`.

Implication: every program is position-independent at
assembly time, not at run time. Once assembled, a `.bin`'s
internal label references are baked to the chosen base.

### 3.5.2 Co-loading multiple binaries

`cor24-run --run <main.s>` accepts additional flags:

- `--load-binary <file>@<addr>` — place the bytes of `file`
  starting at `addr` in the emulator's address space before
  execution starts. Repeat for each secondary binary.
- `--patch <addr>=<value>` — write a single 24-bit value at
  `addr`. Used to install function pointers at known shared
  locations after the binaries are placed.

Example layout from the sws+swye demo:

| Base | Contents |
|------|----------|
| `0x000000` | `sws.bin` (primary program — starts at reset) |
| `0x010000` | a data file the editor operates on |
| `0x080000` | `swye.bin` (secondary program, assembled at that base) |
| `0x0F0000` | pre-canned input for swye |
| `0x0FFE00` | function-pointer slot — patched with `swye._main` address |

The primary program reads the function-pointer slot and calls
through it to invoke the secondary program. When the secondary
returns (via the standard calling convention in
`docs/isa.md` §7), control resumes in the primary.

### 3.5.3 Entry-point convention

The C toolchain (`tc24r` → `sw-cor24-x-assembler`) produces a
symbol named `_main` at the entry point of a program. The
loader discovers `_main`'s address by grepping the `.lst`
file:

```sh
grep '_main:' swye.lst -A 1 | grep -o '^[0-9a-f]*' | head -1
```

That address is then installed at a shared function-pointer
slot with `--patch`. sw-as24 should support the same
convention: emit a label the loader can find in the `.lst`,
and have a standard "this is the entry point" name.

Open: should sw-as24 adopt `_main` as the entry label, or
follow as24.c's `start` convention (which triggers a `G`
record in `.lgo`)? See `docs/output-formats.md` §1 and
`docs/self-host-toolchain.md` §4.

### 3.5.4 FPGA parity

The FPGA side of the runtime must preserve the same model:
load multiple binaries at configurable addresses, patch
function-pointer slots between them, and start at the reset
vector with the primary program. The existing host-side
`cor24-run` flow is the reference — the on-FPGA loader is
expected to be capable of the same actions, driven either by
the monitor or by a dedicated boot sequence.

### 3.5.5 In-emulator test harness (derived)

The same co-loading mechanism is the natural shape of the
sw-as24 regression harness: a test monitor co-loads sw-as24,
a source buffer, a decoder, and an execution region, dispatches
through them, halts, and the emulator's memory dump is the
test oracle. See `docs/oracle-protocol.md` §4.3 for the full
design. The harness is out of scope for the specs saga but
depends only on what this document already pins.

## 4. Interrupts

- On interrupt entry: `ir := PC; PC := iv` (as if `jal ir, (iv)`
  were executed).
- Return from interrupt: `jmp (ir)` — restores PC **and** clears
  the interrupt-in-service latch so further interrupts can be
  taken.
- `iv` is loaded with `mov iv, r0` (the only way to set it).
- `ir` is written only by the CPU on interrupt entry; it is read
  via `jmp (ir)` and written via the `la ir, imm24` encoding
  slot (which repurposes that slot as `jmp imm24`).

## 5. Open Questions for Self-Hosting

These are the runtime-environment decisions sw-as24 has to
resolve before it can run on the target.

1. **Load address.** Today `cor24-run --assemble` produces a
   flat image that loads at `0x000000`. For self-hosting, does
   sw-as24 itself live at `0x000000` (replacing any existing
   monitor) or at some higher offset so a monitor can coexist?
   Implies the answer to (2).
2. **Monitor coexistence.** Is there a resident monitor in
   SRAM above sw-as24, or does sw-as24 run standalone and
   replace it? See `docs/self-host-toolchain.md` for the
   unresolved tooling contract.
3. **Load format on the wire.** sw-as24 consumes source over
   UART and emits object bytes. Both directions need agreed
   framing. Most-likely choice: source is plain text with CR/LF
   tolerance; output is `.lgo` (one record per line, ASCII).
4. **Entry point convention.** as24.c's `.lgo` emits a `G`
   record only if a `start:` symbol is defined. Adopt that
   same rule or mandate an entry point? (Recommended: adopt
   as24.c's behaviour so existing `.s` files load unchanged.)
5. **Stack placement during self-assembly.** sw-as24 itself
   uses the EBR stack. How much EBR is available at runtime for
   user programs that sw-as24 is in the middle of assembling?
   Related: can sw-as24's internal structures live in SRAM, or
   do they share EBR with the user stack?
6. **Source input size limits.** SRAM is 1 MB. sw-as24's
   internal representation (form list, symbol table) consumes
   some of that. What's the maximum `.s` file we promise to
   assemble on-board?
7. **Error channel.** as24.c writes errors to stderr; on a
   bare-metal UART there is no stderr. Prefix error lines with
   a sentinel (e.g. leading `?`, matching as24.c's own
   convention) and emit them on the same UART TX stream.
8. **Reset / re-entry.** After sw-as24 finishes assembling and
   the user program halts, how does control return to the
   monitor / assembler prompt? Needs a defined handshake.

Each of these blocks a specific milestone in
`docs/plan.md`. Resolutions should be recorded as amendments
here and in `docs/self-host-toolchain.md`, with the plan saga
number that closed the question.

## 6. Provenance

- Memory map, I/O registers, UART bit layout, reset vector:
  `web-sw-cor24-demos/src/data/isa/memory.rs` (current as of
  2026-04 FPGA bitstream).
- Interrupt semantics: `cor24-rs/docs/isa-reference.md` §11 and
  `web-sw-cor24-demos/src/data/isa/registers.rs`.
- UART hex-ASCII filtering behaviour: documented in
  `docs/architecture.md` and observable in `cor24-run` source.
