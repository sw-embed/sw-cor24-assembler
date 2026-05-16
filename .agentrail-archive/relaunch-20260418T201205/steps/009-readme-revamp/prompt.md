Rewrite README.md to match the new scope.

Remove every reference to the prior C implementation (tc24r, as24,
C-subset constraints, "native assembler in C"). Replace with the
self-hosting .s-based framing.

Sections (keep it concise; link to docs/ rather than duplicating):
- Title + one-line description ("self-hosting COR24 assembler written
  in COR24 assembly").
- Status: Relaunch saga in progress; single-mnemonic smoke test is
  the current milestone.
- Quickstart:
    just vendor-fetch       # build and copy cor24-run from the
                            # sibling sw-cor24-emulator repo
    just build              # assemble src/sw-as24.s -> build/sw-as24.bin
    just test               # smoke test (nop.s byte-identical diff)
- Repository layout: a short tree of the top-level directories with
  one-line descriptions.
- Documentation: links to docs/prd.md, docs/architecture.md,
  docs/design.md, docs/plan.md.
- Cross-repo context: point at sw-cor24-emulator (vendored), note
  that sw-cor24-x-assembler is the reference implementation used
  during development.
- License: whatever the existing COPYRIGHT / LICENSE says (do not
  change license terms).

Exit criteria:
- No occurrence of "tc24r", "C-subset", "struct", "malloc", "cas24"
  in README.md.
- Every link resolves to a file that exists in this repo or to a
  sibling repo path.
- `markdown-checker` (if available in PATH) reports no ASCII
  violations.
