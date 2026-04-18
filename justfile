# sw-cor24-assembler -- self-hosting COR24 assembler
# Build system using a vendored cor24-run (Rust cross-assembler +
# emulator, pinned by vendor/active.env + vendor/sw-em24/*/version.json).

# Load vendor/active.env so $SW_EM24_VERSION and siblings are in
# recipe environment. This is how the `run` recipe finds the
# vendored binary without hardcoding the version.
set dotenv-load := true

# Default: show the recipe list.
default:
    @just --list

# Materialize vendor/sw-em24/<v>/bin/cor24-run from the upstream
# sibling repo. Idempotent; safe to run on every clone.
vendor-fetch:
    ./scripts/vendor-fetch.sh

# Verify every vendored artifact is present. Exits non-zero with a
# clear hint if a binary is missing.
vendor-check:
    ./scripts/vendor-fetch.sh --check

# Assemble src/sw-as24.s into build/sw-as24.bin using the vendored
# cor24-run. Does NOT auto-invoke vendor-fetch; it fails fast with a
# pointer to `just vendor-fetch` if the binary is not in place.
build:
    ./scripts/build.sh

# Run the smoke test: byte-identical output for tests/smoke/nop.s
# between sw-as24 (self-hosted) and cor24-run (reference).
test:
    ./scripts/test.sh

# Assemble + execute a user-provided .s file through the vendored
# cor24-run. Useful for sanity-checking an input before routing it
# through sw-as24.
# Usage: just run tests/smoke/nop.s
run file:
    vendor/sw-em24/$SW_EM24_VERSION/bin/cor24-run --run {{file}}

# Remove the build/ directory. No-op when it is already absent.
clean:
    rm -rf build/
