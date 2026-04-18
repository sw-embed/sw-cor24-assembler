Build the mnemonic lookup table mapping instruction names to encoding info.

1. Define parallel arrays: mnem_names[], mnem_types[], mnem_opcodes[].
2. Populate with all 49 COR24 mnemonics from the ISA.
3. Categorize by encoding type: no-operand, reg, reg-reg, reg-imm8,
   reg-imm24, branch-offset, reg-offset-reg, etc.
4. Implement mnemonic lookup: given a string, return index or -1.
5. Test: verify all mnemonics are found, unknown strings return -1.

Reference: Rust assembler's instruction dispatch and cor24-emulator ISA defs.
