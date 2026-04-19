; src/sw-as24.s -- minimum viable self-hosted COR24 assembler.
;
; Recognises exactly one mnemonic: "nop". Emits the ASCII hex
; representation of one byte on UART TX, then halts via branch-loop.
;   match    -> "FF" (ASCII 'F','F') -- nop encodes as 0xFF
;   mismatch -> "00" (ASCII '0','0') -- error sentinel (0x00 is
;               not a valid COR24 instruction encoding today, so
;               it doubles as a safe distinguisher from any real
;               output byte sw-as24 will learn to emit in later
;               sagas)
;
; Output is hex-encoded rather than raw binary because cor24-run
; filters 0x00 out of its UART TX observation paths (per-byte log,
; summary, raw --terminal stdout). Emitting printable hex chars
; sidesteps the filter and makes the byte stream observable through
; any cor24-run capture mode. scripts/hex2bin.sh is the host-side
; decoder that turns the hex stream back into a raw binary for
; byte-identical comparison.
;
; Scope (Relaunch saga): prove the toolchain round-trip end-to-end.
; Later sagas introduce labels, operands, multiple mnemonics, two-pass
; assembly, directives, forward refs. None of those are here.
;
; UART memory-mapped I/O (matching sw-cor24-forth's convention):
;   data   = 0xFF0100 = -65280 (RX/TX data register)
;   status = 0xFF0101 = -65279 (bit 7 = TX busy, bit 0 = RX ready)
;
; Register usage:
;   r0 = byte scratch / return value
;   r1 = jal link register
;   r2 = UART base (reloaded as needed)
;   fp = unused here (restricted by ISA's load/ALU capability rules)
;   sp = hardware data stack for jal link save/restore

; ============================================================
; Entry point
; ============================================================
_start:
    ; Banner: emit 'S' (0x53 = 83) so a human watching UART sees
    ; that sw-as24 booted before the assembly logic runs.
    lc      r0, 83
    la      r2, putc
    jal     r1, (r2)

    ; Read three bytes into r0 scratch one at a time, comparing each
    ; against 'n','o','p'. On any mismatch, branch to fail. A 0x04
    ; (EOT) or 0x0A (newline) in the first three positions counts as
    ; mismatch too -- the input is malformed for a single-`nop` line.

    ; --- byte 1: expect 'n' (110) ---
    la      r2, getc
    jal     r1, (r2)
    lc      r1, 110             ; 'n'
    ceq     r0, r1
    brf     fail

    ; --- byte 2: expect 'o' (111) ---
    la      r2, getc
    jal     r1, (r2)
    lc      r1, 111             ; 'o'
    ceq     r0, r1
    brf     fail

    ; --- byte 3: expect 'p' (112) ---
    la      r2, getc
    jal     r1, (r2)
    lc      r1, 112             ; 'p'
    ceq     r0, r1
    brf     fail

    ; Match. Emit "FF" (ASCII 'F' 'F' = 70, 70). That is the hex
    ; representation of byte 0xFF, which is the COR24 encoding of
    ; `nop` (verified by cor24-run --assemble). Trailing bytes in
    ; the UART RX buffer are left unread -- cor24-run's -n cap in
    ; scripts/test.sh bounds the emulation, so draining is
    ; unnecessary for a single-mnemonic smoke test.
    lc      r0, 70              ; 'F'
    la      r2, putc
    jal     r1, (r2)
    lc      r0, 70              ; 'F'
    la      r2, putc
    jal     r1, (r2)
    bra     halt

fail:
    ; Mismatch. Emit "00" (ASCII '0' '0' = 48, 48) = hex for 0x00,
    ; which is not a valid COR24 instruction encoding today and so
    ; reliably distinguishes a fail-path run from any real assembly
    ; output sw-as24 will produce in later sagas.
    lc      r0, 48              ; '0'
    la      r2, putc
    jal     r1, (r2)
    lc      r0, 48              ; '0'
    la      r2, putc
    jal     r1, (r2)
    ; fall through to halt

halt:
    bra     halt

; ============================================================
; putc: write byte in r0 to UART TX, polling TX-busy first.
;
;   jal calling convention: r1 holds the return address. Save it on
;   the data stack so the callee is free to use r1 as scratch.
; ============================================================
putc:
    push    r1                  ; save return address
    push    r0                  ; save byte
    la      r1, -65280          ; UART base
.putc_wait:
    lb      r2, 1(r1)           ; status, sign-extended
    cls     r2, z               ; C = (status < 0) = TX busy
    brt     .putc_wait
    pop     r0                  ; restore byte
    sb      r0, 0(r1)           ; transmit
    pop     r1                  ; restore return address
    jmp     (r1)

; ============================================================
; getc: read one byte from UART RX into r0, polling RX-ready first.
;
;   Same jal convention as putc. Returns the received byte in r0.
; ============================================================
getc:
    push    r1                  ; save return address
.getc_wait:
    la      r0, -65280          ; UART base
    lbu     r0, 1(r0)           ; status, zero-extended
    lcu     r1, 1               ; bit-0 mask
    and     r0, r1              ; isolate RX-ready
    ceq     r0, z               ; C = (not ready)
    brt     .getc_wait
    la      r0, -65280          ; reload UART base
    lbu     r0, 0(r0)           ; read byte
    pop     r1                  ; restore return address
    jmp     (r1)
