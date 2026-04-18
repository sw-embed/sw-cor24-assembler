; src/sw-as24.s -- minimum viable self-hosted COR24 assembler.
;
; Recognises exactly one mnemonic: "nop". Emits byte 0x00 on a match,
; byte 0xFF on anything else, then halts via branch-loop.
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

    ; Match. Emit 0x00 and halt. Trailing bytes in the UART RX
    ; buffer (newline, EOT, etc.) are left unread -- cor24-run's
    ; -n instruction cap in scripts/test.sh bounds the emulation,
    ; so draining is unnecessary for a single-mnemonic smoke test.
    lc      r0, 0               ; emit 0x00 = nop encoding
    la      r2, putc
    jal     r1, (r2)
    bra     halt

fail:
    lc      r0, 255             ; emit 0xFF = error sentinel
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
