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

    # Three resolution strategies, in order of preference:
    #   1. $SW_EM24_BIN -- explicit path set in active.env or the
    #      shell environment. Highest priority: a dev can always
    #      override by pointing at a known-good binary.
    #   2. Upstream sibling + cargo target/release (the canonical
    #      build-from-source flow this manifest describes).
    #   3. System-installed cor24-run on PATH (last-resort fallback
    #      on dev systems that don't follow the sibling-repos
    #      layout).
    # Pick the first that yields an existing file; copy it into
    # the vendored bin/.

    local cor24_src=""

    if [ -n "${SW_EM24_BIN:-}" ]; then
        if [ -f "$SW_EM24_BIN" ]; then
            cor24_src="$SW_EM24_BIN"
            echo "  source: SW_EM24_BIN override ($cor24_src)"
        else
            echo "error: SW_EM24_BIN is set but $SW_EM24_BIN is not a file" >&2
            return 1
        fi
    fi

    if [ -z "$cor24_src" ]; then
        upstream="$(resolve_local_repo "$manifest")"
        if [ -n "$upstream" ]; then
            local commit bin_rel build_cmd build_cwd
            commit="$(manifest_get "$manifest" .commit)"
            bin_rel="$(manifest_get "$manifest" .binary_src)"
            build_cmd="$(manifest_get "$manifest" .build_cmd)"
            build_cwd="$(manifest_get "$manifest" '.build_cwd // "."')"
            echo "  upstream: $upstream (commit $commit)"
            local candidate="$upstream/$bin_rel"
            if [ -f "$candidate" ]; then
                cor24_src="$candidate"
            else
                echo "  warning: $candidate not built" >&2
                echo "           run '$build_cmd' in $upstream/$build_cwd" >&2
            fi
        fi
    fi

    if [ -z "$cor24_src" ]; then
        local sys_bin
        sys_bin="$(command -v cor24-run 2>/dev/null || true)"
        if [ -n "$sys_bin" ]; then
            cor24_src="$sys_bin"
            echo "  source: system PATH ($cor24_src)"
        fi
    fi

    if [ -z "$cor24_src" ]; then
        echo "error: sw-em24: no cor24-run binary could be resolved" >&2
        echo "  tried (in order):" >&2
        echo "    1. \$SW_EM24_BIN override     -- unset" >&2
        echo "    2. $expected_path/target/release/cor24-run" >&2
        echo "                                  -- sibling not populated or not built" >&2
        echo "    3. cor24-run on system PATH   -- not found" >&2
        echo "  to fix, pick one:" >&2
        echo "    - export SW_EM24_BIN=/path/to/cor24-run  (or set it in vendor/active.env)" >&2
        echo "    - git clone https://github.com/sw-embed/sw-cor24-emulator.git $REPO_ROOT/$expected_path" >&2
        echo "      && (cd $REPO_ROOT/$expected_path && cargo build --release)" >&2
        return 1
    fi

    cp "$cor24_src" "$dest/bin/cor24-run"
    chmod +x "$dest/bin/cor24-run"
    echo "  copied: cor24-run"
}

# --- Main -------------------------------------------------------------------

echo "vendor-fetch: mode=$MODE"
echo ""

fetch_em24
fetch_em24_rc=$?
echo ""

echo "vendor-fetch: done"
exit "$fetch_em24_rc"
