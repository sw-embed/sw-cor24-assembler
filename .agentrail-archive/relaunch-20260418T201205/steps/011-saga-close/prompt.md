Close the Relaunch saga.

Validation:
1. From a clean vendor state (`rm -rf vendor/sw-em24/v*/bin/cor24-run`),
   run `just vendor-fetch && just build && just test`. The whole
   sequence must succeed end-to-end with byte-identical output.
2. `agentrail history` shows all prior steps completed with no
   outstanding `[ ]` markers.
3. `git status` is clean. All saga work is already committed.

Housekeeping:
- Update docs/plan.md:
  - Move the Relaunch saga from "Current saga" to a new "Completed
    sagas" section with its completion date.
  - Promote the saga 2 (Lexer and line parsing) stub to the
    "Current saga" position in anticipation of the next saga.
  - Append a Change-log entry: "2026-MM-DD: Relaunch saga closed.
    sw-as24 recognises `nop` and emits byte-identical output to
    cor24-run on tests/smoke/nop.s."
- Commit the plan update.

Completion:
- `agentrail complete --done --summary ... --actions ...` to close
  the saga.

Post-saga handoff:
- The feature branch `feat/relaunch-project` is now ready to be
  renamed to a PR branch targeting `dev`. Do NOT perform the rename
  in this step -- flag it as the next human action in the step
  summary.

Exit criteria:
- `just test` green from a cold vendor state.
- Saga status is Completed.
- docs/plan.md reflects completion and names the next saga.
