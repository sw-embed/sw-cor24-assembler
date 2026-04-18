Write scripts/build.sh -- the bash wrapper that invokes the vendored
cor24-run to assemble src/sw-as24.s.

Responsibilities:
1. Verify vendor/sw-em24/v*/bin/cor24-run exists. If not, print a
   helpful message naming `just vendor-fetch` and exit non-zero.
2. Load vendor/active.env to learn the active version.
3. Create build/ if missing.
4. Invoke cor24-run to assemble src/sw-as24.s into
   build/sw-as24.bin. The exact flag syntax is pinned by consulting
   `cor24-run --help` during this step -- look for an assemble-only
   mode (e.g. --assemble) or document the observed behaviour.
5. Exit 0 on success, non-zero on any assembler error (cor24-run
   error messages should surface to stderr unfiltered).

Constraints (from docs/design.md):
- Bash + vendored cor24-run only. No Rust, C, Python, make
  invocations.
- The script must be runnable directly (`./scripts/build.sh`) and
  from the justfile recipe.

Exit criteria:
- scripts/build.sh is executable and passes `bash -n`.
- Running it after step 8 (once src/sw-as24.s exists) produces
  build/sw-as24.bin.
- Running it on a clean clone without a vendored binary exits
  non-zero with a message pointing at `just vendor-fetch`.
