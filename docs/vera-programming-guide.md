# VERA Programming Guide

## Table of Contents

- [Overview](#overview)
- [Accessing VRAM](#accessing-vram)
- [Display Composer](#display-composer)
- [Layer Configuration](#layer-configuration)
- [Tile Mode Deep Dive](#tile-mode-deep-dive)
- [Bitmap Mode](#bitmap-mode)
- [Sprites](#sprites)
- [Palette](#palette)
- [Scrolling and Parallax](#scrolling-and-parallax)
- [VERA FX](#vera-fx)
- [PSG Audio](#psg-audio)
- [PCM Audio](#pcm-audio)
- [Practical Recipes](#practical-recipes)

## Overview

VERA (Video Embedded Retro Adapter) is the custom FPGA-based video and audio controller in the Commander X16. It provides:
- 128 KB dedicated VRAM
- Two independent layers (tile or bitmap mode)
- 128 sprites
- 256-color palette (12-bit RGB, 4096 possible colors)
- 16-voice PSG audio
- Stereo PCM audio playback
- Hardware scrolling
- VERA FX acceleration

VERA is accessed through memory-mapped registers at $9F20–$9F3F. It has its own 128 KB address space ($00000–$1FFFF) separate from the CPU.

## Accessing VRAM

VERA has two independent address pointers (ADDRx). Use VERA_CTRL bit 0 (ADDRSEL) to select which pointer is active:

- ADDRSEL=0: Reads/writes to VERA_DATA0 use address pointer 0
- ADDRSEL=1: Reads/writes to VERA_DATA1 use address pointer 1

Setting an address (show the three registers ADDR_L, ADDR_M, ADDR_H):
- ADDR_L ($9F20): bits [7:0] of address
- ADDR_M ($9F21): bits [15:8] of address
- ADDR_H ($9F22): bits [0-3] = addr[19:16], bit 3 = DECR (count down), bits [4-7] = auto-increment step

Auto-increment values (bits 7-4 of ADDR_H):

| Value | Increment |
|---|---|
| 0 | 0 (none) |
| 1 | 1 |
| 2 | 2 |
| 3 | 4 |
| 4 | 8 |
| 5 | 16 |
| 6 | 32 |
| 7 | 64 |
| 8 | 128 |
| 9 | 256 |
| 10 | 512 |
| 11 | 40 |
| 12 | 80 |
| 13 | 160 |
| 14 | 320 |
| 15 | 640 |

Values 11-15 are useful for navigating bitmap rows at common widths.

Example: Set VRAM address to $10000 with auto-increment 1:

```asm
lda #$00
sta $9F20        ; ADDR_L = $00
sta $9F21        ; ADDR_M = $00
lda #$11         ; increment=1 (high nibble), addr[16]=1 (bit 0)
sta $9F22        ; ADDR_H
; Now write bytes via $9F23 (DATA0) — address auto-increments after each write
```

## Display Composer

The Display Composer controls the overall display output.

### Video Output ($9F29 when DCSEL=0)

| Bit | Name | Description |
|---|---|---|
| 7 | Current field | Interlace: 0=even, 1=odd (read only) |
| 6 | Sprites enable | 1=sprites visible |
| 5 | Layer 1 enable | 1=layer 1 visible |
| 4 | Layer 0 enable | 1=layer 0 visible |
| 3:2 | Chroma disable | 0=normal, 1/2=monochrome modes |
| 1:0 | Output mode | 0=disabled, 1=VGA, 2=NTSC composite, 3=RGB |

### Scaling ($9F2A, $9F2B when DCSEL=0)

HSCALE and VSCALE control the output resolution scaling. The formula is:
- Active pixels = 640 / (HSCALE / 128)
- Active lines = 480 / (VSCALE / 128)

| HSCALE/VSCALE | Resolution |
|---|---|
| 128 ($80) | 640x480 (1:1) |
| 64 ($40) | 320x240 (2:1) |
| 32 ($20) | 160x120 (4:1) |

### Border Color ($9F2C when DCSEL=0)

Palette index for the border area (visible when active area doesn't fill the screen, or with custom start/stop).

### DC Registers with DCSEL=1 ($9F29-$9F2C)

When VERA_CTRL bit 1 (DCSEL) is set to 1:
- $9F29: DC_HSTART (horizontal active start / 4)
- $9F2A: DC_HSTOP (horizontal active stop / 4)
- $9F2B: DC_VSTART (vertical active start / 2)
- $9F2C: DC_VSTOP (vertical active stop / 2)

These allow creating a smaller active display area within the 640x480 frame.

## Layer Configuration

Each layer (L0 and L1) can independently operate in tile mode or bitmap mode.

### Layer Config Register ($9F2D for L0, $9F34 for L1)

| Bit | Name | Description |
|---|---|---|
| 7:6 | Map height | 0=32, 1=64, 2=128, 3=256 tiles |
| 5:4 | Map width | 0=32, 1=64, 2=128, 3=256 tiles |
| 3 | T256C | 1=256-color text mode (tile mode only) |
| 2 | Bitmap mode | 0=tile mode, 1=bitmap mode |
| 1:0 | Color depth | 0=1bpp, 1=2bpp, 2=4bpp, 3=8bpp |

### MAPBASE Register ($9F2E for L0, $9F35 for L1)

VRAM address of the tile map, in units of 512 bytes: `VRAM_address = MAPBASE * 512`

### TILEBASE Register ($9F2F for L0, $9F36 for L1)

| Bit | Name | Description |
|---|---|---|
| 7:2 | Address | VRAM address of tile data, in units of 2048 bytes |
| 1 | Tile width | 0=8 pixels, 1=16 pixels |
| 0 | Tile height | 0=8 pixels, 1=16 pixels |

VRAM address = (TILEBASE >> 2) * 2048 (i.e., only bits 7:2 matter for address, and bit 1 = tile_width, bit 0 = tile_height)

## Tile Mode Deep Dive

### Map Entry Format (2 bytes per tile)

#### 1 BPP (2-color) Mode

| Byte | Bits | Description |
|---|---|---|
| 0 | 7:0 | Character index |
| 1 | 7:4 | Background color |
| 1 | 3:0 | Foreground color |

#### 2 BPP (4-color) Mode

| Byte | Bits | Description |
|---|---|---|
| 0 | 7:0 | Tile index (low byte) |
| 1 | 7:4 | Palette offset (selects which group of 4 colors) |
| 1 | 3 | V-flip |
| 1 | 2 | H-flip |
| 1 | 1:0 | Tile index (high 2 bits) -> 10-bit index (0-1023) |

#### 4 BPP (16-color) Mode

| Byte | Bits | Description |
|---|---|---|
| 0 | 7:0 | Tile index (low byte) |
| 1 | 7:4 | Palette offset (selects which group of 16 colors) |
| 1 | 3 | V-flip |
| 1 | 2 | H-flip |
| 1 | 1:0 | Tile index (high 2 bits) -> 10-bit index (0-1023) |

#### 8 BPP (256-color) Mode

| Byte | Bits | Description |
|---|---|---|
| 0 | 7:0 | Tile index (low byte) |
| 1 | 3 | V-flip |
| 1 | 2 | H-flip |
| 1 | 1:0 | Tile index (high 2 bits) -> 10-bit index (0-1023) |

In 8bpp, there is no palette offset -- all 256 colors are available per tile.

### T256C Text Mode

When the T256C bit is set in 1bpp mode, the map entry format changes:
- Byte 0: Character index
- Byte 1: Foreground color (full 8-bit palette index; background is always color 0, i.e., transparent)

### Tile Data Layout

Tiles are stored in VRAM as pixel data, row by row:
- 1bpp: 1 bit per pixel, 8 pixels per byte (MSB first)
- 2bpp: 2 bits per pixel, 4 pixels per byte
- 4bpp: 4 bits per pixel, 2 pixels per byte (high nibble first)
- 8bpp: 1 byte per pixel

Tile size in bytes:

| BPP | 8x8 tile | 16x16 tile |
|---|---|---|
| 1 | 8 bytes | 32 bytes |
| 2 | 16 bytes | 64 bytes |
| 4 | 32 bytes | 128 bytes |
| 8 | 64 bytes | 256 bytes |

## Bitmap Mode

Set bit 2 of the layer config register. In bitmap mode:
- TILEBASE points to the start of bitmap data (same address calculation)
- TILEBASE bit 0 selects bitmap width: 0=320 pixels, 1=640 pixels
- Color depth bits select BPP (1/2/4/8)
- MAPBASE is used as a palette offset (bits 7:2) in 1/2/4 bpp modes

Bitmap row stride depends on width and BPP:

| Width | 1bpp | 2bpp | 4bpp | 8bpp |
|---|---|---|---|---|
| 320 | 40 | 80 | 160 | 320 |
| 640 | 80 | 160 | 320 | 640 |

Memory usage for full-screen bitmaps:
- 320x240 @ 8bpp = 75,000 bytes (~73 KB)
- 320x240 @ 4bpp = 37,500 bytes (~37 KB)
- 640x480 @ 1bpp = 38,400 bytes (~38 KB)

## Sprites

VERA supports 128 hardware sprites. Sprite attributes are stored in VRAM at $1FC00 (default), 8 bytes per sprite.

### Sprite Attribute Format (8 bytes)

| Offset | Bits | Description |
|---|---|---|
| 0-1 | 11:0 | Image address in VRAM / 32 (so actual address = value * 32) |
| 0-1 | 15:12 | Mode: bit 15 = 8bpp (1) or 4bpp (0) |
| 2-3 | 9:0 | X position (signed, -512 to 511 visible at 0-319/639) |
| 4-5 | 9:0 | Y position (signed, -512 to 511 visible at 0-239/479) |
| 6 | 3:2 | Z-depth: 0=disabled, 1=behind both layers, 2=between L0 and L1, 3=in front of both |
| 6 | 1 | V-flip |
| 6 | 0 | H-flip |
| 6 | 7:4 | Collision mask (4 bits) |
| 7 | 7:6 | Sprite height: 0=8, 1=16, 2=32, 3=64 |
| 7 | 5:4 | Sprite width: 0=8, 1=16, 2=32, 3=64 |
| 7 | 3:0 | Palette offset (which group of 16 colors for 4bpp) |

### Sprite Image Data

- 4bpp: 4 bits per pixel, high nibble first. Color 0 is transparent.
- 8bpp: 1 byte per pixel. Color 0 is transparent.

Image size in bytes:

| Size | 4bpp | 8bpp |
|---|---|---|
| 8x8 | 32 | 64 |
| 16x16 | 128 | 256 |
| 32x32 | 512 | 1024 |
| 64x64 | 2048 | 4096 |

### Sprite Collision

Hardware collision detection via the ISR register ($9F27). When sprites overlap:
- SPRCOL bit (bit 3) is set in ISR
- Bits 7:4 contain the OR of collision masks of all overlapping sprites
- Read ISR to get collision info, write to clear

### Practical: Setting Up a Sprite

```asm
; Load sprite image data to VRAM $10000
; Set address to $10000, increment 1
lda #$00
sta $9F20
sta $9F21
lda #$11            ; increment=1, addr bit 16=1
sta $9F22

; Write 128 bytes of 16x16 4bpp sprite data
ldx #0
@write_sprite:
lda sprite_data,x
sta $9F23           ; DATA0
inx
cpx #128
bne @write_sprite

; Configure sprite 0 attributes
; Sprite attributes at VRAM $1FC00 + (sprite# * 8)
; Sprite 0 = $1FC00
lda #$00
sta $9F20           ; ADDR_L
lda #$FC
sta $9F21           ; ADDR_M
lda #$11            ; increment=1, addr bit 16=1
sta $9F22

; Bytes 0-1: address/32 = $10000/32 = $0800, mode=4bpp (bit 7 of byte 1 = 0)
lda #$00            ; address low byte: $00
sta $9F23
lda #$08            ; address high: $08 (4bpp mode, addr bits)
sta $9F23

; Bytes 2-3: X position = 160
lda #160
sta $9F23
lda #$00
sta $9F23

; Bytes 4-5: Y position = 120
lda #120
sta $9F23
lda #$00
sta $9F23

; Byte 6: Z-depth=3 (in front), no flip, collision mask=0
lda #%00001100      ; z-depth = 3
sta $9F23

; Byte 7: 16x16, palette offset 0
lda #%01010000      ; height=16, width=16
sta $9F23

; Enable sprites in display composer
lda $9F29
ora #$40            ; set bit 6
sta $9F29
```

## Palette

256 entries, each 2 bytes (little-endian), stored in VRAM at $1FA00:
- Byte 0: GGGG BBBB (green high nibble, blue low nibble)
- Byte 1: 0000 RRRR (red in low nibble)

Each channel is 4 bits (0-15), giving 12-bit color (4096 possible colors).

### Default Palette

Entry 0 is typically black ($000). The default palette provides a reasonable set of colors. The first 16 entries match the Commodore 64 palette. Entries 16-255 provide a broader color range.

### Setting a Palette Entry

```asm
; Set palette entry 5 to bright red ($F00)
; Palette address = $1FA00 + (index * 2) = $1FA00 + 10 = $1FA0A
lda #$0A
sta $9F20
lda #$FA
sta $9F21
lda #$11            ; increment=1, addr bit 16=1
sta $9F22

lda #$00            ; GB = $00
sta $9F23
lda #$0F            ; 0R = $0F (red=15)
sta $9F23
```

## Scrolling and Parallax

Each layer has independent horizontal and vertical scroll registers:
- L0: $9F30/$9F31 (H), $9F32/$9F33 (V)
- L1: $9F37/$9F38 (H), $9F39/$9F3A (V)

Scroll values are 12-bit (0-4095). The map wraps around.

### Parallax Scrolling

Use two layers scrolling at different speeds:

```asm
; In VSYNC handler:
; Layer 0 (background) scrolls at half speed
; Layer 1 (foreground) scrolls at full speed
inc scroll_counter
lda scroll_counter
sta $9F37           ; L1 H-scroll (full speed)
lsr a
sta $9F30           ; L0 H-scroll (half speed)
```

## VERA FX

VERA FX provides hardware-accelerated operations, accessible when DCSEL >= 2 in VERA_CTRL:

### DCSEL Values

| DCSEL | Registers at $9F29-$9F2C |
|---|---|
| 0 | Standard Display Composer |
| 1 | DC_HSTART/HSTOP/VSTART/VSTOP |
| 2 | FX_CTRL, FX_TILEBASE, FX_MAPBASE |
| 3 | FX_MULT_ACCUM |
| 4 | FX_X_INCR, FX_Y_INCR |
| 5 | FX_X_POS, FX_Y_POS |
| 6 | FX_CACHE_L/H, FX_POLY_FILL |

Key FX capabilities:
- **Cache write**: Write 4 bytes to VRAM in a single store (32-bit cache)
- **Line helper**: Hardware-assisted Bresenham line drawing
- **Polygon fill**: Hardware-assisted horizontal span filling
- **16-bit multiply**: 16x16 -> 32-bit multiplication
- **Affine helper**: Texture mapping support

VERA FX is an advanced topic. See the VERA Programmer's Reference for complete details.

## PSG Audio

VERA includes a 16-voice Programmable Sound Generator. PSG registers are in VRAM at $1F9C0, 4 bytes per voice.

### PSG Voice Registers (at VRAM $1F9C0 + voice * 4)

| Offset | Name | Description |
|---|---|---|
| 0 | FREQ_L | Frequency low byte |
| 1 | FREQ_H | Frequency high byte |
| 2 | VOLUME/LR | [7:6]=Left/Right (0=off, 1=left, 2=right, 3=both), [5:0]=volume (0-63) |
| 3 | WAVEFORM/PW | [7:6]=waveform (0=pulse, 1=sawtooth, 2=triangle, 3=noise), [5:0]=pulse width (for pulse wave) |

### Frequency Formula

`frequency_hz = (FREQ * 48828.125) / 65536`

Or equivalently: `FREQ = frequency_hz * 65536 / 48828.125`

Some useful values:

| Note | Hz | FREQ value |
|---|---|---|
| A4 | 440 | $0242 |
| C5 | 523.25 | $02B3 |
| Middle C (C4) | 261.63 | $0159 |

### Practical: Play a Tone

```asm
; Play A4 (440 Hz) on voice 0, both speakers
; PSG voice 0 at VRAM $1F9C0
lda #$C0
sta $9F20
lda #$F9
sta $9F21
lda #$11        ; increment 1, bit16=1
sta $9F22

; Frequency = $0242
lda #$42
sta $9F23       ; FREQ_L
lda #$02
sta $9F23       ; FREQ_H

; Volume = 63, both channels
lda #$FF        ; LR=11 (both), vol=63
sta $9F23

; Waveform = pulse, 50% duty
lda #$3F        ; waveform=00 (pulse), pw=63 (50%)
sta $9F23
```

## PCM Audio

VERA provides a stereo PCM FIFO for sample playback.

### Registers

- $9F3B VERA_AUDIO_CTRL: [7]=FIFO reset, [5]=16-bit, [4]=stereo, [3:0]=volume (0-15)
- $9F3C VERA_AUDIO_RATE: Sample rate = AUDIO_RATE * 48828.125 / 65536 Hz. Set to 0 to pause.
- $9F3D VERA_AUDIO_DATA: Write samples to FIFO (4 KB buffer)

Common sample rates:

| AUDIO_RATE | Sample Rate |
|---|---|
| 128 ($80) | ~24.4 kHz |
| 171 ($AB) | ~32.6 kHz |
| 255 ($FF) | ~48.3 kHz |

### AFLOW IRQ

The AFLOW interrupt (bit 2 of VERA_IEN) fires when the FIFO is less than 25% full, signaling it's time to feed more samples.

### Practical: Start PCM Playback

```asm
; Reset FIFO, set 8-bit mono, volume 15
lda #$8F        ; reset=1, 8-bit, mono, vol=15
sta $9F3B
lda #$0F        ; clear reset, keep settings
sta $9F3B

; Set sample rate (~24.4 kHz)
lda #$80
sta $9F3C

; Fill FIFO with initial samples
ldx #0
@fill:
lda sample_data,x
sta $9F3D
inx
bne @fill       ; write 256 bytes

; Enable AFLOW interrupt to keep feeding
lda $9F26
ora #$04
sta $9F26
```

## Practical Recipes

### Initialize a Tile Layer

```asm
; Set up Layer 0: 64x32 tiles, 4bpp, 8x8 tiles
; Map at VRAM $00000, tiles at VRAM $10000

; Layer 0 config: map 64x32, 4bpp
lda #%00010010      ; map_h=0(32), map_w=1(64), T256C=0, bitmap=0, depth=2(4bpp)
sta $9F2D           ; L0_CONFIG

; Map base: $00000 / 512 = 0
lda #$00
sta $9F2E           ; L0_MAPBASE

; Tile base: $10000 / 2048 = 32, shift left 2: $80. Tile size 8x8 (bits 1:0 = 00)
lda #$80
sta $9F2F           ; L0_TILEBASE

; Enable Layer 0 in display composer
lda $9F29
ora #$10            ; bit 4 = L0 enable
sta $9F29

; Reset scroll
stz $9F30
stz $9F31
stz $9F32
stz $9F33
```

---

Cross-reference: See [Memory Map](memory-map.md) for register details, [Sound Programming](sound-programming.md) for audio details, [Game Development Guide](game-development-guide.md) for game-specific VERA usage.
