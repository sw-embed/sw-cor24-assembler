# Plan -- `sw-as24` sagas

**Status:** Specs-foundation saga (saga 2) is current. Relaunch
(saga 1) closed 2026-04-18. Lexer and line parsing, formerly
saga 2, is now saga 3; all subsequent sagas shifted by +1.
**Scope:** Living roadmap. The current saga is detailed; later sagas
are stubs to be fleshed out when they become current.

## Conventions

- One saga = one reviewable unit of work ending in a rename from
  `feat/<slug>` to `pr/<slug>`.
- Sagas are tracked in `.agentrail/`; archived sagas land in
  `.agentrail-archive/`.
- The feature branch (`feat/relaunch-project` for saga 1) accumulates
  commits throughout a saga. At saga completion, the dev agent runs
  `git branch -m feat/<slug> pr/<slug>` -- that rename IS the
  handoff. A separate release engineer agent picks up the `pr/`
  branch, merges it into `dev`, and pushes to GitHub. Dev agents
  have no write access to the remote and do not invoke `git push`,
  `gh pr create`, or any other GitHub-side command.

## Current saga: 2. Specs foundation

Land repo-local, authoritative specifications so that every
downstream saga (lexer, encoder, symbol table, regression, self-
host) implements against *this repo* rather than deferring to
sibling repos for ISA / language / format details.

**Goal:** six specification documents live under `docs/`, each
authoritative for one axis of sw-as24's behaviour, each with a
provenance footer naming its sources.

**Outputs:**

- [`docs/isa.md`](isa.md) -- COR24 ISA: registers (r0, r1, r2,
  fp, sp, z, iv, ir, c -- selectors 0..7 are internal only),
  memory map, I/O, 34-mnemonic instruction set, decode ROM
  byte-level mapping, addressing modes, calling convention.
- [`docs/as24-language.md`](as24-language.md) -- `.s` source
  language: lexical rules, literals (decimal + `0...h` hex),
  labels on own line, symbols, directives
  (`.text`/`.data`/`.bss`/`.byte`/`.word`/`.comm`/`.globl`/
  `. = . + N`), branch-too-far rewriting, error format,
  optional `-O` peephole optimizer.
- [`docs/output-formats.md`](output-formats.md) -- `.lgo`
  (as24.c default, hex-ASCII load + go), `.lst` (listing
  layout), `.obj` (linkable records), `.s` roundtrip, plus
  the raw `.bin` convention cor24-run uses today.
- [`docs/fpga-runtime.md`](fpga-runtime.md) -- runtime
  environment: SRAM/EBR/MMIO map, UART protocol, reset, the
  multi-binary loading model (cor24-run `--load-binary @addr`,
  `--patch`, `_main` entry convention) established by sws+swye.
- [`docs/self-host-toolchain.md`](self-host-toolchain.md) --
  editor/linker/loader/monitor contract; mostly open questions;
  points at sw-cor24-script + sw-cor24-yocto-ed as the existing
  multi-binary precedent.
- [`docs/oracle-protocol.md`](oracle-protocol.md) -- REST
  oracle served by as24.c (URL / request-shape TBD), test
  corpus inventory (per-opcode, directive coverage, edge cases),
  regression-procedure sketch.

**Plus:** CLAUDE.md index; `docs/architecture.md` §2 repointed
from sibling-repo references to in-repo specs; this plan
renumbered.

**Exit:** all six docs committed, referenced from CLAUDE.md and
`docs/architecture.md`. No sw-as24 behavioural change in this
saga -- it is documentation only. The vendor repoint from
cor24-rs to sw-cor24-x-assembler is **not** part of this saga;
it is blocked on upstream x-assembler landing a `[[bin]]`
target, and tracked for a later saga once that unblocks.

## Completed sagas

### 1. Relaunch (closed 2026-04-18)

**Goal met:** replaced the obsolete C-based scope with a `.s`-based
scaffolding that passes a byte-identical single-mnemonic smoke test
end-to-end, on a cold vendor + build from `just vendor-fetch` +
`just build` + `just test`.

**Exit criteria (as shipped):**

- `docs/{prd,architecture,design,plan,utility}.md` present and
  consistent. (`utility.md` added mid-saga to document the future
  device-side hex decoder.)
- Directory layout from `design.md` instantiated.
- `just vendor-fetch` resolves a vendored `cor24-run` via the
  sibling `cor24-rs` repo (or `$SW_EM24_BIN` override, or system
  PATH); manifest pins commit `40033d90e80dcef1a420bd3db7c8fd22fb9f181f`.
  (The step prompt originally named `sw-cor24-emulator` as the
  sibling; discovered mid-saga that `cor24-rs` is the stabilized
  upstream and `sw-cor24-emulator` is an as-yet-undiverged fork.)
- `just test` passes byte-identical: `cor24-run --assemble nop.s`
  produces `0xFF`; `sw-as24` emits hex-ASCII `"SFF"` on UART TX;
  after banner-strip + `scripts/hex2bin.sh`, candidate = `0xFF`.
  (The step prompt assumed `nop` encodes to `0x00`; empirically
  it's `0xFF`, corrected mid-saga.)
- README, CLAUDE.md, and `.gitignore` rewritten for the new scope.

**Design decisions that landed:**

- Vendoring pattern mirrors `sw-cor24-ocaml`. `vendor/active.env`
  as single source of truth for versions. `vendor-fetch.sh`
  resolves binaries via three strategies (env override, sibling
  source build, system PATH).
- sw-as24 emits hex-ASCII on UART TX rather than raw bytes,
  because `cor24-run` filters `0x00` from every observation path.
  `scripts/hex2bin.sh` is the host-side decoder; `sw-hexload`
  (future) is the device-side decoder.
- Saga-1 sw-as24 is deliberately minimal: no labels, no comments
  in input, no operands, no directives, no symbol table, no
  two-pass. Every one of those is a later saga.

**Steps (as run):**

| # | Slug                      | Outcome |
|---|---------------------------|---------|
| 1 | docs-foundation           | `docs/{prd,architecture,design,plan}.md` (587 lines). |
| 2 | layout-skeleton           | `src/ tests/smoke/ scripts/` + `.gitignore`. |
| 3 | vendor-manifest           | `vendor/active.env`, `vendor/sw-em24/v0.1.0/version.json`. |
| 4 | vendor-fetch-script       | `scripts/vendor-fetch.sh` ported from ocaml; later extended with `$SW_EM24_BIN` override and system-PATH fallback. |
| 5 | justfile                  | Six recipes + `default` list. |
| 6 | build-script              | `scripts/build.sh` with assembly-error propagation. |
| 7 | smoke-input               | `tests/smoke/nop.s` + `scripts/test.sh` (multiple rewrites). |
| 8 | sw-as24-skeleton          | `src/sw-as24.s` (106 bytes assembled). Adopted hex-ASCII output mid-step. |
| 9 | readme-revamp             | `README.md` rewrite + ASCII cleanup sweep across all `docs/*.md`. |
|10 | claude-md-revamp          | `CLAUDE.md` rewrite; AgentRail protocol preserved byte-identical. |
|11 | saga-close                | This. |

**Non-goals delivered-as-expected** (from saga 1's `design.md`):
labels, comments in input, multiple mnemonics, operands, directives,
symbol table, two passes. All deferred to sagas 3-10 (renumbered
after saga 2 was inserted; originally written as sagas 2-9).

## Upcoming sagas (stubs)

The ordering below is a current best guess. A stub may be split,
merged, or reordered when it becomes current.

### 3. Lexer and line parsing

Not yet planned in detail. Authoritative step list will be written
into `.agentrail/` when this saga starts.

**Anticipated goal:** move sw-as24 from its saga-1 "three-byte
compare against the literal nop" to a real line-oriented parser.
Outputs of this saga, in rough order of priority:

- Comment stripping (`;` to end of line) so header-commented `.s`
  files can be fed without pre-processing. Restores the comment
  line that was stripped from `tests/smoke/nop.s` in saga 1.
- Line reader with a proper line-buffer size (pins **Q2** from
  `architecture.md` for the input buffer; symbol-table size still
  deferred).
- Simple tokeniser: whitespace-separated mnemonic + operands,
  comma-separated operands.
- Expand recognised mnemonic set from 1 to a small handful
  (`nop`, and enough printable-zero-operand peers like `halt` /
  register-only `push r0` / `pop r0` that the saga is non-trivial).
- Extend `src/sw-as24.s` with a proper `byte_to_hex_pair` helper
  (currently hard-coded to emit "FF" or "00"); grows as soon as
  more than two output byte values exist.
- First shared bit-fiddling primitive that `sw-hexload` (future,
  see `docs/utility.md`) can also consume: nibble_to_ascii and
  ascii_to_nibble.
- Pick up **Q3** (pass-1 caching strategy) from
  `architecture.md` when the tokeniser begins to retain state.

**Anticipated non-goals:** symbol tables, forward references, the
full register parser, addressing-mode parsing, two-pass scanning,
directives. Those land in sagas 4-7.

### 4. Register + addressing mode parser

Parse the legal register names (`r0`, `r1`, `r2`, `fp`, `sp`,
`z`, `iv`, `ir`, and the `c` condition flag where applicable),
and the `offset(base)` addressing form. Exercises the first real
operand decoding logic. The selector integers 0..7 used by the
decode ROM are an implementation detail; never accept `r3..r7`
as input tokens.

### 5. Instruction encoding -- no-operand and register-only

Encode every mnemonic that has only register (or no) operands.
Includes the ALU group (`add`, `sub`, `mul`, `and`, `or`, `xor`,
`shl`, `sra`, `srl`), the comparison group (`ceq`, `cls`, `clu`),
the extension group (`sxt`, `zxt`), and `mov` / `push` / `pop`.
`nop` (byte `0xFF`) lands here too.

### 6. Instruction encoding -- immediates and loads

Encode mnemonics that carry immediate operands or offset-base
addressing: `lc`, `lcu`, `la`, `lb`, `lbu`, `lw`, `sb`, `sw`.

### 7. Symbol table and two-pass assembly

Implement pass 1 (label collection + address assignment) and pass 2
(emission with known-symbol resolution). Forward references still
unsupported; they error rather than silently mis-encode.

### 8. Forward references

Record and patch forward references for branches (`rel8`) and `la`
(`abs24`). Report unresolved symbols and out-of-range branches.

### 9. Branch / jump encoding

Encode `bra`, `brt`, `brf`, `jmp`, `jal` (depending on operand form
and whether the symbol table already resolves the target from
saga 7 / 8 -- exact split pinned when this saga becomes current).
Includes the branch-too-far rewrite (`docs/as24-language.md` §5.4)
that as24.c's `fixbra()` implements.

### 10. Directives

Implement `.byte`, `.word`, `.comm`; silently accept the
no-op directives (`.text`, `.data`, `.bss`, `.globl`). Handle the
location-counter bump `. = . + N`.

### 11. Error reporting polish

Line numbers on every error, aggregation, non-zero exit on failure,
exhaustive error-category taxonomy. Match as24.c's `? Line N:`
error format (`docs/as24-language.md` §6). Tests with deliberately
malformed inputs.

### 12. Hosting-model decision

Resolve **Q1** from `architecture.md` and the open questions in
`docs/self-host-toolchain.md`. Choose standalone UART or
monitor-hosted and wire the chosen I/O path into `sw-as24.s`.

### 13. Full ecosystem regression

Wire up the REST oracle per `docs/oracle-protocol.md`. Collect
`.s` inputs from `sw-cor24-forth`, `sw-cor24-macrolisp`,
`sw-cor24-pascal`, `sw-cor24-pcode`, `sw-cor24-script`,
`sw-cor24-yocto-ed`, and the emulator examples. Assemble each
with both `sw-as24` and the oracle (as24.c via REST); require
byte-identical output. Fix divergences.

### 14. Self-hosting close (G5)

`sw-as24` assembles its own source (`src/sw-as24.s`) and the
resulting binary is byte-identical to the oracle's output for the
same source. Triggers the PRD's S3 success criterion.

### 15. Release

Tag a 0.1.0, write `CHANGES.md`, update
`sw-cor24-project/docs/status.md` to mark the native assembler
complete, and publish to GitHub. The vendor pin in `active.env`
moves from cor24-rs to a real `sw-cor24-x-assembler` release
artifact once one exists (assuming x-assembler has landed a
`[[bin]]` target by then).

## Change log

- 2026-04-18: Initial draft landed as part of the Relaunch saga.
- 2026-04-18: Relaunch saga (saga 1) closed. `just test` green
  end-to-end from cold vendor state. sw-as24 recognises `nop` and
  emits hex-ASCII "SFF" on UART, decoded to the byte-identical
  `0xFF` machine code that `cor24-run --assemble` produces. Saga 2
  (Lexer and line parsing) promoted to current. Feature branch
  `feat/relaunch-project` renamed to `pr/relaunch` for the release
  engineer to merge into `dev`.
- 2026-04-18: Specs-foundation saga inserted as the new saga 2.
  The lexer saga previously labelled saga 2 is now saga 3; every
  downstream saga shifts by +1 (final count = 15). Motivation:
  the ISA / language / format / runtime specs serve multiple
  downstream sagas and warrant their own close rather than being
  bundled into lexer work.
