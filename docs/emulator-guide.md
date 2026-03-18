# Emulator Guide

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Command-Line Options](#command-line-options)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [HostFS (-fsroot)](#hostfs--fsroot)
- [SD Card Images](#sd-card-images)
- [Debugger (F12)](#debugger-f12)
- [Emulator-Specific Registers](#emulator-specific-registers)
- [GIF and WAV Recording](#gif-and-wav-recording)
- [WebAssembly Build](#webassembly-build)
- [Known Differences from Hardware](#known-differences-from-hardware)

## Overview

The Commander X16 emulator (`x16emu`) is the official emulator for the X16 platform. It accurately emulates the 65C02S CPU, VERA graphics/audio, YM2151, VIAs, SD card, and other subsystems. It's the primary development and testing tool for X16 software.

Source: [X16Community/x16-emulator](https://github.com/X16Community/x16-emulator)

## Installation

### Pre-built Binaries (Recommended)

Download the latest release from [GitHub Releases](https://github.com/X16Community/x16-emulator/releases):
- **macOS**: `x16emu_macos.zip` — extract and place `x16emu` on your PATH
- **Linux**: `x16emu_linux.zip` — extract, ensure SDL2 is installed (`sudo apt install libsdl2-2.0-0`)
- **Windows**: `x16emu_win64.zip` — extract to a convenient location

You also need `rom.bin` from the [x16-rom releases](https://github.com/X16Community/x16-rom/releases). Place it in the same directory as `x16emu` or specify with `-rom`.

### Using the Setup Script

```bash
./scripts/setup.sh
```

This installs the emulator, ROM, and other tools automatically.

### Building from Source

```bash
git clone https://github.com/X16Community/x16-emulator.git
cd x16-emulator

# Install SDL2 dependency
# macOS: brew install sdl2
# Linux: sudo apt install libsdl2-dev

make
```

Then build the ROM:
```bash
git clone https://github.com/X16Community/x16-rom.git
cd x16-rom
make
# Produces build/x16/rom.bin
```

## Basic Usage

```bash
# Start emulator (boots to BASIC)
x16emu

# Run a .prg file directly
x16emu -prg myprogram.prg -run

# Specify ROM location
x16emu -rom /path/to/rom.bin

# Set SD card root directory (HostFS)
x16emu -fsroot /path/to/files
```

## Command-Line Options

### Program Loading

| Option | Description |
|---|---|
| `-prg <file>` | Load .prg file into memory (uses file's embedded load address) |
| `-run` | Auto-run the loaded program (simulates `RUN` or `SYS`) |
| `-bas <file>` | Load and run a BASIC program |
| `-rom <file>` | Use specified ROM image (default: `rom.bin` in current dir) |
| `-cart <file>` | Load cartridge ROM image |
| `-nvram <file>` | NVRAM image file (persistent storage) |

### Display

| Option | Description |
|---|---|
| `-scale <n>` | Window scale factor (1, 2, 3, 4; default: 2) |
| `-quality <q>` | Scaling quality: `nearest` (sharp pixels) or `linear` (smooth) |
| `-fullscreen` | Start in fullscreen mode |
| `-nosound` | Disable audio output |

### Hardware Configuration

| Option | Description |
|---|---|
| `-ram <n>` | Set RAM size in KB: 512 (default), 1024, 1536, 2048 |
| `-keymap <layout>` | Keyboard layout (en, de, fr, etc.) |
| `-joy1 <type>` | Joystick 1 type: SNES (default), NES |
| `-joy2 <type>` | Joystick 2 type |
| `-joy3 <type>` | Joystick 3 type |
| `-joy4 <type>` | Joystick 4 type |
| `-rtc` | Enable RTC (Real-Time Clock) emulation |

### Storage

| Option | Description |
|---|---|
| `-fsroot <dir>` | Mount host directory as SD card filesystem (HostFS) |
| `-sdcard <file>` | Use SD card image file |

### Debugging

| Option | Description |
|---|---|
| `-debug` | Enable debug mode (shows CPU trace, VERA state) |
| `-dump <type>` | Dump state on exit: `cpu`, `ram`, `bank`, `vram` |
| `-log <flags>` | Enable log output (K=KERNAL, S=SD, V=VERA) |
| `-test <n>` | Exit with code after N cycles (for automated testing) |
| `-echo` | Echo KERNAL CHROUT to host terminal |
| `-warp` | Run at maximum speed (no frame limiting) |

### Miscellaneous

| Option | Description |
|---|---|
| `-version` | Show emulator version |
| `-help` | Show all options |
| `-gif <file>` | Record GIF animation (F9 to start/stop) |
| `-wav <file>` | Record audio to WAV file (F10 to start/stop) |

## Keyboard Shortcuts

### General

| Key | Action |
|---|---|
| F1 | Toggle warp mode (max speed) |
| F5 | Save screenshot (PNG) |
| F7 | Save/restore state |
| F8 | Toggle recording (activity LED) |
| F9 | Toggle GIF recording |
| F10 | Toggle WAV recording |
| F11 | Toggle fullscreen |
| F12 | Open debugger |
| Ctrl+V | Paste text from clipboard |
| Ctrl+R | Reset (warm reset) |
| Ctrl+Shift+R | Hard reset (power cycle) |
| Ctrl+Q | Quit emulator |

### In BASIC

| Key | Action |
|---|---|
| Ctrl+C | Break (stop running program) |
| Ctrl+S | Toggle scroll pause |
| Run/Stop | STOP key (mapped to Escape on most keyboards) |

### SNES Controller Mapping (Keyboard)

When using keyboard as SNES controller:

| Keyboard | SNES Button |
|---|---|
| Arrow keys | D-Pad |
| X | B button |
| Z | A button |
| A | Y button |
| S | X button |
| D | L button |
| C | R button |
| Return | Start |
| Left Shift | Select |

## HostFS (-fsroot)

HostFS maps a host directory to the emulated SD card filesystem:

```bash
x16emu -fsroot ./myfiles
```

This makes all files in `./myfiles/` accessible to X16 programs via standard file I/O:

```basic
LOAD "MYPROGRAM.PRG"
OPEN 1,8,0,"MYFILE.TXT"
```

Notes:
- File names are case-insensitive (matching FAT32 behavior)
- Create subdirectories on the host for CD commands
- Faster than SD card images for development iteration
- Changes on host are immediately visible to the emulator

## SD Card Images

For testing with a real FAT32 filesystem image:

```bash
# Create a 32MB image (macOS)
dd if=/dev/zero of=sdcard.img bs=1M count=32
# Format as FAT32
# macOS: Use Disk Utility or mkfs.fat (from dosfstools)
# Linux: mkfs.fat -F 32 sdcard.img

# Mount, copy files, unmount
# Then use:
x16emu -sdcard sdcard.img
```

For development, HostFS (`-fsroot`) is usually more convenient.

## Debugger (F12)

The built-in debugger is a powerful tool for development. Press F12 to enter.

### Debugger Panels

- **CPU**: Shows PC, A, X, Y, SP, status flags (NVBDIZC)
- **Disassembly**: Shows instructions around the current PC
- **Memory**: Hex dump of memory
- **Stack**: Current stack contents
- **Breakpoints**: Active breakpoints list
- **VERA**: VERA register state
- **VRAM**: VERA VRAM viewer
- **Sprites**: Sprite attribute viewer
- **Palette**: Color palette viewer

### Debugger Commands

| Command | Description |
|---|---|
| `s` / Step | Execute single instruction |
| `n` / Next | Execute until next line (step over JSR) |
| `c` / Continue | Resume execution |
| `b <addr>` | Set breakpoint at address |
| `del <n>` | Delete breakpoint number N |
| `info b` | List breakpoints |
| `x <addr> [count]` | Examine memory |
| `set <addr> <val>` | Set memory value |
| `r` | Show registers |
| `bt` | Show call stack (backtrace) |

### Breakpoint Types

```
b $080D           # Break at address
b $080D if A==$FF # Conditional break
watch $9F23       # Break on write to address
rwatch $A000      # Break on read from address
```

### VERA Debugging

The debugger can inspect:
- VERA register state (all registers)
- VRAM contents (visual hex viewer)
- Layer configuration and map data
- Sprite attributes and images
- Palette entries

### Tips

1. Use `-debug` flag to get CPU trace output to the terminal
2. Write debug markers: `STA $9FB0` outputs characters to the host console
3. Read `$9FB2` to detect emulator vs. real hardware
4. Use the VERA VRAM viewer to verify tile/sprite data was loaded correctly
5. Set breakpoints on KERNAL entry points to trace I/O operations

## Emulator-Specific Registers

These registers only exist in the emulator (reading on real hardware returns open bus):

| Address | Name | Description |
|---|---|---|
| $9FB0 | EMU_DEBUG | Write: output character to host console |
| $9FB1 | EMU_VERBOSITY | Write: set log verbosity level |
| $9FB2 | EMU_DETECT | Read: returns $45 ('E') if in emulator |
| $9FB3 | EMU_KEYMAP | Read/write: keyboard layout setting |

### Using Debug Output

```asm
; Print a debug string to host console
ldx #0
@dbg:
    lda debug_msg,x
    beq @dbg_done
    sta $9FB0
    inx
    bra @dbg
@dbg_done:

debug_msg: .byte "Reached checkpoint 1", $0A, 0
```

```c
// C equivalent
void debug_print(const char *msg) {
    while (*msg) {
        *(volatile char*)0x9FB0 = *msg++;
    }
}
```

## GIF and WAV Recording

### GIF Recording
```bash
# Specify output file
x16emu -gif recording.gif

# In emulator, press F9 to start/stop recording
# GIF captures at screen resolution
```

### WAV Recording
```bash
# Specify output file
x16emu -wav audio.wav

# Press F10 to start/stop recording
# Records all audio output (PSG + YM2151 + PCM)
```

## WebAssembly Build

The emulator can be compiled to WebAssembly for running X16 programs in a web browser. The X16Community provides a web-based version for quick testing.

This is useful for:
- Sharing demos without requiring users to install anything
- Embedding X16 programs in web pages
- Quick testing on any platform

## Known Differences from Hardware

The emulator is highly accurate but has some differences:
- Timing may not be cycle-exact in all cases
- SD card access patterns may differ from real SPI timing
- USB keyboard vs. PS/2 keyboard behavior
- Audio output timing/latency depends on host SDL2 audio
- The emulator-specific registers ($9FB0-$9FBF) do not exist on hardware

Always test on real hardware (or the most recent emulator release) before distributing software.

Cross-reference: See [Development Guide](development-guide.md) for debugging workflows. See [Hardware Reference](hardware-reference.md) for real hardware details.
