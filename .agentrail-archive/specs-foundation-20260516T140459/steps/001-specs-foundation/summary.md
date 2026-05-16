Six authoritative spec docs landed under docs/, with CLAUDE.md and docs/architecture.md repointed at them. Plan.md renumbered so Specs foundation is saga 2 and Lexer shifted to saga 3 (downstream sagas all +1 to finish at saga 15).

Documents:
- docs/isa.md — COR24 ISA: registers (only r0/r1/r2 carry the r prefix; fp/sp/z/iv/ir are proper names; selectors 0..7 never appear as tokens), memory map, I/O, 34-mnemonic set, decode ROM byte-level table, addressing modes, calling convention. 0xFF nop flagged as post-as24.c addition.
- docs/as24-language.md — lexical rules, literal syntax (decimal + 0...h hex), labels-on-own-line, directives (.text/.data/.bss/.byte/.word/.comm/.globl/.=.+N), branch-too-far rewriting, error format, optional -O peephole optimizer.
- docs/output-formats.md — .lgo (as24.c default, hex-ASCII load+go), .lst, .obj, .s roundtrip; raw .bin as cor24-run-specific.
- docs/fpga-runtime.md — memory + UART + reset + interrupts; the multi-binary loading model (cor24-run --base-addr, --load-binary @addr, --patch, _main) from sws+swye; in-emulator test harness pointer.
- docs/self-host-toolchain.md — editor/linker/loader/monitor contract sketch with explicit open questions; sws+swye cited as ecosystem precedent.
- docs/oracle-protocol.md — REST oracle (as24.c; URL TBD); local as24.c fallback; in-emulator co-loaded test harness §4.3 (monitor calls sw-as24 to assemble a source buffer, decoder converts to bytes, monitor jumps, emulator dumps final state — offline end-to-end oracle).

Process note: initial draft of this work was done directly on dev (incorrectly). After user feedback, created dcasm/feat/saga-2-specs-foundation, archived Relaunch saga to .agentrail-archive/, initialized this saga, added this step, and committed both content and agentrail state.

Not done in this step (intentional):
- Vendor repoint from cor24-rs to sw-cor24-x-assembler. Blocked on upstream x-assembler landing a [[bin]] target. Tracked in docs/output-formats.md §5 and docs/architecture.md §2.
- REST oracle URL + request/response shape. User-provided detail pending; placeholder in docs/oracle-protocol.md §2.
- Verification of the opcode table against dis_rom.v directly. Current tables agree between as24.c's instab, x-assembler's encode, and web-demos' instruction summary; a ROM dump would close the loop.

Exit criteria met: six spec docs committed; CLAUDE.md and architecture.md reference them as in-repo canonical sources; plan.md renumbered with change-log entry.
