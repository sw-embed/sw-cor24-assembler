Implement forward reference resolution.

1. During second pass, when a label is not yet resolved, record a
   forward reference: fwd_addr[], fwd_label[], fwd_type[] (absolute24
   or relative8).
2. After second pass completes, resolve all forward references by
   patching the code buffer.
3. For relative8 (branches): calculate signed offset, check range (±127).
4. For absolute24 (la): write 24-bit address into code buffer.
5. Report errors for unresolved symbols and out-of-range branches.
6. Test with programs that have forward branches and forward la references.
7. Verify byte-identical output with cross-assembler.

Reference: Rust assembler's ForwardRef struct and resolution logic.
