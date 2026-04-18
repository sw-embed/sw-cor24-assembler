# Plan -- `sw-as24` sagas

**Status:** Draft (Relaunch saga)
**Scope:** Living roadmap. The current saga is detailed; later sagas
are stubs to be fleshed out when they become current.

## Conventions

- One saga = one reviewable unit of work ending in a PR.
- Sagas are tracked in `.agentrail/`; archived sagas land in
  `.agentrail-archive/`.
- The feature branch (`feat/relaunch-project` for saga 1) accumulates
  commits throughout a saga. At saga completion, the branch is
  renamed / opened as a PR targeting `dev`.

## Current saga: 1. Relaunch

**Goal:** replace the obsolete C-based scope with `.s`-based
scaffolding + a single-mnemonic smoke test end-to-end.

**Exit criteria:**

- `docs/{prd,architecture,design,plan}.md` present and consistent.
- Directory layout from `design.md` instantiated.
- `just vendor-fetch` succeeds against a locally-built sibling
  `sw-cor24-emulator`.
- `just test` passes: `sw-as24` (built from `src/sw-as24.s`) emits
  `0x00` for `tests/smoke/nop.s`, byte-identical to `cor24-run`'s
  output for the same input.
- README, CLAUDE.md, and `.gitignore` match the new scope.

**Planned steps** (provisional; authoritative list lives in
`.agentrail/` once the saga is initialised):

| # | Slug                      | Summary                                                                 |
|---|---------------------------|-------------------------------------------------------------------------|
| 1 | docs-foundation           | Land `docs/{prd,architecture,design,plan}.md` (this commit family).     |
| 2 | layout-skeleton           | Create empty `src/`, `tests/smoke/`, `scripts/`, `vendor/` with README-level placeholders and project `.gitignore`. |
| 3 | vendor-manifest           | Write `vendor/active.env`, `vendor/.gitignore`, `vendor/sw-em24/<v>/version.json`, `vendor/sw-em24/<v>/bin/.gitkeep`. |
| 4 | vendor-fetch-script       | Port `scripts/vendor-fetch.sh` from `sw-cor24-ocaml`; pare it down to the single `sw-em24` tool and exercise `--check`. |
| 5 | justfile                  | Write `justfile` with `vendor-fetch`, `vendor-check`, `build`, `test`, `run`, `clean`. |
| 6 | build-script              | Write `scripts/build.sh` that invokes vendored `cor24-run` on `src/sw-as24.s` and drops artifacts under `build/`. |
| 7 | smoke-input               | Write `tests/smoke/nop.s` and `scripts/test.sh` (runs both assemblers on the input and diffs the byte output). |
| 8 | sw-as24-skeleton          | Write `src/sw-as24.s` with UART I/O, banner, and the single-mnemonic recogniser for `nop` -> `0x00`. |
| 9 | readme-revamp             | Rewrite `README.md` for the new scope; link to `docs/`.                 |
|10 | claude-md-revamp          | Rewrite `CLAUDE.md` to match the `.s` scope; preserve AgentRail protocol. |
|11 | saga-close                | Verify the whole saga end-to-end, update `docs/plan.md` to reflect completion, `agentrail complete --done`, archive saga. |

Steps 1-4 are pure infrastructure. Steps 5-7 wire the build and test
harness. Step 8 is the only `.s` code, intentionally trivial. Steps
9-11 finalise.

**Explicit non-goals for this saga** (quoted from `design.md`):
labels, comments, multiple mnemonics, operands, directives, symbol
table, two passes.

## Upcoming sagas (stubs)

The ordering below is a current best guess. A stub may be split,
merged, or reordered when it becomes current.

### 2. Lexer and line parsing

Introduce real line parsing: comment stripping, label recognition,
mnemonic + operand tokenisation, numeric literal parsing
(decimal, hex, signed). Expands the recognised mnemonic set from 1
to a small handful (`nop`, `mov`, `push`, `pop`, plus whatever the
smoke tests need). Picks up **Q2** (static size limits) and
**Q3** (pass-1 caching) from `architecture.md`.

### 3. Register + addressing mode parser

Parse `r0..r2`, `fp`, `sp`, `z`, `iv`, `ir`, and the
`offset(base)` addressing form. Exercises the first real operand
decoding logic.

### 4. Instruction encoding -- no-operand and register-only

Encode every mnemonic that has only register (or no) operands.
Includes the ALU group (`add`, `sub`, `mul`, `and`, `or`, `xor`,
`shl`, `sra`, `srl`), the comparison group (`ceq`, `cls`, `clu`),
the extension group (`sxt`, `zxt`), and `mov` / `push` / `pop`.

### 5. Instruction encoding -- immediates and loads

Encode mnemonics that carry immediate operands or offset-base
addressing: `lc`, `lcu`, `la`, `lb`, `lbu`, `lw`, `sb`, `sw`.

### 6. Symbol table and two-pass assembly

Implement pass 1 (label collection + address assignment) and pass 2
(emission with known-symbol resolution). Forward references still
unsupported; they error rather than silently mis-encode.

### 7. Forward references

Record and patch forward references for branches (`rel8`) and `la`
(`abs24`). Report unresolved symbols and out-of-range branches.

### 8. Branch / jump encoding

Encode `bra`, `brt`, `brf`, `jmp`, `jal` (depending on operand form
and whether the symbol table already resolves the target from
saga 6 / 7 -- exact split pinned when this saga becomes current).

### 9. Directives

Implement `.org`, `.byte`, `.word`, `.comm`; silently accept the
no-op directives (`.text`, `.data`, `.globl`, `.align`).

### 10. Error reporting polish

Line numbers on every error, aggregation, non-zero exit on failure,
exhaustive error-category taxonomy. Tests with deliberately malformed
inputs.

### 11. Hosting-model decision

Resolve **Q1** from `architecture.md`. Choose standalone UART or
monitor-hosted and wire the chosen I/O path into `sw-as24.s`.

### 12. Full ecosystem regression

Collect `.s` inputs from `sw-cor24-forth`, `sw-cor24-macrolisp`,
`sw-cor24-pascal`, `sw-cor24-pcode`, and the emulator examples.
Assemble each with both `sw-as24` and `cor24-run`; require
byte-identical output. Fix divergences.

### 13. Self-hosting close (G5)

`sw-as24` assembles its own source (`src/sw-as24.s`) and the
resulting binary is byte-identical to `cor24-run`'s output for the
same source. Triggers the PRD's S3 success criterion.

### 14. Release

Tag a 0.1.0, write `CHANGES.md`, update
`sw-cor24-project/docs/status.md` to mark the native assembler
complete, and publish to GitHub. The vendor pin in `active.env`
moves from a local-path alias to a real `sw-cor24-x-assembler`
release artifact once one exists.

## Change log

- 2026-04-18: Initial draft landed as part of the Relaunch saga.
