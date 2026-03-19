# Development Guide

## Table of Contents

## Toolchain Overview

| Tool | Purpose | Language |
|---|---|---|
| cc65/cl65 | C compiler + linker (all-in-one) | C |
| ca65 + ld65 | Assembler + linker (part of cc65 suite) | 65xx assembly |
| ACME | Cross-assembler | 65xx assembly |
| X16 BASIC | Built-in interpreted language (ROM) | BASIC |
| prog8c | Compiled structured language for 6502 | Prog8 |
| llvm-mos | LLVM-based backend for 6502 | C, C++ |
| rust-mos | Rust compiler fork (Docker) | Rust (no_std) |
| x16emu | Official Commander X16 emulator | — |

Most X16 development uses cc65 (C or assembly), ACME, or BASIC. Prog8 and llvm-mos are newer but gaining traction.

## Installing the Toolchain

### Quick Setup

```bash
# Using the setup script (recommended)
./scripts/setup.sh

# Or minimal check only
./scripts/setup.sh --minimal
```

### Manual Installation

#### cc65

**macOS:**
```bash
brew install cc65
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install cc65
```

**Linux (Arch):**
```bash
sudo pacman -S cc65
```

**From source:**
```bash
git clone https://github.com/cc65/cc65.git
cd cc65 && make -j$(nproc)
sudo make install PREFIX=/usr/local
```

#### ACME Assembler

```bash
git clone https://github.com/meonwax/acme.git
cd acme/src && make
sudo cp acme /usr/local/bin/
```

#### X16 Emulator

Download the latest release from [X16Community/x16-emulator](https://github.com/X16Community/x16-emulator/releases). You also need the ROM image from [X16Community/x16-rom](https://github.com/X16Community/x16-rom/releases).

Place `x16emu` (or `x16emu.exe`) and `rom.bin` in the same directory, or on your PATH.

## Your First C Program

### Step 1: Create a project

```bash
make new-project NAME=hello-c
cd projects/hello-c
```

### Step 2: Edit src/main.c

```c
#include <stdio.h>
#include <conio.h>
#include <cx16.h>

int main(void) {
    clrscr();
    bgcolor(COLOR_BLUE);
    textcolor(COLOR_WHITE);
    clrscr();

    printf("Hello, Commander X16!\n");
    printf("Press any key...\n");
    cgetc();
    return 0;
}
```

### Step 3: Build and run

```bash
make        # builds build/hello-c.prg
make run    # builds and launches in emulator
```

## Your First Assembly Program (ca65)

### Step 1: Create a project

```bash
make new-project NAME=hello-asm TEMPLATE=ca65-asm
cd projects/hello-asm
```

### Step 2: Edit src/main.s

```asm
.include "x16.inc"

.segment "BASICSTUB"
    .word @next
    .word 10          ; line 10
    .byte $9E         ; SYS
    .byte "2061", 0
@next:
    .word 0

.segment "CODE"
start:
    ldx #0
@loop:
    lda message,x
    beq @done
    jsr CHROUT
    inx
    bra @loop
@done:
    jsr GETIN
    beq @done         ; wait for keypress
    rts

.segment "RODATA"
message:
    .byte "HELLO FROM ASSEMBLY!", $0D, 0
```

### Step 3: Build and run

```bash
make
make run
```

## Your First ACME Program

### Step 1: Create a project

```bash
make new-project NAME=hello-acme TEMPLATE=acme-asm
cd projects/hello-acme
```

### Step 2: Edit src/main.a

```
!source "include/x16.a"

* = $0801
; BASIC stub
!byte $0C, $08      ; next line pointer
!byte $0A, $00      ; line 10
!byte $9E           ; SYS token
!text "2061", 0     ; "2061"
!byte $00, $00      ; end of BASIC

* = $080D
    ldx #0
.loop
    lda message,x
    beq .done
    jsr CHROUT
    inx
    bra .loop
.done
    jsr GETIN
    beq .done
    rts

message
    !text "HELLO FROM ACME!", $0D, 0
```

## Your First BASIC Program

The simplest way to start programming the X16 — no toolchain required.

### Step 1: Create a project

```bash
make new-project NAME=hello-basic TEMPLATE=basic
cd projects/hello-basic
```

### Step 2: Edit src/main.bas

```basic
10 SCREEN 0
20 COLOR 1,6
30 CLS
40 PRINT "HELLO, COMMANDER X16!"
50 PRINT
60 PRINT "PRESS ANY KEY..."
70 GET A$:IF A$="" GOTO 70
```

### Step 3: Run in emulator

```bash
make run    # launches x16emu -bas src/main.bas -run
```

The emulator's `-bas` flag loads a text BASIC file as if you typed it in. No compilation step needed.

### BASIC Graphics

BASIC can access VERA directly using `VPOKE` and `POKE` for graphics beyond simple text:

#### Direct VRAM Access with VPOKE

```basic
10 REM VPOKE BANK, ADDRESS, VALUE
20 REM WRITE TO TEXT LAYER MAP (LAYER 1 AT $B000)
30 VPOKE 1, $B000 + ROW*$100 + COL*2, CHARCODE
40 VPOKE 1, $B000 + ROW*$100 + COL*2 + 1, COLOR
```

#### Bitmap Mode Setup

Set up a 320x240 8bpp bitmap for pixel drawing:

```basic
10 REM CONFIGURE 320X240 BITMAP, 8BPP, LAYER 0
20 POKE $9F2A, $40:REM HSCALE=64 (320 WIDE)
30 POKE $9F2B, $40:REM VSCALE=64 (240 HIGH)
40 POKE $9F2D, $07:REM L0 CONFIG: 8BPP + BITMAP
50 POKE $9F2F, $00:REM L0 TILEBASE: DATA AT VRAM $00000
60 POKE $9F29, $11:REM DC_VIDEO: VGA + LAYER 0 ENABLED
70 REM PLOT PIXEL AT (X,Y) WITH COLOR C
80 PO = Y*320 + X : BA = 0
90 IF PO > $FFFF THEN PO = PO - $10000 : BA = 1
100 VPOKE BA, PO, C
```

#### Custom Palette

```basic
10 REM SET PALETTE ENTRY I TO RGB (R,G,B) — 4 BITS EACH
20 VPOKE 1, $FA00+I*2, G*16+B
30 VPOKE 1, $FA00+I*2+1, R
```

### BASIC Sprites

Use the high-level `SPRMEM`, `SPRITE`, and `MOVSPR` commands:

```basic
10 REM UPLOAD SPRITE PIXEL DATA TO VRAM $10000
20 FOR I=0 TO 127:VPOKE 1,I,$11:NEXT
30 REM CONFIGURE: SPRMEM SPRITE, BANK, ADDR, BPP
40 SPRMEM 0, 1, 0, 0:REM SPRITE 0 IMAGE AT $10000, 4BPP
50 REM DISPLAY: SPRITE ID,ZDEPTH,HFLIP,VFLIP,PALOFF,WIDTH,HEIGHT
60 SPRITE 0, 3, 0, 0, 0, 1, 2:REM Z=3(FRONT), 16X32
70 MOVSPR 0, 160, 120:REM MOVE SPRITE 0 TO CENTER
```

You can also set sprite attributes directly with VPOKE to the sprite attribute table at VRAM $1FC00 (8 bytes per sprite):

```basic
10 REM SET SPRITE 0 X POSITION TO 160
20 VPOKE 1, $FC02, 160:REM X LOW BYTE
30 VPOKE 1, $FC03, 0:REM X HIGH BYTE
```

### BASIC Audio

BASIC provides dedicated audio commands for both PSG and FM synthesis:

```basic
10 PSGINIT:FMINIT:REM RESET AUDIO
20 REM PSG: SET WAVEFORM AND PLAY A NOTE
30 PSGWAV 0, 2:REM VOICE 0 = TRIANGLE
40 PSGNOTE 0, 48, 60:REM PLAY C4 FOR 1 SECOND
50 REM FM: LOAD INSTRUMENT AND PLAY
60 FMINST 0, 0:REM CHANNEL 0 = PIANO PRESET
70 FMNOTE 0, 48, 30:REM PLAY C4 FOR HALF SECOND
```

For direct PSG register access (e.g., sound effects), use VPOKE to the PSG register space at VRAM $1F9C0:

```basic
10 REM PLAY A BEEP ON PSG VOICE 14
20 VPOKE 1,$F9F8,$7C:REM FREQ LOW
30 VPOKE 1,$F9F9,$0A:REM FREQ HIGH
40 VPOKE 1,$F9FA,$F0:REM VOLUME=48, BOTH CHANNELS
50 VPOKE 1,$F9FB,$20:REM TRIANGLE WAVEFORM
60 REM SILENCE IT LATER
70 VPOKE 1,$F9FA,0:REM VOLUME=0
```

### BASIC Input

#### Keyboard with GET

```basic
10 REM NON-BLOCKING: RETURNS EMPTY STRING IF NO KEY
20 GET A$:IF A$="" GOTO 20
30 IF A$="W" THEN PRINT "UP!"
40 IF A$=" " THEN PRINT "SPACE!"
```

#### Joystick with JOY()

```basic
10 REM JOY(0)=KEYBOARD-AS-JOYSTICK, JOY(1-4)=SNES PORTS
20 JV = JOY(0)
30 REM BUTTONS ARE ACTIVE-HIGH IN BASIC (UNLIKE ASM)
40 IF (JV AND 8) THEN PRINT "UP"
50 IF (JV AND 4) THEN PRINT "DOWN"
60 IF (JV AND 64) THEN PRINT "BUTTON A"
70 IF (JV AND 128) THEN PRINT "BUTTON B"
```

### Beyond Line Numbers

For larger BASIC projects, consider [BASLOAD](https://github.com/stefan-b-jakobsson/basload-x16) which lets you write BASIC without line numbers and compiles labels automatically.

## Your First Prog8 Program

[Prog8](https://prog8.readthedocs.io) is a compiled structured language with first-class X16 support.

### Step 1: Install prog8c

```bash
# macOS
brew install prog8

# Or use the setup script
./scripts/setup.sh --prog8
```

### Step 2: Create a project

```bash
make new-project NAME=hello-prog8 TEMPLATE=prog8
cd projects/hello-prog8
```

### Step 3: Edit src/main.p8

```prog8
%import textio
%zeropage basicsafe

main {
    sub start() {
        txt.clear_screen()
        txt.print("hello from prog8!\n")
        txt.print("press any key...\n")

        repeat {
            cx16.r0L = cbm.GETIN()
            if cx16.r0L != 0
                break
        }
    }
}
```

### Step 4: Build and run

```bash
make        # compiles to build/main.prg
make run    # builds and launches in emulator
```

## Using llvm-mos C

[llvm-mos](https://llvm-mos.org/) brings modern C11/C++20 support to the X16 with superior optimization over cc65.

### Quick Start

```bash
# Install (or use: ./scripts/setup.sh --llvm-mos)
curl -LO https://github.com/llvm-mos/llvm-mos-sdk/releases/latest/download/llvm-mos-macos.tar.xz
tar xf llvm-mos-macos.tar.xz && export PATH="$PWD/llvm-mos/bin:$PATH"

# Create and build a project
make new-project NAME=hello-llvm TEMPLATE=llvm-mos-c
cd projects/hello-llvm
make run
```

The workflow is the same as cc65 but uses `mos-cx16-clang` instead of `cl65`. No `-t cx16` flag needed — the target is in the compiler binary name.

See [Cross-Compilation Guide](cross-compilation-guide.md) for detailed llvm-mos information, header differences, and comparison to cc65.

## cc65 Target Details

### Headers
- `<cx16.h>` — X16-specific defines (VERA registers, banking, virtual registers r0-r15)
- `<cbm.h>` — Commodore-compatible functions (cbm_open, cbm_read, etc.)
- `<conio.h>` — Console I/O (clrscr, cgetc, textcolor, bgcolor, gotoxy, cprintf, etc.)
- `<stdio.h>` — Standard I/O (printf, fopen, fread, etc.)
- `<peekpoke.h>` — PEEK/POKE macros
- `<joystick.h>` — Joystick driver

### Pseudo-Variables (cx16.h)
```c
// Banking
RAM_BANK = *(volatile unsigned char*)0x00;
ROM_BANK = *(volatile unsigned char*)0x01;

// Virtual registers
struct { unsigned char lo, hi; } r0, r1, ..., r15;
// Access: r0.lo, r0.hi, or *(unsigned*)&r0 for 16-bit
```

### Linker Configs
The default cx16 target config works for most programs. Custom configs are useful when you need:
- Specific segment placement
- Multiple code segments across banks
- Custom BSS regions

### Calling KERNAL from C

```c
#include <cx16.h>
#include <cbm.h>

// Using inline assembly for KERNAL calls
void __fastcall__ chrout(char c) {
    __asm__("jsr $FFD2");
}

// Or use the cc65 KERNAL wrappers where available
```

## Sprite Setup from C

Setting up hardware sprites from C using `vpoke()` and `VERA.data0`:

```c
#include <cx16.h>

// Write sprite image data to VRAM
void load_sprite_data(unsigned long vram_addr,
                      const unsigned char *data,
                      unsigned int len) {
    unsigned int i;
    // vpoke() sets address with auto-increment (0x10 prefix = stride 1)
    vpoke(data[0], 0x100000 | vram_addr);
    for (i = 1; i < len; i++) {
        VERA.data0 = data[i];
    }
}

// Configure sprite attributes (8 bytes at VRAM $1FC00 + sprite * 8)
void setup_sprite(unsigned char sprite, unsigned long img_addr,
                  unsigned int x, unsigned int y,
                  unsigned char bpp8, unsigned char w, unsigned char h) {
    unsigned int addr_field = (unsigned int)(img_addr >> 5);

    // Set VERA address to sprite attribute block with auto-increment
    vpoke(addr_field & 0xFF, 0x11FC00UL + sprite * 8);
    VERA.data0 = (addr_field >> 8) | (bpp8 ? 0x80 : 0x00);
    VERA.data0 = x & 0xFF;            // X low
    VERA.data0 = x >> 8;              // X high
    VERA.data0 = y & 0xFF;            // Y low
    VERA.data0 = y >> 8;              // Y high
    VERA.data0 = (3 << 2);            // Z-depth=3 (in front)
    VERA.data0 = (h << 6) | (w << 4); // size + palette offset 0
}

void main(void) {
    // Load 16x16 4bpp sprite data (128 bytes) to VRAM $10000
    load_sprite_data(0x10000UL, my_sprite_data, 128);

    // Configure sprite 0: image at $10000, position (160,120),
    // 4bpp, width=16 (1), height=16 (1)
    setup_sprite(0, 0x10000UL, 160, 120, 0, 1, 1);

    // Enable sprites in display composer
    vera_sprites_enable(1);
}
```

## Audio from C

### YM2151 FM from C

```c
#include <cx16.h>

// Write to YM2151 register with required delay
void ym_write(unsigned char reg, unsigned char val) {
    unsigned char i;
    YM2151.reg = reg;       // $9F40
    YM2151.data = val;      // $9F41
    // Wait for busy flag to clear (~10 iterations at 8 MHz)
    for (i = 0; i < 10; i++) {
        __asm__("nop");
    }
}

void play_fm_note(void) {
    unsigned char ch = 0;

    // Algorithm 0, L+R output, feedback 0
    ym_write(0x20 + ch, 0xC0);

    // OP4 (carrier, slot $18): TL=0 (loudest), fast attack
    ym_write(0x60 + 0x18, 0x00);  // TL
    ym_write(0x80 + 0x18, 0x1F);  // AR=31 (instant)
    ym_write(0xE0 + 0x18, 0x07);  // D1L=0, RR=7

    // Silence modulator operators
    ym_write(0x60 + 0x00, 0x7F);  // OP1 TL=127
    ym_write(0x60 + 0x08, 0x7F);  // OP2
    ym_write(0x60 + 0x10, 0x7F);  // OP3

    // Set note: octave 4, A (KC=$4A)
    ym_write(0x28 + ch, 0x4A);

    // Key on: all 4 operators, channel 0
    ym_write(0x08, 0x78);
}
```

### PSG from C

```c
#include <cx16.h>

// Set PSG voice registers via VRAM at $1F9C0 + voice*4
void psg_play(unsigned char voice, unsigned int freq,
              unsigned char vol, unsigned char waveform) {
    unsigned long addr = 0x1F9C0UL + voice * 4;
    vpoke(freq & 0xFF, 0x100000 | addr);   // freq low + auto-increment
    VERA.data0 = freq >> 8;                // freq high
    VERA.data0 = 0xC0 | (vol & 0x3F);     // both channels + volume
    VERA.data0 = (waveform << 6);          // waveform
}

void psg_stop(unsigned char voice) {
    // Set volume to 0
    vpoke(0, 0x1F9C2UL + voice * 4);
}
```

## Program Structure

### .PRG File Format
- First 2 bytes: load address (little-endian), typically $0801
- Remaining bytes: program data loaded starting at that address
- BASIC stub at $0801 provides `SYS 2061` to auto-run machine code at $080D

### Memory Layout of a Typical Program
```
$0801  BASIC stub ("10 SYS 2061")
$080D  Machine code starts (CODE segment)
...    CODE continues
...    RODATA (read-only data: strings, lookup tables)
...    DATA (initialized variables)
...    BSS (uninitialized variables, zeroed at startup)
$9EFF  End of available fixed RAM
```

## Working with Banked RAM

### From C (cc65)

```c
#include <cx16.h>

// Switch bank and access data
void read_bank_data(unsigned char bank, unsigned char *dest, unsigned len) {
    unsigned char old_bank = RAM_BANK;
    RAM_BANK = bank;
    memcpy(dest, (void*)0xA000, len);
    RAM_BANK = old_bank;
}
```

### From Assembly

```asm
; Load data from file into banked RAM
; Use SETLFS, SETNAM, then LOAD with bank switching
lda #1              ; logical file
ldx #8              ; device (SD card)
ldy #2              ; secondary address (load to specified address)
jsr SETLFS

lda #name_len
ldx #<filename
ldy #>filename
jsr SETNAM

lda #5              ; target RAM bank
sta RAM_BANK
lda #0              ; 0 = load
ldx #<$A000
ldy #>$A000
jsr LOAD
```

## Multi-Bank Code Placement

For programs larger than ~38 KB, place code in banked RAM and call across banks.

### ca65 Linker Configuration

Add a custom segment for banked code in your linker config:

```
MEMORY {
    MAIN:     start = $0801, size = $97FF, fill = yes;
    BANK1:    start = $A000, size = $2000, fill = yes, bank = 1;
    BANK2:    start = $A000, size = $2000, fill = yes, bank = 2;
}
SEGMENTS {
    BASICSTUB: load = MAIN, type = ro;
    CODE:      load = MAIN, type = ro;
    RODATA:    load = MAIN, type = ro;
    BSS:       load = MAIN, type = bss;
    BANK1CODE: load = BANK1, type = ro;
    BANK2CODE: load = BANK2, type = ro;
}
```

### Cross-Bank Calling (Trampoline)

Code in banked RAM can't directly JSR to another bank. Use a trampoline in fixed RAM:

```asm
; Trampoline in fixed RAM (CODE segment)
; Call a routine in banked RAM
call_banked:
    ; A = target bank, r0 = target address
    pha
    lda RAM_BANK         ; save current bank
    pha
    txa
    sta RAM_BANK         ; switch to target bank
    jsr trampoline_jsr   ; indirect call
    pla
    sta RAM_BANK         ; restore original bank
    rts

trampoline_jsr:
    jmp (r0)             ; jump to address in r0

; Usage from fixed RAM:
;   lda #2               ; bank 2
;   ldx #<my_bank2_func
;   stx r0
;   ldx #>my_bank2_func
;   stx r0+1
;   jsr call_banked
```

### cc65 Code Segments

In cc65, use `#pragma codeseg` to place functions in specific segments:

```c
#pragma codeseg("BANK1CODE")

void banked_function(void) {
    // This function's code will be placed in BANK1CODE segment
}

#pragma codeseg("CODE")  // back to default
```

## Programming VERA from C

```c
#include <cx16.h>

// Set VERA address with auto-increment
#define VERA_ADDR_L  (*(volatile unsigned char*)0x9F20)
#define VERA_ADDR_M  (*(volatile unsigned char*)0x9F21)
#define VERA_ADDR_H  (*(volatile unsigned char*)0x9F22)
#define VERA_DATA0   (*(volatile unsigned char*)0x9F23)

void vera_set_addr(unsigned long addr, unsigned char increment) {
    VERA_ADDR_L = (unsigned char)(addr);
    VERA_ADDR_M = (unsigned char)(addr >> 8);
    VERA_ADDR_H = (unsigned char)((addr >> 16) & 0x01) | (increment << 4);
}

// Write a byte to VRAM
void vera_poke(unsigned long addr, unsigned char val) {
    vera_set_addr(addr, 0);
    VERA_DATA0 = val;
}

// Fill VRAM region
void vera_fill(unsigned long addr, unsigned char val, unsigned count) {
    vera_set_addr(addr, 1);  // auto-increment 1
    while (count--) {
        VERA_DATA0 = val;
    }
}
```

## Makefile Patterns

### Basic cc65 Makefile

```makefile
PROJECT = $(notdir $(CURDIR))
TARGET  = cx16
CC      = cl65
CFLAGS  = -t $(TARGET) -O
SRC     = $(wildcard src/*.c)
PRG     = build/$(PROJECT).prg

all: $(PRG)

$(PRG): $(SRC) | build
	$(CC) $(CFLAGS) -o $@ $^

build:
	mkdir -p build

clean:
	rm -rf build

run: $(PRG)
	x16emu -prg $< -run

.PHONY: all clean run
```

### Mixed C + Assembly

```makefile
C_SRC = $(wildcard src/*.c)
S_SRC = $(wildcard src/*.s)
OBJS  = $(C_SRC:src/%.c=build/%.o) $(S_SRC:src/%.s=build/%.o)

build/%.o: src/%.c | build
	cc65 -t cx16 -O -o build/$*.s $<
	ca65 -t cx16 -o $@ build/$*.s

build/%.o: src/%.s | build
	ca65 -t cx16 -I include -o $@ $<

$(PRG): $(OBJS)
	ld65 -t cx16 -o $@ $^ cx16.lib
```

## Debugging

### Emulator Debug Mode

Launch with: `x16emu -debug`

### F12 Debugger (in emulator)

Press F12 to enter the built-in debugger. Features:
- CPU state display (registers, flags, stack)
- Memory viewer
- Disassembly view
- Breakpoints (address or condition)
- Single-step execution
- VRAM viewer
- Sprite viewer
- Palette viewer

### Monitor (in emulator)

The ML Monitor (enter with `MON` from BASIC) provides:
- Memory examination and modification
- Disassembly
- Simple assembler
- Register view/modification
- File load/save

See [ROM Reference](rom-reference.md) for full Monitor commands.

### Debug Output

```asm
; Write a character to the emulator's host console (debug output)
; Only works in emulator!
lda #'A'
sta $9FB0        ; EMU_DEBUG register
```

```c
// C equivalent
*(volatile char*)0x9FB0 = 'A';
```

### Detecting the Emulator

```asm
lda $9FB2        ; EMU_DETECT
cmp #$45         ; 'E' = running in emulator
beq in_emulator
```

## Asset Pipeline

### Converting Graphics

For sprites and tiles, you need to convert images to VERA's pixel format:

**Using Python + Pillow:**
```python
from PIL import Image

def png_to_4bpp(filename):
    img = Image.open(filename).convert('P', colors=16)
    pixels = list(img.getdata())
    output = []
    for i in range(0, len(pixels), 2):
        byte = (pixels[i] << 4) | pixels[i+1]
        output.append(byte)
    return bytes(output)
```

**Using upstream tools:**
The x16-demo repo contains various asset conversion scripts that can be adapted.

### Loading Assets at Runtime

```c
// Load a binary file to VRAM using BVLOAD
// From BASIC: BVLOAD "SPRITES.BIN",8,0,$10000
// From C:
cbm_k_setnam("SPRITES.BIN");
cbm_k_setlfs(0, 8, 2);
// Set VERA address, then LOAD
```

## llvm-mos Overview

[llvm-mos](https://llvm-mos.org/) is an LLVM backend targeting 6502-family CPUs. It produces significantly better optimized code than cc65 for C and C++.

- Supports C11, C++20
- Much better optimization (LLVM's full optimization pipeline)
- Can be 2-5x faster than cc65 output
- Target: `mos-cx16-clang`
- Linker scripts compatible with X16
- Growing community support

See [Cross-Compilation Guide](cross-compilation-guide.md) for details.

## Complete Examples

Working projects in `projects/` demonstrate many of the patterns above:

- **[pong-asm](../projects/pong-asm/)** — Full game in ca65 assembly: sprites, PSG audio, VSYNC loop, controller input
- **[pong-c](../projects/pong-c/)** — Same game in cc65 C: `vpoke()`, `VERA.data0`, joystick API
- **[pong-basic](../projects/pong-basic/)** — Same game in BASIC: `SPRMEM`/`SPRITE`/`MOVSPR`, `VPOKE` audio, `JOY()`

Cross-reference: See [Emulator Guide](emulator-guide.md) for detailed emulator usage. See [Memory Map](memory-map.md) for address details.
