# Design — Relaunch saga

**Status:** Draft (Relaunch saga)
**Scope:** The scaffolding and first smoke test that prove the
pivot. This document is rewritten each phase; when the next saga
begins, prior phases' content moves to a dated section or is replaced.

## Objective

End the relaunch saga with a repository that (a) no longer describes a
C implementation, (b) builds its own `.s` source through a vendored
`cor24-run`, and (c) passes a smoke test that exercises the full
toolchain end-to-end on the single mnemonic `nop`.

## Directory layout

```
sw-cor24-assembler/
├── README.md                  # revamped, describes the .s-based scope
├── justfile                   # recipe runner
├── .gitignore                 # build/, vendor bin/
├── CLAUDE.md                  # updated session protocol + project rules
├── docs/
│   ├── prd.md
│   ├── architecture.md
│   ├── design.md              # this file
│   └── plan.md
├── src/
│   └── sw-as24.s              # the self-hosted assembler (starts tiny)
├── tests/
│   └── smoke/
│       └── nop.s              # single "nop"; expected byte 0x00
├── scripts/
│   ├── vendor-fetch.sh        # port of the sw-cor24-ocaml script
│   ├── build.sh               # assemble src/sw-as24.s with vendored cor24-run
│   └── test.sh                # assemble nop.s with both tools, diff bytes
└── vendor/
    ├── .gitignore             # ignores */v*/bin/*, keeps .gitkeep
    ├── active.env             # single-source-of-truth version pins
    └── sw-em24/<version>/
        ├── version.json       # manifest (repo, commit, artifact paths)
        └── bin/
            └── .gitkeep       # placeholder; cor24-run lands here on fetch
```

The `.agentrail/` directory (new saga) and `.agentrail-archive/`
(preserved C-era saga) are tracked but are not part of the build
surface.

## Vendor strategy

Directly mirrors `sw-cor24-ocaml`. Every vendored tool has:

1. An entry in `vendor/active.env`:
   ```
   SW_EM24_VERSION=v0.1.0
   ```
2. A manifest at `vendor/<tool>/<version>/version.json` with (at
   minimum) the upstream repo, a local sibling path, the pinned
   commit SHA, and a map of artifacts to copy.
3. A gitignored `bin/` (kept present by `.gitkeep`) where
   `scripts/vendor-fetch.sh` deposits the built binary.
4. A copy rule in `scripts/vendor-fetch.sh` that locates the local
   sibling repo via `repo_path_local`, verifies the pinned commit,
   and copies `target/release/cor24-run` into the manifest's `bin/`
   directory.

The one vendored tool for the relaunch saga is `sw-em24` (upstream
`sw-cor24-emulator`, artifact `cor24-run`). The Rust cross-assembler
library (`sw-cor24-x-assembler`) is a transitive dependency of
`cor24-run` and is not vendored separately; if a later saga needs to
consult its source, it does so by path, not by copy. The user may
elect to re-vendor against a different upstream later; the version
pin (`active.env`) is the only thing that needs to change.

## Justfile recipes

Initial set — minimum viable for the smoke test:

| Recipe          | Purpose                                                  |
| --------------- | -------------------------------------------------------- |
| `vendor-fetch`  | Materialize `vendor/sw-em24/<v>/bin/cor24-run`.          |
| `vendor-check`  | Verify that expected vendor artifacts are present.       |
| `build`         | Assemble `src/sw-as24.s` with the vendored `cor24-run`.  |
| `test`          | Run the smoke test: both tools assemble `nop.s`; diff.   |
| `run FILE`      | Assemble + execute an arbitrary `.s` via `cor24-run`.    |
| `clean`         | Remove `build/`.                                         |

Design decisions:

- No `install` target — this project builds artifacts under `build/`
  and does not install anywhere.
- `build` does not depend on `vendor-fetch`; failing fast with a
  helpful message when the vendor binary is missing is preferable
  to silent fetching.
- `test` is the contract the relaunch saga closes against. It must
  be green by the end of this saga.

## Smoke test

Input — `tests/smoke/nop.s`:

```
; single nop, one byte
nop
```

Expected behaviour:

1. `cor24-run --assemble tests/smoke/nop.s` (or equivalent
   invocation; exact flag pinned during the saga) emits a single
   byte `0x00`.
2. `sw-as24`, built from `src/sw-as24.s` by the same `cor24-run`,
   then run against `tests/smoke/nop.s` as input, emits the same
   single byte `0x00`.
3. `scripts/test.sh` diffs the two outputs and exits 0 iff they
   match.

## `src/sw-as24.s` for this saga

Minimum viable assembler: recognises literally one mnemonic, `nop`,
and emits one byte. Expectations:

- UART input loop that reads a line into an input buffer.
- String compare against the literal `nop`.
- On match, emit `0x00` to UART output.
- On mismatch or end-of-input with no match, emit an error code and
  exit non-zero.

Deliberately omitted (later sagas): labels, comments, multiple
mnemonics, operands, directives, a symbol table, two passes.

## README revamp

Replace the current C-oriented README with a scope statement that
matches the PRD:

- One-line description: self-hosting COR24 assembler written in
  COR24 assembly.
- Build: `just vendor-fetch && just build`.
- Test: `just test`.
- Status: Relaunch in progress; single-mnemonic smoke test is the
  current milestone.
- Links: PRD, architecture, plan.

## CLAUDE.md update

The existing `CLAUDE.md` still describes the C implementation (tc24r,
no structs, no malloc, etc.). It must be rewritten to match the new
scope:

- Remove tc24r C subset constraints.
- Replace build instructions with `just build` / `just test`.
- Keep the AgentRail session protocol (it is tool-bound, not
  implementation-bound).
- Update architecture summary to point at `docs/architecture.md`
  rather than duplicating it.

## Out of scope for this saga

Anything not listed above. The plan document enumerates which saga
picks up each deferred topic.
