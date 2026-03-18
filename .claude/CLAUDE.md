# Commander X16 Development Environment

## Quick Reference
- `make new-project NAME=foo TEMPLATE=cc65-c` — Scaffold new project
- `make build PROJECT=projects/foo` — Build a project
- `make run PROJECT=projects/foo` — Build + run in emulator
- `make list-templates` — Show available templates + toolchain status
- `make setup` — Install toolchain (cc65, emulator, ROM)
- `make clean PROJECT=projects/foo` — Remove build artifacts

## Templates

| Template | Language | Compiler | Entry Point | Build |
|----------|----------|----------|-------------|-------|
| cc65-c (default) | C | cl65 | src/main.c | `make` |
| ca65-asm | 65C02 ASM | ca65+ld65 | src/main.s | `make` |
| acme-asm | 65C02 ASM | ACME | src/main.a | `make` |
| basic | BASIC | none | src/main.bas | runtime only |
| prog8 | Prog8 | prog8c | src/main.p8 | `make` |
| llvm-mos-c | C/C++ | mos-cx16-clang | src/main.c | `make` |
| rust-mos | Rust | cargo (Docker) | src/main.rs | `make` |

All compiled templates output `.prg` files with BASIC stub at $0801 ("10 SYS 2061"), main code at $080D.

## Project Structure Convention
Every project follows: src/ (source), assets/ (graphics/sound data), build/ (output, gitignored), Makefile, README.md.

## Template Placeholders
Templates use `{{PROJECT_NAME}}`, `{{DATE}}`, `{{YEAR}}` — replaced at project creation by scripts/new-project.sh.

## Documentation
Comprehensive docs in docs/:
- architecture-overview.md — CPU, memory, VERA, audio, I/O
- memory-map.md — Complete $0000-$FFFF address space
- hardware-reference.md — Expansion, cartridges, SMC
- development-guide.md — Toolchain setup, first program
- game-development-guide.md — Game loops, VSYNC, input, sprites, collisions
- vera-programming-guide.md — Graphics layers, sprites, palette, scrolling
- sound-programming.md — PSG, YM2151 FM, PCM playback
- cross-compilation-guide.md — cc65 vs llvm-mos vs Rust comparison
- rom-reference.md — KERNAL API and ROM bank details
- emulator-guide.md — x16emu options and debugging

## X16 Hardware Essentials (for code generation)

### Memory Layout
- $0000-$0001: RAM_BANK ($00), ROM_BANK ($01) select registers
- $0002-$0021: KERNAL virtual registers r0-r15 (16-bit, little-endian)
- $0022-$007F: User zero page (94 bytes, fastest access)
- $0100-$01FF: CPU stack (256 bytes, grows downward)
- $0801-$9EFF: User program space (~38 KB)
- $9F00-$9F0F: VIA1 (I2C, SNES controllers)
- $9F10-$9F1F: VIA2 (IEC serial, SD card SPI)
- $9F20-$9F3F: VERA registers
- $9F40-$9F41: YM2151 FM synth (address, data)
- $A000-$BFFF: Banked RAM (8 KB window, 256 banks = 2 MB total, selected by $00)
- $C000-$FFFF: Banked ROM (16 KB window, selected by $01)

### VERA Registers ($9F20-$9F3F)
- $9F20: VERA_ADDR_L — Address bits [7:0]
- $9F21: VERA_ADDR_M — Address bits [15:8]
- $9F22: VERA_ADDR_H — bits [3:0]=addr[19:16], bit 3=DECR, bits [7:4]=auto-increment stride
- $9F23: VERA_DATA0 — Data port 0 (auto-increments)
- $9F24: VERA_DATA1 — Data port 1 (independent address)
- $9F25: VERA_CTRL — bit 0=ADDRSEL, bits [2:1]=DCSEL, bit 7=reset
- $9F26: VERA_IEN — Interrupt enable (VSYNC, LINE, SPRCOL, AFLOW)
- $9F27: VERA_ISR — Interrupt status flags
- $9F29: VERA_DC_VIDEO — Output mode, layer/sprite enable (when DCSEL=0)
- $9F2A/$9F2B: VERA_DC_HSCALE/VSCALE — $80=640x480, $40=320x240
- VRAM: 128 KB ($00000-$1FFFF)
- Sprite attrs: $1FC00-$1FFFF (128 sprites x 8 bytes)
- Palette: $1FA00-$1FBFF (256 colors x 2 bytes, 12-bit RGB)
- PSG registers: $1F9C0-$1F9FF (16 voices x 4 bytes)

### KERNAL Entry Points
- CHROUT ($FFD2): Print character to current output
- GETIN ($FFE4): Get key from keyboard buffer
- CHRIN ($FFCF): Input character from current input
- SETLFS ($FFBA): Set file logical/device/secondary address
- SETNAM ($FFBD): Set filename
- LOAD ($FFD5): Load file to memory
- SAVE ($FFD8): Save memory to file
- OPEN ($FFC0): Open logical file
- CLOSE ($FFC3): Close logical file
- READST ($FFB7): Read I/O status
- MEMORY_FILL ($FF68): Fill memory region
- MEMORY_COPY ($FF6B): Copy memory between banks
- screen_mode ($FF5F): Get/set screen mode
- FETCH ($FE00): Read from any RAM/ROM bank
- STASH ($FE03): Write to any RAM bank

## Critical Best Practices

### VERA Programming
- ALWAYS use auto-increment for sequential VRAM access (set stride in $9F22 bits [7:4])
- Set address registers in order: L ($9F20), M ($9F21), then H ($9F22) — H latches the full address
- Use dual address pointers (ADDRSEL in $9F25) for copy/transform operations
- Update VRAM during VBLANK to prevent tearing
- VERA FX cache write is 4x faster than sequential byte writes for fills

### cc65 C Gotchas
- C89 only (no C99+); printf/sscanf add 2-3 KB of bloat
- `long` (32-bit) operations are very slow — use `unsigned char`/`unsigned int` where possible
- Variables in nested blocks create stack overhead — declare at function scope
- Use `--static-locals` and `-Or` (register keyword) for performance
- cc65 code is ~3-5x slower than hand asm; llvm-mos is ~1.5-2x slower
- Use `#include <cx16.h>`, `<cbm.h>`, `<conio.h>` for X16 APIs

### llvm-mos C
- Drop-in replacement for cc65 in most cases
- 2-5x better optimization, supports C11/C++20
- Use `mos-cx16-clang` instead of `cl65`
- Headers largely compatible with cc65

### 65C02 Assembly
- Use zero page ($22-$7F) for loop counters and frequently accessed vars (1 cycle faster per op)
- Avoid page boundary crossings in tight loops (adds 1 cycle penalty)
- STZ stores zero without touching A register
- PHX/PLX/PHY/PLY avoid A register for push/pull
- Replace JSR+RTS with JMP (tail call optimization)
- LDA/LDX/LDY set zero flag — don't add redundant CMP #0
- ca65: segments BASICSTUB ($0801), CODE ($080D), RODATA, BSS
- ACME: `* = $0801`, `!word`/`!byte`/`!pet` directives, `.label` local labels

### BASIC
- Line-numbered (10, 20, 30...), PETSCII uppercase
- SCREEN, COLOR, CLS for display; GET A$ for input
- No compilation — loaded directly by emulator with -bas flag

### Prog8
- `%import textio` for text I/O, `%zeropage basicsafe` for safe ZP usage
- `txt.print()`, `cbm.GETIN()` for I/O
- Compiler auto-merges identical strings
- Can inline assembly for performance-critical sections

### Rust (Experimental)
- `#![no_std]` + `#![no_main]` required
- KERNAL calls via unsafe transmute of function pointer addresses
- Docker-based build (mrkits/rust-mos for x86_64, mikaellund/rust-mos for ARM)
- Larger binaries than C/asm alternatives

### Game Development Patterns
- Game loop: VSYNC wait -> input -> physics -> collision -> sprite update -> scroll -> VRAM -> audio
- Budget: ~133,333 CPU cycles per frame @ 8 MHz / 60 Hz
- Use hardware scrolling (write scroll registers) — it's free
- Use hardware sprite collision (VERA_ISR bit 3) + software bounding box
- Parallax: Layer 0 scrolls at half speed, Layer 1 at full speed
- Metatiles compress large maps — expand to VRAM as needed

### Audio Patterns
- PSG: 16 voices at VRAM $1F9C0, 4 bytes each (freq_lo, freq_hi, vol/LR, wave/PW)
- YM2151: 8 voices, register address $9F40, data $9F41, MUST check busy flag bit 7
- PCM: FIFO at $9F3D, AFLOW interrupt when <25% full
- Channel allocation: YM ch0-5 + PSG v0-7 for music, YM ch6-7 + PSG v8-15 for SFX
- IRQ-driven music tick at 60 Hz via VSYNC

### Common Pitfalls
- Color 0 is always transparent — don't use for opaque content
- Stack is only 256 bytes ($0100-$01FF) — avoid deep recursion
- Emulator != real hardware — YM2151 timing, composite mode, video timing differ
- VRAM is only 128 KB — plan layout carefully (no room for >1 full 320x240x256 bitmap)
- Always handle missing YM chip gracefully (may not be present)
- Test composite display mode, not just VGA
