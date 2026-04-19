Create the vendor manifest layout for the sw-em24 (cor24-run) tool.

Mirror sw-cor24-ocaml/vendor/ exactly. Files to create:

- vendor/.gitignore
  Pattern: `*/v*/bin/*` to ignore binaries, `!*/v*/bin/.gitkeep` to
  preserve the directory. Copy the ocaml precedent verbatim.
- vendor/active.env
  Single line: `SW_EM24_VERSION=v0.1.0` plus a header comment
  explaining it is the single source of truth for version pins.
- vendor/sw-em24/v0.1.0/version.json
  Manifest. Required fields (see
  /disk1/github/softwarewrighter/devgroup/work/dcoca/github/sw-embed/sw-cor24-ocaml/vendor/sw-em24/v0.1.0/version.json
  for the precedent): name "sw-em24", version "v0.1.0", description,
  repo "https://github.com/sw-embed/sw-cor24-emulator.git",
  repo_path_local "../sw-cor24-emulator", commit (SHA of the
  upstream sibling's current HEAD), tag "TBD", build_cmd
  "cargo build --release", binary_src "target/release/cor24-run",
  platforms{} with sha256/size TBD, recorded_at/recorded_by TBD.
- vendor/sw-em24/v0.1.0/bin/.gitkeep
  Empty placeholder so the bin dir is tracked.

The upstream sibling path to resolve is
../sw-cor24-emulator relative to this repo (so:
/disk1/github/softwarewrighter/devgroup/work/dcasm/github/sw-embed/sw-cor24-emulator).
If that path does not exist in this worktree, leave commit as "TBD"
and document the gap in the step summary; the next step
(vendor-fetch-script) will catch and report the missing sibling.

Exit criteria:
- All four files present with correct content.
- `jq -r '.name' vendor/sw-em24/v0.1.0/version.json` prints sw-em24.
