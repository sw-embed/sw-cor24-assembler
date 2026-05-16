Rewrite CLAUDE.md to match the new .s-based scope without losing the
AgentRail session protocol.

REMOVE from the current CLAUDE.md:
- "tc24r C Subset Constraints" section (no structs, no malloc,
  no string library, single translation unit, 24-bit int / 8-bit
  char). The project no longer contains C.
- Any reference to cas24, tc24r, as24 (command name), .c files.
- The Build/Test section's tc24r / as24 invocations.

PRESERVE verbatim:
- The "CRITICAL: AgentRail Session Protocol" section and its six
  numbered steps (START, BEGIN, WORK, COMMIT, COMPLETE, STOP).
- The Key Rules list.
- The Useful Commands table.

UPDATE:
- Project Overview: reframe around the self-hosting .s-based
  assembler; point at docs/prd.md for the full statement.
- Build / Test: replace with `just vendor-fetch`, `just build`,
  `just test` commands. Include the one-liner `just --list` as a
  discovery hint.
- Architecture: shrink to a one-paragraph summary and defer to
  docs/architecture.md as the source of truth.
- Cross-Repo Context: keep, still accurate. Confirm sibling repo
  listings still resolve under ~/github/sw-embed/ (or equivalent
  work tree).

Exit criteria:
- `grep -c "tc24r\|cas24" CLAUDE.md` returns 0.
- The AgentRail protocol block is byte-identical to the previous
  version (diff the relevant lines to be sure).
- A fresh Claude Code session reading CLAUDE.md can, in principle,
  run the full agentrail start -> begin -> work -> commit -> complete
  cycle without needing external context.
