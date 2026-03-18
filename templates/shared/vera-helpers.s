; vera-helpers.s
; ca65 macros for VERA programming on the Commander X16
;
; Provides convenience macros for common VERA operations:
;   VERA_SET_ADDR   - Set VERA address with auto-increment stride
;   VERA_WRITE      - Write a byte to VERA_DATA0
;   VERA_SET_LAYER  - Configure a VERA tile layer
;   VERA_SET_SPRITE - Point VERA address at a sprite attribute block
;
; Usage:
;   .include "vera-helpers.s"

; ---------------------------------------------------------------------------
; VERA Register Addresses
; ---------------------------------------------------------------------------
VERA_ADDR_L     = $9F20         ; Address bits 0-7
VERA_ADDR_M     = $9F21         ; Address bits 8-15
VERA_ADDR_H     = $9F22         ; bits 0-3: addr[16:19], bit 4: DECR, bits 4-7: increment
VERA_DATA0      = $9F23         ; Data port 0
VERA_DATA1      = $9F24         ; Data port 1
VERA_CTRL       = $9F25         ; Control register
VERA_IEN        = $9F26         ; Interrupt enable
VERA_ISR        = $9F27         ; Interrupt status
VERA_IRQLINE_L  = $9F28         ; IRQ raster line (low byte)
VERA_DC_VIDEO   = $9F29         ; Display composer: video output mode
VERA_DC_HSCALE  = $9F2A         ; Display composer: horizontal scale
VERA_DC_VSCALE  = $9F2B         ; Display composer: vertical scale
VERA_DC_BORDER  = $9F2C         ; Display composer: border color
VERA_L0_CONFIG  = $9F2D         ; Layer 0 configuration
VERA_L0_MAPBASE = $9F2E         ; Layer 0 map base address
VERA_L0_TILEBASE = $9F2F        ; Layer 0 tile base address
VERA_L0_HSCROLL_L = $9F30       ; Layer 0 horizontal scroll (low)
VERA_L0_HSCROLL_H = $9F31       ; Layer 0 horizontal scroll (high)
VERA_L0_VSCROLL_L = $9F32       ; Layer 0 vertical scroll (low)
VERA_L0_VSCROLL_H = $9F33       ; Layer 0 vertical scroll (high)
VERA_L1_CONFIG  = $9F34         ; Layer 1 configuration
VERA_L1_MAPBASE = $9F35         ; Layer 1 map base address
VERA_L1_TILEBASE = $9F36        ; Layer 1 tile base address
VERA_L1_HSCROLL_L = $9F37       ; Layer 1 horizontal scroll (low)
VERA_L1_HSCROLL_H = $9F38       ; Layer 1 horizontal scroll (high)
VERA_L1_VSCROLL_L = $9F39       ; Layer 1 vertical scroll (low)
VERA_L1_VSCROLL_H = $9F3A       ; Layer 1 vertical scroll (high)
VERA_AUDIO_CTRL = $9F3B         ; Audio control
VERA_AUDIO_RATE = $9F3C         ; Audio sample rate
VERA_AUDIO_DATA = $9F3D         ; Audio FIFO data
VERA_SPI_DATA   = $9F3E         ; SPI data
VERA_SPI_CTRL   = $9F3F         ; SPI control

; ---------------------------------------------------------------------------
; Auto-increment stride values for VERA_ADDR_H bits 4-7
; ---------------------------------------------------------------------------
VERA_STRIDE_0   = $00           ; No increment
VERA_STRIDE_1   = $10           ; Increment by 1
VERA_STRIDE_2   = $20           ; Increment by 2
VERA_STRIDE_4   = $30           ; Increment by 4
VERA_STRIDE_8   = $40           ; Increment by 8
VERA_STRIDE_16  = $50           ; Increment by 16
VERA_STRIDE_32  = $60           ; Increment by 32
VERA_STRIDE_64  = $70           ; Increment by 64
VERA_STRIDE_128 = $80           ; Increment by 128
VERA_STRIDE_256 = $90           ; Increment by 256
VERA_STRIDE_512 = $A0           ; Increment by 512

; ---------------------------------------------------------------------------
; VERA_SET_ADDR - Set VERA address with auto-increment stride
; ---------------------------------------------------------------------------
; Parameters:
;   addr   - 17-bit VRAM address (e.g., $00000 - $1FFFF)
;   stride - auto-increment stride (use VERA_STRIDE_* constants)
;
; Example:
;   VERA_SET_ADDR $00000, VERA_STRIDE_1
; ---------------------------------------------------------------------------
.macro VERA_SET_ADDR addr, stride
    lda     #<(addr)
    sta     VERA_ADDR_L
    lda     #>(addr)
    sta     VERA_ADDR_M
    lda     #(^(addr) | stride)
    sta     VERA_ADDR_H
.endmacro

; ---------------------------------------------------------------------------
; VERA_WRITE - Write a byte to VERA_DATA0
; ---------------------------------------------------------------------------
; Parameters:
;   value - byte value to write
;
; Example:
;   VERA_WRITE $42
; ---------------------------------------------------------------------------
.macro VERA_WRITE value
    lda     #value
    sta     VERA_DATA0
.endmacro

; ---------------------------------------------------------------------------
; VERA_SET_LAYER - Configure a VERA tile layer
; ---------------------------------------------------------------------------
; Parameters:
;   layer    - layer number (0 or 1)
;   enabled  - 1 to enable, 0 to disable
;   mode     - color depth / mode byte for config register
;   mapbase  - map base address register value
;   tilebase - tile base address register value
;
; Example:
;   VERA_SET_LAYER 1, 1, $60, $00, $04
; ---------------------------------------------------------------------------
.macro VERA_SET_LAYER layer, enabled, mode, mapbase, tilebase
.if layer = 0
    ; Layer 0
    lda     #mode
    sta     VERA_L0_CONFIG
    lda     #mapbase
    sta     VERA_L0_MAPBASE
    lda     #tilebase
    sta     VERA_L0_TILEBASE
    ; Enable/disable layer 0 in DC_VIDEO (bit 4)
    lda     VERA_DC_VIDEO
    .if enabled
        ora     #$10
    .else
        and     #<~$10
    .endif
    sta     VERA_DC_VIDEO
.else
    ; Layer 1
    lda     #mode
    sta     VERA_L1_CONFIG
    lda     #mapbase
    sta     VERA_L1_MAPBASE
    lda     #tilebase
    sta     VERA_L1_TILEBASE
    ; Enable/disable layer 1 in DC_VIDEO (bit 5)
    lda     VERA_DC_VIDEO
    .if enabled
        ora     #$20
    .else
        and     #<~$20
    .endif
    sta     VERA_DC_VIDEO
.endif
.endmacro

; ---------------------------------------------------------------------------
; VERA_SET_SPRITE - Point VERA address at sprite attribute block in VRAM
; ---------------------------------------------------------------------------
; Sprite attributes are located at VRAM $1FC00-$1FFFF.
; Each sprite has 8 bytes of attributes.
;
; Parameters:
;   sprite_num - sprite number (0-127)
;
; Example:
;   VERA_SET_SPRITE 0    ; Point at sprite 0 attributes
; ---------------------------------------------------------------------------
.macro VERA_SET_SPRITE sprite_num
    lda     #<($FC00 + (sprite_num * 8))
    sta     VERA_ADDR_L
    lda     #>($FC00 + (sprite_num * 8))
    sta     VERA_ADDR_M
    lda     #($10 | $01)           ; Auto-increment 1, bank 1 ($1xxxx)
    sta     VERA_ADDR_H
.endmacro
