Implement register name parsing.

1. Parse register names: r0, r1, r2, fp, sp, z, iv, ir.
2. Map to register numbers 0-7.
3. Handle the offset(base) addressing mode: parse "offset(rN)" into
   offset value + base register number.
4. Return error indicator for invalid register names.
5. Test with all valid register names and common invalid inputs.

Reference: Rust assembler's register parsing.
