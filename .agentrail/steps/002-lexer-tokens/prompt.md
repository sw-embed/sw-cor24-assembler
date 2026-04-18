Implement line-by-line lexer and token extraction.

1. Read input line from UART (or memory buffer) into line_buf.
2. Strip comments (everything after ';').
3. Skip blank lines.
4. Detect labels (word ending with ':' at start of line).
5. Tokenize remaining line into: mnemonic, operand1, operand2.
6. Handle comma-separated operands.
7. Parse number literals: decimal, hex (0x prefix, # prefix, h suffix).
8. Parse negative numbers (signed).
9. Test with simple inputs: labels, instructions, comments, blank lines.

Reference: Rust assembler's line parsing in assembler.rs
