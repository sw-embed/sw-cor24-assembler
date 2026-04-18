Port scripts/vendor-fetch.sh from sw-cor24-ocaml, tailored to this
project's single vendored tool (sw-em24).

Reference:
/disk1/github/softwarewrighter/devgroup/work/dcoca/github/sw-embed/sw-cor24-ocaml/scripts/vendor-fetch.sh

Keep: the shebang + `set -euo pipefail`, the SCRIPT_DIR / REPO_ROOT
bootstrap, the `--check` mode, the active.env source, the
`manifest_get` jq helper, and the `resolve_local_repo` helper.

Drop: the fetch_pascal, fetch_pcode helpers (we do not vendor those
tools). Keep fetch_em24, simplified: copy
<upstream>/target/release/cor24-run into vendor/sw-em24/<ver>/bin/.
Respect MODE=check for --check.

Produce helpful errors:
- Missing vendor/active.env -> exit 4 with a pointer to step 3.
- Missing upstream sibling -> exit 1 with the path the manifest
  expected to resolve.
- Missing cor24-run binary -> warn with the cargo build command
  the user should run in the sibling repo.

Exit criteria:
- scripts/vendor-fetch.sh is executable (chmod +x) and bash-shellcheck-clean.
- `./scripts/vendor-fetch.sh --check` runs without crashing (it may
  report MISSING for cor24-run on a fresh clone; that is the point).
- Running without flags, given a sibling repo with a built
  cor24-run, populates vendor/sw-em24/v0.1.0/bin/cor24-run and a
  second --check reports ok.
