Create the smoke-test input and harness that close docs/design.md's
exit criterion.

Files to write:

- tests/smoke/nop.s
  Single `nop` mnemonic with a short header comment. Nothing else --
  no labels, no second instruction. This is the minimum input that
  exercises the toolchain end-to-end.

- scripts/test.sh
  Responsibilities:
  1. Verify vendor/sw-em24/v*/bin/cor24-run exists and build/sw-as24.bin
     exists; if either is missing, print how to produce it
     (`just vendor-fetch` / `just build`) and exit non-zero.
  2. Produce the reference bytes: run cor24-run in assemble-only mode
     on tests/smoke/nop.s, save output to build/ref.bin.
  3. Produce the candidate bytes: run build/sw-as24.bin under
     cor24-run (emulator mode), feed tests/smoke/nop.s as UART
     input, capture UART output, save to build/candidate.bin.
  4. diff -q build/ref.bin build/candidate.bin and exit with the
     diff's return code.

The exact cor24-run invocations (assemble-only flag, UART feed flag,
UART capture flag) are pinned during this step by consulting
`cor24-run --help`.

Exit criteria:
- tests/smoke/nop.s is a single-line .s file recognised by
  cor24-run.
- scripts/test.sh is executable, passes `bash -n`, and once step 8
  is done, `just test` exits 0.
