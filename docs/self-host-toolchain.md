# Self-Host Toolchain

What sw-as24 needs around it to be useful on the target FPGA
once it runs there. This is a sketch — every section names an
open question rather than a decision.

## 1. Goal

A COR24-resident workflow that lets a user: edit a `.s` file,
assemble it, load it into memory, run it, observe UART output,
and iterate. No Rust, no gcc, no REST service on the target.

Concretely that means five pieces:

1. **Editor** — view and edit `.s` source on-device.
2. **Assembler** — sw-as24 itself. ← this repo.
3. **Linker** — optional; only needed if sw-as24 emits
   unresolved object files. If sw-as24 emits `.lgo` directly
   (with all labels resolved), no linker is needed.
4. **Loader** — consume the assembler's output (likely `.lgo`)
   and write bytes into memory at the target addresses.
5. **Runner / monitor** — transfer control to a loaded
   program's entry point; return control to the monitor on
   `halt` / `bra .`.

sw-as24 is piece (2). The others live somewhere else —
probably a sibling repo (`sw-cor24-monitor`? the name doesn't
exist yet) or folded into this repo as companion tools in
`src/`.

## 1.5 Precedent: sws + swye + cor24-run

The sw-embed ecosystem already runs multiple on-device binaries
together via `cor24-run`. The key worked example is
[`sw-cor24-script`](https://github.com/sw-embed/sw-cor24-script)
(sws — a Tcl-like interpreter written in C) launching
[`sw-cor24-yocto-ed`](https://github.com/sw-embed/sw-cor24-yocto-ed)
(swye — a modal text editor, also C). See
`sw-cor24-script/docs/examples/editor-demo.sh` for the complete
mechanism.

What that demo establishes as the ecosystem convention:

- **Binary-per-tool model.** Each tool is a standalone `.bin`
  assembled at a known base address. sws at `0x000000`, swye at
  `0x080000`, data and command buffers at their own bases.
- **Co-loading via cor24-run.** `--load-binary <file>@<addr>`
  places each binary; `--patch <addr>=<val>` installs
  function-pointer hand-offs between them.
- **`_main` entry convention.** tc24r emits `_main:` at the
  entry point of every program. The loader greps the `.lst` to
  find `_main`'s address and patches it into the caller's
  function-pointer slot. The `.bin` itself is raw bytes — the
  `.lst` carries the symbolic information needed to wire
  programs together.
- **Cross-program calls.** Caller loads `_main`'s address from
  the patched slot and invokes via `jal r1, (rX)`. Returns
  follow the standard COR24 calling convention (§7 of
  `docs/isa.md`).

Implications for the self-hosted sw-as24:

- sw-as24 should emit a `.lst` that contains enough symbol info
  for a loader to find its entry point. as24.c's `.lst` already
  does this (labels render as `name:` on their own line).
- sw-as24 must support assembly at a non-zero base address (the
  as24.c model assumes `0x000000`; `sw-cor24-x-assembler`
  already supports `assemble_at(src, base)`; sw-as24 must
  match).
- If sw-as24 emits `.lgo`, the loader format is already well
  matched: each `L` record carries an absolute address.

## 2. Contract sw-as24 depends on

Whatever the monitor/loader looks like, sw-as24 assumes:

- **Source input:** UART RX stream, plain ASCII, newline
  terminated. Line length ≤ 132 chars (as24.c `LINSIZ`). Some
  control character or sequence signals end-of-input (exact
  convention TBD — `Ctrl-D`? A line containing `.end`? Just
  `EOF` from the host side of the serial link?).
- **Output:** UART TX stream. Default emission is `.lgo`
  (one `L` / `G` record per line). Error lines start with `?`
  and include the source line number. `.lst` output is
  optional; if requested via a flag it interleaves with
  `.lgo` (need a separator convention) or goes to a separate
  stream (only possible if TX is multiplexed).
- **Working RAM:** enough of SRAM (somewhere above sw-as24's
  own footprint) to hold the form list + symbol table for the
  largest `.s` file we commit to assembling. See
  `docs/fpga-runtime.md` §5 open question 6.
- **Re-entry point:** after finishing, sw-as24 returns to some
  fixed address in the monitor. Convention TBD.

## 3. Bootstrap path

Until any of (1)/(3)/(4)/(5) exist:

- Edit `.s` files on the host with whatever editor. Check in.
- Assemble with the bootstrap cross-assembler
  (`sw-cor24-x-assembler`, formerly `cor24-run --assemble`).
- Load into the emulator with `cor24-run --run`, or onto the
  physical FPGA via whatever the existing flow is (undocumented
  in this repo — track in `docs/oracle-protocol.md`).

Once sw-as24 can assemble its own source byte-for-byte on the
host, the cross-assembler is retired. At that point (and not
before) it becomes meaningful to plan (1)/(3)/(4)/(5).

## 4. Open Questions

1. **Where do the other pieces live?** New sibling repos
   (`sw-cor24-editor`, `sw-cor24-monitor`, `sw-cor24-loader`)?
   Or companion sources in this repo? Precedent in the sw-embed
   ecosystem favours "one project per tool."
2. **Common format between pieces.** If the editor saves to
   the same flash/SRAM region the assembler reads, is there a
   shared file-system abstraction? Or does each tool consume
   a raw UART stream?
3. **Load format.** `.lgo` is the natural intermediate
   (as24.c default, printable ASCII, survives UART). Confirm
   the monitor/loader will accept it without modification. See
   `docs/utility.md` for the `sw-hexload` sketch.
4. **Linker scope.** as24.c supports `.obj` output via `-c`
   and a separate `ld24` tool (also in
   `cor24-rs/docs/research/asld24/`). If multi-file programs
   matter for the self-hosted flow, port `ld24` too. If not,
   document that sw-as24 is strictly single-file and skip
   the linker.
5. **Editor primitives.** Line-oriented (ed-style)? Visual
   (vi-style)? makerlisp has a strong opinion here somewhere;
   ask before designing.
6. **Versioning and handoff.** When a new `.s` is edited and
   re-assembled, does the monitor remember the last-loaded
   image address? Does it know how to hot-swap? This affects
   the monitor's state machine, not sw-as24, but sw-as24's
   output needs to carry enough information for the monitor to
   do the right thing.

## 5. Provenance

- `sw-hexload` sketch: `docs/utility.md` (this repo).
- Hosting options previously considered:
  `docs/architecture.md` §6.
- Reference tools that exercise parts of this flow on the host
  side: `cor24-run` (load + run), makerlisp `as24.c`/`ld24.c`.
