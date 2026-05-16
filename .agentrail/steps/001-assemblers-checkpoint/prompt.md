Write docs/assemblers-checkpoint.md capturing the three-assembler model, bootstrap chain, demo ladder, and current blockers.

Content:
- Status (sw-as24 = nop-only; saga 2 specs landed)
- Three projects: dcasm (this repo, flat as24 in .s), dchla (sw-cor24-hlasm, macro/structured assembler in .s, emits .s via UART), dcxas (sw-cor24-x-assembler, Rust rlib, host-only bootstrap)
- dw* siblings = Rust web demos (dwdem holds web-sw-cor24-demos)
- Bootstrap chain: dcxas bootstraps dcasm.s → on-COR24 dcasm assembles itself → done. Parallel chain: dcxas bootstraps hlasm.s → hlasm runs on COR24, emits .s, dcasm assembles to bin → eventually hlasm bootstraps itself.
- Demo ladder: Rung 1 = sw-as24 assembles fib.s byte-identical. Rung 2 = in-emulator co-loaded harness (oracle-protocol.md §4.3). Rung 3 = self-host close (saga 14).
- Blockers: none on critical path; REST oracle URL pending; x-assembler [[bin]] target pending.
- Explicit non-dependency: sw-as24 is NOT planning to use hlasm. dcasm written in flat as24; dchla is a consumer of dcasm, not a precursor.
- Alignment notes / gaps in plan.md (dchla not yet in saga 13 corpus; demo ladder undocumented).

Reference: CLAUDE.md gets a one-line pointer; docs/plan.md change-log entry; the doc itself is the deliverable.
