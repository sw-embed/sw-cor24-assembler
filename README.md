# sw-cor24-assembler

A self-hosting COR24 assembler written in COR24 assembly.

## Status

**Relaunch saga in progress.** The project was re-scoped away from a
C implementation to a `.s`-only implementation that will eventually
assemble its own source on COR24 hardware. Current milestone:
single-mnemonic smoke test -- `sw-as24` reads `nop` on UART, emits
the byte-identical encoding that the Rust cross-assembler would
produce.

See [`docs/plan.md`](docs/plan.md) for the saga breakdown.

## Quickstart

```bash
just vendor-fetch    # materialize vendor/sw-em24/<v>/bin/cor24-run
                     # from the sibling cor24-rs repo (or SW_EM24_BIN
                     # override, or system PATH -- see vendor/active.env)
just build           # assemble src/sw-as24.s -> build/sw-as24.bin
just test            # smoke test: cor24-run's and sw-as24's output
                     # on tests/smoke/nop.s are byte-identical
just --list          # discover every recipe
```

Requirements on the host: `bash`, `just`, `jq`, `xxd` (ships in
`vim-common` on most distros). For `just vendor-fetch` to build
from source, also `cargo` + `rustc` and a clone of
[cor24-rs](https://github.com/sw-embed/cor24-rs) at
`../cor24-rs`. See the fallback options documented in
[`vendor/active.env`](vendor/active.env).

## Repository layout

```
sw-cor24-assembler/
|-- README.md                # this file
|-- justfile                 # build / test / vendor recipes
|-- docs/
|   |-- prd.md               # product requirements (long-lived)
|   |-- architecture.md      # system architecture (long-lived)
|   |-- design.md            # current-saga design decisions
|   |-- plan.md              # saga roadmap
|   `-- utility.md           # forward-looking sw-hexload sketch
|-- src/
|   `-- sw-as24.s            # the self-hosted assembler (grows each saga)
|-- tests/
|   `-- smoke/nop.s          # byte-identical smoke test input
|-- scripts/
|   |-- vendor-fetch.sh      # fetch vendored tools from manifests
|   |-- build.sh             # assemble sw-as24.s via vendored cor24-run
|   |-- test.sh              # run the smoke test pipeline
|   `-- hex2bin.sh           # host-side decoder for sw-as24's hex output
|-- vendor/
|   |-- active.env           # single-source-of-truth version pins
|   `-- sw-em24/<v>/         # vendored cor24-run (binary is gitignored)
|-- .agentrail/              # saga tracking (see docs/plan.md)
`-- .agentrail-archive/      # prior C-era saga, preserved for reference
```

## Documentation

- [PRD](docs/prd.md) -- goals, non-goals, success criteria, stakeholders.
- [Architecture](docs/architecture.md) -- pipeline, data model, open
  questions (hosting model, static size limits, self-host verification).
- [Design](docs/design.md) -- current-saga directory layout, vendor
  strategy, justfile recipe set, smoke-test spec, hex-encoded UART
  output rationale.
- [Plan](docs/plan.md) -- saga roadmap and change log.
- [Utility](docs/utility.md) -- forward-looking design for
  `sw-hexload`, the device-side companion to sw-as24's hex output.

## Cross-repo context

- [cor24-rs](https://github.com/sw-embed/cor24-rs) -- the stabilized
  upstream that ships `cor24-run` (combined Rust cross-assembler +
  emulator) and the reference assembler library this project ports
  from. Vendored by pinned commit in
  [`vendor/sw-em24/v0.1.0/version.json`](vendor/sw-em24/v0.1.0/version.json).
- [sw-cor24-emulator](https://github.com/sw-embed/sw-cor24-emulator)
  -- sw-embed fork of `cor24-rs` reserved for future divergent changes.
  No tracked divergence yet; we vendor from `cor24-rs` directly.
- [sw-cor24-x-assembler](https://github.com/sw-embed/sw-cor24-x-assembler)
  -- Rust cross-assembler library (rlib) used as the behavioural
  reference. Included transitively via `cor24-run`.
- [sw-cor24-project](https://github.com/sw-embed/sw-cor24-project) --
  the ecosystem umbrella listing every COR24 repo.

## What is a "COR24 assembler"?

COR24 is a 24-bit RISC ISA (MakerLisp-inspired). `cor24-run` is the
Rust host tool that assembles `.s` files into machine code and/or
runs them on the emulator. This project's goal is to produce an
assembler that can run on *COR24 itself* -- byte-identical output
to `cor24-run --assemble`, with no host dependencies once the
toolchain is self-hosted.

Full statement of goals and success criteria: [`docs/prd.md`](docs/prd.md).
