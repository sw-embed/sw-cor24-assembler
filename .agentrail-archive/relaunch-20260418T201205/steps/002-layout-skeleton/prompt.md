Instantiate the directory skeleton described in docs/design.md.

Create (empty) src/, tests/smoke/, scripts/, vendor/ and populate
them with placeholder files that keep the directories under version
control until real content arrives in later steps. Write the
project-level .gitignore.

Exit criteria:
- src/.gitkeep, tests/smoke/.gitkeep, scripts/.gitkeep exist.
- .gitignore at repo root ignores build/ and nothing else yet
  (vendor has its own .gitignore landing in the next step).
- `git status` shows only tracked additions; no stray files.

Do NOT yet create vendor/ content -- that is step 3. Only lay down
the top-level skeleton so later steps have a consistent layout to
fill in.
