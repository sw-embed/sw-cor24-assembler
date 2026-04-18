# sw-cor24-assembler -- self-hosting COR24 assembler.
#
# Build glue over the vendored cor24-run (pinned by vendor/active.env
# + vendor/sw-em24/*/version.json). Recipe logic lives in scripts/;
# justfile recipes are one-line delegates.
#
# `just --list` renders the single comment line immediately above
# each recipe as its description, so keep those one-liners.

# Load vendor/active.env so $SW_EM24_VERSION is in recipe env.
set dotenv-load := true

# Show the recipe list.
default:
    @just --list

# Materialize vendor/sw-em24/<v>/bin/cor24-run from the sibling repo.
vendor-fetch:
    ./scripts/vendor-fetch.sh

# Verify every vendored artifact is present; exit non-zero if missing.
vendor-check:
    ./scripts/vendor-fetch.sh --check

# Assemble src/sw-as24.s into build/sw-as24.bin via vendored cor24-run.
build:
    ./scripts/build.sh

# Run the smoke test: sw-as24 vs cor24-run byte-identical on nop.s.
test:
    ./scripts/test.sh

# Assemble + execute a user .s file through vendored cor24-run.
run file:
    vendor/sw-em24/$SW_EM24_VERSION/bin/cor24-run --run {{file}}

# Remove the build/ directory. No-op when already absent.
clean:
    rm -rf build/
