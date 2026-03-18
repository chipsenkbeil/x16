; basic-stub.s
; BASIC stub: 10 SYS 2061
; Include this at the start of your program after .org $0801
;
; This generates the standard BASIC stub that makes a .prg auto-run.
; The stub puts a single BASIC line "10 SYS 2061" which jumps to $080D
; where the machine code begins.
;
; Usage:
;   .segment "BASICSTUB"
;   .include "basic-stub.s"

.segment "BASICSTUB"
    .word @next_line     ; pointer to next BASIC line
    .word 10             ; line number 10
    .byte $9E            ; SYS token
    .byte "2061",0       ; "2061" + null terminator
@next_line:
    .word 0              ; end of BASIC program
