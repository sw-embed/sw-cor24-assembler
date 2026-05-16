# Assemblers Checkpoint

A point-in-time orientation doc for anyone (human or agent)
joining the sw-as24 effort. Names the three COR24 assembler
projects, maps the bootstrap chain, lays out the demo ladder
we are climbing, and lists what currently blocks each rung.

Last updated: 2026-05-16, on landing of the Specs Foundation
saga. Updated checkpoints replace this doc rather than
appending; consult `git log -- docs/assemblers-checkpoint.md`
for history.

## 1. Status (this repo)

- `sw-as24` itself: unchanged since saga 1. Recognises the
  literal `nop` mnemonic, emits hex-ASCII `"SFF"` over UART,
  byte-identical (after host-side `hex2bin.sh`) to
  `cor24-run --assemble nop.s`.
- Specifications landed (saga 2, merged to `dev` cbe8835):
  six docs under `docs/` are now authoritative for sw-as24's
  target behaviour — ISA, language, output formats, FPGA
  runtime, self-host toolchain contract, oracle protocol.
- Roadmap: see [`plan.md`](plan.md). Specs Foundation is
  saga 2; Lexer and line parsing is saga 3 (next to start);
  self-host close is saga 14; release is saga 15.

## 2. The three assembler projects

| dev user | Repo | Role | Source language | Runs on |
|----------|------|------|-----------------|---------|
| **dcxas** | [`sw-cor24-x-assembler`](https://github.com/sw-embed/sw-cor24-x-assembler) | Cross-assembler, bootstrap-only | Rust (rlib + soon-to-arrive CLI) | Host |
| **dcasm** | [`sw-cor24-assembler`](https://github.com/sw-embed/sw-cor24-assembler) (this repo) | Flat assembler — same dialect as makerlisp `as24.c` | COR24 assembly (`.s`, the language documented in [`as24-language.md`](as24-language.md)) | COR24 |
| **dchla** | [`sw-cor24-hlasm`](https://github.com/sw-embed/sw-cor24-hlasm) | HLASM-inspired macro / structured-control-flow assembler — reads `.hlasm`, emits plain `.s` over UART | COR24 assembly (`.s`) | COR24 |

**Naming convention.** `dc*` user accounts hold the native
(COR24-resident) project sources. `dw*` user accounts hold
the **Rust-based web demo** counterparts. For example:

- `dwhla` holds `web-sw-cor24-hlasm` (Rust → WASM, demonstrates
  hlasm in-browser).
- `dwdem` holds `web-sw-cor24-demos` — the umbrella site at
  https://sw-embed.github.io/web-sw-cor24-demos/. This site
  is the source of the ISA tables this repo's
  [`isa.md`](isa.md) was derived from.

`dcxas` is the deliberate exception to the dc-prefix
convention: it hosts Rust code (the cross-assembler library)
because that is what it is. Only `dcxas` uses Rust for the
actual assembler. `dcasm` and `dchla` are written in COR24
assembly and execute on COR24 hardware (emulator today, FPGA
eventually).

## 3. Bootstrap chain

The goal is an acyclic bootstrap that retires the Rust
cross-assembler once both COR24-resident assemblers
self-host. The chain has two parallel arcs that share `dcxas`
as the initial host-side bootstrap.

### 3.1 dcasm arc

```
[host]                                [COR24]

dcxas (Rust)
    │  assemble dcasm.s
    ▼
sw-as24.bin (built by dcxas)  ───run──►  sw-as24
                                            │  assemble dcasm.s
                                            ▼
                                         sw-as24.bin'  ──compare──►  byte-identical?
                                                                       │
                                                                       ▼
                                                                 self-host close ✓
                                                                 (saga 14)
```

After self-host close, `dcxas` is retained only as a
regression oracle alongside the REST-served `as24.c`. It is
no longer a build-time dependency.

### 3.2 dchla arc (parallel)

```
[host]                                [COR24]

dcxas (Rust)
    │  assemble hlasm.s
    ▼
hlasm.bin (built by dcxas)  ───run──►  hlasm
                                          │  read .hlasm source
                                          │  emit plain .s on UART
                                          ▼
                                        .s text  ──►  sw-as24  ──►  user.bin
                                                       (or cor24-run
                                                        during bootstrap)

(For hlasm self-host:)
hlasm reads its own .hlasm source  →  emits .s
                                       │
                                       ▼
                                     sw-as24 assembles  →  hlasm.bin'
                                                            │
                                                            ▼
                                                      hlasm self-host close ✓
```

**Key invariant.** sw-as24 is the flat assembler at the
bottom of the stack. Everything above it (hlasm, future
compilers, scripting languages like sws) ultimately produces
flat `.s` that sw-as24 consumes. **sw-as24 does not depend on
anything above it.** That's what keeps the bootstrap acyclic.

### 3.3 Why sw-as24 is NOT written in hlasm

Tempting question: "since hlasm has nicer macros, why not
write sw-as24 in hlasm?" Answer: because then bootstrap
becomes circular. dcasm would need hlasm to build, hlasm
needs dcasm to build, neither can start cold. Keeping sw-as24
in flat as24 (the dialect makerlisp's `as24.c` accepts, the
dialect hlasm emits) preserves a clean bottom of the stack.

This is a deliberate constraint, not an oversight. Anyone
proposing "let's just use hlasm for this" should be pointed
back here.

## 4. Demo ladder

The work between now and a public-facing demo is divided into
three rungs. Each rung is a visible deliverable that proves
sw-as24 has crossed a meaningful threshold.

### Rung 1 — Real program, byte-identical

**Demo:** sw-as24 assembles `fib.s` (or `sieve.s`, from
`cor24-rs/docs/research/asld24/`) byte-identical to the REST
oracle's output. A recursive program with forward references,
branches, and a real calling convention.

**What it proves:** the assembler handles real code, not just
the saga-1 literal-`nop` match.

**What it needs (saga-by-saga):**
- Saga 3 — Lexer and line parsing.
- Saga 4 — Register + addressing mode parser.
- Saga 5 — Instruction encoding, no-operand and register-only.
- Saga 6 — Instruction encoding, immediates and loads.
- Saga 7 — Symbol table + two-pass assembly.
- Saga 8 — Forward references.
- Saga 9 — Branch / jump encoding (including the
  branch-too-far rewrite from [`as24-language.md`](as24-language.md) §5.4).

### Rung 2 — In-emulator end-to-end

**Demo:** the co-loaded test-harness pattern from
[`oracle-protocol.md`](oracle-protocol.md) §4.3. A test monitor
at `0x000000` co-loads sw-as24, a source buffer, a hex
decoder, and an execution region. The monitor calls sw-as24
to assemble, decodes the `.lgo` output to bytes, jumps into
the loaded program, halts, and the emulator's memory dump is
the assertion target. This mirrors the sws+swye demo at
`sw-cor24-script/docs/examples/editor-demo.sh`.

**What it proves:** the assembler runs on COR24 (not just
host) and produces bytes that the rest of the COR24
toolchain consumes correctly. Same loading model the FPGA
target will use.

**What it needs:**
- Rung 1 (a working assembler).
- Saga 10 — Directives (so non-trivial programs assemble).
- A tiny test monitor (~50 lines of `.s`). Reuses the
  loading model already documented in
  [`fpga-runtime.md`](fpga-runtime.md) §3.5.
- A hex-decoder binary (`sw-hexload` sketch in
  [`utility.md`](utility.md) is the on-FPGA version; the
  test version can be simpler).

### Rung 3 — Self-host close

**Demo:** `just test-self-host` (or equivalent). sw-as24 (the
binary built by `dcxas` from `dcasm.s`) assembles its own
source `dcasm.s` on COR24, and the output is byte-identical
to the oracle's output for the same source.

**What it proves:** dcasm is acyclic and complete. dcxas is
no longer required for builds; it stays as a regression
oracle only.

**What it needs:**
- Rung 1 + Rung 2.
- Saga 11 — Error reporting polish (so self-assembly is
  diagnosable when it fails).
- Saga 12 — Hosting-model decision (Q1 in
  [`architecture.md`](architecture.md)).
- Saga 14 — the close itself.

After Rung 3, hlasm self-host (the analogous close for dchla)
becomes possible: sw-as24 is finally a usable bottom-of-stack
for hlasm to compile against on-device.

## 5. Blockers

Hard, on the critical path: **none**. Saga 3 (Lexer) is fully
unblocked and can start whenever the next session opens.

Soft / out-of-band:

- **REST oracle URL + request shape unknown.** Placeholder in
  [`oracle-protocol.md`](oracle-protocol.md) §2. Blocks saga 13
  (full ecosystem regression), not earlier sagas. The bootstrap
  oracle (as24.c local build or sw-cor24-x-assembler) covers
  the gap until then.
- **`sw-cor24-x-assembler` has no `[[bin]]` target.** It is an
  rlib only. Blocks the vendor repoint from `cor24-rs/cor24-run`
  to x-assembler. Tracked in [`output-formats.md`](output-formats.md) §5
  and [`architecture.md`](architecture.md) §2. Not critical —
  the current cor24-run-based bootstrap works.
- **`dis_rom.v` not directly verified.** The opcode table in
  [`isa.md`](isa.md) §6 is reconciled from three independent
  sources (as24.c instab, x-assembler encode, web-demos
  instruction summary) that agree, but the hardware ROM
  itself was not parsed in saga 2. Soft confidence concern; a
  dump-and-diff is a 30-minute job for whoever wants to close
  it.
- **dchla not yet in the saga-13 corpus.** `hlasm.s` is a
  non-trivial real program and belongs in the regression
  corpus alongside forth, macrolisp, pascal, pcode, script,
  yocto-ed.

## 6. Cross-repo dependencies for sw-as24

Inbound (sw-as24 needs):

- `sw-cor24-x-assembler` (or `cor24-rs`'s `cor24-run`) at
  build time for bootstrap. Vendored. See
  [`architecture.md`](architecture.md) §2.
- The REST oracle (or a local as24.c build) at test time. See
  [`oracle-protocol.md`](oracle-protocol.md).

Outbound (consume sw-as24's output, will benefit from its
self-hosting close):

- `sw-cor24-hlasm` (`dchla`) — its on-COR24 toolchain wants
  sw-as24 to assemble the `.s` that hlasm emits over UART.
- Every other `dc*` ecosystem project that targets COR24
  (`sw-cor24-script`, `sw-cor24-yocto-ed`, `sw-cor24-forth`,
  `sw-cor24-pascal`, `sw-cor24-basic`, `sw-cor24-prolog`,
  `sw-cor24-apl`, `sw-cor24-macrolisp`, `sw-cor24-tinyc`, …)
  will eventually want a native assembler on-board. sw-as24 is
  the answer.

## 7. Provenance

- Three-project model and bootstrap chain: user statement
  (this session, 2026-04-18 / 2026-05-16).
- Multi-binary loading + `_main` entry convention:
  [`sw-cor24-script/docs/examples/editor-demo.sh`](https://github.com/sw-embed/sw-cor24-script),
  [`sw-cor24-yocto-ed`](https://github.com/sw-embed/sw-cor24-yocto-ed).
- ISA, language, format, runtime specs: [`isa.md`](isa.md),
  [`as24-language.md`](as24-language.md),
  [`output-formats.md`](output-formats.md),
  [`fpga-runtime.md`](fpga-runtime.md), and their own
  provenance footers.
