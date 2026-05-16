# Compatibility Oracle Protocol

sw-as24's byte-for-byte correctness is verified against a
reference assembler. This doc specifies how.

## 1. Oracle

The current reference is **makerlisp's `as24.c`**, accessed via
a REST service that runs `as24.c` against a submitted `.s` and
returns the `.lst` (and/or `.lgo`). This is the oldest and
most-authoritative COR24 assembler; byte-identity against it is
the one invariant the regression suite defends.

Runner-up references that should agree with as24.c:

- `sw-cor24-x-assembler` (Rust rlib).
- `cor24-run --assemble` (Rust emulator's built-in
  cross-assembler).

If all three agree, byte-identity is unambiguous. If they
disagree, as24.c wins (and the disagreement is a bug somewhere
in the Rust codebases).

## 2. REST Service

**Unresolved.** The user has mentioned a REST service exposing
`as24.c`; the URL, request shape, and authentication model are
not yet recorded in this repo. This section is a placeholder;
fill in once the details are known.

Expected rough shape (educated guess — verify before coding):

```
POST https://<host>/as24?format=<lgo|lst|obj>
Content-Type: text/plain

<raw .s source>
```

Response:

```
200 OK
Content-Type: text/plain

<raw output in the requested format>
```

or on error:

```
400 Bad Request
Content-Type: text/plain

<stderr from as24.c>
```

### What sw-as24 needs from the protocol

- Deterministic output: identical input `.s` → identical
  output bytes, every time.
- A published pin for which as24.c version (git commit) is
  serving. Byte-identity is only defined against a specific
  revision; if the server upgrades silently, the oracle
  shifts under us.
- Reasonable timeout. The test harness needs to assemble 10s
  to 100s of fixtures per run.
- Stable error-message format so failures are diffable (nice
  to have, not required for byte-identity).

### TODO

- [ ] Record the REST service URL.
- [ ] Document the exact request/response shape.
- [ ] Pin the as24.c commit the service is running.
- [ ] Decide whether to mirror the service in CI (for network
      independence) or rely on it being up.
- [ ] Add a `scripts/oracle.sh` helper that wraps curl calls.

## 3. Test Corpus

### 3.1 Current

`tests/smoke/nop.s` — a single one-line source for the smoke
test. Covers almost nothing.

### 3.2 Needed

A corpus that collectively exercises every opcode, every
directive, every addressing mode, and the non-trivial edge
cases. Proposed minimum:

- **Every mnemonic × every legal register combination.**
  Drives the 210+ byte encoding entries in the decode ROM.
  Generate programmatically from `docs/isa.md` §6 if possible.
- **Every directive.** `.text`, `.data`, `.bss`, `.byte`,
  `.word`, `.comm`, `.globl`, `. = . + N`, symbol definition
  `NAME = value`.
- **Forward and backward labels.** Label defined before use;
  label defined after use.
- **Branch-too-far rewriting.** A branch that exceeds ±127
  bytes, forcing `fixbra()` to rewrite. Both unconditional
  (`bra`) and conditional (`brt`/`brf`) variants.
- **Immediate boundary cases.** `imm8 = -128`, `imm8 = 127`,
  `u8 = 0`, `u8 = 255`, `imm24 = 0`, `imm24 = (2^24)-1`,
  `imm24 = -(2^24)`.
- **Expressions / literals.** Decimal, hex (`0ffh` form).
- **Comments.** Full-line `;`, trailing `;`, no-comment.
- **Labels with `L` prefix** (optimizer-sensitive naming).
- **Empty programs.** Source with only directives, only
  comments, completely empty.
- **Existing working programs.** `fib.s`, `sieve.s` from
  `cor24-rs/docs/research/asld24/` — non-trivial end-to-end
  exercises.

### 3.3 Corpus location

Once established, corpus lives at `tests/corpus/`. Each fixture
is a pair: `fixture_name.s` (input) + `fixture_name.lgo`
(expected output — recorded from the oracle at the pinned
as24.c commit). Regression test: assemble every `.s` with
sw-as24 (or the bootstrap cross-assembler during saga 1–12),
diff against the recorded `.lgo`.

## 4. Running the Oracle

### 4.1 Against the REST service

Wrap in `scripts/oracle.sh` (not yet written). Shape:

```
scripts/oracle.sh <input.s> [--format lgo|lst]
  → outputs the reference result on stdout
  → exit 0 on assembler success, non-zero on oracle error
```

Used by the test harness when regenerating recorded expected
outputs.

### 4.2 Locally (if as24.c is on PATH)

`as24.c` from `cor24-rs/docs/research/asld24/as24.c` compiles
with any ANSI C compiler (one `.c` file, no dependencies
beyond the standard library). If a developer has it built
locally:

```
./as24 < input.s > expected.lgo       # default .lgo
./as24 -l < input.s > expected.lst    # listing
./as24 -c < input.s > expected.obj    # object file
```

The service-based oracle and a local build should produce
identical output (`as24.c` has no system dependencies). A
local build is a useful network-independent fallback.

### 4.3 In-emulator co-loaded harness (end-to-end)

The oracle approaches above compare bytes. They do not prove
that the bytes sw-as24 emits also *run correctly*. A stronger
harness, modelled on the sws+swye demo in
`sw-cor24-script/docs/examples/editor-demo.sh`, exercises the
whole pipeline inside a single `cor24-run` invocation — no
network, no host-side linking, no UART roundtrip games:

```
  +-----------------------+   0x000000
  | monitor (test driver) |   calls sw-as24 via function ptr
  +-----------------------+
  | source buffer (.s)    |   0x010000 (loaded via --load-binary)
  +-----------------------+
  | sw-as24 binary        |   0x080000 (assembled with --base-addr)
  +-----------------------+
  | output buffer (.lgo)  |   0x0C0000 (empty; sw-as24 fills it)
  +-----------------------+
  | decoder (hex->bytes)  |   0x0D0000 (another callable binary, or inlined)
  +-----------------------+
  | loaded program area   |   0x0E0000 (decoder writes bytes here)
  +-----------------------+
  | function-pointer slots|   0x0FFE00 (monitor writes _main addrs here)
  +-----------------------+
```

Flow in one emulator run:

1. Monitor starts at reset vector `0x000000`.
2. Monitor calls `sw_as24._main(source=0x010000, output=0x0C0000)`
   via the patched function-pointer slot. sw-as24 reads the
   source, writes `.lgo` records into the output buffer,
   returns.
3. Monitor calls `hex_decode._main(input=0x0C0000,
   output=0x0E0000)` the same way (or inlines it). The decoder
   parses `L` records and writes raw bytes to their target
   addresses inside the loaded-program region.
4. Monitor transfers control to `0x0E0000 + entry_offset`
   (the `G` record's address from the `.lgo`). The user program
   runs.
5. The user program halts (`bra .` or writes a sentinel) and
   the emulator's `--dump` flag captures memory. The test
   assertion is a diff against a recorded end-state.

### 4.3.1 Why this harness

- **Offline.** Depends only on `cor24-run`, sw-as24, a decoder,
  and a tiny monitor. No REST.
- **Realistic.** Uses the exact `--load-binary` + `--patch` +
  function-pointer pattern that the on-FPGA self-hosted flow
  will use (see `docs/fpga-runtime.md` §3.5 and
  `docs/self-host-toolchain.md` §1.5).
- **End-to-end.** Proves both correct encoding *and* correct
  execution. A byte-compare oracle cannot detect a decoder bug
  or a loader misplacement that happens to leave the compare
  buffer identical but the executed bytes elsewhere.
- **Reusable.** Every new corpus entry is a triple — source
  `.s`, expected end state (e.g. register contents, memory
  bytes, UART transcript) — and the same monitor drives them
  all.

### 4.3.2 What's needed

- A minimal test monitor (sw-as24-adjacent? new repo?): ~50
  lines of `.s` that reads three function-pointer slots,
  dispatches through them in sequence, halts.
- A decoder: a small binary or inlined routine that parses
  `.lgo` records and writes bytes. `sw-hexload` in
  `docs/utility.md` is exactly this, sized for on-FPGA use;
  the test version can be simpler.
- Build glue in `scripts/` to:
  - Assemble the monitor, sw-as24, decoder at their three
    base addresses.
  - Extract their `_main` addresses from `.lst` files.
  - Invoke `cor24-run` with the right `--load-binary` and
    `--patch` args.
  - Run with `--dump` and diff against recorded end state.
- A corpus `tests/corpus/` where each fixture is
  `name.s` + `name.end-state` (or similar).

### 4.3.3 When

Out of scope for this (specs-foundation) saga. Natural home:
saga 13 (full ecosystem regression) or earlier if a dedicated
harness saga is inserted. The specs here make the harness
implementable; the harness itself is later work.

## 5. Failure Modes

### 5.1 sw-as24 emits different bytes

Normal regression failure. Diff the bytes byte-by-byte, find
the first divergence, correlate with the source line. Common
causes (based on expected implementation quirks):

- Missing or extra `fixbra()` rewrite.
- Sign-extension error on `imm8` / `d8`.
- Wrong encoding for a register pair (e.g. `mov r0, r2` not
  using the exact ROM entry).
- `.word` emitting bytes in big-endian instead of
  little-endian.

### 5.2 Oracle is unreachable

sw-as24 development is not blocked. Use local as24.c, or a
previously-recorded fixture corpus (the whole point of the
`tests/corpus/` pair is that it works offline).

### 5.3 Oracle version drifted

Detected by the test harness comparing its pinned commit hash
to the service's advertised version. Fail loudly; do not
silently accept the new output as correct.

## 6. Provenance

- as24.c: `cor24-rs/docs/research/asld24/as24.c`.
- REST service: to be documented — user-provided detail
  pending.
- Test corpus: to be built. Existing reference `.s` files:
  `cor24-rs/docs/research/asld24/fib.s`,
  `cor24-rs/docs/research/asld24/sieve.s`,
  `sw-cor24-x-assembler/src/examples/assembler/*.s`,
  `web-sw-cor24-demos/docs/examples/*.s`.
