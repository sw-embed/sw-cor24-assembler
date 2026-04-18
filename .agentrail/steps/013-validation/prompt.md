Byte-for-byte validation against cross-assembler.

1. Collect all .s test files from sw-cor24-x-assembler and language repos.
2. For each file: assemble with both cas24 (native) and as24 (cross).
3. Compare output byte arrays — must be identical.
4. Fix any encoding discrepancies found.
5. Test with: emulator examples, Forth kernel (forth.s), p-code VM (pvm.s),
   MacroLisp output, TinyC output, Pascal runtime output.
6. Create a regression test script that automates this comparison.
7. Document any intentional differences (if any).
