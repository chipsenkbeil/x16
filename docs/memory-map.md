# Memory Map

Comprehensive memory map reference for the Commander X16 computer. All addresses are in hexadecimal unless otherwise noted.

---

## Table of Contents

- [Address Space Overview](#address-space-overview)
- [Zero Page ($0000-$00FF)](#zero-page-0000-00ff)
- [CPU Stack ($0100-$01FF)](#cpu-stack-0100-01ff)
- [KERNAL/BASIC Work Area ($0200-$07FF)](#kernalbasic-work-area-0200-07ff)
- [User Program Space ($0800-$9EFF)](#user-program-space-0800-9eff)
- [I/O Registers ($9F00-$9FFF)](#io-registers-9f00-9fff)
  - [VIA1 Registers ($9F00-$9F0F)](#via1-registers-9f00-9f0f)
  - [VIA2 Registers ($9F10-$9F1F)](#via2-registers-9f10-9f1f)
  - [VERA Registers ($9F20-$9F3F)](#vera-registers-9f20-9f3f)
  - [YM2151 Registers ($9F40-$9F41)](#ym2151-registers-9f40-9f41)
  - [Emulator-Only Registers ($9FA0-$9FBF)](#emulator-only-registers-9fa0-9fbf)
- [Banked RAM ($A000-$BFFF)](#banked-ram-a000-bfff)
- [Banked ROM ($C000-$FFFF)](#banked-rom-c000-ffff)
- [VRAM Layout (VERA's 128 KB)](#vram-layout-veras-128-kb)

---

## Address Space Overview

The Commander X16 uses the 65C02 CPU with a 64 KB address space. Banked memory extends this significantly: up to 2 MB of RAM and 4 MB of ROM are accessible through bank-switching windows.

| Range | Size | Description |
|---|---|---|
| `$0000`-`$0001` | 2 | RAM/ROM bank select registers |
| `$0002`-`$0021` | 32 | KERNAL virtual registers r0-r15 (16-bit each) |
| `$0022`-`$007F` | 94 | User zero page |
| `$0080`-`$00FF` | 128 | KERNAL zero page |
| `$0100`-`$01FF` | 256 | CPU stack |
| `$0200`-`$03FF` | 512 | KERNAL/BASIC work area |
| `$0400`-`$07FF` | 1024 | User low RAM |
| `$0800`-`$9EFF` | ~38 KB | User program space (programs load at `$0801`) |
| `$9F00`-`$9FFF` | 256 | I/O registers |
| `$A000`-`$BFFF` | 8192 | Banked RAM window |
| `$C000`-`$FFFF` | 16384 | Banked ROM window |

---

## Zero Page ($0000-$00FF)

The zero page is the most performance-critical area of memory on the 65C02. Zero-page addressing modes use only a single-byte operand, making instructions shorter and faster. The X16 divides this space between bank registers, KERNAL virtual registers, user space, and KERNAL/BASIC workspace.

### Detailed Breakdown

| Address | Name | Description |
|---|---|---|
| `$00` | RAM_BANK | Current RAM bank (0-255). Writing here selects which 8 KB bank is visible at `$A000`-`$BFFF`. |
| `$01` | ROM_BANK | Current ROM bank (0-255). Writing here selects which 16 KB bank is visible at `$C000`-`$FFFF`. |
| `$02`-`$03` | r0 / r0L, r0H | Virtual register 0 |
| `$04`-`$05` | r1 / r1L, r1H | Virtual register 1 |
| `$06`-`$07` | r2 / r2L, r2H | Virtual register 2 |
| `$08`-`$09` | r3 / r3L, r3H | Virtual register 3 |
| `$0A`-`$0B` | r4 / r4L, r4H | Virtual register 4 |
| `$0C`-`$0D` | r5 / r5L, r5H | Virtual register 5 |
| `$0E`-`$0F` | r6 / r6L, r6H | Virtual register 6 |
| `$10`-`$11` | r7 / r7L, r7H | Virtual register 7 |
| `$12`-`$13` | r8 / r8L, r8H | Virtual register 8 |
| `$14`-`$15` | r9 / r9L, r9H | Virtual register 9 |
| `$16`-`$17` | r10 / r10L, r10H | Virtual register 10 |
| `$18`-`$19` | r11 / r11L, r11H | Virtual register 11 |
| `$1A`-`$1B` | r12 / r12L, r12H | Virtual register 12 |
| `$1C`-`$1D` | r13 / r13L, r13H | Virtual register 13 |
| `$1E`-`$1F` | r14 / r14L, r14H | Virtual register 14 |
| `$20`-`$21` | r15 / r15L, r15H | Virtual register 15 |
| `$22`-`$7F` | -- | Free for user programs (94 bytes) |
| `$80`-`$FF` | -- | Reserved for KERNAL/BASIC |

### Notes on Virtual Registers

- r0-r15 are used as parameters and return values for many KERNAL API calls. They are 16-bit, stored little-endian (low byte first, high byte second).
- The KERNAL may clobber any or all of r0-r15 during API calls. Save any values you need before calling KERNAL routines.
- The `L` and `H` suffixes refer to the low byte and high byte respectively. For example, `r0L` is at `$02` and `r0H` is at `$03`.
- These registers are modeled after the GEOS calling convention and provide a structured way to pass multi-byte parameters without relying solely on A/X/Y.

---

## CPU Stack ($0100-$01FF)

- Hardware stack, grows downward from `$01FF`.
- Used for JSR/RTS return addresses, PHA/PLA, interrupts (IRQ/NMI push P and PC).
- Stack pointer initialized to `$FF` by KERNAL on boot.
- Limited to 256 bytes -- deep recursion or heavy nesting should be avoided.
- Each JSR consumes 2 bytes (return address), each interrupt consumes 3 bytes (return address + status register).
- Typical safe nesting depth is roughly 40-50 levels of JSR before risk of overflow, less if interrupts are active and also using the stack.

---

## KERNAL/BASIC Work Area ($0200-$07FF)

| Range | Size | Description |
|---|---|---|
| `$0200`-`$02FF` | 256 | BASIC input buffer |
| `$0300`-`$033B` | 60 | KERNAL I/O: open file table, device numbers, secondary addresses, etc. |
| `$033C`-`$03FF` | 196 | System variables (cassette buffer area on C64, repurposed on X16) |
| `$0400`-`$07FF` | 1024 | Available for user programs (but below standard load address) |

### Notes

- The `$0400`-`$07FF` region is technically free but sits below the conventional load address. It is a good place to store small lookup tables, variables, or buffers that should not interfere with BASIC programs.
- BASIC programs and the BASIC interpreter use `$0200`-`$03FF` extensively. If you are writing pure assembly with no BASIC, much of this area can be reclaimed -- but be aware that KERNAL routines may still reference portions of it.

---

## User Program Space ($0800-$9EFF)

- Programs load at `$0801` (standard `.PRG` load address).
- The first two bytes of a `.PRG` file are the load address in little-endian format (`$01`, `$08` for the standard address).
- A BASIC stub is typically placed at `$0801`-`$080C` containing a `SYS` command to jump to the machine code entry point. Machine code then starts at `$080D` or wherever the stub directs.
- Top of available low RAM is `$9EFF` (just below the I/O area at `$9F00`).
- Total usable contiguous RAM: approximately 38 KB (`$0801` to `$9EFF`).

### BASIC Stub Format

A typical BASIC stub for auto-starting machine code:

```
$0801: $0C $08    ; Pointer to next BASIC line ($080C)
$0803: $0A $00    ; Line number 10
$0805: $9E        ; SYS token
$0806: $32 $30 $36 $31  ; "2061" (ASCII, = $080D)
$080A: $00        ; End of BASIC line
$080B: $00 $00    ; End of BASIC program (null pointer)
$080D: ...        ; Machine code starts here
```

---

## I/O Registers ($9F00-$9FFF)

All hardware peripherals are memory-mapped into a single 256-byte I/O page. This region is never banked.

### Overview Table

| Range | Device | Description |
|---|---|---|
| `$9F00`-`$9F0F` | VIA1 (65C22) | I2C bus, SNES controllers, NMI |
| `$9F10`-`$9F1F` | VIA2 (65C22) | IEC serial bus, SD card SPI, user port |
| `$9F20`-`$9F3F` | VERA | Video, sprites, palette, PSG audio, PCM audio |
| `$9F40`-`$9F41` | YM2151 | FM synthesis chip |
| `$9F42`-`$9F7F` | -- | Reserved |
| `$9F80`-`$9F9F` | -- | Expansion I/O (shared) |
| `$9FA0`-`$9FBF` | -- | Emulator registers (emulator only, no-op on hardware) |
| `$9FC0`-`$9FFF` | -- | Expansion I/O (slot-select) |

---

### VIA1 Registers ($9F00-$9F0F)

VIA1 is a WDC 65C22 Versatile Interface Adapter. It handles the I2C bus (for real-time clock, etc.), SNES controller input, and generates the NMI signal.

| Address | Name | Description |
|---|---|---|
| `$9F00` | VIA1_PRB | Port B data: I2C SDA/SCL output bits |
| `$9F01` | VIA1_PRA | Port A data: I2C SDA input, SNES controller data/clock/latch |
| `$9F02` | VIA1_DDRB | Port B data direction register (1 = output, 0 = input) |
| `$9F03` | VIA1_DDRA | Port A data direction register |
| `$9F04` | VIA1_T1CL | Timer 1 counter low byte (read: counter, write: latch) |
| `$9F05` | VIA1_T1CH | Timer 1 counter high byte (write starts timer) |
| `$9F06` | VIA1_T1LL | Timer 1 latch low byte |
| `$9F07` | VIA1_T1LH | Timer 1 latch high byte |
| `$9F08` | VIA1_T2CL | Timer 2 counter low byte |
| `$9F09` | VIA1_T2CH | Timer 2 counter high byte |
| `$9F0A` | VIA1_SR | Shift register |
| `$9F0B` | VIA1_ACR | Auxiliary control register (timer modes, shift register mode, latching) |
| `$9F0C` | VIA1_PCR | Peripheral control register (CA1/CA2/CB1/CB2 control) |
| `$9F0D` | VIA1_IFR | Interrupt flag register (read: pending IRQs, write: clear flags) |
| `$9F0E` | VIA1_IER | Interrupt enable register (bit 7: 1=set, 0=clear selected bits) |
| `$9F0F` | VIA1_PRA_NH | Port A data, no handshake (read/write without affecting CA1/CA2) |

#### VIA1 Port B Bit Assignments ($9F00)

| Bit | Signal | Description |
|---|---|---|
| 0 | I2C_SDA_OUT | I2C data line output |
| 1 | I2C_SCL | I2C clock line |
| 2-7 | -- | Reserved / accent LED on some revisions |

#### VIA1 Port A Bit Assignments ($9F01)

| Bit | Signal | Description |
|---|---|---|
| 0 | SNES_DATA1 | SNES controller 1 serial data |
| 1 | SNES_DATA2 | SNES controller 2 serial data |
| 2 | SNES_DATA3 | SNES controller 3 serial data (accent) |
| 3 | SNES_DATA4 | SNES controller 4 serial data (accent) |
| 4 | SNES_LATCH | SNES controller latch (active high) |
| 5 | SNES_CLK | SNES controller clock |
| 6 | I2C_SDA_IN | I2C data line input |
| 7 | -- | Accent LED / reserved |

---

### VIA2 Registers ($9F10-$9F1F)

VIA2 is a second WDC 65C22. It handles the IEC serial bus (for disk drives and printers), SD card SPI interface, and user port signals.

| Address | Name | Description |
|---|---|---|
| `$9F10` | VIA2_PRB | Port B data: IEC serial bus signals (ATN, CLK, DATA) |
| `$9F11` | VIA2_PRA | Port A data: SD card SPI, user port |
| `$9F12` | VIA2_DDRB | Port B data direction register |
| `$9F13` | VIA2_DDRA | Port A data direction register |
| `$9F14` | VIA2_T1CL | Timer 1 counter low byte |
| `$9F15` | VIA2_T1CH | Timer 1 counter high byte |
| `$9F16` | VIA2_T1LL | Timer 1 latch low byte |
| `$9F17` | VIA2_T1LH | Timer 1 latch high byte |
| `$9F18` | VIA2_T2CL | Timer 2 counter low byte |
| `$9F19` | VIA2_T2CH | Timer 2 counter high byte |
| `$9F1A` | VIA2_SR | Shift register |
| `$9F1B` | VIA2_ACR | Auxiliary control register |
| `$9F1C` | VIA2_PCR | Peripheral control register |
| `$9F1D` | VIA2_IFR | Interrupt flag register |
| `$9F1E` | VIA2_IER | Interrupt enable register |
| `$9F1F` | VIA2_PRA_NH | Port A data, no handshake |

#### VIA2 Port B Bit Assignments ($9F10)

| Bit | Signal | Description |
|---|---|---|
| 0 | IEC_DATA_OUT | IEC serial data line output |
| 1 | IEC_CLK_OUT | IEC serial clock line output |
| 2 | IEC_ATN | IEC attention signal (active low) |
| 3 | -- | Reserved |
| 4 | IEC_CLK_IN | IEC serial clock line input |
| 5 | IEC_DATA_IN | IEC serial data line input |
| 6-7 | -- | Reserved |

---

### VERA Registers ($9F20-$9F3F)

VERA (Video Embedded Retro Adapter) is a custom FPGA-based video and audio chip. It contains its own 128 KB of VRAM, a palette, sprite engine, two tile/bitmap layers, a 16-voice PSG, and a PCM audio channel. CPU access to VRAM is through the address/data port mechanism described below.

See also: [VRAM Layout (VERA's 128 KB)](#vram-layout-veras-128-kb)

#### Address and Data Ports

| Address | Name | Bits | Description |
|---|---|---|---|
| `$9F20` | VERA_ADDR_L | `[7:0]` | VRAM address bits 0-7 |
| `$9F21` | VERA_ADDR_M | `[7:0]` | VRAM address bits 8-15 |
| `$9F22` | VERA_ADDR_H | `[7:4]`=increment step, `[3]`=DECR, `[2:0]`=addr`[18:16]` | High address + auto-increment config |
| `$9F23` | VERA_DATA0 | `[7:0]` | Data port 0 (reads/writes VRAM at address pointer 0) |
| `$9F24` | VERA_DATA1 | `[7:0]` | Data port 1 (reads/writes VRAM at address pointer 1) |

**Auto-increment:** After each read or write to DATA0 or DATA1, the corresponding address pointer is adjusted by the increment step. The step value (bits `[7:4]` of ADDR_H) encodes as:

| Value | Increment |
|---|---|
| 0 | 0 (no increment) |
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

When the DECR bit (bit 3) is set, the increment is subtracted instead of added.

#### Control and Interrupt Registers

| Address | Name | Bits | Description |
|---|---|---|---|
| `$9F25` | VERA_CTRL | `[7]`=reset, `[2]`=DCSEL, `[1]`=ADDRSEL, `[0]`=? | Control register |
| `$9F26` | VERA_IEN | `[7:4]`=line`[8]`, `[3]`=SPRCOL, `[2]`=AFLOW, `[1]`=LINE, `[0]`=VSYNC | Interrupt enable |
| `$9F27` | VERA_ISR | `[7:4]`=sprite_collisions, `[3]`=SPRCOL, `[2]`=AFLOW, `[1]`=LINE, `[0]`=VSYNC | Interrupt status (write 1 to clear) |
| `$9F28` | VERA_IRQLINE_L | `[7:0]` | IRQ raster line compare (low 8 bits; bit 8 in IEN`[7]`) |

**ADDRSEL (bit 1 of VERA_CTRL):** Selects which address pointer is affected by writes to `$9F20`-`$9F22`. When 0, registers configure address pointer 0 (used by DATA0). When 1, they configure address pointer 1 (used by DATA1).

**DCSEL (bit 2 of VERA_CTRL):** Selects which set of registers appears at `$9F29`-`$9F2C`. See below for the two register sets.

#### Display Composer Registers (DCSEL = 0)

When VERA_CTRL bit 2 (DCSEL) = 0, registers `$9F29`-`$9F2C` map to:

| Address | Name | Bits | Description |
|---|---|---|---|
| `$9F29` | VERA_DC_VIDEO | `[7]`=current_field, `[6]`=sprites_en, `[5]`=L1_en, `[4]`=L0_en, `[3:2]`=chroma_disable, `[1:0]`=output_mode | Display composer: video output config |
| `$9F2A` | VERA_DC_HSCALE | `[7:0]` | Horizontal scale (128 = 1x, 64 = 2x) |
| `$9F2B` | VERA_DC_VSCALE | `[7:0]` | Vertical scale (128 = 1x, 64 = 2x) |
| `$9F2C` | VERA_DC_BORDER | `[7:0]` | Border color (palette index) |

**Output mode** (`[1:0]` of DC_VIDEO):

| Value | Mode |
|---|---|
| 0 | Disabled (no output) |
| 1 | VGA |
| 2 | NTSC composite/S-Video |
| 3 | RGB interlaced (accent) |

**Scaling:** The scale values use a fixed-point representation where 128 = 1:1 mapping. A value of 64 doubles the pixels (2x zoom), 32 gives 4x zoom, etc. Values above 128 shrink the display.

#### Display Composer Registers (DCSEL = 1)

When VERA_CTRL bit 2 (DCSEL) = 1, registers `$9F29`-`$9F2C` map to:

| Address | Name | Bits | Description |
|---|---|---|---|
| `$9F29` | VERA_DC_HSTART | `[7:0]` | Active display horizontal start (in pixels / 4) |
| `$9F2A` | VERA_DC_HSTOP | `[7:0]` | Active display horizontal stop (in pixels / 4) |
| `$9F2B` | VERA_DC_VSTART | `[7:0]` | Active display vertical start (in pixels / 2) |
| `$9F2C` | VERA_DC_VSTOP | `[7:0]` | Active display vertical stop (in pixels / 2) |

These registers control the visible area of the display, allowing you to reduce the active region (useful for overscan-safe areas in NTSC/PAL output).

#### VERA FX Registers (DCSEL = 2-6)

VERA FX is a set of hardware-accelerated operations accessible through DCSEL values 2 through 6. These provide features such as:

- **DCSEL 2:** FX control, transparency/cache/polygon fill configuration
- **DCSEL 3:** FX tile base, map base configuration
- **DCSEL 4:** FX X/Y position increment values
- **DCSEL 5:** FX X/Y position values
- **DCSEL 6:** FX accumulator, accum reset, blend mode

VERA FX enables hardware-assisted operations including fast cache-based VRAM writes (writing 4 bytes at once from a cache), one-cycle 32-bit affine transformation helpers, and line draw/polygon fill acceleration.

#### Layer 0 Registers

| Address | Name | Bits | Description |
|---|---|---|---|
| `$9F2D` | VERA_L0_CONFIG | `[7:6]`=map_height, `[5:4]`=map_width, `[3]`=T256C, `[2]`=bitmap_mode, `[1:0]`=color_depth | Layer 0 configuration |
| `$9F2E` | VERA_L0_MAPBASE | `[7:0]` | Layer 0 map base address (VRAM addr`[16:9]`) |
| `$9F2F` | VERA_L0_TILEBASE | `[7:2]`=addr`[16:11]`, `[1]`=tile_width(0=8,1=16), `[0]`=tile_height(0=8,1=16) | Layer 0 tile base + tile size |
| `$9F30` | VERA_L0_HSCROLL_L | `[7:0]` | Layer 0 horizontal scroll (low byte) |
| `$9F31` | VERA_L0_HSCROLL_H | `[3:0]` | Layer 0 horizontal scroll (high nibble, bits 11-8) |
| `$9F32` | VERA_L0_VSCROLL_L | `[7:0]` | Layer 0 vertical scroll (low byte) |
| `$9F33` | VERA_L0_VSCROLL_H | `[3:0]` | Layer 0 vertical scroll (high nibble, bits 11-8) |

**Color depth** (`[1:0]` of L0_CONFIG):

| Value | Depth | Colors |
|---|---|---|
| 0 | 1 bpp | 2 |
| 1 | 2 bpp | 4 |
| 2 | 4 bpp | 16 |
| 3 | 8 bpp | 256 |

**Map dimensions** (`[7:6]` for height, `[5:4]` for width):

| Value | Tiles |
|---|---|
| 0 | 32 |
| 1 | 64 |
| 2 | 128 |
| 3 | 256 |

**T256C (bit 3):** In 1-bpp text mode, setting this bit enables 256-color foreground mode, where the attribute byte selects from all 256 palette entries for the foreground color instead of the usual 16.

**Bitmap mode (bit 2):** When set, the layer operates in bitmap mode rather than tile/map mode. In bitmap mode, TILEBASE points to the start of pixel data and there is no tile map.

#### Layer 1 Registers

| Address | Name | Bits | Description |
|---|---|---|---|
| `$9F34` | VERA_L1_CONFIG | (same layout as L0_CONFIG) | Layer 1 configuration |
| `$9F35` | VERA_L1_MAPBASE | (same layout as L0_MAPBASE) | Layer 1 map base address |
| `$9F36` | VERA_L1_TILEBASE | (same layout as L0_TILEBASE) | Layer 1 tile base + tile size |
| `$9F37` | VERA_L1_HSCROLL_L | `[7:0]` | Layer 1 horizontal scroll (low byte) |
| `$9F38` | VERA_L1_HSCROLL_H | `[3:0]` | Layer 1 horizontal scroll (high nibble) |
| `$9F39` | VERA_L1_VSCROLL_L | `[7:0]` | Layer 1 vertical scroll (low byte) |
| `$9F3A` | VERA_L1_VSCROLL_H | `[3:0]` | Layer 1 vertical scroll (high nibble) |

Layer 1 is configured identically to Layer 0. By default, Layer 1 is the text screen (80x60 characters). Layer 0 is behind Layer 1 in the render order: the final composited output is (back to front) background color, Layer 0, Layer 1, sprites.

#### Audio Registers

| Address | Name | Bits | Description |
|---|---|---|---|
| `$9F3B` | VERA_AUDIO_CTRL | `[7]`=FIFO_reset, `[5]`=16-bit, `[4]`=stereo, `[3:0]`=PCM_volume | Audio/PCM control |
| `$9F3C` | VERA_AUDIO_RATE | `[7:0]` | PCM playback sample rate |
| `$9F3D` | VERA_AUDIO_DATA | `[7:0]` | PCM data FIFO (write samples here) |

**PCM sample rate:** The effective sample rate is `VERA_AUDIO_RATE / 128 * 25 MHz / 512`. A rate value of 128 gives approximately 48,828 Hz. A value of 0 stops playback.

**PCM FIFO:** The FIFO is 4 KB deep. When it falls below a threshold, VERA asserts the AFLOW interrupt (bit 2 of ISR). This allows interrupt-driven audio streaming.

**PSG (Programmable Sound Generator):** The 16-voice PSG is not directly accessible through I/O registers. Instead, PSG voice parameters are written to VRAM addresses `$1F9C0`-`$1F9FF` (see [VRAM Layout](#vram-layout-veras-128-kb)). Each voice occupies 4 bytes.

#### SPI Registers

| Address | Name | Bits | Description |
|---|---|---|---|
| `$9F3E` | VERA_SPI_DATA | `[7:0]` | SPI data (directly exposed from VERA to SD card) |
| `$9F3F` | VERA_SPI_CTRL | `[1]`=slow_clock, `[0]`=chip_select | SPI control |

These registers provide raw SPI access through VERA, primarily used for SD card communication by the KERNAL's CMDR-DOS.

---

### YM2151 Registers ($9F40-$9F41)

The Yamaha YM2151 (OPM) is a 4-operator FM synthesis chip providing 8 voices of FM audio. It is accessed through a simple 2-register interface.

| Address | Name | Description |
|---|---|---|
| `$9F40` | YM_ADDR | Register address (write only). Write the internal register number here. |
| `$9F41` | YM_DATA | Register data (write: set selected register, read: status byte) |

#### Write Protocol

1. Write the target register number (0-255) to `$9F40`.
2. Read `$9F41` and check bit 7 (busy flag). Wait until it is 0.
3. Write the data value to `$9F41`.
4. Wait for the busy flag to clear again before the next write.

```asm
; Example: write value $3F to YM2151 register $20 (channel 0 RL/FB/CON)
lda #$20
sta $9F40        ; select register $20
@wait1:
lda $9F41        ; read status
bmi @wait1       ; loop if bit 7 (busy) is set
lda #$3F
sta $9F41        ; write data
```

#### Key YM2151 Internal Registers

| Register | Description |
|---|---|
| `$01` | LFO reset / test |
| `$08` | Key on/off (bits `[6:3]`=operators, `[2:0]`=channel) |
| `$0F` | Noise enable and frequency |
| `$10`-`$17` | Timer A (high 8 bits per channel) |
| `$18` | Timer B |
| `$19` | Timer control |
| `$1B` | CT/waveform select |
| `$20`-`$27` | RL/feedback/connection per channel |
| `$28`-`$2F` | Key code per channel |
| `$30`-`$37` | Key fraction per channel |
| `$38`-`$3F` | PMS/AMS per channel |
| `$40`-`$5F` | DT1/MUL per operator |
| `$60`-`$7F` | TL (total level / volume) per operator |
| `$80`-`$9F` | KS/AR (key scale / attack rate) per operator |
| `$A0`-`$BF` | AMS-EN/D1R per operator |
| `$C0`-`$DF` | DT2/D2R per operator |
| `$E0`-`$FF` | D1L/RR per operator |

---

### Emulator-Only Registers ($9FA0-$9FBF)

These registers exist only in the official X16 emulator. On real hardware, reads return open bus values and writes have no effect.

| Address | Name | Description |
|---|---|---|
| `$9FB0` | EMU_DEBUG | Write a byte to output a character to the host console (debug logging) |
| `$9FB1` | EMU_VERBOSITY | Set emulator log verbosity level |
| `$9FB2` | EMU_DETECT | Reads `$45` (ASCII 'E') if running in the emulator; open bus on hardware |
| `$9FB3` | EMU_KEYMAP | Keyboard layout selector |
| `$9FB4`-`$9FBF` | -- | Reserved for emulator use |

#### Emulator Detection

```asm
; Check if running in emulator
lda $9FB2
cmp #$45         ; 'E'
beq @in_emulator
; running on real hardware
@in_emulator:
; running in emulator
```

---

## Banked RAM ($A000-$BFFF)

The `$A000`-`$BFFF` region is an 8 KB window into banked RAM. The active bank is selected by writing a bank number (0-255) to `$00` (RAM_BANK).

- **Standard configuration:** 512 KB total -- 64 banks (banks 0-63).
- **Maximum configuration:** 2 MB total -- 256 banks (banks 0-255). Actual bank count depends on the installed RAM.
- **Bank 0** is used by the KERNAL as a work area. It is available after initial boot/setup, but writing to it carelessly can corrupt KERNAL state.
- **Banks 1-63** (or higher, depending on RAM) are fully available to user programs.

### Bank Usage Conventions

| Bank | Typical Usage |
|---|---|
| 0 | KERNAL work area (use with care) |
| 1-63 | Free for user programs |
| 64-255 | Free if additional RAM is installed |

### Code Examples

```asm
; Switch to RAM bank 5 and read a byte
lda #5
sta $00          ; RAM_BANK
lda $A000        ; read first byte of bank 5

; Copy 256 bytes from bank 3 to bank 7
lda #3
sta $00          ; source bank
ldx #0
@copy_loop:
lda $A000,x      ; read from bank 3
pha
lda #7
sta $00          ; switch to destination bank
pla
sta $A000,x      ; write to bank 7
lda #3
sta $00          ; switch back to source bank
inx
bne @copy_loop
```

### Common Uses

- **Data storage:** Level maps, dialogue text, lookup tables.
- **Music/SFX data:** Streaming audio data to VERA PCM or composing YM2151 sequences.
- **Sprite sheets:** Staging sprite or tile data before copying to VRAM via VERA data ports.
- **Double buffering:** Using two banks as alternating frame buffers for smooth animation updates.
- **Heap/dynamic allocation:** Programs can implement their own allocator across banked RAM for large data sets.

---

## Banked ROM ($C000-$FFFF)

The `$C000`-`$FFFF` region is a 16 KB window into banked ROM. The active bank is selected by writing to `$01` (ROM_BANK).

### ROM Bank Table

| Bank | Contents |
|---|---|
| 0 | KERNAL |
| 1 | Keyboard tables |
| 2 | CMDR-DOS (FAT32 filesystem driver) |
| 3 | GEOS KERNAL |
| 4 | BASIC (part 1) |
| 5 | BASIC (part 2) |
| 6 | Machine Language Monitor |
| 7 | X16 Edit (screen editor, part 1) |
| 8 | (Reserved) |
| 9 | (Reserved) |
| 10 (`$0A`) | Audio API (FMCHORD, FMINIT, etc.) |
| 11 (`$0B`) | X16 Edit (screen editor, part 2) |
| 12-31 | (Reserved / future use) |
| 32-255 | Cartridge ROM (active via expansion slot) |

### Cartridge Boot Protocol

1. On boot, the KERNAL checks bank 32 for a cartridge signature.
2. The signature consists of the bytes `CX16` at address `$C000` in bank 32.
3. If the signature is found, execution jumps to the cartridge entry point at `$C004` in bank 32.
4. The cartridge has full access to ROM banks 32-255 for code and data.

### Important Notes

- **Interrupt vectors:** The CPU vectors at `$FFFA`-`$FFFF` (NMI, RESET, IRQ) are always read from ROM bank 0 (KERNAL), regardless of the current ROM_BANK setting. This is a hardware feature ensuring the KERNAL always handles interrupts.
- **KERNAL bank switching:** KERNAL routines may internally switch ROM banks. If you are calling KERNAL from code running in a ROM bank other than 0, always save and restore ROM_BANK around the call.
- **Jump table:** The KERNAL jump table at `$FF00`-`$FFF9` contains `JMP` instructions that handle bank switching automatically. Always call KERNAL routines through the jump table, not at their internal addresses.

```asm
; Safe KERNAL call from arbitrary ROM bank context
lda $01          ; save current ROM_BANK
pha
stz $01          ; switch to bank 0 (KERNAL)
jsr $FFD2        ; CHROUT - output character in A
pla
sta $01          ; restore original ROM bank
```

Note: For most KERNAL calls made through the jump table, the bank switching is handled automatically and explicit save/restore is not necessary. It becomes necessary only when accessing KERNAL data or non-jump-table entry points directly.

---

## VRAM Layout (VERA's 128 KB)

VERA has its own 128 KB address space (`$00000`-`$1FFFF`), completely separate from the CPU's 64 KB address space. The CPU accesses VRAM exclusively through the VERA data port registers (`$9F23` / `$9F24`). See [VERA Registers](#vera-registers-9f20-9f3f) for details on setting up the address pointers.

### Default VRAM Layout (after boot)

After KERNAL initialization, VRAM is laid out as follows:

| VRAM Address | Size | Contents |
|---|---|---|
| `$00000`-`$0F7FF` | ~62 KB | Available (tile data, sprite data, bitmaps, user data) |
| `$0F800`-`$0FFFF` | 2 KB | Default character set (Layer 1 tile data, PETSCII font) |
| `$1B000`-`$1B7FF` | 2 KB | Default Layer 1 map data (80x60 text screen) |
| `$1F9C0`-`$1F9FF` | 64 B | Sprite attributes (128 sprites x 8 bytes) |
| `$1FA00`-`$1FBFF` | 512 B | Palette (256 entries x 2 bytes each) |
| `$1FC00`-`$1FFFF` | 1 KB | PSG registers (16 voices x 4 bytes) + reserved |

Note: The map base and tile base addresses are configurable through the layer registers. The above reflects the default KERNAL setup.

### Sprite Attributes ($1FC00 region)

Each of the 128 sprites has an 8-byte attribute entry:

| Offset | Bits | Description |
|---|---|---|
| 0 | `[7:0]` | Address bits `[12:5]` of sprite data |
| 1 | `[7]`=mode (0=4bpp, 1=8bpp), `[3:0]`=address bits `[16:13]` | Address high + color mode |
| 2 | `[7:0]` | X position (low byte) |
| 3 | `[1:0]` | X position (high bits, 10-bit total) |
| 4 | `[7:0]` | Y position (low byte) |
| 5 | `[1:0]` | Y position (high bits, 10-bit total) |
| 6 | `[7:4]`=collision_mask, `[3:2]`=z_depth, `[1]`=vflip, `[0]`=hflip | Collision, depth, and flipping |
| 7 | `[7:4]`=sprite_height, `[3:0]`=sprite_width | Size + palette offset |

**Z-depth values** (bits `[3:2]` of offset 6):

| Value | Depth |
|---|---|
| 0 | Disabled (not rendered) |
| 1 | Between background and Layer 0 |
| 2 | Between Layer 0 and Layer 1 |
| 3 | In front of Layer 1 |

**Sprite sizes** (width and height fields):

| Value | Pixels |
|---|---|
| 0 | 8 |
| 1 | 16 |
| 2 | 32 |
| 3 | 64 |

### Palette ($1FA00-$1FBFF)

The palette contains 256 entries, each 2 bytes in VERA's 12-bit color format:

| Byte | Bits | Description |
|---|---|---|
| 0 | `[7:4]`=green, `[3:0]`=blue | Green and blue channels (4 bits each) |
| 1 | `[3:0]`=red | Red channel (4 bits) |

Each channel has 16 levels (0-15), giving 4096 possible colors. The default palette is initialized by the KERNAL to a selection of useful colors.

**Palette entry 0** is special: it is the global background/transparency color. Pixels with palette index 0 are transparent when compositing layers and sprites.

### PSG Registers ($1F9C0-$1F9FF)

Each of the 16 PSG voices is configured by writing 4 bytes to VRAM:

| Offset | Bits | Description |
|---|---|---|
| 0 | `[7:0]` | Frequency low byte |
| 1 | `[7:0]` | Frequency high byte |
| 2 | `[7:6]`=waveform, `[5:0]`=volume | Waveform select + volume (0-63) |
| 3 | `[7:6]`=pulse_width, `[1:0]`=LR | Pulse width (for pulse wave) + stereo output |

**Waveforms:**

| Value | Waveform |
|---|---|
| 0 | Pulse |
| 1 | Sawtooth |
| 2 | Triangle |
| 3 | Noise |

**Stereo output** (bits `[1:0]`):

| Value | Output |
|---|---|
| 0 | Mute |
| 1 | Left only |
| 2 | Right only |
| 3 | Both (stereo center) |

Voice N is at VRAM address `$1F9C0 + (N * 4)`, where N is 0-15.

### Practical Notes

- VRAM is only accessible through VERA's data port registers (`$9F23` for DATA0, `$9F24` for DATA1). There is no direct CPU mapping.
- Use the auto-increment feature to write sequential data efficiently. Set the desired increment in `$9F22` and simply write successive bytes to the data port.
- The two independent address pointers (DATA0 and DATA1) allow simultaneous read-from-one-address and write-to-another patterns, which is very useful for copying or transforming VRAM data.
- Plan your VRAM layout carefully to avoid overlap between layer map data, tile data, sprite data, and bitmap framebuffers. The 128 KB fills up quickly in graphically rich applications.
- When using bitmap mode, a 320x240 8-bpp framebuffer consumes 75 KB of VRAM, leaving only about 53 KB for other assets. Using 4-bpp or tiled modes is much more VRAM-efficient.
