Write src/sw-as24.s -- the minimum viable self-hosted assembler that
recognises exactly one mnemonic (`nop`) and emits one byte (0x00).

Reference for COR24 ISA register constraints:
/disk1/github/softwarewrighter/devgroup/work/dcfth/github/sw-embed/sw-cor24-forth/CLAUDE.md
(the "COR24 ISA -- Register Capabilities" section).

Structure:
1. Banner: on startup, emit a short identification string on UART
   (so `cor24-run` output is recognisable when debugging).
2. Input loop: read one line from UART into a fixed-size buffer,
   terminating on newline or EOF.
3. Compare: hand-roll a string compare against the literal "nop".
4. On match: emit byte 0x00 on UART.
5. On mismatch: emit a distinguishable error byte (e.g., 0xFF) on
   UART and exit the program with a non-zero status.
6. Halt.

Constraints:
- Implementation language: COR24 .s assembly only.
- Respect the ISA register capability rules (load / ALU destinations
  are only r0, r1, r2; fp and sp are restricted).
- Decimal immediates, not hex (matches forth/pascal convention).
- Comments use `;` only.
- No labels on inline instruction lines ("label: instr" is illegal).

Scope (deliberately excluded -- later sagas):
- Multiple mnemonics.
- Operands of any kind.
- Labels in input.
- Comments in input.
- Directives.
- Symbol table.
- Two-pass assembly.

Exit criteria:
- `just build` produces build/sw-as24.bin without error.
- `just test` passes: byte-identical output vs cor24-run on
  tests/smoke/nop.s.
- The source is readable and the mnemonic-matching logic is
  obvious to a future session that will extend it.
