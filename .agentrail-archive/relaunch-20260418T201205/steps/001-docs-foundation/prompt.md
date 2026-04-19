Establish the documentation baseline for the sw-as24 relaunch.

Write docs/prd.md, docs/architecture.md, docs/design.md, docs/plan.md
so that later steps have an anchor for scope decisions. The PRD and
architecture doc are long-lived; the design and plan docs are phase-
scoped and will be revised each saga.

Exit criteria:
- Four files present under docs/ with consistent cross-references.
- PRD names goals (self-hosting, byte-identical output, .s-only
  implementation, emulator + FPGA targets), non-goals, and explicit
  success criteria.
- Architecture doc includes the two-pass pipeline, parallel-array
  data model, byte-identical-output compatibility contract, and
  flags open questions (hosting model, static size limits, pass-1
  caching, self-host verification).
- Design doc scopes the relaunch: directory layout, vendor strategy
  mirroring sw-cor24-ocaml, justfile recipes, smoke-test spec
  (nop.s -> 0x00), sw-as24.s skeleton scope.
- Plan doc enumerates 11 relaunch steps plus stubs for upcoming
  sagas; change-log section seeded.
