# Architecture Overview

This document provides a comprehensive overview of the Commander X16 hardware architecture, covering the CPU, memory subsystem, video and audio hardware, I/O controllers, and peripheral interfaces.

## Table of Contents

- [System Block Diagram](#system-block-diagram)
- [65C02S CPU](#65c02s-cpu)
- [Memory Architecture](#memory-architecture)
- [VERA (Video Embedded Retro Adapter)](#vera-video-embedded-retro-adapter)
- [YM2151 FM Audio](#ym2151-fm-audio)
- [VIA I/O (65C22)](#via-io-65c22)
- [System Management Controller (SMC)](#system-management-controller-smc)
- [SD Card Storage](#sd-card-storage)
- [Expansion Slots](#expansion-slots)
- [Clock and RTC](#clock-and-rtc)
- [System Comparison](#system-comparison)

---

## System Block Diagram

```
                          +------------------+
                          |   SMC (ATtiny816)|
                          |  Power, PS/2 KB, |
                          |  Reset, NMI, LED |
                          +--------+---------+
                                   | I2C (addr $42)
                                   |
+----------+    System Bus    +----+----+    I2C     +-----------+
| 65C02S   |<===============>|  VIA1   |<---------->| RTC       |
| CPU      |    (addr/data/  | $9F00   |            | MCP7940N  |
| 8 MHz    |     control)    +---------+            | addr $6F  |
+----+-----+                 | SNES ctrl           +-----------+
     |                       | NMI source
     |
     +============== System Bus ==============+
     |              |              |           |
+----+----+   +----+----+   +----+----+  +----+----+
|  RAM    |   |  ROM    |   |  VERA   |  |  VIA2   |
| 512 KB  |   | 512 KB  |   |  $9F20  |  |  $9F10  |
| banked  |   | banked  |   +---------+  +---------+
| 256 x   |   | 32 ROM  |   | 128 KB  |  | IEC bus |
| 8 KB    |   | banks   |   |  VRAM   |  | SD card |
+---------+   +---------+   +----+----+  | (SPI)   |
                             |    |       | User    |
                        +----+  +-+--+    | port    |
                        |       |    |    +---------+
                   Video Out   PSG  PCM
                   (VGA/       16    stereo
                    composite)  voice FIFO
                                  |
                             Audio Out
                                  |
                            +-----+-----+
                            |  YM2151   |
                            | FM synth  |
                            | $9F40-41  |
                            | 8 voices  |
                            +-----------+

  +---------------------------------------------------+
  |              Expansion Slots (x4)                  |
  |  60-pin edge connectors on system bus              |
  |  I/O select: $9800-$9BFF (one range per slot)     |
  |  Shared IRQ line                                   |
  +---------------------------------------------------+
  |              Cartridge Slot                         |
  |  ROM banks 32-255 in banking window                |
  +---------------------------------------------------+
```

## 65C02S CPU

The Commander X16 uses the **WDC 65C02S** processor running at **8 MHz**.

**Key characteristics:**

- 8-bit data bus, 16-bit address bus (64 KB directly addressable)
- CMOS design with lower power consumption than the original NMOS 6502
- Extended instruction set over the NMOS 6502:
  - **STZ** — Store zero to memory
  - **BRA** — Branch always (unconditional relative branch)
  - **PHX/PLX** — Push/pull X register
  - **PHY/PLY** — Push/pull Y register
  - **TRB/TSB** — Test and reset/set bits
  - **INC A / DEC A** — Increment/decrement accumulator
  - New addressing modes: (ZP) indirect without indexing
- **WAI** — Wait for interrupt (halts CPU until IRQ/NMI, reduces power)
- **STP** — Stop the processor (requires reset to resume)
- Decimal mode works correctly (unlike the NMOS 6502, which has BCD bugs)
- All undefined opcodes are NOPs (not traps or undefined behavior)

## Memory Architecture

The X16 uses a **64 KB address space** extended through bank switching to access up to 2 MB of RAM and 512 KB of ROM.

```
$FFFF +------------------+
      |   Banked ROM     |  16 KB window
      |   (32 banks)     |  Bank register: $01
$C000 +------------------+
      |   Banked RAM     |  8 KB window
      |   (256 banks     |  Bank register: $00
      |    max, 64 std)  |
$A000 +------------------+
      |                  |
      |   Fixed RAM      |  ~38.75 KB usable
      |                  |
$9F00 +--I/O Registers---+  256 bytes
      |                  |
      |   Fixed RAM      |
      |   (continued)    |
$0002 +------------------+
      | $01: ROM bank    |
      | $00: RAM bank    |
$0000 +------------------+
```

**Address space breakdown:**

| Range | Size | Description |
|---|---|---|
| `$0000–$0001` | 2 bytes | Bank registers (RAM bank, ROM bank) |
| `$0002–$0021` | 32 bytes | 16-bit ABI registers (r0–r15) |
| `$0022–$007F` | 94 bytes | User zero page |
| `$0080–$00FF` | 128 bytes | KERNAL/BASIC zero page |
| `$0100–$01FF` | 256 bytes | CPU stack |
| `$0200–$03FF` | 512 bytes | KERNAL/BASIC working storage |
| `$0400–$0800` | ~1 KB | User low memory |
| `$0801–$9EFF` | ~38 KB | BASIC program area / user memory |
| `$9F00–$9FFF` | 256 bytes | I/O registers |
| `$A000–$BFFF` | 8 KB | Banked RAM window |
| `$C000–$FFFF` | 16 KB | Banked ROM window |

**Banking details:**

- **RAM banking:** 256 banks of 8 KB each = 2 MB maximum. The standard configuration ships with 64 banks (512 KB). The RAM bank register at `$00` selects which bank is visible at `$A000–$BFFF`.
- **ROM banking:** 32 banks of 16 KB each = 512 KB. The ROM bank register at `$01` selects which bank is visible at `$C000–$FFFF`. Banks 0–31 are system ROM. Banks 32–255 are reserved for cartridge ROM.

Cross-reference: See [Memory Map](memory-map.md) for a complete address space reference.

## VERA (Video Embedded Retro Adapter)

VERA is the custom **FPGA-based video and audio controller** that provides all graphics output and part of the audio subsystem. It has its own dedicated 128 KB of VRAM, separate from main system RAM.

**Video capabilities:**

| Feature | Details |
|---|---|
| VRAM | 128 KB dedicated |
| Layers | 2 independent tile/bitmap layers (Layer 0, Layer 1) |
| Sprites | 128, with per-sprite palette offset, Z-depth, H/V flip |
| Resolutions | 640x480 or 320x240 (other modes via horizontal/vertical scaling) |
| Tile modes | 2, 4, 16, or 256 colors per tile |
| Bitmap modes | 2, 4, 16, or 256 colors |
| Palette | 256 entries, 12-bit RGB (4096 possible colors) |
| Scrolling | Hardware scrolling on both layers |
| VERA FX | Hardware-accelerated multiply, polygon fill, cache/line helpers |

**Audio capabilities:**

| Feature | Details |
|---|---|
| PSG | 16 voices, selectable waveforms (pulse, sawtooth, triangle, noise) |
| PCM | Stereo FIFO playback, 8-bit or 16-bit, configurable sample rate |

**VERA register interface** (I/O mapped at `$9F20–$9F3F`):

| Register | Address | Description |
|---|---|---|
| ADDRx_L | $9F20 | VRAM address low byte |
| ADDRx_M | $9F21 | VRAM address mid byte |
| ADDRx_H | $9F22 | VRAM address high byte + increment + ADDR select |
| DATA0 | $9F23 | VRAM data port 0 (auto-increment via ADDR0) |
| DATA1 | $9F24 | VRAM data port 1 (auto-increment via ADDR1) |
| CTRL | $9F25 | Control register (reset, DCSEL, ADDRSEL) |
| IEN | $9F26 | Interrupt enable (VSYNC, LINE, SPRCOL, AFLOW) |
| ISR | $9F27 | Interrupt status register |
| IRQLINE_L | $9F28 | IRQ line compare (low byte) |
| DC_VIDEO | $9F29 | Display composer: output mode, chroma, layers, sprites |
| DC_HSCALE | $9F2A | Horizontal scale |
| DC_VSCALE | $9F2B | Vertical scale |
| DC_BORDER | $9F2C | Border color |
| L0_CONFIG | $9F2D | Layer 0 configuration |
| L0_MAPBASE | $9F2E | Layer 0 map base address |
| L0_TILEBASE | $9F2F | Layer 0 tile base address |
| L0_HSCROLL | $9F30–$9F31 | Layer 0 horizontal scroll |
| L0_VSCROLL | $9F32–$9F33 | Layer 0 vertical scroll |
| L1_CONFIG | $9F34 | Layer 1 configuration |
| L1_MAPBASE | $9F35 | Layer 1 map base address |
| L1_TILEBASE | $9F36 | Layer 1 tile base address |
| L1_HSCROLL | $9F37–$9F38 | Layer 1 horizontal scroll |
| L1_VSCROLL | $9F39–$9F3A | Layer 1 vertical scroll |
| AUDIO_CTRL | $9F3B | Audio control (PCM volume, sample rate, stereo, FIFO reset) |
| AUDIO_RATE | $9F3C | PCM sample rate |
| AUDIO_DATA | $9F3D | PCM data FIFO / PSG register write |
| SPI_DATA | $9F3E | SPI data port |
| SPI_CTRL | $9F3F | SPI control |

VERA supports two independent address pointers (ADDR0 and ADDR1) with configurable auto-increment, allowing efficient data streaming to VRAM without repeatedly setting the address.

Cross-reference: See [VERA Programming Guide](vera-programming-guide.md) for programming details.

## YM2151 FM Audio

The **Yamaha YM2151** (OPM — FM Operator Type-M) provides FM synthesis audio, giving the X16 a rich sound palette alongside VERA's PSG.

**Key characteristics:**

| Feature | Details |
|---|---|
| Voices | 8 simultaneous |
| Operators | 4 per voice |
| Algorithms | 8 selectable per voice |
| Envelopes | Full ADSR per operator |
| Frequency range | ~16 Hz to ~4 kHz fundamental |
| LFO | AM and PM modulation |
| Output | Stereo, directly connected to audio output |

**Register interface:**

| Address | Description |
|---|---|
| `$9F40` | Address register (write the register number here) |
| `$9F41` | Data register (write the register value here) |

**Programming notes:**

- Write the target register number to `$9F40`, then write the data byte to `$9F41`.
- The YM2151 has a busy flag — after each write, wait for the chip to be ready before the next write. Reading `$9F40` returns the status; bit 7 is the busy flag.
- The chip generates its own audio clock from the system bus, so timing is deterministic.

Cross-reference: See [Sound Programming](sound-programming.md) for programming techniques and examples.

## VIA I/O (65C22)

Two **WDC 65C22 VIA** (Versatile Interface Adapter) chips provide general-purpose I/O, timers, and peripheral interfaces.

Each VIA provides:

- Two 8-bit bidirectional I/O ports (Port A and Port B)
- Two 16-bit programmable interval timers
- An 8-bit shift register
- Handshake control lines (CA1, CA2, CB1, CB2)
- Interrupt generation (IRQ)

### VIA1 (`$9F00–$9F0F`)

| Function | Details |
|---|---|
| I2C bus master | Communicates with the SMC (address `$42`) and RTC (address `$6F`) via bit-banged I2C on Port A |
| SNES controller | Directly reads SNES-compatible controller data via bit-banging on Port B (data, clock, latch) |
| NMI source | Timer or external event on VIA1 triggers the CPU's NMI line |

### VIA2 (`$9F10–$9F1F`)

| Function | Details |
|---|---|
| IEC serial bus | Directly drives the Commodore IEC serial bus lines (ATN, CLK, DATA) for connecting IEC peripherals |
| SD card SPI | Directly communicates with the SD card slot via bit-banged SPI on Port A/B |
| User port | Directly exposes I/O pins on the user port header for user hardware projects |

**VIA register layout** (same for both, offset from base address):

| Offset | Register | Description |
|---|---|---|
| `$00` | PRB | Port B data |
| `$01` | PRA | Port A data |
| `$02` | DDRB | Port B data direction |
| `$03` | DDRA | Port A data direction |
| `$04` | T1C-L | Timer 1 counter low |
| `$05` | T1C-H | Timer 1 counter high |
| `$06` | T1L-L | Timer 1 latch low |
| `$07` | T1L-H | Timer 1 latch high |
| `$08` | T2C-L | Timer 2 counter low |
| `$09` | T2C-H | Timer 2 counter high |
| `$0A` | SR | Shift register |
| `$0B` | ACR | Auxiliary control register |
| `$0C` | PCR | Peripheral control register |
| `$0D` | IFR | Interrupt flag register |
| `$0E` | IER | Interrupt enable register |
| `$0F` | PRA2 | Port A data (no handshake) |

## System Management Controller (SMC)

The **ATtiny816** microcontroller serves as the System Management Controller, handling essential board-level functions outside the main CPU's domain.

**Responsibilities:**

- **Power sequencing** — Controls the power-on and power-off sequence for the board
- **PS/2 keyboard** — Decodes PS/2 keyboard protocol and buffers keystrokes
- **Reset button** — Monitors the reset button and asserts the CPU reset line
- **NMI button** — Monitors the NMI button and asserts NMI through VIA1
- **Activity LED** — Drives the front-panel activity LED

**Communication:**

- Connected to the CPU via the I2C bus through VIA1
- I2C address: `$42`
- The CPU can read keyboard scancodes, control power state, and query SMC status through I2C transactions
- SMC firmware can be updated in-system using the `x16-flash` utility

Cross-reference: See [Hardware Reference](hardware-reference.md) for SMC register details.

## SD Card Storage

The X16 uses a **full-size SD card slot** as its primary mass storage device.

**Interface details:**

- Connected via SPI protocol through VIA2 (directly bit-banged, no separate SPI controller)
- **CMDR-DOS** (in ROM) provides FAT32 filesystem access
- Accessible through the standard KERNAL file I/O API: `SETNAM`, `SETLFS`, `OPEN`, `CHKIN`, `CHKOUT`, `CHRIN`, `CHROUT`, `CLOSE`, `CLRCHN`

**Supported features:**

- `.PRG` program files (load and save)
- Sequential data files
- Directory listing
- Disk commands via channel 15 (rename, delete, mkdir, etc.)
- Subdirectory navigation
- Long filename support

Cross-reference: See [ROM Reference](rom-reference.md) for CMDR-DOS commands and KERNAL file I/O API.

## Expansion Slots

The X16 provides **four expansion slots** for adding hardware capabilities.

**Physical interface:**

- 60-pin edge connector per slot
- Direct access to the CPU bus (address lines, data lines, control signals)
- Each slot has a dedicated I/O select range within `$9800–$9BFF` (256 bytes per slot)
- Shared active-low IRQ line across all slots

**Cartridge slot:**

- Functionally similar to an expansion slot but with ROM bank access
- Cartridge ROM occupies banks 32–255 in the ROM banking window (`$C000–$FFFF`)
- Allows up to 224 banks x 16 KB = 3.5 MB of cartridge ROM
- Cartridges can also map I/O into the `$9800–$9BFF` range

Cross-reference: See [Hardware Reference](hardware-reference.md) for expansion slot pinout and electrical details.

## Clock and RTC

**System clocks:**

| Clock | Speed | Source |
|---|---|---|
| CPU clock | 8 MHz | Crystal oscillator on the main board |
| VERA clock | Independent | VERA has its own clock for video timing generation |
| YM2151 clock | 3.579545 MHz | Derived from system clock |

**Real-Time Clock:**

- **MCP7940N** RTC chip on the I2C bus (address `$6F`)
- Provides: year, month, day, weekday, hours, minutes, seconds
- Battery-backed (CR1220 coin cell) — retains time when powered off
- Accessible through KERNAL API or directly via I2C through VIA1

## System Comparison

The Commander X16 was designed as a spiritual successor to the Commodore 64, with significantly enhanced capabilities while remaining approachable to hobbyist programmers.

| Feature | Commander X16 | Commodore 64 | Commodore 128 |
|---|---|---|---|
| **CPU** | 65C02S @ 8 MHz | 6510 @ 1 MHz | 8502 @ 2 MHz |
| **RAM** | 512 KB (banked) | 64 KB | 128 KB |
| **Video chip** | VERA (128 KB VRAM) | VIC-II | VIC-IIe / VDC |
| **Sound** | VERA PSG + YM2151 | SID 6581/8580 | SID 6581/8580 |
| **Storage** | SD card (FAT32) | 1541 floppy | 1571 floppy |
| **Sprites** | 128 | 8 | 8 |
| **Colors** | 256 (from 4096) | 16 | 16 |
| **Max resolution** | 640x480 | 320x200 | 640x200 (VDC) |
| **Tile layers** | 2 independent | 1 (with tricks) | 1 |
| **Clock speed** | 8 MHz | ~1 MHz | ~2 MHz |
| **ROM** | 512 KB (banked) | 20 KB | 72 KB |

---

*For further reading, see the [Memory Map](memory-map.md) for complete address details, the [VERA Programming Guide](vera-programming-guide.md) for graphics and audio programming, and the [Hardware Reference](hardware-reference.md) for detailed hardware specifications.*
