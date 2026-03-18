# Web References

URLs visited during the initial research and knowledge base creation for this project.

## User-Provided Starting Points

These three URLs were provided by the user as the starting points for research:

| URL | Purpose |
|-----|---------|
| https://github.com/X16Community | X16 community GitHub organization — list all repos |
| https://www.commanderx16.com/ | Official Commander X16 project site |
| https://cx16forum.com/forum/ | Community forum structure and discussion categories |

## X16 Community GitHub Repositories

| URL | What Was Learned |
|-----|-----------------|
| https://github.com/X16Community | 10 repositories: x16-emulator (C, 277 stars), x16-rom (Assembly, 68 stars), x16-docs (CSS, 121 stars), x16-smc-bootloader, faq, x16-smc, x16-user-guide, vera-module, x16-demo, x16-flash. All actively maintained. |
| https://github.com/X16Community/x16-emulator | Emulator features, CLI options (-keymap, -prg, -bas, -run, -sdcard), build instructions, release availability via GitHub and snap store. |
| https://github.com/X16Community/x16-rom | ROM build requires GNU Make, Python 3.7+, cc65 assembler, LZSA compression utility. Project structure and contributor info. |
| https://github.com/X16Community/x16-docs | Full documentation repository structure — all reference markdown files listed. |
| https://github.com/X16Community/x16-demo | Demo repository structure showing how assembly programs are organized and built. |

## Official X16 Reference Documentation (x16-docs raw files)

Systematically fetched the entire official programmer's reference from the x16-docs repository:

| URL | What Was Learned |
|-----|-----------------|
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2001%20-%20Overview.md | Complete system overview: 65C02S at 8MHz, 64KB address space with banking, memory map details. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2002%20-%20Getting%20Started.md | Toolchain setup, program creation workflow, getting started guide. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2004%20-%20BASIC.md | BASIC V2 compatibility plus X16 extensions for graphics, audio, file I/O, sprites. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2005%20-%20KERNAL.md | KERNAL jump table addresses ($FFxx), parameters, return values; X16-specific additions beyond C64 KERNAL. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2007%20-%20Machine%20Language%20Monitor.md | Built-in ML monitor commands for debugging: memory examination, disassembly, breakpoints, register display. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2008%20-%20Memory%20Map.md | Every address range $0000-$FFFF: zero page banking registers, KERNAL r0-r15, user program space, I/O ($9F00-$9FFF), banked RAM ($A000-$BFFF, up to 256 banks = 2MB), banked ROM ($C000-$FFFF, 32 ROM + 224 cartridge banks). |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2009%20-%20VERA%20Programmer%27s%20Reference.md | VERA registers at $9F20-$9F3F (36 registers), VRAM layout: graphics $00000-$1F9BF, PSG $1F9C0-$1F9FF, palette $1FA00-$1FBFF, sprite attrs $1FC00-$1FFFF. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2010%20-%20VERA%20FX%20Reference.md | VERA FX hardware acceleration: blitting operations, polygon fill, cache operations. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2011%20-%20Sound%20Programming.md | YM2151 8-channel FM synthesis at $9F40-$9F41, PSG 16 channels (pulse/saw/tri/noise), PCM up to 48kHz 16-bit stereo with 4KB FIFO. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2012%20-%20IO%20Programming.md | Two 65C22 VIAs: VIA1 ($9F00) for NES controllers, I2C, IEC serial; VIA2 ($9F10) user port. I2C bus for SMC communication. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2013%20-%20Working%20with%20CMDR-DOS.md | DOS commands compatible with Commodore DOS, adapted for SD cards with FAT32, long filenames, timestamps, partitions, subdirectories. |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2014%20-%20Hardware.md | 4 expansion slots with 60-pin edge connector, IO3-IO7 address ranges, cartridge boot protocol (bank 32, "CX16" signature at $C000). |
| https://raw.githubusercontent.com/X16Community/x16-docs/master/X16%20Reference%20-%2015%20-%20Upgrade%20Guide.md | How to update ROM, VERA, and SMC firmware with tools and process warnings. |

## External Technical References

| URL | Why Visited | What Was Learned |
|-----|-------------|-----------------|
| https://www.pagetable.com/?p=1373 | X16 architectural deep-dive | 512KB ROM in 32 banks of 16KB each; Bank 0 = KERNAL + DOS; ROM uses 19-bit addressing with top 5 bits selecting ROM bank via zero page $01. |
| https://www.8bitcoding.com/p/vera-overview.html | VERA chip capabilities | VERA specs: 640x480@60Hz (alt 320x240), 256 colors from 4096, 2 layers for tile/bitmap, 128 sprites up to 64x64, 128KB VRAM, 16-channel PSG, PCM playback, VGA/NTSC/S-Video/RGB output. |
| https://www.commanderx16.com/faq.html | Project specs and capabilities | FAQ with X16 specifications, goals, and hardware capabilities. |

## Toolchain Documentation

| URL | Why Visited | What Was Learned |
|-----|-------------|-----------------|
| https://cc65.github.io/doc/cx16.html | cc65 X16 target documentation | Build commands (`cl65 -o program.prg -t cx16 source.c`), X16-specific target config, available headers, memory layout, startup code, library functions. |
| https://llvm-mos.org/wiki/Welcome | Alternative LLVM-based 6502 compiler | LLVM-MOS supports C/C++ (C99/C++11), Rust, and Zig for 6502 targets. Confirms Commander X16 support with working demos. |

## Web Searches Performed

8 search queries were used to discover the external references above:

1. `Commander X16 technical architecture ROM VERA chip`
2. `X16 ROM structure BASIC KERNAL organization`
3. `VERA chip X16 video audio sprites tiles capabilities`
4. `Commander X16 65C02 CPU processor specifications`
5. `X16 emulator development how to use`
6. `X16 SMC System Management Controller functions`
7. `X16 development toolchain cc65 ACME assembler`
8. `X16 game development software structure programming`
