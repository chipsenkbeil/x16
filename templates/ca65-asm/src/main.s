; main.s - Commander X16 Hello World (ca65 assembly)
;
; A well-commented starter program demonstrating:
;   - BASIC stub for auto-run
;   - KERNAL calls for character I/O
;   - String printing via CHROUT
;   - Waiting for keypress via GETIN
;
; Build: make
; Run:   make run

.include "x16.inc"

; ---------------------------------------------------------------------------
; BASIC stub at $0801: "10 SYS 2061"
; This allows the program to auto-run when loaded
; ---------------------------------------------------------------------------
.segment "BASICSTUB"
    .word @next_line        ; Pointer to next BASIC line
    .word 10                ; Line number 10
    .byte $9E               ; SYS token
    .byte "2061", 0         ; "2061" + null terminator
@next_line:
    .word 0                 ; End of BASIC program (null pointer)

; ---------------------------------------------------------------------------
; CODE segment - main program starts at $080D
; ---------------------------------------------------------------------------
.segment "CODE"

main:
    ; Print the hello message character by character
    ldx     #0              ; X = string index
@print_loop:
    lda     hello_msg, x    ; Load next character
    beq     @wait_key       ; If zero (end of string), done printing
    jsr     CHROUT          ; Call KERNAL: output character to screen
    inx                     ; Advance to next character
    bne     @print_loop     ; Continue (branch always, string < 256 chars)

@wait_key:
    ; Wait for the user to press a key
    jsr     GETIN           ; Call KERNAL: get character from keyboard buffer
    cmp     #0              ; Was a key pressed?
    beq     @wait_key       ; No key yet, keep polling

    ; Return to BASIC
    rts

; ---------------------------------------------------------------------------
; RODATA segment - read-only data
; ---------------------------------------------------------------------------
.segment "RODATA"

hello_msg:
    .byte   $93             ; PETSCII: clear screen
    .byte   "HELLO FROM {{PROJECT_NAME}}!", $0D
    .byte   $0D
    .byte   "COMMANDER X16 - 65C02 @ 8MHZ", $0D
    .byte   "VERA GRAPHICS & AUDIO", $0D
    .byte   "512KB BANKED RAM", $0D
    .byte   $0D
    .byte   "PRESS ANY KEY TO CONTINUE...", $0D
    .byte   0               ; Null terminator
