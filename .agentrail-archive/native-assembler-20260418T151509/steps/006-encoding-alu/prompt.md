Implement ALU instruction encoding.

1. Encode add, sub, mul (2 bytes, reg-reg).
2. Encode and, or, xor (2 bytes, reg-reg).
3. Encode shl, sra, srl (2 bytes, reg-reg).
4. Encode ceq, cls, clu comparison instructions (2 bytes, reg-reg).
5. Encode sxt, zxt (2 bytes, reg-reg).
6. Test each instruction against cross-assembler output.

Reference: Rust assembler's ALU encoding functions.
