Implement assembler directives.

1. .org ADDRESS — set current address (with optional fill).
2. .byte VAL1, VAL2, ... — emit raw bytes.
3. .word VAL1, VAL2, ... — emit 24-bit little-endian words.
4. .comm NAME, SIZE — BSS allocation (advance address without emitting).
5. Ignore: .text, .data, .globl, .align (pass through silently).
6. Test each directive against cross-assembler output.

Reference: Rust assembler's directive handling.
