Write the justfile with the relaunch recipe set.

Reference: /disk1/github/softwarewrighter/devgroup/work/dcoca/github/sw-embed/sw-cor24-ocaml/justfile

Recipes to provide (exact names):
- vendor-fetch : shells out to ./scripts/vendor-fetch.sh
- vendor-check : shells out to ./scripts/vendor-fetch.sh --check
- build        : shells out to ./scripts/build.sh
- test         : shells out to ./scripts/test.sh
- run FILE     : runs vendored cor24-run against FILE (assembles +
                 executes a user-provided .s file)
- clean        : rm -rf build/

Decisions:
- Include `set dotenv-load` so vendor/active.env is sourced
  automatically for any recipe that needs $SW_EM24_VERSION.
- Do NOT let `build` auto-invoke `vendor-fetch`; failing with a
  clear pointer to `just vendor-fetch` when the binary is missing
  is preferable to silent fetching.
- Keep recipes short; real logic belongs in scripts/.

Exit criteria:
- `just --list` shows all six recipes.
- `just clean` is a no-op on a repo that has no build/ dir (no
  error).
- `just vendor-check` exits non-zero with a clear message on a
  fresh clone where cor24-run has not been fetched.
