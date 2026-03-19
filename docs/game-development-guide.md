# Game Development Guide

## Table of Contents

## Overview

The Commander X16 is well-suited for retro-style game development with hardware features that surpass the classic 8-bit machines: 128 hardware sprites, two scrollable tile layers, 128 KB VRAM, 512 KB banked RAM, and FM + PSG audio.

## Game Loop and VSYNC

Every game needs a main loop synchronized to the display refresh rate (60 Hz for NTSC timing).

### VSYNC Synchronization

The VERA generates a VSYNC interrupt at the start of each vertical blank period. Use this to synchronize your game loop:

```asm
; Method 1: Wait for VSYNC by polling
wait_vsync:
    lda $9F27          ; VERA ISR
    and #$01           ; check VSYNC bit
    beq wait_vsync
    lda #$01
    sta $9F27          ; acknowledge VSYNC (write 1 to clear)
    rts

; Main game loop
game_loop:
    jsr wait_vsync
    jsr read_input
    jsr update_game
    jsr update_sprites
    jsr update_scroll
    jmp game_loop
```

```asm
; Method 2: Use VSYNC IRQ
setup_irq:
    sei
    ; Save old IRQ vector
    lda $0314
    sta old_irq
    lda $0315
    sta old_irq+1

    ; Set new IRQ vector
    lda #<game_irq
    sta $0314
    lda #>game_irq
    sta $0315

    ; Enable VSYNC interrupt in VERA
    lda #$01
    sta $9F26          ; VERA IEN

    cli
    rts

game_irq:
    lda $9F27          ; VERA ISR
    and #$01           ; VSYNC?
    beq @not_vsync
    sta $9F27          ; acknowledge

    inc vsync_flag     ; signal main loop

@not_vsync:
    jmp (old_irq)      ; chain to original handler
```

### C Game Loop (cc65)

```c
#include <cx16.h>

void waitvsync(void) {
    while (!(VERA.irq_flags & 0x01)) ;
    VERA.irq_flags = 0x01;  // acknowledge
}

void main(void) {
    // Setup...
    while (1) {
        waitvsync();
        read_input();
        update_game();
        render();
    }
}
```

## Input

### SNES Controllers

```asm
; Read SNES controller 1
jsr $FF53          ; joystick_scan (usually called by KERNAL IRQ)
lda #1             ; joystick 1
jsr $FF56          ; joystick_get
; A = buttons low  (active low: 0 = pressed)
;   bit 0=B, 1=Y, 2=Select, 3=Start, 4=Up, 5=Down, 6=Left, 7=Right
; X = buttons high
;   bit 0=A, 1=X, 2=L, 3=R
; Y = 0 if present

; Example: check if A button is pressed
txa
and #$01           ; bit 0 of high byte
bne @a_not_pressed ; remember: 0 = pressed (active low)
    ; A button is pressed!
@a_not_pressed:
```

```c
// C version
#include <joystick.h>
#include <cx16.h>

unsigned char joy;
joy_install(cx16_std_joy);

// In game loop:
joy = joy_read(0);  // joystick 0 (port 1)
if (joy & JOY_BTN_1) { /* A pressed */ }
if (joy & JOY_UP)    { /* Up pressed */ }
```

### Keyboard Input

```asm
; Check for keypress (non-blocking)
jsr $FFE4          ; GETIN
cmp #0
beq no_key
; A = key code

; Common key codes:
; $91 = Cursor Up, $11 = Cursor Down
; $9D = Cursor Left, $1D = Cursor Right
; $20 = Space, $0D = Return
; $03 = Run/Stop (Break)
```

### Mouse Input

```asm
; Enable mouse (visible cursor)
lda #$01
ldx #0             ; screen mode for scaling
jsr $FF68          ; mouse_config

; Read mouse state
ldx #$02           ; store results starting at r0 (offset into virtual regs)
jsr $FF6B          ; mouse_get  (use correct KERNAL call)
; r0 = X position (16-bit)
; r1 = Y position (16-bit)
; A = button state (bit 0=left, bit 1=right, bit 2=middle)
```

## Sprite System

### Loading Sprite Data to VRAM

```asm
; Load a 16x16 4bpp sprite to VRAM address $10000
; Data is 128 bytes (16x16 / 2 for 4bpp)

; Set VERA address to $10000, auto-increment 1
stz $9F20          ; ADDR_L = 0
stz $9F21          ; ADDR_M = 0
lda #$11           ; increment=1, addr bit16=1
sta $9F22

; Copy sprite data
ldx #0
@copy:
    lda sprite_gfx,x
    sta $9F23      ; DATA0
    inx
    cpx #128
    bne @copy
```

### Configuring Sprite Attributes

Sprite attributes are at VRAM $1FC00 (default), 8 bytes per sprite:

```asm
; Helper: set sprite N attributes
; sprite_num in A, x_pos, y_pos, etc. passed via ZP
set_sprite:
    ; Calculate VRAM address: $1FC00 + (sprite_num x 8)
    asl                ; x2
    asl                ; x4
    asl                ; x8
    clc
    adc #$00
    sta $9F20          ; ADDR_L
    lda #$FC
    sta $9F21          ; ADDR_M
    lda #$11           ; increment=1, addr bit16=1
    sta $9F22

    ; Write 8 attribute bytes via DATA0
    ; Bytes 0-1: image address / 32
    lda sprite_addr_lo
    sta $9F23
    lda sprite_addr_hi ; include mode bit (bit 7 = 8bpp)
    sta $9F23

    ; Bytes 2-3: X position
    lda sprite_x_lo
    sta $9F23
    lda sprite_x_hi
    sta $9F23

    ; Bytes 4-5: Y position
    lda sprite_y_lo
    sta $9F23
    lda sprite_y_hi
    sta $9F23

    ; Byte 6: Z-depth, flip, collision mask
    lda #%00001100     ; Z=3 (in front), no flip
    sta $9F23

    ; Byte 7: size, palette offset
    lda #%01010000     ; 16x16, palette offset 0
    sta $9F23
    rts
```

### Sprite Movement

```asm
; Move sprite 0's X position
; Read current X, add velocity, write back

; Point to sprite 0 attribute byte 2 (X position)
lda #$02
sta $9F20
lda #$FC
sta $9F21
lda #$11
sta $9F22

; Read X position (bytes 2-3)
; Note: to read, use VERA_DATA0 after setting address
; But since VERA auto-increments, we need to set address first
; Re-set to position bytes
lda #$02
sta $9F20          ; byte 2 of sprite 0
lda player_x
sta $9F23          ; write new X low byte
lda player_x+1
sta $9F23          ; write new X high byte
; Y position is next
lda player_y
sta $9F23          ; write new Y low byte
lda player_y+1
sta $9F23          ; write new Y high byte
```

### Sprite Animation

```asm
; Animate by changing the sprite image address
; Assume frames at VRAM $10000, $10080, $10100, $10180 (128 bytes each for 16x16 4bpp)

animate_player:
    ; Advance frame counter
    inc anim_timer
    lda anim_timer
    and #$07           ; change frame every 8 vsync periods
    bne @no_change

    ; Next frame
    inc anim_frame
    lda anim_frame
    and #$03           ; 4 frames, wrap around
    sta anim_frame

    ; Calculate image address: $10000 + (frame x 128)
    ; $10000 / 32 = $0800 base
    ; 128 / 32 = 4 per frame offset
    asl                ; frame x 2
    asl                ; frame x 4
    clc
    adc #$00           ; add to base low byte ($00)
    sta sprite_img_lo
    lda #$08           ; base high byte
    sta sprite_img_hi

    ; Update sprite 0 attribute bytes 0-1
    stz $9F20
    lda #$FC
    sta $9F21
    lda #$11
    sta $9F22
    lda sprite_img_lo
    sta $9F23
    lda sprite_img_hi
    sta $9F23

@no_change:
    rts
```

## Tile-Based Worlds

### Setting Up a Tile Layer

```asm
; Configure Layer 0 for a tile-based game world
; 64x64 tiles, 4bpp, 8x8 tiles
; Map at VRAM $00000 (8192 bytes = 64x64x2)
; Tiles at VRAM $04000

; Layer config
lda #%00100010     ; map 64x64 (bits 7:4 = 01,01), 4bpp (bits 1:0 = 10)
sta $9F2D          ; L0_CONFIG

; Map base: $00000 / 512 = 0
lda #$00
sta $9F2E          ; L0_MAPBASE

; Tile base: $04000 / 2048 = 2, shifted left 2 = 8. Tile size 8x8.
lda #$08
sta $9F2F          ; L0_TILEBASE

; Enable Layer 0
lda $9F29
ora #$10
sta $9F29
```

### Writing Map Data

```asm
; Fill tile map with a pattern
; Map at VRAM $00000, 64x64 tiles, 2 bytes each

stz $9F20
stz $9F21
lda #$10           ; increment=1, addr bit16=0
sta $9F22

; Write tile entries (tile index + attributes)
ldx #0             ; tile counter
ldy #0             ; row counter
@row:
    ldx #0
@col:
    ; Tile index (low byte)
    txa
    and #$0F       ; simple pattern: repeat every 16 tiles
    sta $9F23

    ; Tile attributes: palette 0, no flip
    lda #$00
    sta $9F23

    inx
    cpx #64
    bne @col

    iny
    cpy #64
    bne @row
```

### Scrolling

```asm
; Scroll Layer 0 based on player position
; scroll_x and scroll_y are 16-bit values

update_scroll:
    ; H-scroll
    lda scroll_x
    sta $9F30          ; L0_HSCROLL_L
    lda scroll_x+1
    and #$0F           ; only low 4 bits for 12-bit scroll
    sta $9F31          ; L0_HSCROLL_H

    ; V-scroll
    lda scroll_y
    sta $9F32          ; L0_VSCROLL_L
    lda scroll_y+1
    and #$0F
    sta $9F33          ; L0_VSCROLL_H
    rts
```

### Map Wrapping

With a 64x64 tile map (512x512 pixels with 8x8 tiles), the map wraps automatically when you scroll beyond its bounds. This is useful for:
- Infinite scrolling: update the row/column that's about to scroll into view
- Large worlds: stream map data from banked RAM as the player moves

```asm
; When scrolling right, update the column that's about to appear
; column_to_update = (scroll_x / 8 + 40) MOD 64 (for 320px wide screen)
```

### Metatiles

For larger game worlds with less memory, use metatiles (2x2 or 4x4 groups of tiles defined as a single logical unit):

```
; Metatile definition (4 tiles for a 2x2 metatile)
metatile_0: .byte $10, $11  ; top-left, top-right
            .byte $20, $21  ; bottom-left, bottom-right
```

Store the world map as metatile indices, then expand to actual tiles when writing to VRAM.

## Parallax Scrolling

Use both layers at different scroll rates:

```asm
; Layer 0 = background (slow scroll)
; Layer 1 = foreground (fast scroll, follows player)

; Configure both layers
; Layer 1 follows player exactly
lda player_x
sec
sbc #160           ; center player (320/2)
sta $9F37          ; L1_HSCROLL_L
; ...

; Layer 0 scrolls at half speed
lda player_x
sec
sbc #160
lsr                ; divide by 2
sta $9F30          ; L0_HSCROLL_L
; ...
```

Setup:
- Layer 0: far background (mountains, sky) -- slower parallax
- Layer 1: near foreground (platforms, terrain) -- matches player movement
- Sprites: characters, items, projectiles

## Collision Detection

### Bounding Box Collision

```asm
; Check if two rectangles overlap
; Object A: ax, ay, aw, ah
; Object B: bx, by, bw, bh
; Returns: carry set if collision

check_bbox:
    ; if ax + aw <= bx -> no collision
    lda ax
    clc
    adc aw
    cmp bx
    bcc @no_col

    ; if bx + bw <= ax -> no collision
    lda bx
    clc
    adc bw
    cmp ax
    bcc @no_col

    ; if ay + ah <= by -> no collision
    lda ay
    clc
    adc ah
    cmp by
    bcc @no_col

    ; if by + bh <= ay -> no collision
    lda by
    clc
    adc bh
    cmp ay
    bcc @no_col

    sec                ; collision!
    rts
@no_col:
    clc                ; no collision
    rts
```

### Tile-Based Collision

Check the tile at the player's target position:

```asm
; Check if tile at pixel (px, py) is solid
; Convert pixel coords to tile coords: tile_x = px / 8, tile_y = py / 8
; Look up tile in map data

check_tile_solid:
    ; tile_x = px / 8
    lda px
    lsr
    lsr
    lsr
    sta tile_x

    ; tile_y = py / 8
    lda py
    lsr
    lsr
    lsr
    sta tile_y

    ; Map offset = (tile_y x 64 + tile_x) x 2 (for 64-wide map, 2 bytes/entry)
    ; Read tile index from VRAM map
    ; ... (calculate VRAM address and read via VERA)

    ; Compare against solid tile list
    cmp #SOLID_TILE_START
    bcs @solid
    clc
    rts
@solid:
    sec
    rts
```

### Hardware Sprite Collision

VERA provides basic sprite collision detection:

```asm
; After rendering, check VERA ISR for sprite collision
lda $9F27
and #$08           ; SPRCOL bit
beq @no_collision
; Bits 7:4 of ISR contain collision mask OR of overlapping sprites
lda $9F27
lsr
lsr
lsr
lsr                ; collision mask in A
; Clear the flag
lda #$08
sta $9F27
@no_collision:
```

Use collision masks on sprites to categorize them (e.g., mask bit 0 = player, bit 1 = enemy, bit 2 = projectile).

## Audio for Games

### Sound Effect System

Reserve some audio channels for SFX:
- YM2151 channels 6-7 for FM sound effects
- PSG voices 12-15 for PSG sound effects

```asm
; Play a "jump" sound effect on PSG voice 12
play_jump_sfx:
    ; Voice 12 at VRAM $1F9C0 + (12 x 4) = $1F9F0
    lda #$F0
    sta $9F20
    lda #$F9
    sta $9F21
    lda #$11
    sta $9F22

    lda #$00           ; freq low
    sta $9F23
    lda #$06           ; freq high (high pitch)
    sta $9F23
    lda #$FF           ; both channels, max volume
    sta $9F23
    lda #$80           ; triangle wave
    sta $9F23

    ; Start decay timer (in game loop, decrease volume over frames)
    lda #63
    sta sfx_jump_vol
    rts
```

### Music Playback

Use ZSM files with a player library, or roll your own:

```asm
; In VSYNC handler, advance music tick
music_tick:
    ; Read next music event from banked RAM
    lda music_bank
    sta RAM_BANK

    ldy music_ptr
    lda (music_base),y
    ; Parse and apply register writes...
    ; Advance pointer...
    rts
```

See [Sound Programming](sound-programming.md) for full audio details.

## Memory Management

### Fixed RAM (~38 KB)

```
$0000-$07FF  System use (ZP, stack, KERNAL vars)
$0800-$080C  BASIC stub
$080D-$9EFF  Your program code + data (~38 KB)
  $080D+     CODE segment
  ...        RODATA, DATA segments
  ...        BSS (variables)
  ...        Heap / dynamic allocation
$9F00-$9FFF  I/O (not RAM)
```

### Banked RAM (512 KB)

With 64 banks of 8 KB each (banks 0-63), you have substantial storage:

| Banks | Usage |
|---|---|
| 0 | KERNAL work (usable with care) |
| 1-4 | Level map data |
| 5-10 | Sprite sheets (source data for VRAM) |
| 11-15 | Music data (ZSM or custom format) |
| 16-20 | Sound effects |
| 21-63 | Additional level data, cutscene data, etc. |

### Streaming Data

For worlds larger than VRAM, stream tile/sprite data from banked RAM:

```asm
; Load next section of tileset from RAM bank to VRAM
load_tileset_section:
    lda #TILESET_BANK
    sta RAM_BANK

    ; Set VERA address for tile data region
    ; ...

    ; Copy from $A000 to VRAM
    ldx #0
    ldy #0
@stream:
    lda $A000,x
    sta $9F23          ; VERA DATA0
    inx
    bne @stream
    inc @stream+2      ; next page (self-modifying code)
    iny
    cpy #32            ; 32 pages = 8192 bytes
    bne @stream
    rts
```

## Performance Tips

1. **Use zero-page variables** for frequently-accessed data (loop counters, pointers, positions). ZP access is 1 cycle faster per instruction.

2. **Unroll tight loops** when speed matters:
```asm
; Instead of a loop for 4 iterations:
lda data+0 : sta $9F23
lda data+1 : sta $9F23
lda data+2 : sta $9F23
lda data+3 : sta $9F23
```

3. **VERA auto-increment** is your friend -- set it once and stream data without recalculating addresses.

4. **VERA FX cache write** can write 4 bytes to VRAM per store instruction, 4x faster for fills.

5. **Use lookup tables** instead of multiplication/division. Pre-calculate at startup.

6. **Minimize bank switching** in hot paths. Keep active data in the same bank.

7. **Time your updates**: You have ~2.5 million cycles per frame at 8 MHz / 60 Hz = 133,333 cycles. That's generous for an 8-bit machine but not unlimited.

8. **Update VRAM during VBLANK** when possible to avoid visual glitches.

9. **Use hardware features**: scrolling is free (just write scroll registers), sprites move by changing attributes (no redrawing), and collision detection has hardware support.

## Walkthrough: Simple Platformer

A high-level outline for building a platformer:

### 1. Project Setup
```bash
make new-project NAME=platformer TEMPLATE=ca65-asm
```

### 2. Initialize Display
- Set 320x240 mode (HSCALE/VSCALE = 64)
- Configure Layer 1 for 64x32 tile map, 4bpp, 8x8 tiles
- Configure Layer 0 for background parallax
- Enable sprites

### 3. Load Assets
- Load tileset to VRAM (platforms, ground, decorations)
- Load sprite sheets to VRAM (player frames, enemies)
- Set up palette

### 4. Build the Level
- Store level data in banked RAM (metatile indices)
- Expand metatiles into Layer 1 tile map

### 5. Game Loop
```
loop:
    wait for VSYNC
    read controller input
    apply gravity to player
    check horizontal movement + tile collision
    check vertical movement + tile collision
    update player animation frame
    update enemy positions + AI
    check player-enemy collision (bbox)
    update scroll position (track player)
    update parallax (Layer 0)
    update sprite attributes in VRAM
    update sound effects
    goto loop
```

### 6. Physics
- Gravity: add constant to Y velocity each frame
- Jump: set negative Y velocity when grounded + button pressed
- Horizontal: set X velocity from input, apply friction
- Collision: check destination tile, stop at tile boundary if solid

### 7. Level Transitions
- When player reaches edge, load next level section from banked RAM
- Update tile map, reset scroll, reposition player

## Complete Examples

The `projects/` directory contains fully working game implementations that demonstrate the patterns in this guide:

- **[pong-asm](../projects/pong-asm/)** — Assembly (ca65) Pong with hardware sprites, PSG audio, VSYNC game loop, and SNES controller input
- **[pong-c](../projects/pong-c/)** — C (cc65) Pong showing the same game logic in C with `vpoke()`, `VERA.data0`, and joystick input
- **[pong-basic](../projects/pong-basic/)** — BASIC Pong using `SPRMEM`, `SPRITE`, `MOVSPR`, `VPOKE` for PSG audio, and `JOY()` for input

Each implements the full game loop pattern: VSYNC wait → input → physics → collision → sprite update → audio.

Cross-reference: See [VERA Programming Guide](vera-programming-guide.md) for graphics details. See [Sound Programming](sound-programming.md) for audio. See [Memory Map](memory-map.md) for address reference. See [Development Guide](development-guide.md) for build tools.
