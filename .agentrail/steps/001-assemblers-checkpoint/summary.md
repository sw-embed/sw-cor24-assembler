docs/assemblers-checkpoint.md landed. Covers:

1. Status: sw-as24 still nop-only; saga 2 specs landed on dev cbe8835.
2. Three projects: dcxas (Rust rlib bootstrap, host), dcasm (this repo, flat as24 in .s, on COR24), dchla (sw-cor24-hlasm, macro-assembler in .s emitting .s via UART, on COR24).
3. dw-prefix convention = Rust web demos (dwhla, dwdem, etc.). Only dcxas uses Rust on the dc side.
4. Bootstrap chain (acyclic): dcxas → dcasm.bin → dcasm self-host close. Parallel: dcxas → hlasm.bin → hlasm emits .s → dcasm assembles → eventually hlasm self-host on top.
5. Explicit anti-pattern: sw-as24 is NOT written in hlasm. Doing so would make bootstrap circular.
6. Demo ladder: Rung 1 (sw-as24 assembles fib.s byte-identical), Rung 2 (in-emulator co-loaded harness modeling sws+swye), Rung 3 (self-host close, saga 14).
7. Blockers: none on critical path. Soft: REST oracle URL, x-assembler [[bin]] target, dis_rom.v direct verification, dchla missing from saga-13 corpus.

Single-step saga; closing with --done.

Process note: branch was created with dg-new-feature off origin/dev (which now includes the merged specs-foundation commits). Previous specs-foundation saga archived inside this feat branch because origin/dev's .agentrail/ still showed it as active.
