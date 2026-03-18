# Development Guide

## Table of Contents

## Toolchain Overview

| Tool | Purpose | Language |
|---|---|---|
| cc65/cl65 | C compiler + linker (all-in-one) | C |
| ca65 + ld65 | Assembler + linker (part of cc65 suite) | 65xx assembly |
| ACME | Cross-assembler | 65xx assembly |
| llvm-mos | LLVM-based backend for 6502 | C, C++, Rust, Zig |
| x16emu | Official Commander X16 emulator | — |

Most X16 development uses cc65 (C or assembly) or ACME. llvm-mos is newer but gaining traction.

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

Cross-reference: See [Emulator Guide](emulator-guide.md) for detailed emulator usage. See [Memory Map](memory-map.md) for address details.
