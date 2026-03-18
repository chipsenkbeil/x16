---
name: x16-hardware
description: >
  Quick reference for Commander X16 hardware: VERA registers, memory map,
  KERNAL entry points, sprite/tile formats, audio registers, and I/O addresses.
---

# Commander X16 Hardware Quick Reference

## Memory Map

| Address | Size | Description |
|---------|------|-------------|
| $0000 | 1 | RAM_BANK — selects $A000-$BFFF bank (0-255) |
| $0001 | 1 | ROM_BANK — selects $C000-$FFFF bank |
| $0002-$0021 | 32 | KERNAL virtual registers r0-r15 (16-bit LE) |
| $0022-$007F | 94 | User zero page (fastest access) |
| $0080-$00FF | 128 | KERNAL/BASIC zero page |
| $0100-$01FF | 256 | CPU stack (grows downward from $01FF) |
| $0200-$03FF | 512 | BASIC/KERNAL work area |
| $0400-$07FF | 1024 | User low RAM |
| $0801-$9EFF | ~38 KB | User program space (PRG load target) |
| $9F00-$9F0F | 16 | VIA1 — I2C, SNES controllers, NMI |
| $9F10-$9F1F | 16 | VIA2 — IEC serial, SD card (SPI) |
| $9F20-$9F3F | 32 | VERA — Video, sprites, audio |
| $9F40 | 1 | YM2151 register address |
| $9F41 | 1 | YM2151 register data (bit 7 = busy) |
| $A000-$BFFF | 8 KB | Banked RAM window (256 banks = 2 MB) |
| $C000-$FFFF | 16 KB | Banked ROM window |

## VERA Registers ($9F20-$9F3F)

| Address | Name | Bits | Description |
|---------|------|------|-------------|
| $9F20 | ADDR_L | [7:0] | VRAM address low byte |
| $9F21 | ADDR_M | [7:0] | VRAM address mid byte |
| $9F22 | ADDR_H | [3:0]=addr[19:16], [3]=DECR, [7:4]=stride | VRAM address high + auto-increment |
| $9F23 | DATA0 | [7:0] | Data port 0 (uses address 0) |
| $9F24 | DATA1 | [7:0] | Data port 1 (uses address 1) |
| $9F25 | CTRL | [0]=ADDRSEL, [2:1]=DCSEL, [7]=reset | Control register |
| $9F26 | IEN | [0]=VSYNC, [1]=LINE, [2]=SPRCOL, [3]=AFLOW | Interrupt enable |
| $9F27 | ISR | [0]=VSYNC, [1]=LINE, [2]=SPRCOL, [3]=AFLOW | Interrupt status (write 1 to ack) |
| $9F28 | IRQLINE_L | [7:0] | IRQ raster line (low 8 bits) |
| $9F29 | DC_VIDEO | [1:0]=output, [4]=L0en, [5]=L1en, [6]=SpEn | Display composer (DCSEL=0) |
| $9F2A | DC_HSCALE | [7:0] | Horizontal scale ($80=1x, $40=2x) |
| $9F2B | DC_VSCALE | [7:0] | Vertical scale ($80=1x, $40=2x) |
| $9F2C | DC_BORDER | [7:0] | Border color (palette index) |
| $9F2D | L0_CONFIG | [1:0]=depth, [2]=bitmap, [3]=T256C, [5:4]=mapW, [7:6]=mapH | Layer 0 config |
| $9F2E | L0_MAPBASE | [7:0] | Layer 0 map base (x 512 bytes) |
| $9F2F | L0_TILEBASE | [7:1]=base(x2048), [0]=tileH16 | Layer 0 tile base + height |
| $9F30-$9F33 | L0_HSCROLL/VSCROLL | 12-bit each | Layer 0 scroll position |
| $9F34-$9F3A | L1_* | same layout as L0 | Layer 1 config/map/tile/scroll |
| $9F3B | AUDIO_CTRL | [0]=PCMen, [3:1]=vol, [4]=16bit, [5]=stereo, [6]=reset, [7]=FIFO full | Audio control |
| $9F3C | AUDIO_RATE | [7:0] | PCM sample rate |
| $9F3D | AUDIO_DATA | [7:0] | PCM FIFO data |
| $9F3E | SPI_DATA | [7:0] | SPI data port |
| $9F3F | SPI_CTRL | [0]=select | SPI control |

## VERA Stride Values (ADDR_H bits [7:4])

| Value | Stride | Value | Stride |
|-------|--------|-------|--------|
| 0 | 0 | 8 | 128 |
| 1 | 1 | 9 | 256 |
| 2 | 2 | 10 | 512 |
| 3 | 4 | 11 | 40 |
| 4 | 8 | 12 | 80 |
| 5 | 16 | 13 | 160 |
| 6 | 32 | 14 | 320 |
| 7 | 64 | 15 | 640 |

## Display Composer Output Modes ($9F29 bits [1:0])

| Value | Mode |
|-------|------|
| 0 | Disabled |
| 1 | VGA |
| 2 | NTSC composite |
| 3 | RGB interlaced |

## Layer Config Color Depth (bits [1:0])

| Value | Depth | Colors |
|-------|-------|--------|
| 0 | 1 bpp | 2 |
| 1 | 2 bpp | 4 |
| 2 | 4 bpp | 16 |
| 3 | 8 bpp | 256 |

## Layer Config Map Size (bits [5:4] width, [7:6] height)

| Value | Tiles |
|-------|-------|
| 0 | 32 |
| 1 | 64 |
| 2 | 128 |
| 3 | 256 |

## Sprite Attribute Format (8 bytes at VRAM $1FC00 + sprite_id * 8)

| Offset | Bits | Field |
|--------|------|-------|
| 0 | [7:0] | Address [12:5] |
| 1 | [3:0]=addr[16:13], [7]=mode(0=4bpp,1=8bpp) | Address high + color mode |
| 2 | [7:0] | X position [7:0] |
| 3 | [1:0] | X position [9:8] |
| 4 | [7:0] | Y position [7:0] |
| 5 | [1:0] | Y position [9:8] |
| 6 | [3:0]=collision mask, [2]=hflip, [3]=vflip, [7:6]=Z-depth | Flags |
| 7 | [7:4]=palette offset, [5:4]=height, [7:6]=width | Size + palette |

Sprite Z-depth: 0=disabled, 1=behind both layers, 2=between layers, 3=in front

Sprite sizes (width/height each): 0=8, 1=16, 2=32, 3=64 pixels

## Tile Map Entry Format (2 bytes)

| Byte | Bits | Field |
|------|------|-------|
| 0 | [7:0] | Tile index [7:0] |
| 1 | [1:0]=tile[9:8], [2]=hflip, [3]=vflip, [7:4]=palette offset | Index high + flags |

## PSG Voice Format (4 bytes at VRAM $1F9C0 + voice * 4)

| Offset | Field |
|--------|-------|
| 0 | Frequency low byte |
| 1 | Frequency high byte |
| 2 | [5:0]=volume, [7:6]=LR (0=mute,1=L,2=R,3=both) |
| 3 | [5:0]=pulse width, [7:6]=waveform (0=pulse,1=saw,2=tri,3=noise) |

Frequency formula: freq_hz = 48828.125 * reg_value / 131072

## YM2151 FM Synthesis ($9F40/$9F41)

- Write register address to $9F40, then data to $9F41
- **MUST check busy flag**: read $9F41 bit 7, wait until 0 before writing
- 8 channels (0-7), 4 operators per channel (M1, C1, M2, C2)
- Key registers: $08=key on/off, $20-$27=connect/feedback, $28-$2F=KC (note), $30-$37=KF (fine)

## KERNAL Jump Table

| Address | Name | Description |
|---------|------|-------------|
| $FF68 | MEMORY_FILL | Fill memory with byte |
| $FF6B | MEMORY_COPY | Copy memory (cross-bank) |
| $FF6E | MEMORY_CRC | Compute CRC of region |
| $FF71 | MEMORY_DECOMPRESS | LZSA2 decompression |
| $FF5F | screen_mode | Get/set screen mode |
| $FFB7 | READST | Read I/O status byte |
| $FFBA | SETLFS | Set logical/device/secondary |
| $FFBD | SETNAM | Set filename pointer + length |
| $FFC0 | OPEN | Open logical file |
| $FFC3 | CLOSE | Close logical file |
| $FFCF | CHRIN | Input char from channel |
| $FFD2 | CHROUT | Output char to channel |
| $FFD5 | LOAD | Load file to memory |
| $FFD8 | SAVE | Save memory to file |
| $FFE4 | GETIN | Get char from keyboard buffer |
| $FE00 | FETCH | Read byte from any bank |
| $FE03 | STASH | Write byte to any RAM bank |

## Default VRAM Layout

| VRAM Address | Size | Content |
|-------------|------|---------|
| $00000 | varies | Layer 0 tile map |
| $04000 | varies | Layer 1 tile map |
| $0F800 | 2 KB | Default character set |
| $1F000 | varies | Internal use |
| $1F9C0 | 64 | PSG registers (16 voices x 4) |
| $1FA00 | 512 | Palette (256 x 2 bytes) |
| $1FC00 | 1024 | Sprite attributes (128 x 8 bytes) |

## Palette Entry Format (2 bytes, little-endian at VRAM $1FA00)

| Byte | Bits | Field |
|------|------|-------|
| 0 | [3:0]=green, [7:4]=blue | GB nibbles |
| 1 | [3:0]=red | R nibble |

12-bit color: 4 bits each for R, G, B (0-15 per channel).

## Common PETSCII Codes

| Code | Character |
|------|-----------|
| $0D | Carriage return |
| $12 | Reverse on |
| $92 | Reverse off |
| $93 | Clear screen |
| $91 | Cursor up |
| $11 | Cursor down |
| $9D | Cursor left |
| $1D | Cursor right |
| $13 | Home |
| $01-$1A | Colors (various) |
