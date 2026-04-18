# Architecture -- `sw-as24`

**Status:** Draft (Relaunch saga)
**Scope:** Long-lived reference. Evolves as sagas resolve the TBDs
flagged below.

## 1. System context

```
           .s text                         machine code
 (UART / monitor file) --->  sw-as24  ---> (UART / monitor file)
                              ^
                              | runs on
                              v
                  +----------------------+
                  | COR24 CPU            |
                  | emulator  | FPGA     |
                  +----------------------+
```

`sw-as24` is a COR24 program. Its source is COR24 `.s` and its binary
runs on the same ISA it assembles. During development, the vendored
`cor24-run` both assembles `sw-as24.s` (acting as the cross-assembler)
and executes the resulting binary (acting as the emulator). Once G5 is
met, `sw-as24` can assemble itself.

## 2. Reference implementation

The canonical behaviour is defined by `sw-cor24-x-assembler`
(`cor24-assembler` Rust crate, `rlib`). Its public entry point is
`Assembler::assemble(&str)`. This project ports that behaviour to `.s`.

Encoding tables (opcodes, register numbers, ISA types) originate in
`sw-cor24-emulator`'s decode ROM; see `../sw-cor24-emulator` for the
authoritative definitions.

## 3. Pipeline

`sw-as24` is a two-pass assembler.

```
 input --> Pass 1: scan       -->  symbol table
                   (labels,
                    addresses)
                                  --> instruction list
                                      (sized, symbols unresolved)

 Pass 2: encode     --> code buffer  --> output
 (+ forward-ref
    patching)
```

### Pass 1 -- address assignment

- Read the input stream line by line.
- Strip comments (`;` to end of line).
- Recognise labels (identifier followed by `:`) and bind them to the
  current address in the symbol table.
- Compute the size of every instruction or directive -- *without*
  emitting code -- and advance the current address accordingly.
- Record enough state to replay the stream in pass 2 (either by
  re-reading the input or by caching a compact internal form; the
  choice is a design decision for a later saga).

### Pass 2 -- code emission

- Walk the stream (or the cached form) again.
- For every instruction, look up the opcode / encoding type in the
  mnemonic table and emit bytes into the code buffer.
- Resolve symbolic references: if the target label is known, patch
  immediately; if not, record a forward reference keyed by buffer
  offset, reference type (`rel8`, `abs24`), and label.
- After the second pass, walk the forward-reference list and patch
  the code buffer.

### Error handling

Errors do not abort; they are accumulated with a line number and
category (unknown mnemonic, invalid register, invalid operand,
unresolved symbol, branch out of range, duplicate label). After
assembly completes, the accumulated error list is written to the
output channel and the program exits non-zero.

## 4. Data model (logical)

Only parallel arrays -- the ISA has no struct literal semantics, and
the design constrains allocation to fixed, statically-sized regions.

| Region             | Purpose                                             |
| ------------------ | --------------------------------------------------- |
| line buffer        | current input line                                  |
| token buffer       | mnemonic, operands for current line                 |
| mnemonic table     | names, encoding types, opcode bytes                 |
| symbol table       | `sym_names[]`, `sym_addrs[]`                        |
| forward refs       | `fwd_offsets[]`, `fwd_labels[]`, `fwd_types[]`      |
| code buffer        | emitted machine code                                |
| error log          | line numbers + error-kind codes                     |

Exact sizes are a design concern (see `design.md`) and are pinned in
the first saga that cares about them.

## 5. ISA coverage

All mnemonics, addressing modes, and directives accepted by the Rust
cross-assembler. A coverage matrix (mnemonic -> saga-introduced-in)
is maintained in `plan.md` as sagas progress.

## 6. Hosting model (TBD)

`sw-as24` must obtain input and emit output somehow. Two options are
under consideration; the relaunch saga is deliberately agnostic.

**(i) Standalone, UART-only.** The program runs bare-metal. Input
bytes arrive on UART RX; output bytes go out on UART TX. A trivial
wrapper on the host (or `cor24-run`'s UART plumbing) feeds the input
and captures the output. This matches how `sw-cor24-forth` operates.

**(ii) Monitor-hosted, service-vector I/O.** The program runs under
`sw-cor24-monitor` and uses service vectors for line-oriented I/O,
giving it something closer to stdin/stdout. This matches where the
ecosystem is heading for interactive tools.

Trade-offs:

- (i) minimises dependencies and works today; awkward for anything
  longer than a short `.s` file.
- (ii) matches the eventual on-device workflow (editor -> assembler ->
  run), but drags in the monitor and its ABI.

The decision is deferred to the saga that first needs more than the
smoke-test's `nop` input. Until then, `sw-as24` reads from whatever
input channel `cor24-run` gives it and writes to whatever output
channel it gives it.

## 7. Dependencies

### Build-time (host)

- `bash` -- build / test scripts, `vendor-fetch.sh`.
- `just` -- recipe runner.
- `jq` -- manifest parsing in `vendor-fetch.sh` (following the
  `sw-cor24-ocaml` precedent).
- Vendored `cor24-run` -- Rust-built binary, assembles `.s` -> machine
  code and executes it. Pinned by commit in `vendor/active.env` +
  `vendor/sw-em24/<version>/version.json`.

### Runtime (on COR24)

- Today: none beyond the emulator's UART and the code itself.
- Eventually (hosting-model dependent): `sw-cor24-monitor` service
  vectors, if option (ii) is chosen.

Explicitly *not* dependencies of this repository: Rust, `cargo`, any
C compiler, `make`, Python, any scripting runtime other than `bash`.

## 8. Repository layout

See `design.md` Section  Directory layout. The relaunch saga lays down this
structure; later sagas only fill it in.

## 9. Compatibility contract

`sw-as24`'s output is contractually byte-identical to
`cor24-run`'s output for every input both tools accept. This is the
one invariant the regression suite defends. Any divergence is a bug
in `sw-as24` (not a feature) until explicitly documented in this
architecture doc.

## 10. Open questions (live)

- **Q1.** Hosting model (Section 6). Owner: architecture saga after relaunch.
- **Q2.** Static size limits (code buffer, symbol table capacity,
  forward-ref capacity). Owner: the two-pass / symbol-table saga.
- **Q3.** Pass 1 caching strategy -- re-read the input vs. serialise a
  compact internal form. Owner: the two-pass saga.
- **Q4.** Self-hosting verification harness (G5). Owner: dedicated
  self-host saga near the end of the plan.
