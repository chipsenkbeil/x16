# Hardware Reference

## Table of Contents

- [Board Overview](#board-overview)
- [Expansion Slots](#expansion-slots)
- [Cartridge Development](#cartridge-development)
- [I/O Ports](#io-ports)
- [System Management Controller (SMC)](#system-management-controller-smc)
- [Real-Time Clock (RTC)](#real-time-clock-rtc)
- [VIA Register Reference](#via-register-reference-wdc-65c22)
- [Power Supply](#power-supply)

## Board Overview

The Commander X16 is a single-board computer with:
- WDC 65C02S CPU @ 8 MHz
- VERA FPGA (video + audio)
- YM2151 FM synthesis chip
- 512 KB SRAM (banked) + 512 KB ROM
- SD card slot
- 4 expansion slots
- 2x WDC 65C22 VIA chips
- ATtiny816 System Management Controller (SMC)
- MCP7940N Real-Time Clock (RTC)
- PS/2 keyboard connector
- 2x SNES controller ports
- IEC serial port
- User port header

## Expansion Slots

The X16 has four expansion slots using 60-pin edge connectors.

### Connector Pinout (60-pin Edge Connector)

Each slot provides direct access to the CPU bus:

**Side A (component side):**

| Pin | Signal | Description |
|---|---|---|
| 1 | GND | Ground |
| 2 | D0 | Data bus bit 0 |
| 3 | D1 | Data bus bit 1 |
| 4 | D2 | Data bus bit 2 |
| 5 | D3 | Data bus bit 3 |
| 6 | D4 | Data bus bit 4 |
| 7 | D5 | Data bus bit 5 |
| 8 | D6 | Data bus bit 6 |
| 9 | D7 | Data bus bit 7 |
| 10 | A0 | Address bus bit 0 |
| 11 | A1 | Address bus bit 1 |
| 12 | A2 | Address bus bit 2 |
| 13 | A3 | Address bus bit 3 |
| 14 | A4 | Address bus bit 4 |
| 15 | A5 | Address bus bit 5 |
| 16 | A6 | Address bus bit 6 |
| 17 | A7 | Address bus bit 7 |
| 18 | A8 | Address bus bit 8 |
| 19 | A9 | Address bus bit 9 |
| 20 | A10 | Address bus bit 10 |
| 21 | A11 | Address bus bit 11 |
| 22 | A12 | Address bus bit 12 |
| 23 | A13 | Address bus bit 13 |
| 24 | A14 | Address bus bit 14 |
| 25 | A15 | Address bus bit 15 |
| 26 | PHI2 | System clock (8 MHz) |
| 27 | R/W | Read/Write (high=read) |
| 28 | IRQ | Interrupt request (active low, open collector) |
| 29 | NMI | Non-maskable interrupt (active low) |
| 30 | +5V | Power supply |

**Side B (solder side):**

| Pin | Signal | Description |
|---|---|---|
| 1 | GND | Ground |
| 2-5 | IOx | I/O select lines (active low, one per slot) |
| 6 | RESET | System reset (active low) |
| 7-28 | (Various) | Bus and control signals |
| 29 | AUDIO_L or AUDIO_R | Audio mix input |
| 30 | +5V | Power supply |

(Note: Exact pinout may vary -- consult the official X16 schematics for the definitive reference.)

### I/O Select Ranges

Each expansion slot has a dedicated I/O select region in the address space:

| Slot | I/O Range | Select Line |
|---|---|---|
| 1 | $9800-$9BFF | IO1 |
| 2 | $9C00-$9FFF (partial) | IO2 |
| 3 | (shared) | IO3 |
| 4 | (shared) | IO4 |

The IOx lines go active (low) when the CPU accesses the corresponding address range, allowing the expansion card to respond to reads/writes without additional address decoding.

### Expansion Card Design Tips

- Cards should respond only when their IOx select line is active
- Use active-low select as chip enable for your logic
- The IRQ line is shared (active low, open-collector) -- multiple cards can assert IRQ
- Keep bus loading in mind -- add buffers for long signal runs
- Power budget: each slot provides +5V, total system draw should stay within the PSU rating

## Cartridge Development

The cartridge slot is functionally an expansion slot with additional ROM banking support.

### Boot Protocol

1. On power-up, the KERNAL checks ROM bank 32 for a cartridge signature
2. Signature: bytes `$43 $58 $31 $36` ("CX16") at address $C000 in bank 32
3. If the signature is found, execution jumps to the entry point at $C004 in bank 32
4. The cartridge takes full control of the system

### Cartridge ROM Layout

```
Bank 32 ($C000-$FFFF):
  $C000: "CX16"       ; 4-byte signature
  $C004: entry point   ; JMP to cartridge startup code
  $C007+: code/data    ; Cartridge code

Banks 33-255: Additional cartridge ROM (up to ~3.5 MB)
```

### IO7 Select

Cartridges can also use the IO7 select line for memory-mapped I/O at a specific address range, providing hardware register access beyond the ROM banks.

### Example Cartridge Header (ca65)

```asm
.segment "CARTHDR"
    .byte "CX16"          ; Signature
    jmp cart_start         ; Entry point at $C004

.segment "CARTCODE"
cart_start:
    ; Cartridge initialization
    ; Set up screen, load data, etc.
    jmp main_loop
```

### Cartridge Linker Config

```
MEMORY {
    CARTHDR:  type = ro, start = $C000, size = $0007, bank = 32;
    CARTCODE: type = ro, start = $C007, size = $3FF9, bank = 32;
    CARTDAT:  type = ro, start = $C000, size = $4000, bank = 33;
}
```

## I/O Ports

### SNES Controller Ports (2 ports)

Two SNES-compatible controller ports on the front of the board.

Controllers are read via VIA1 using a bit-banging protocol. The KERNAL provides the `joystick_scan` ($FF53) and `joystick_get` ($FF56) API calls.

Button mapping (active-low: 0 = pressed):

| Bit (byte 1 / A register) | Button |
|---|---|
| 7 | Right |
| 6 | Left |
| 5 | Down |
| 4 | Up |
| 3 | Start |
| 2 | Select |
| 1 | Y |
| 0 | B |

| Bit (byte 2 / X register) | Button |
|---|---|
| 3 | R |
| 2 | L |
| 1 | X |
| 0 | A |

Joystick numbers: 0 = keyboard (SNES-like mapping), 1-4 = physical controller ports.

```asm
; Read controller 1
lda #1
jsr $FF56       ; joystick_get
; A = buttons byte 1 (active low)
; X = buttons byte 2 (active low)
; Y = 0 if present
```

### IEC Serial Port

Standard Commodore IEC serial bus connector for connecting vintage peripherals:
- 1541/1571/1581 floppy drives
- Printers
- Other IEC devices

The IEC bus is directly driven by VIA2. The KERNAL provides standard Commodore serial bus routines (LISTEN, TALK, ACPTR, CIOUT, etc.).

Device numbers: 4-5 = printers, 8-11 = disk drives (SD card is device 8 by default).

### PS/2 Keyboard Port

Mini-DIN 6-pin PS/2 keyboard connector on the back. The keyboard is handled by the SMC (ATtiny816), which translates PS/2 scancodes and communicates with the CPU via I2C through VIA1.

Supported features:
- Full PS/2 keyboard protocol
- Multiple keyboard layouts (configurable via KERNAL or emulator)
- Modifier keys (Shift, Ctrl, Alt, Win/Cmd)

### User Port

A header on the board connected to VIA2 Port A and Port B pins, providing:
- 8 general-purpose I/O lines (individually configurable as input or output)
- 2 handshake lines (CA1/CA2 or CB1/CB2)
- Access to VIA2 timer and shift register functions

This is the primary interface for custom hardware projects (sensors, LEDs, motor drivers, etc.).

## System Management Controller (SMC)

The SMC is an ATtiny816 microcontroller that manages:
- Power-on sequencing
- PS/2 keyboard interface
- Reset button
- NMI button
- Power LED
- Activity LED

### I2C Interface

The SMC communicates with the CPU via I2C on VIA1. Its I2C address is **$42**.

### SMC Register Map

| Register | R/W | Description |
|---|---|---|
| $01 | R | SMC firmware version (major) |
| $02 | R | SMC firmware version (minor) |
| $04 | R | Keyboard buffer (read next key event) |
| $05 | R | Keyboard buffer count |
| $07 | W | Power off (write $01 to power down) |
| $08 | W | Reset (write $01 to hard reset) |
| $09 | W | NMI (write $01 to trigger NMI) |
| $18 | W | Activity LED brightness (0-255) |
| $19 | W | Power LED brightness (0-255) |
| $21 | W | I2C address for bootloader operations |
| $80 | W | Enter bootloader mode (for firmware update) |

### Reading from SMC (Assembly)

```asm
; Read SMC firmware version (major)
ldx #$42        ; SMC I2C address
ldy #$01        ; register $01
jsr $FEC6       ; i2c_read_byte
; A = firmware major version
```

### SMC Firmware Update

The SMC firmware can be updated using the `x16-flash` utility:
1. Download new SMC firmware
2. Run the flash utility on the X16
3. The utility uses the I2C bootloader protocol to write new firmware

Source: [X16Community/x16-smc](https://github.com/X16Community/x16-smc)

## Real-Time Clock (RTC)

The MCP7940N RTC chip provides battery-backed date/time.

### I2C Address: $6F

### Access via KERNAL

```asm
; Get current date/time
jsr $FF50        ; clock_get_date_time
; r0L = year (0-99), r0H = month (1-12)
; r1L = day (1-31), r1H = hours (0-23)
; r2L = minutes (0-59), r2H = seconds (0-59)
; r3L = jiffies (0-59)

; Set date/time
lda #26          ; year 2026
sta $02          ; r0L
lda #3           ; March
sta $03          ; r0H
lda #15          ; day 15
sta $04          ; r1L
lda #14          ; 14:00
sta $05          ; r1H
lda #30          ; :30
sta $06          ; r2L
lda #0           ; :00
sta $07          ; r2H
stz $08          ; jiffies = 0
jsr $FF4D        ; clock_set_date_time
```

### Direct I2C Access

```asm
; Read seconds register directly from RTC
ldx #$6F        ; RTC I2C address
ldy #$00        ; register 0 (seconds)
jsr $FEC6       ; i2c_read_byte
; A = BCD seconds (bit 7 = oscillator running)
and #$7F        ; mask off oscillator bit
; A = BCD seconds value
```

## VIA Register Reference (WDC 65C22)

Both VIA1 ($9F00) and VIA2 ($9F10) use the same register layout:

### Register Map (offset from base address)

| Offset | Name | Description |
|---|---|---|
| $0 | PRB | Port B data register |
| $1 | PRA | Port A data register (with handshake) |
| $2 | DDRB | Port B data direction (1=output, 0=input) |
| $3 | DDRA | Port A data direction |
| $4 | T1C-L | Timer 1 counter low (read=counter, write=latch) |
| $5 | T1C-H | Timer 1 counter high (write starts timer) |
| $6 | T1L-L | Timer 1 latch low |
| $7 | T1L-H | Timer 1 latch high |
| $8 | T2C-L | Timer 2 counter low |
| $9 | T2C-H | Timer 2 counter high |
| $A | SR | Shift register |
| $B | ACR | Auxiliary control register |
| $C | PCR | Peripheral control register |
| $D | IFR | Interrupt flag register |
| $E | IER | Interrupt enable register |
| $F | PRA-NH | Port A data (no handshake) |

### Auxiliary Control Register (ACR)

| Bit | Description |
|---|---|
| 7 | Timer 1 control: 1=square wave on PB7 |
| 6 | Timer 1 control: 1=continuous, 0=one-shot |
| 5 | Timer 2 control: 1=count PB6 pulses, 0=one-shot |
| 4:2 | Shift register mode (000=disabled) |
| 1 | Port B latch enable |
| 0 | Port A latch enable |

### Peripheral Control Register (PCR)

| Bit | Description |
|---|---|
| 7:5 | CB2 control |
| 4 | CB1 edge: 0=negative, 1=positive |
| 3:1 | CA2 control |
| 0 | CA1 edge: 0=negative, 1=positive |

### Interrupt Flag/Enable Registers

| Bit | Source |
|---|---|
| 7 | Any interrupt (IFR) / Set/clear (IER) |
| 6 | Timer 1 |
| 5 | Timer 2 |
| 4 | CB1 |
| 3 | CB2 |
| 2 | Shift register |
| 1 | CA1 |
| 0 | CA2 |

IER: Write with bit 7=1 to enable bits, bit 7=0 to disable bits.

### VIA1 Signal Assignments

| Port | Bit | Signal | Function |
|---|---|---|---|
| PB0 | 0 | I2C SDA out | I2C data output |
| PB1 | 1 | I2C SCL | I2C clock |
| PA | various | SNES data | Controller shift register data |

### VIA2 Signal Assignments

| Port | Bit | Signal | Function |
|---|---|---|---|
| PB | various | IEC bus | ATN, CLK, DATA lines |
| PA | various | User port + SD SPI | MOSI, MISO, SCK, CS |

## Power Supply

- Input: barrel jack, center-positive
- Voltage: 5V DC regulated
- The board has modest power requirements; a quality 2A+ 5V supply is recommended
- Expansion cards draw from the same supply -- account for their power needs

---

Cross-reference: See [Memory Map](memory-map.md) for I/O register addresses. See [Architecture Overview](architecture-overview.md) for system-level view. See [Contributing Guide](contributing-guide.md) for hardware-related repos.
