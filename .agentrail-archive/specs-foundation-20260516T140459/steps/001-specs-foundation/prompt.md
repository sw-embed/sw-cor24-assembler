Write repo-local, authoritative specifications covering ISA, as24 language, output formats, FPGA runtime, self-host toolchain, and oracle protocol. Update CLAUDE.md + docs/architecture.md to treat these as the in-repo canonical sources.

Inputs:
- cor24-rs/docs/research/asld24/as24.c (makerlisp reference)
- dwdem/.../web-sw-cor24-demos/src/data/isa/*.rs (ISA summaries)
- dcxas/.../sw-cor24-x-assembler (Rust rlib, encode tables)
- dcscr/.../sw-cor24-script + dcyed/.../sw-cor24-yocto-ed (multi-binary loading precedent)

Outputs:
- docs/isa.md (registers, memory, opcodes, decode ROM, calling conv)
- docs/as24-language.md (lexical rules, directives, branches, optimizer)
- docs/output-formats.md (.lgo / .lst / .obj / .bin)
- docs/fpga-runtime.md (memory + UART + multi-binary loading model)
- docs/self-host-toolchain.md (editor/loader/monitor — sketch + open questions)
- docs/oracle-protocol.md (REST + corpus — placeholder details)
- CLAUDE.md (index + register-name rule)
- docs/architecture.md §2 (repointed to in-repo specs)
- docs/plan.md (renumber Lexer → Saga 3)

Register-name rule enforced throughout: only r0, r1, r2, fp, sp, z, iv, ir, c are valid names. Never r3..r7.

0xFF nop is flagged as post-as24.c addition so byte-level expectations are clear.

Exit: six spec docs present, CLAUDE.md + architecture.md wired to them, plan.md renumbered. No sw-as24 behavioural change in this step.
