;
; wait_vblank.s — WAI-based vblank wait for cc65
;
; The WAI instruction ($CB) halts the CPU until the next interrupt.
; With VERA VSYNC interrupts enabled (default), this waits for vblank.
;
; cc65's inline assembler doesn't recognize WAI, so we use a separate
; assembly file with the raw opcode byte.
;

.export _wait_vblank

.proc _wait_vblank
    .byte $CB       ; WAI — wait for interrupt
    rts
.endproc
