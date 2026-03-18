; main.s - Two-Player Pong for Commander X16 (ca65 assembly)
;
; Player 1: A key = up, Z key = down (left paddle)
; Player 2: Cursor Up = up, Cursor Down = down (right paddle)
; First to 9 points wins. Press any key to restart after game over.
;
; Uses 3 hardware sprites (2 paddles + ball), text layer for score,
; and PSG voices 14-15 for sound effects.
;
; Build: make
; Run:   make run

.include "x16.inc"

; ===========================================================================
; PRG load address header ($0801 in little-endian)
; ===========================================================================
.segment "LOADADDR"
    .word $0801

; ===========================================================================
; Game constants
; ===========================================================================
PADDLE_SPEED    = 3
BALL_SPEED_INIT = 2
P1_X            = 16            ; Paddle 1 X pixel position
P2_X            = 296           ; Paddle 2 X pixel position
PADDLE_HEIGHT   = 32
PADDLE_WIDTH    = 8
BALL_SIZE       = 8
TOP_WALL        = 8
BOTTOM_WALL     = 232           ; 240 - BALL_SIZE
PADDLE_MIN_Y    = 8
PADDLE_MAX_Y    = 200           ; 240 - PADDLE_HEIGHT - 8
BALL_START_X    = 156           ; (320 - 8) / 2
BALL_START_Y    = 116           ; (240 - 8) / 2
WIN_SCORE       = 9
PADDLE_HIT_LEFT = 24            ; P1_X + PADDLE_WIDTH
PADDLE_HIT_RIGHT = 296          ; P2_X
POST_SCORE_PAUSE = 60           ; 1 second at 60fps

; VRAM addresses for sprite pixel data
VRAM_PADDLE_GFX = $10000
VRAM_BALL_GFX   = $10080

; Sprite attribute addresses
VRAM_SPR0_ATTR  = $1FC00        ; Paddle 1
VRAM_SPR1_ATTR  = $1FC08        ; Paddle 2
VRAM_SPR2_ATTR  = $1FC10        ; Ball

; PSG voice addresses in VRAM
VRAM_PSG_V14    = $1F9F8        ; Voice 14 (bounce SFX)
VRAM_PSG_V15    = $1F9FC        ; Voice 15 (score SFX)

; SFX durations
BOUNCE_SFX_DUR  = 4
SCORE_SFX_DUR   = 20

; ===========================================================================
; ZEROPAGE segment - game variables in zero page for fast access
; ===========================================================================
.segment "ZEROPAGE"

ball_x_lo:      .res 1          ; Ball X position (16-bit for subpixel)
ball_x_hi:      .res 1
ball_y_lo:      .res 1          ; Ball Y position (16-bit)
ball_y_hi:      .res 1
ball_dx:        .res 1          ; Ball X speed (unsigned)
ball_dy:        .res 1          ; Ball Y speed (unsigned)
ball_dir_x:     .res 1          ; 0 = moving right, 1 = moving left
ball_dir_y:     .res 1          ; 0 = moving down, 1 = moving up
p1_y:           .res 1          ; Player 1 paddle Y position
p2_y:           .res 1          ; Player 2 paddle Y position
p1_score:       .res 1          ; Player 1 score (0-9)
p2_score:       .res 1          ; Player 2 score (0-9)
sfx_bounce_timer: .res 1        ; Bounce sound countdown
sfx_score_timer:  .res 1        ; Score sound countdown
frame_count:    .res 1          ; Frame counter (for randomness)
pause_timer:    .res 1          ; Post-score pause countdown
game_over:      .res 1          ; 0 = playing, nonzero = game over
joy_data:       .res 1          ; Joystick byte 0 from JOYSTICK_GET
temp1:          .res 1          ; Temp variable
temp2:          .res 1          ; Temp variable

; ===========================================================================
; BASIC stub at $0801: "10 SYS 2061"
; ===========================================================================
.segment "BASICSTUB"
    .word @next_line
    .word 10
    .byte $9E
    .byte "2061", 0
@next_line:
    .word 0

; ===========================================================================
; CODE segment - main program
; ===========================================================================
.segment "CODE"

; ---------------------------------------------------------------------------
; main - Entry point. Initialize everything and run game loop.
; ---------------------------------------------------------------------------
main:
    ; Set screen mode 2 (40x30 text, 320x240)
    lda     #2
    clc
    jsr     SCREEN_MODE

    ; Set 320x240 resolution (HSCALE/VSCALE = $40 for 2x)
    lda     #$40
    sta     VERA_DC_HSCALE
    sta     VERA_DC_VSCALE

    ; Set border color to black
    stz     VERA_DC_BORDER

    ; Clear screen
    lda     #PETSCII_CLR
    jsr     CHROUT

    ; Upload paddle sprite data to VRAM
    jsr     upload_sprite_data

    ; Configure sprite attributes
    jsr     setup_sprite_attrs

    ; Enable sprites in display composer
    ; Ensure DCSEL=0 so $9F29 maps to DC_VIDEO
    lda     VERA_CTRL
    and     #$F9            ; Clear DCSEL bits [2:1]
    sta     VERA_CTRL
    lda     VERA_DC_VIDEO
    ora     #$40            ; Set sprite enable bit (bit 6)
    sta     VERA_DC_VIDEO

    ; Initialize game state
    jsr     init_game_state

    ; Draw initial scores
    jsr     draw_scores

    ; Draw center line
    jsr     draw_center_line

; ---------------------------------------------------------------------------
; game_loop - Main game loop: VSYNC -> input -> update -> render
; ---------------------------------------------------------------------------
game_loop:
    ; Wait for VSYNC
    jsr     wait_vsync

    ; Increment frame counter
    inc     frame_count

    ; Check if game is over
    lda     game_over
    bne     @handle_game_over

    ; Check if we are in post-score pause
    lda     pause_timer
    beq     @no_pause
    dec     pause_timer
    jsr     update_sfx
    jsr     update_sprites
    jmp     game_loop

@no_pause:
    ; Read input
    jsr     read_input

    ; Move paddles based on input
    jsr     move_paddles

    ; Move ball
    jsr     move_ball

    ; Check collisions
    jsr     check_collisions

    ; Update sprite positions in VERA
    jsr     update_sprites

    ; Update sound effects
    jsr     update_sfx

    jmp     game_loop

@handle_game_over:
    jsr     show_game_over
    jmp     main            ; Restart the whole game

; ---------------------------------------------------------------------------
; wait_vsync - Wait for vertical blank interrupt flag
; ---------------------------------------------------------------------------
wait_vsync:
    wai
    rts

; ---------------------------------------------------------------------------
; init_game_state - Reset all game variables to starting values
; ---------------------------------------------------------------------------
init_game_state:
    ; Scores
    stz     p1_score
    stz     p2_score

    ; Paddle positions (centered vertically)
    lda     #104            ; (240 - 32) / 2 = 104
    sta     p1_y
    sta     p2_y

    ; Ball state
    jsr     reset_ball

    ; Timers and flags
    stz     sfx_bounce_timer
    stz     sfx_score_timer
    stz     frame_count
    stz     pause_timer
    stz     game_over

    rts

; ---------------------------------------------------------------------------
; reset_ball - Center ball and set direction based on frame_count
; ---------------------------------------------------------------------------
reset_ball:
    ; Center ball position
    lda     #<BALL_START_X
    sta     ball_x_lo
    lda     #>BALL_START_X
    sta     ball_x_hi

    lda     #<BALL_START_Y
    sta     ball_y_lo
    lda     #>BALL_START_Y
    sta     ball_y_hi

    ; Set ball speed
    lda     #BALL_SPEED_INIT
    sta     ball_dx
    sta     ball_dy

    ; Randomize direction based on frame_count
    lda     frame_count
    and     #$01
    sta     ball_dir_x      ; 0=right, 1=left

    lda     frame_count
    lsr                     ; Shift bit 1 into bit 0
    and     #$01
    sta     ball_dir_y      ; 0=down, 1=up

    rts

; ---------------------------------------------------------------------------
; read_input - Read keyboard joystick (joystick 0)
; ---------------------------------------------------------------------------
read_input:
    lda     #0              ; Joystick 0 = keyboard
    jsr     JOYSTICK_GET
    ; A = byte 0: bits are active-low (0 = pressed)
    ; bit 7=B(Z), bit 6=Y(A), bit 5=Select(S), bit 4=Start(Enter)
    ; bit 3=Up, bit 2=Down, bit 1=Left, bit 0=Right
    sta     joy_data
    rts

; ---------------------------------------------------------------------------
; move_paddles - Move paddles based on input, clamped to play area
; ---------------------------------------------------------------------------
move_paddles:
    ; --- Player 1: bit 6 (Y/A-key) = up, bit 7 (B/Z-key) = down ---

    ; Check P1 up (bit 6, active low)
    lda     joy_data
    and     #$40            ; Test bit 6
    bne     @p1_not_up      ; Bit set = not pressed
    ; Move P1 up
    lda     p1_y
    sec
    sbc     #PADDLE_SPEED
    cmp     #PADDLE_MIN_Y
    bcs     @p1_store_y     ; If >= MIN, store it
    lda     #PADDLE_MIN_Y   ; Clamp to minimum
@p1_store_y:
    sta     p1_y
    jmp     @p1_done
@p1_not_up:

    ; Check P1 down (bit 7, active low)
    lda     joy_data
    and     #$80            ; Test bit 7
    bne     @p1_done        ; Bit set = not pressed
    ; Move P1 down
    lda     p1_y
    clc
    adc     #PADDLE_SPEED
    cmp     #PADDLE_MAX_Y+1
    bcc     @p1_store_y2    ; If < MAX+1, store it
    lda     #PADDLE_MAX_Y   ; Clamp to maximum
@p1_store_y2:
    sta     p1_y
@p1_done:

    ; --- Player 2: bit 3 (Up arrow) = up, bit 2 (Down arrow) = down ---

    ; Check P2 up (bit 3, active low)
    lda     joy_data
    and     #$08            ; Test bit 3
    bne     @p2_not_up
    ; Move P2 up
    lda     p2_y
    sec
    sbc     #PADDLE_SPEED
    cmp     #PADDLE_MIN_Y
    bcs     @p2_store_y
    lda     #PADDLE_MIN_Y
@p2_store_y:
    sta     p2_y
    jmp     @p2_done
@p2_not_up:

    ; Check P2 down (bit 2, active low)
    lda     joy_data
    and     #$04            ; Test bit 2
    bne     @p2_done
    ; Move P2 down
    lda     p2_y
    clc
    adc     #PADDLE_SPEED
    cmp     #PADDLE_MAX_Y+1
    bcc     @p2_store_y2
    lda     #PADDLE_MAX_Y
@p2_store_y2:
    sta     p2_y
@p2_done:
    rts

; ---------------------------------------------------------------------------
; move_ball - Move ball according to velocity and direction
; ---------------------------------------------------------------------------
move_ball:
    ; --- Move X ---
    lda     ball_dir_x
    bne     @move_x_left

    ; Moving right: add dx to x
    lda     ball_x_lo
    clc
    adc     ball_dx
    sta     ball_x_lo
    lda     ball_x_hi
    adc     #0
    sta     ball_x_hi
    jmp     @move_y

@move_x_left:
    ; Moving left: subtract dx from x
    lda     ball_x_lo
    sec
    sbc     ball_dx
    sta     ball_x_lo
    lda     ball_x_hi
    sbc     #0
    sta     ball_x_hi

    ; Check for underflow (went negative / wrapped around)
    bcs     @move_y         ; If carry clear after SBC, we underflowed
    ; Ball went past left edge - will be caught by collision check
    stz     ball_x_lo
    stz     ball_x_hi

@move_y:
    ; --- Move Y ---
    lda     ball_dir_y
    bne     @move_y_up

    ; Moving down: add dy to y
    lda     ball_y_lo
    clc
    adc     ball_dy
    sta     ball_y_lo
    lda     ball_y_hi
    adc     #0
    sta     ball_y_hi
    rts

@move_y_up:
    ; Moving up: subtract dy from y
    lda     ball_y_lo
    sec
    sbc     ball_dy
    sta     ball_y_lo
    lda     ball_y_hi
    sbc     #0
    sta     ball_y_hi

    ; Check for underflow
    bcs     @move_y_done
    stz     ball_y_lo
    stz     ball_y_hi
@move_y_done:
    rts

; ---------------------------------------------------------------------------
; check_collisions - Check ball vs walls, paddles, and scoring
; ---------------------------------------------------------------------------
check_collisions:
    ; --- Top/bottom wall bounce ---
    ; Check top wall
    lda     ball_y_hi
    bne     @check_bottom   ; If high byte > 0, definitely below top
    lda     ball_y_lo
    cmp     #TOP_WALL
    bcs     @check_bottom
    ; Hit top wall - bounce down
    lda     #TOP_WALL
    sta     ball_y_lo
    stz     ball_y_hi
    stz     ball_dir_y      ; 0 = moving down
    jsr     play_bounce_sfx
    jmp     @check_paddles

@check_bottom:
    ; Check bottom wall (ball_y >= BOTTOM_WALL)
    lda     ball_y_hi
    bne     @hit_bottom     ; High byte > 0 means >= 256, way past bottom
    lda     ball_y_lo
    cmp     #BOTTOM_WALL
    bcc     @check_paddles
@hit_bottom:
    lda     #BOTTOM_WALL
    sta     ball_y_lo
    stz     ball_y_hi
    lda     #1
    sta     ball_dir_y      ; 1 = moving up
    jsr     play_bounce_sfx

@check_paddles:
    ; --- Left paddle (P1) collision ---
    ; Ball must be moving left and in the paddle X zone
    lda     ball_dir_x
    beq     @check_right_paddle ; If moving right, skip left paddle check

    ; Check if ball X <= PADDLE_HIT_LEFT
    lda     ball_x_hi
    bne     @check_score_left   ; If high byte > 0, X > 255, not near left paddle
    lda     ball_x_lo
    cmp     #PADDLE_HIT_LEFT
    bcs     @check_score_left   ; Ball X >= hit zone, not there yet

    ; Check if ball X < P1_X (past the paddle, it's a score)
    lda     ball_x_lo
    cmp     #P1_X
    bcc     @score_p2           ; Ball is behind the paddle

    ; Ball is in paddle X zone - check Y overlap
    ; Ball bottom (ball_y + BALL_SIZE) must be > paddle top (p1_y)
    ; Ball top (ball_y) must be < paddle bottom (p1_y + PADDLE_HEIGHT)
    lda     ball_y_lo
    clc
    adc     #BALL_SIZE
    sta     temp1               ; temp1 = ball bottom
    lda     p1_y
    clc
    adc     #PADDLE_HEIGHT
    sta     temp2               ; temp2 = paddle bottom

    ; ball_y < paddle_bottom?
    lda     ball_y_lo
    cmp     temp2
    bcs     @check_score_left   ; Ball top >= paddle bottom, no hit

    ; ball_bottom > paddle_top?
    lda     temp1
    cmp     p1_y
    bcc     @check_score_left   ; Ball bottom < paddle top, no hit
    beq     @check_score_left   ; Ball bottom == paddle top, no hit

    ; Hit left paddle! Bounce right
    stz     ball_dir_x          ; 0 = moving right
    lda     #PADDLE_HIT_LEFT
    sta     ball_x_lo
    stz     ball_x_hi

    ; Adjust ball Y speed based on where it hit the paddle
    jsr     adjust_ball_angle_p1
    jsr     play_bounce_sfx
    jmp     @done

@check_score_left:
    ; Check if ball went past left edge (score for P2)
    lda     ball_x_hi
    bne     @check_right_paddle
    lda     ball_x_lo
    cmp     #P1_X
    bcs     @check_right_paddle
@score_p2:
    ; Player 2 scores
    lda     #2
    jsr     score_point
    jmp     @done

@check_right_paddle:
    ; --- Right paddle (P2) collision ---
    lda     ball_dir_x
    bne     @done               ; If moving left, skip right paddle check

    ; Check if ball right edge (ball_x + BALL_SIZE) >= PADDLE_HIT_RIGHT
    lda     ball_x_lo
    clc
    adc     #BALL_SIZE
    sta     temp1               ; temp1 = ball right edge low
    lda     ball_x_hi
    adc     #0
    sta     temp2               ; temp2 = ball right edge high

    ; Compare ball_right with PADDLE_HIT_RIGHT (296 = $128)
    ; Actually P2_X = 296 and PADDLE_HIT_RIGHT = 296
    ; Check: ball_right >= 296?
    lda     temp2
    cmp     #>PADDLE_HIT_RIGHT
    bcc     @done               ; High byte < 1, not there yet
    bne     @past_right_paddle  ; High byte > 1, past it
    ; High byte == 1, check low byte
    lda     temp1
    cmp     #<PADDLE_HIT_RIGHT
    bcc     @done               ; Low byte < $28, not there yet

@past_right_paddle:
    ; Check if ball right edge > P2_X + PADDLE_WIDTH (304 = $130)
    lda     temp2
    cmp     #>(P2_X + PADDLE_WIDTH)
    bcc     @check_p2_y
    bne     @score_p1
    lda     temp1
    cmp     #<(P2_X + PADDLE_WIDTH)
    bcs     @score_p1

@check_p2_y:
    ; Ball is in paddle X zone - check Y overlap
    lda     ball_y_lo
    clc
    adc     #BALL_SIZE
    sta     temp1               ; ball bottom

    lda     p2_y
    clc
    adc     #PADDLE_HEIGHT
    sta     temp2               ; paddle bottom

    lda     ball_y_lo
    cmp     temp2
    bcs     @score_p1           ; Ball top >= paddle bottom

    lda     temp1
    cmp     p2_y
    bcc     @score_p1           ; Ball bottom < paddle top
    beq     @score_p1           ; Ball bottom == paddle top

    ; Hit right paddle! Bounce left
    lda     #1
    sta     ball_dir_x          ; 1 = moving left

    ; Set ball X so its right edge is at PADDLE_HIT_RIGHT
    lda     #<(PADDLE_HIT_RIGHT - BALL_SIZE)
    sta     ball_x_lo
    lda     #>(PADDLE_HIT_RIGHT - BALL_SIZE)
    sta     ball_x_hi

    jsr     adjust_ball_angle_p2
    jsr     play_bounce_sfx
    jmp     @done

@score_p1:
    ; Player 1 scores
    lda     #1
    jsr     score_point

@done:
    rts

; ---------------------------------------------------------------------------
; adjust_ball_angle_p1 - Vary ball Y speed based on hit position on P1
; ---------------------------------------------------------------------------
adjust_ball_angle_p1:
    ; Calculate hit offset: ball_y - p1_y
    ; If ball hits near top or bottom of paddle, dy = 3
    ; If near center, dy = 1
    lda     ball_y_lo
    clc
    adc     #(BALL_SIZE / 2)    ; Ball center
    sec
    sbc     p1_y                ; offset from paddle top
    ; A = offset (0..~36)
    ; Paddle center = PADDLE_HEIGHT/2 = 16
    ; Distance from center determines angle
    sec
    sbc     #(PADDLE_HEIGHT / 2)
    ; A = signed distance from paddle center
    bpl     @p1_pos
    eor     #$FF
    clc
    adc     #1                  ; A = abs(distance)
@p1_pos:
    ; A = absolute distance from center (0..~16)
    cmp     #10
    bcs     @p1_fast
    cmp     #5
    bcs     @p1_med
    ; Close to center - slow Y, fast X
    lda     #1
    sta     ball_dy
    lda     #3
    sta     ball_dx
    rts
@p1_med:
    lda     #2
    sta     ball_dy
    lda     #2
    sta     ball_dx
    rts
@p1_fast:
    lda     #3
    sta     ball_dy
    lda     #2
    sta     ball_dx
    rts

; ---------------------------------------------------------------------------
; adjust_ball_angle_p2 - Vary ball Y speed based on hit position on P2
; ---------------------------------------------------------------------------
adjust_ball_angle_p2:
    lda     ball_y_lo
    clc
    adc     #(BALL_SIZE / 2)
    sec
    sbc     p2_y
    sec
    sbc     #(PADDLE_HEIGHT / 2)
    bpl     @p2_pos
    eor     #$FF
    clc
    adc     #1
@p2_pos:
    cmp     #10
    bcs     @p2_fast
    cmp     #5
    bcs     @p2_med
    lda     #1
    sta     ball_dy
    lda     #3
    sta     ball_dx
    rts
@p2_med:
    lda     #2
    sta     ball_dy
    lda     #2
    sta     ball_dx
    rts
@p2_fast:
    lda     #3
    sta     ball_dy
    lda     #2
    sta     ball_dx
    rts

; ---------------------------------------------------------------------------
; score_point - A player scored. A = 1 for P1, 2 for P2.
; ---------------------------------------------------------------------------
score_point:
    cmp     #1
    bne     @p2_scored

    ; Player 1 scored
    inc     p1_score
    lda     p1_score
    cmp     #WIN_SCORE
    bcs     @p1_wins
    jmp     @do_reset

@p2_scored:
    inc     p2_score
    lda     p2_score
    cmp     #WIN_SCORE
    bcs     @p2_wins
    jmp     @do_reset

@p1_wins:
    lda     #1
    sta     game_over
    jsr     draw_scores
    jsr     play_score_sfx
    rts

@p2_wins:
    lda     #2
    sta     game_over
    jsr     draw_scores
    jsr     play_score_sfx
    rts

@do_reset:
    jsr     draw_scores
    jsr     play_score_sfx
    jsr     reset_ball

    ; Set pause timer
    lda     #POST_SCORE_PAUSE
    sta     pause_timer
    rts

; ---------------------------------------------------------------------------
; draw_scores - Display score at top of screen using PLOT + CHROUT
; ---------------------------------------------------------------------------
draw_scores:
    ; Position cursor at row 0, col 12 (centered in 40-col mode)
    ; PLOT: carry clear = set, X = row, Y = column
    clc
    ldx     #0
    ldy     #12
    jsr     PLOT

    ; Print "P1:"
    lda     #'P'
    jsr     CHROUT
    lda     #'1'
    jsr     CHROUT
    lda     #':'
    jsr     CHROUT

    ; Print P1 score digit
    lda     p1_score
    clc
    adc     #'0'
    jsr     CHROUT

    ; Print separator
    lda     #' '
    jsr     CHROUT
    lda     #' '
    jsr     CHROUT
    lda     #' '
    jsr     CHROUT
    lda     #' '
    jsr     CHROUT

    ; Print "P2:"
    lda     #'P'
    jsr     CHROUT
    lda     #'2'
    jsr     CHROUT
    lda     #':'
    jsr     CHROUT

    ; Print P2 score digit
    lda     p2_score
    clc
    adc     #'0'
    jsr     CHROUT

    rts

; ---------------------------------------------------------------------------
; draw_center_line - Draw a dashed center line using text characters
; ---------------------------------------------------------------------------
draw_center_line:
    lda     #1
    sta     temp1           ; temp1 = current row
@line_loop:
    ; Position cursor: X = row, Y = column
    clc
    ldx     temp1
    ldy     #20
    jsr     PLOT

    ; Draw a vertical bar character every other row
    lda     temp1
    and     #$01
    bne     @skip_char
    lda     #$7E            ; PETSCII pipe/vertical bar
    jsr     CHROUT
    jmp     @next_row
@skip_char:
    lda     #' '
    jsr     CHROUT
@next_row:
    inc     temp1
    lda     temp1
    cmp     #30             ; 30 rows in mode 2
    bcc     @line_loop
    rts

; ---------------------------------------------------------------------------
; update_sprites - Write all sprite positions to VERA sprite attributes
; ---------------------------------------------------------------------------
update_sprites:
    ; --- Sprite 0: Paddle 1 ---
    ; Set VERA address to sprite 0 X position (byte 2 of attr)
    ; VRAM_SPR0_ATTR + 2 = $1FC02
    stz     VERA_CTRL       ; Select address 0
    lda     #<(VRAM_SPR0_ATTR + 2)
    sta     VERA_ADDR_L
    lda     #>(VRAM_SPR0_ATTR + 2)
    sta     VERA_ADDR_M
    lda     #((^(VRAM_SPR0_ATTR + 2)) | VERA_STRIDE_1)
    sta     VERA_ADDR_H     ; Bank bit + stride 1

    ; X position (P1_X = 16, fits in low byte)
    lda     #P1_X
    sta     VERA_DATA0      ; X low
    lda     #0
    sta     VERA_DATA0      ; X high

    ; Y position
    lda     p1_y
    sta     VERA_DATA0      ; Y low
    lda     #0
    sta     VERA_DATA0      ; Y high

    ; --- Sprite 1: Paddle 2 ---
    ; VRAM_SPR1_ATTR + 2 = $1FC0A
    lda     #<(VRAM_SPR1_ATTR + 2)
    sta     VERA_ADDR_L
    lda     #>(VRAM_SPR1_ATTR + 2)
    sta     VERA_ADDR_M
    lda     #((^(VRAM_SPR1_ATTR + 2)) | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    ; X position (P2_X = 296 = $0128)
    lda     #<P2_X
    sta     VERA_DATA0      ; X low = $28
    lda     #>P2_X
    sta     VERA_DATA0      ; X high = $01

    ; Y position
    lda     p2_y
    sta     VERA_DATA0      ; Y low
    lda     #0
    sta     VERA_DATA0      ; Y high

    ; --- Sprite 2: Ball ---
    ; VRAM_SPR2_ATTR + 2 = $1FC12
    lda     #<(VRAM_SPR2_ATTR + 2)
    sta     VERA_ADDR_L
    lda     #>(VRAM_SPR2_ATTR + 2)
    sta     VERA_ADDR_M
    lda     #((^(VRAM_SPR2_ATTR + 2)) | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    ; X position (16-bit)
    lda     ball_x_lo
    sta     VERA_DATA0
    lda     ball_x_hi
    sta     VERA_DATA0

    ; Y position (16-bit)
    lda     ball_y_lo
    sta     VERA_DATA0
    lda     ball_y_hi
    sta     VERA_DATA0

    rts

; ---------------------------------------------------------------------------
; upload_sprite_data - Upload paddle and ball pixel data to VRAM
; ---------------------------------------------------------------------------
upload_sprite_data:
    ; --- Upload paddle graphics to VRAM $10000 ---
    stz     VERA_CTRL
    lda     #<VRAM_PADDLE_GFX
    sta     VERA_ADDR_L
    lda     #>VRAM_PADDLE_GFX
    sta     VERA_ADDR_M
    lda     #(^VRAM_PADDLE_GFX | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    ; Write 128 bytes of $11 (color index 1 in both nibbles, 4bpp)
    ldx     #128
@paddle_loop:
    lda     #$11
    sta     VERA_DATA0
    dex
    bne     @paddle_loop

    ; --- Upload ball graphics to VRAM $10080 ---
    lda     #<VRAM_BALL_GFX
    sta     VERA_ADDR_L
    lda     #>VRAM_BALL_GFX
    sta     VERA_ADDR_M
    lda     #(^VRAM_BALL_GFX | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    ; Write 32 bytes of $11
    ldx     #32
@ball_loop:
    lda     #$11
    sta     VERA_DATA0
    dex
    bne     @ball_loop

    rts

; ---------------------------------------------------------------------------
; setup_sprite_attrs - Configure sprite attributes in VERA
; ---------------------------------------------------------------------------
setup_sprite_attrs:
    stz     VERA_CTRL

    ; --- Sprite 0 (Paddle 1) ---
    lda     #<VRAM_SPR0_ATTR
    sta     VERA_ADDR_L
    lda     #>VRAM_SPR0_ATTR
    sta     VERA_ADDR_M
    lda     #(^VRAM_SPR0_ATTR | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    ; Byte 0: address bits [12:5] of $10000
    ; $10000 >> 5 = $0800
    ; Low byte of $0800 = $00
    lda     #$00
    sta     VERA_DATA0      ; Addr low = $00
    ; Byte 1: addr[16:13] in bits [3:0], mode in bit 7
    ; $0800 >> 8 = $08. Mode = 0 (4bpp).
    lda     #$08
    sta     VERA_DATA0      ; Addr high = $08, mode = 4bpp

    ; Byte 2-3: X position (P1_X = 16)
    lda     #P1_X
    sta     VERA_DATA0
    lda     #0
    sta     VERA_DATA0

    ; Byte 4-5: Y position (initial)
    lda     #104            ; Centered
    sta     VERA_DATA0
    lda     #0
    sta     VERA_DATA0

    ; Byte 6: collision mask [7:4], Z-depth [3:2], vflip [1], hflip [0]
    ; Z-depth = 3 (in front of both layers) = %11 in bits [3:2] = $0C
    lda     #$0C
    sta     VERA_DATA0

    ; Byte 7: height [7:6], width [5:4], palette offset [3:0]
    ; Height = 32 -> %10, Width = 8 -> %00
    ; Byte 7 = %10_00_0000 = $80
    lda     #$80
    sta     VERA_DATA0

    ; --- Sprite 1 (Paddle 2) - same image, different position ---
    lda     #<VRAM_SPR1_ATTR
    sta     VERA_ADDR_L
    lda     #>VRAM_SPR1_ATTR
    sta     VERA_ADDR_M
    lda     #(^VRAM_SPR1_ATTR | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    lda     #$00
    sta     VERA_DATA0      ; Same image as paddle 1
    lda     #$08
    sta     VERA_DATA0

    ; X position (P2_X = 296 = $0128)
    lda     #<P2_X
    sta     VERA_DATA0
    lda     #>P2_X
    sta     VERA_DATA0

    ; Y position
    lda     #104
    sta     VERA_DATA0
    lda     #0
    sta     VERA_DATA0

    ; Z-depth in front
    lda     #$0C
    sta     VERA_DATA0

    ; 8x32
    lda     #$80
    sta     VERA_DATA0

    ; --- Sprite 2 (Ball) ---
    lda     #<VRAM_SPR2_ATTR
    sta     VERA_ADDR_L
    lda     #>VRAM_SPR2_ATTR
    sta     VERA_ADDR_M
    lda     #(^VRAM_SPR2_ATTR | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    ; Ball image at $10080
    ; $10080 >> 5 = $0804
    ; Low byte = $04
    lda     #$04
    sta     VERA_DATA0
    ; High byte = $08, mode = 4bpp
    lda     #$08
    sta     VERA_DATA0

    ; X position (centered: 156)
    lda     #<BALL_START_X
    sta     VERA_DATA0
    lda     #>BALL_START_X
    sta     VERA_DATA0

    ; Y position (centered: 116)
    lda     #<BALL_START_Y
    sta     VERA_DATA0
    lda     #>BALL_START_Y
    sta     VERA_DATA0

    ; Z-depth in front
    lda     #$0C
    sta     VERA_DATA0

    ; 8x8 ball: height=00, width=00 -> byte 7 = $00
    lda     #$00
    sta     VERA_DATA0

    rts

; ---------------------------------------------------------------------------
; play_bounce_sfx - Trigger bounce sound on PSG voice 14
; ---------------------------------------------------------------------------
play_bounce_sfx:
    stz     VERA_CTRL

    ; Set VERA address to PSG voice 14 = VRAM $1F9F8
    lda     #<VRAM_PSG_V14
    sta     VERA_ADDR_L
    lda     #>VRAM_PSG_V14
    sta     VERA_ADDR_M
    lda     #(^VRAM_PSG_V14 | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    ; Frequency: ~1000 Hz
    ; freq_reg = freq_hz * 131072 / 48828.125 = 1000 * 2.6843 = ~2684 = $0A7C
    lda     #$7C
    sta     VERA_DATA0      ; Freq low
    lda     #$0A
    sta     VERA_DATA0      ; Freq high

    ; Volume = 48 (out of 63), LR = both (%11)
    ; Byte 2 = %11_110000 = $F0
    lda     #$F0
    sta     VERA_DATA0

    ; Waveform = pulse (%00), pulse width = 32
    ; Byte 3 = %00_100000 = $20
    lda     #$20
    sta     VERA_DATA0

    ; Set timer
    lda     #BOUNCE_SFX_DUR
    sta     sfx_bounce_timer
    rts

; ---------------------------------------------------------------------------
; play_score_sfx - Trigger score sound on PSG voice 15
; ---------------------------------------------------------------------------
play_score_sfx:
    stz     VERA_CTRL

    ; Set VERA address to PSG voice 15 = VRAM $1F9FC
    lda     #<VRAM_PSG_V15
    sta     VERA_ADDR_L
    lda     #>VRAM_PSG_V15
    sta     VERA_ADDR_M
    lda     #(^VRAM_PSG_V15 | VERA_STRIDE_1)
    sta     VERA_ADDR_H

    ; Frequency: ~300 Hz
    ; freq_reg = 300 * 2.6843 = ~805 = $0325
    lda     #$25
    sta     VERA_DATA0      ; Freq low
    lda     #$03
    sta     VERA_DATA0      ; Freq high

    ; Volume = 48, LR = both
    lda     #$F0
    sta     VERA_DATA0

    ; Waveform = triangle (%10), pulse width = 0
    ; Byte 3 = %10_000000 = $80
    lda     #$80
    sta     VERA_DATA0

    lda     #SCORE_SFX_DUR
    sta     sfx_score_timer
    rts

; ---------------------------------------------------------------------------
; update_sfx - Decay and silence sound effects
; ---------------------------------------------------------------------------
update_sfx:
    ; --- Bounce SFX decay ---
    lda     sfx_bounce_timer
    beq     @check_score_sfx
    dec     sfx_bounce_timer
    bne     @check_score_sfx

    ; Timer hit zero - silence voice 14
    jsr     silence_voice14

@check_score_sfx:
    lda     sfx_score_timer
    beq     @sfx_done
    dec     sfx_score_timer
    bne     @sfx_done

    ; Timer hit zero - silence voice 15
    jsr     silence_voice15

@sfx_done:
    rts

; ---------------------------------------------------------------------------
; silence_voice14 - Mute PSG voice 14
; ---------------------------------------------------------------------------
silence_voice14:
    stz     VERA_CTRL
    lda     #<(VRAM_PSG_V14 + 2)
    sta     VERA_ADDR_L
    lda     #>(VRAM_PSG_V14 + 2)
    sta     VERA_ADDR_M
    lda     #(^(VRAM_PSG_V14 + 2) | VERA_STRIDE_1)
    sta     VERA_ADDR_H
    stz     VERA_DATA0      ; Volume = 0, LR = mute
    rts

; ---------------------------------------------------------------------------
; silence_voice15 - Mute PSG voice 15
; ---------------------------------------------------------------------------
silence_voice15:
    stz     VERA_CTRL
    lda     #<(VRAM_PSG_V15 + 2)
    sta     VERA_ADDR_L
    lda     #>(VRAM_PSG_V15 + 2)
    sta     VERA_ADDR_M
    lda     #(^(VRAM_PSG_V15 + 2) | VERA_STRIDE_1)
    sta     VERA_ADDR_H
    stz     VERA_DATA0      ; Volume = 0, LR = mute
    rts

; ---------------------------------------------------------------------------
; show_game_over - Display winner, wait for keypress
; ---------------------------------------------------------------------------
show_game_over:
    ; Position cursor at center-ish of screen (row 13, col 13)
    clc
    ldx     #13
    ldy     #13
    jsr     PLOT            ; X=row, Y=col

    ; Determine winner
    lda     game_over
    cmp     #1
    bne     @p2_won

    ; Player 1 won
    ldx     #0
@p1_msg_loop:
    lda     p1_win_msg, x
    beq     @wait_restart
    phx
    jsr     CHROUT
    plx
    inx
    bne     @p1_msg_loop

@p2_won:
    ldx     #0
@p2_msg_loop:
    lda     p2_win_msg, x
    beq     @wait_restart
    phx
    jsr     CHROUT
    plx
    inx
    bne     @p2_msg_loop

@wait_restart:
    ; Show "press any key" message (row 15, col 10)
    clc
    ldx     #15
    ldy     #10
    jsr     PLOT

    ldx     #0
@restart_msg_loop:
    lda     restart_msg, x
    beq     @wait_key
    phx
    jsr     CHROUT
    plx
    inx
    bne     @restart_msg_loop

@wait_key:
    jsr     wait_vsync
    jsr     update_sfx
    jsr     GETIN
    beq     @wait_key

    ; Silence any remaining SFX
    jsr     silence_voice14
    jsr     silence_voice15

    rts

; ===========================================================================
; RODATA segment - read-only data
; ===========================================================================
.segment "RODATA"

p1_win_msg:
    .byte   "PLAYER 1 WINS!", 0

p2_win_msg:
    .byte   "PLAYER 2 WINS!", 0

restart_msg:
    .byte   "PRESS ANY KEY TO PLAY", 0
