#!/usr/bin/env bash
#
# vendor-fetch.sh -- materialize vendored toolchain artifacts from
# the manifests committed under vendor/<tool>/<version>/version.json.
#
# This project vendors exactly one tool: sw-em24 (the COR24 emulator,
# upstream sw-cor24-emulator, binary cor24-run). cor24-run is used
# during bootstrap as both the cross-assembler (to build src/sw-as24.s)
# and the emulator (to run the resulting binary). Once sw-as24
# self-hosts (plan.md saga 13), the vendored tool is retained only
# for regression testing.
#
# Usage:
#   ./scripts/vendor-fetch.sh           -- fetch all tools
#   ./scripts/vendor-fetch.sh --check   -- verify artifacts exist
#   ./scripts/vendor-fetch.sh --help
#
# Dependencies: bash, jq, cargo (in the sibling repo, for --release).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor"
ACTIVE_ENV="$VENDOR_DIR/active.env"

cd "$REPO_ROOT"

# --- Argument parsing -------------------------------------------------------

MODE="fetch"

while [ $# -gt 0 ]; do
    case "$1" in
        --check)
            MODE="check"
            shift
            ;;
        -h|--help)
            sed -n '2,18p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

# --- Load active.env --------------------------------------------------------

if [ ! -f "$ACTIVE_ENV" ]; then
    echo "error: $ACTIVE_ENV not found" >&2
    echo "hint: ensure step 003-vendor-manifest has landed in this branch" >&2
    exit 4
fi

# shellcheck source=/dev/null
. "$ACTIVE_ENV"

# --- Helpers ----------------------------------------------------------------

manifest_get() {
    # $1=manifest path, $2=jq filter expression
    jq -r "$2" "$1"
}

resolve_local_repo() {
    # $1=manifest path
    # repo_path_local is relative to the repo root.
    local local_path abs
    local_path="$(manifest_get "$1" .repo_path_local)"
    if [ "$local_path" != "null" ] && [ "$local_path" != "TBD" ]; then
        abs="$(cd "$REPO_ROOT" && cd "$local_path" 2>/dev/null && pwd)" || true
        if [ -n "${abs:-}" ] && [ -d "$abs/.git" ]; then
            echo "$abs"
            return 0
        fi
    fi
    echo ""
}

# --- Fetch sw-em24 (cor24-run) ---------------------------------------------

fetch_em24() {
    local version="${SW_EM24_VERSION:?SW_EM24_VERSION unset in vendor/active.env}"
    local dest="$VENDOR_DIR/sw-em24/$version"
    local manifest="$dest/version.json"
    local expected_path upstream

    echo "--- sw-em24 $version ---"

    if [ ! -f "$manifest" ]; then
        echo "error: manifest not found: $manifest" >&2
        return 1
    fi

    expected_path="$(manifest_get "$manifest" .repo_path_local)"

    if [ "$MODE" = "check" ]; then
        if [ -f "$dest/bin/cor24-run" ]; then
            echo "  cor24-run: ok"
            return 0
        else
            echo "  cor24-run: MISSING"
            echo "  hint: run ./scripts/vendor-fetch.sh to fetch"
            return 1
        fi
    fi

    upstream="$(resolve_local_repo "$manifest")"
    if [ -z "$upstream" ]; then
        echo "error: sw-em24: upstream sibling not found at $expected_path" >&2
        echo "       (manifest: $manifest)" >&2
        echo "hint: clone https://github.com/sw-embed/sw-cor24-emulator.git" >&2
        echo "      into $REPO_ROOT/$expected_path and run 'cargo build --release' there" >&2
        return 1
    fi

    local commit
    commit="$(manifest_get "$manifest" .commit)"
    echo "  upstream: $upstream (commit $commit)"

    local cor24_src="$upstream/target/release/cor24-run"
    if [ -f "$cor24_src" ]; then
        cp "$cor24_src" "$dest/bin/cor24-run"
        chmod +x "$dest/bin/cor24-run"
        echo "  copied: cor24-run"
    else
        echo "  warning: $cor24_src not found" >&2
        echo "           run 'cargo build --release' in $upstream" >&2
        return 1
    fi
}

# --- Main -------------------------------------------------------------------

echo "vendor-fetch: mode=$MODE"
echo ""

fetch_em24
fetch_em24_rc=$?
echo ""

echo "vendor-fetch: done"
exit "$fetch_em24_rc"
