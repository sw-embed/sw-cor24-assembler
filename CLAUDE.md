# sw-cor24-assembler -- Claude Instructions

## Project Overview

Self-hosting COR24 assembler written in COR24 assembly. Source is
`.s`, compiled by the vendored `cor24-run` Rust cross-assembler
during bootstrap, and targeted to run on COR24 hardware (emulator
today, FPGA eventually). Goal is byte-identical machine-code output
to `cor24-run --assemble`, then self-hosted assembly of its own
source once mature.

Full scope: [`docs/prd.md`](docs/prd.md). System structure and open
questions: [`docs/architecture.md`](docs/architecture.md). Current
saga's design decisions: [`docs/design.md`](docs/design.md). Saga
roadmap: [`docs/plan.md`](docs/plan.md).

No C, Rust, Python, or `make` in this repository. Implementation is
`.s` plus `bash` + `justfile` + one-line shell helpers.

## CRITICAL: AgentRail Session Protocol (MUST follow exactly)

### 1. START (do this FIRST, before anything else)
```bash
agentrail next
```
Read the output carefully. It contains your current step, prompt,
plan context, and any relevant skills/trajectories.

### 2. BEGIN (immediately after reading the next output)
```bash
agentrail begin
```

### 3. WORK (do what the step prompt says)
Do NOT ask "want me to proceed?". The step prompt IS your instruction.
Execute it directly.

### 4. COMMIT (after the work is done)
Commit your code changes with git. Use `/mw-cp` for the checkpoint
process (pre-commit checks, docs, detailed commit, push).

### 5. COMPLETE (LAST thing, after committing)
```bash
agentrail complete --summary "what you accomplished" \
  --reward 1 \
  --actions "tools and approach used"
```
- If the step failed: `--reward -1 --failure-mode "what went wrong"`
- If the saga is finished: add `--done`

### 6. STOP (after complete, DO NOT continue working)
Do NOT make further code changes after running `agentrail complete`.
Any changes after complete are untracked and invisible to the next
session. Future work belongs in the NEXT step, not this one.

## Key Rules

- **Do NOT skip steps** -- the next session depends on accurate tracking
- **Do NOT ask for permission** -- the step prompt is the instruction
- **Do NOT continue working** after `agentrail complete`
- **Commit before complete** -- always commit first, then record completion

## Useful Commands

```bash
agentrail status          # Current saga state
agentrail history         # All completed steps
agentrail plan            # View the plan
agentrail next            # Current step + context
```

## Build / Test

This project is driven by `just`. Recipes live in the top-level
`justfile`; discover them with `just --list`.

```bash
just vendor-fetch     # materialize vendor/sw-em24/<v>/bin/cor24-run
                      # from the sibling cor24-rs repo (or
                      # $SW_EM24_BIN, or system PATH -- see
                      # vendor/active.env for the override)
just build            # assemble src/sw-as24.s via vendored cor24-run
                      # -> build/sw-as24.bin + build/sw-as24.lst
just test             # byte-identical smoke test: cor24-run and
                      # sw-as24 must agree on tests/smoke/nop.s
just run FILE         # assemble + execute a user .s via cor24-run
just clean            # remove build/
```

Exit criterion for the current saga is `just test` green against
`tests/smoke/nop.s`.

## Architecture (summary)

sw-as24 is a two-pass COR24 assembler (pass 1 scans labels +
addresses, pass 2 emits code + patches forward references). ISA
coverage mirrors the Rust cross-assembler. Byte-identical output
is the one invariant the regression suite defends.

UART output is hex-ASCII, not raw binary: `cor24-run` filters
`0x00` from every observation path, so sw-as24 emits two printable
hex chars per byte. `scripts/hex2bin.sh` is the host-side decoder;
[`docs/utility.md`](docs/utility.md) sketches a future on-device
decoder (`sw-hexload`) that closes the self-hosting loop.

For the full system diagram, pipeline, data model, and the four
open questions (hosting model, static size limits, pass-1 caching,
self-host verification), read [`docs/architecture.md`](docs/architecture.md).

## Cross-Repo Context

Siblings referenced by this project (paths vary per dev system --
this tree is `/disk1/.../work/dcasm/github/sw-embed/`):

- [`cor24-rs`](https://github.com/sw-embed/cor24-rs) -- stabilized
  upstream that ships `cor24-run` (Rust cross-assembler + emulator).
  Pinned by commit in `vendor/sw-em24/v0.1.0/version.json`.
- [`sw-cor24-emulator`](https://github.com/sw-embed/sw-cor24-emulator)
  -- sw-embed fork of `cor24-rs` reserved for future divergence.
- [`sw-cor24-x-assembler`](https://github.com/sw-embed/sw-cor24-x-assembler)
  -- Rust cross-assembler library (rlib), behavioural reference.
- [`sw-cor24-project`](https://github.com/sw-embed/sw-cor24-project)
  -- ecosystem umbrella listing every COR24 repo.

See `vendor/active.env` for how this project discovers the
vendored `cor24-run` binary (sibling source tree, `$SW_EM24_BIN`
env override, or system PATH).
