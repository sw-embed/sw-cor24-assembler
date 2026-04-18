# PRD — `sw-as24`, a self-hosting COR24 assembler

**Status:** Draft (Relaunch saga)
**Owner:** Softwarewrighter
**Last updated:** 2026-04-18

## Summary

`sw-as24` is a COR24 assembler whose source is itself COR24 assembly. It
accepts standard COR24 `.s` input and emits machine code that is
byte-identical to the existing Rust cross-assembler. Once mature, the
assembler can assemble its own source on COR24 hardware, closing the
bootstrap loop and removing the host toolchain from the runtime path.

## Why

1. **Close the self-hosting loop.** The COR24 ecosystem has Forth, Lisp,
   Pascal, and others that all produce `.s`; none of them can *assemble*
   that `.s` on the target. The final missing piece is a native
   assembler.
2. **Reduce host dependencies.** Today every COR24 build requires a
   Rust toolchain via `cor24-run`. A native assembler lets a
   COR24-hosted monitor/editor workflow produce running binaries with
   no host involvement.
3. **Validate the ISA's self-hosting capacity.** Writing an assembler
   in `.s` stress-tests the ISA, exposes ergonomic gaps, and produces
   a worked example for every other low-level tool that follows.
4. **Educational.** A single-translation-unit assembler written in
   assembly is a tight, readable reference for how the ISA encodes
   instructions.

## Goals

- **G1.** Parse the full COR24 assembly grammar accepted by the Rust
  cross-assembler: all mnemonics, all addressing modes, directives
  (`.org`, `.byte`, `.word`, `.comm`), labels, comments, numeric
  literals (decimal, hex, signed).
- **G2.** Produce byte-identical machine code to the Rust cross-assembler
  for every `.s` input the Rust implementation accepts.
- **G3.** Implementation language is COR24 `.s` exclusively. Build
  glue is `bash` + `justfile`. No C, Rust, Python, or `make` shall
  be introduced into this repository.
- **G4.** Run on the COR24 emulator today and on COR24 FPGA hardware
  when hardware is available. The same `.s` source shall work on both.
- **G5.** Eventually self-host: `sw-as24` assembles its own source and
  produces a binary byte-identical to the one built by the Rust
  cross-assembler.

## Non-goals

- **N1.** Optimizing the emitted machine code. This is an assembler,
  not a peephole optimizer.
- **N2.** Supporting ISAs other than COR24.
- **N3.** Replacing `cor24-run` during *development*. The vendored
  cross-assembler remains the canonical reference and the fallback
  for validation until G5 is met.
- **N4.** Linker / loader functionality. `sw-as24` emits a single
  binary per input; multi-unit linking is out of scope (p-code has
  `p24-load` for that workflow).
- **N5.** New language extensions. If the Rust cross-assembler does
  not accept a syntax, `sw-as24` will not accept it either.

## Success criteria

- **S1.** `just test` passes: `tests/smoke/nop.s` assembled by
  `sw-as24` produces bytes byte-identical to `cor24-run`'s output.
- **S2.** (Future sagas) Regression suite of all `.s` files across
  `sw-cor24-forth`, `sw-cor24-macrolisp`, `sw-cor24-pascal`,
  `sw-cor24-pcode`, and the emulator examples assembles identically
  with both tools.
- **S3.** `sw-as24` assembled from its own source (by itself) produces
  a binary byte-identical to the one the Rust cross-assembler
  produces from the same `.s` source.

## Stakeholders

- Primary maintainer: Softwarewrighter (`dcasm` working tree).
- Downstream consumers: every language project under `sw-embed/` that
  emits `.s` and will eventually want to build on-device.
- Reference implementation: `sw-cor24-x-assembler` (Rust, rlib) and
  `sw-cor24-emulator`'s `cor24-run` binary.

## Assumptions and constraints

- **A1.** The Rust cross-assembler is the behavioural specification.
  Any ambiguity in COR24 syntax is resolved by deferring to whatever
  the Rust implementation does.
- **A2.** Until G5 is met, development relies on a locally-built
  vendored `cor24-run`. The vendor layout follows the pattern
  established in `sw-cor24-ocaml` (`vendor/<tool>/<version>/`
  with a manifest + gitignored `bin/`).
- **A3.** The runtime hosting model on COR24 (standalone UART I/O vs
  monitor-hosted via service vectors) is deliberately unresolved at
  relaunch time; see `architecture.md` §Hosting model.
- **A4.** ISA details — mnemonic set, encoding, register file — live
  in `sw-cor24-emulator` and `sw-cor24-x-assembler`. This project
  consumes them; it does not redefine them.

## Out of scope for the Relaunch saga

The relaunch saga produces scaffolding and a minimal `sw-as24.s` that
recognises the `nop` mnemonic and emits `0x00`. Everything else in
this PRD is addressed by later sagas enumerated in `plan.md`.
