# Design -- Relaunch saga

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
+-- README.md                  # revamped, describes the .s-based scope
+-- justfile                   # recipe runner
+-- .gitignore                 # build/, vendor bin/
+-- CLAUDE.md                  # updated session protocol + project rules
+-- docs/
|   +-- prd.md
|   +-- architecture.md
|   +-- design.md              # this file
|   +-- plan.md
+-- src/
|   +-- sw-as24.s              # the self-hosted assembler (starts tiny)
+-- tests/
|   +-- smoke/
|       +-- nop.s              # single "nop"; expected byte 0x00
+-- scripts/
|   +-- vendor-fetch.sh        # port of the sw-cor24-ocaml script
|   +-- build.sh               # assemble src/sw-as24.s with vendored cor24-run
|   +-- test.sh                # assemble nop.s with both tools, diff bytes
+-- vendor/
    +-- .gitignore             # ignores */v*/bin/*, keeps .gitkeep
    +-- active.env             # single-source-of-truth version pins
    +-- sw-em24/<version>/
        +-- version.json       # manifest (repo, commit, artifact paths)
        +-- bin/
            +-- .gitkeep       # placeholder; cor24-run lands here on fetch
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

Initial set -- minimum viable for the smoke test:

| Recipe          | Purpose                                                  |
| --------------- | -------------------------------------------------------- |
| `vendor-fetch`  | Materialize `vendor/sw-em24/<v>/bin/cor24-run`.          |
| `vendor-check`  | Verify that expected vendor artifacts are present.       |
| `build`         | Assemble `src/sw-as24.s` with the vendored `cor24-run`.  |
| `test`          | Run the smoke test: both tools assemble `nop.s`; diff.   |
| `run FILE`      | Assemble + execute an arbitrary `.s` via `cor24-run`.    |
| `clean`         | Remove `build/`.                                         |

Design decisions:

- No `install` target -- this project builds artifacts under `build/`
  and does not install anywhere.
- `build` does not depend on `vendor-fetch`; failing fast with a
  helpful message when the vendor binary is missing is preferable
  to silent fetching.
- `test` is the contract the relaunch saga closes against. It must
  be green by the end of this saga.

## Smoke test

Input -- `tests/smoke/nop.s`:

```
nop
```

One line, no comments. Saga-1 sw-as24 deliberately does not parse
comments (step 008 non-goal); header comments return in saga 2
once comment-stripping lands.

Expected behaviour:

1. `cor24-run --assemble tests/smoke/nop.s build/ref.bin build/ref.lst`
   emits a single byte `0xFF` (the COR24 encoding of `nop` --
   verified empirically against the Rust assembler's listing
   output).
2. `cor24-run --load-binary build/sw-as24.bin@0 --entry 0 -u "nop\x04" ...`
   loads the already-assembled sw-as24 binary, feeds the .s content
   over UART RX (terminated with 0x04 EOT), runs until self-branch
   halt. sw-as24's UART TX carries the startup banner `S` followed
   by the hex representation of the emitted byte: `"SFF"` on match,
   `"S00"` on fail.
3. `scripts/test.sh` parses cor24-run's `UART output:` summary
   line, strips the one-char banner, pipes the remaining hex text
   through `scripts/hex2bin.sh`, and `diff -q`s the decoded
   `build/candidate.bin` against `build/ref.bin`. Exit 0 iff they
   match.

### Why hex-encoded UART output

sw-as24 emits its machine-code output as ASCII hex (two printable
chars per byte) rather than raw binary. Reason: cor24-run silently
filters byte `0x00` out of every UART-TX observation path -- the
per-byte log, the summary line, and even raw stdout under
`--terminal`. Verified by probing with `lc r0, 0` vs `lc r0, 1`:
the `0x01` byte survives to stdout, the `0x00` byte does not.
Since `nop` encodes to `0xFF` and future instructions will hit
`0x00` too, emitting raw bytes forfeits observability.

Hex encoding sidesteps the filter (all hex digits are printable
0x30-0x46) and carries extra benefits: transport-robust over any
terminal, human-debuggable, matches the classical Intel-HEX /
S-record pattern for shipping binary over text channels. The
design holds even if cor24-run's filter is fixed upstream later.

`scripts/hex2bin.sh` (a one-line wrapper around `xxd -r -p`) is the
host-side decoder. It pairs with sw-as24's output anywhere: the
smoke test, an FPGA flasher, a serial-console capture.

## `src/sw-as24.s` for this saga

Minimum viable assembler: recognises literally one mnemonic, `nop`,
and emits hex for one byte. Expectations:

- UART banner `S` on startup (one printable char; test.sh strips).
- Three-byte UART read into r0, each byte compared against 'n',
  'o', 'p' in sequence via `ceq` + `brf fail`.
- On match, emit two UART bytes `F`, `F` (hex for `0xFF` = nop
  encoding). On mismatch, emit `0`, `0` (hex for `0x00` sentinel).
- Halt via branch-to-self (`halt: bra halt`). cor24-run detects
  self-branch and terminates the emulation.

Calling convention for `putc` and `getc` helpers follows the
`jal r1, (r2)` pattern from `cor24-rs/rust-to-cor24/src/examples/`
(see `uart_hello.s`): `jal` stashes the return address in `r1`;
the callee pushes `r1` on entry, pops before `jmp (r1)` on exit,
leaving r1 free as scratch inside the subroutine.

Deliberately omitted (later sagas): labels in input, comments in
input, multiple mnemonics, operands, directives, a symbol table,
two passes, proper byte-to-hex helper (currently hard-coded for
the two byte values this saga emits).

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
