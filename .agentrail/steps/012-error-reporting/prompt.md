Implement error collection and reporting.

1. Collect errors during assembly (don't abort on first error).
2. Track line numbers for error messages.
3. Report: unknown mnemonic, invalid register, invalid operand,
   unresolved symbol, branch out of range, duplicate label.
4. Output errors via UART after assembly completes.
5. Return non-zero exit status on error.
6. Test with intentionally malformed inputs.
