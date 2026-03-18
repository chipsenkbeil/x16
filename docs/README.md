# Commander X16 Documentation

Welcome to the Commander X16 development documentation. These guides cover everything from hardware architecture to game development.

## System Architecture

- [Architecture Overview](architecture-overview.md) — CPU, memory, VERA, audio, and I/O subsystems
- [Memory Map](memory-map.md) — Complete address space reference ($0000–$FFFF)
- [Hardware Reference](hardware-reference.md) — Expansion slots, cartridges, I/O ports, SMC, VIAs

## Programming Guides

- [VERA Programming Guide](vera-programming-guide.md) — Graphics layers, sprites, palette, scrolling, PSG, PCM
- [Sound Programming](sound-programming.md) — PSG, YM2151 FM synthesis, PCM playback
- [ROM Reference](rom-reference.md) — KERNAL API, BASIC commands, CMDR-DOS, ML Monitor
- [Game Development Guide](game-development-guide.md) — Game loops, input, sprites, tiles, collision, audio

## Development Tools

- [Development Guide](development-guide.md) — Toolchains (cc65, ca65, ACME), building, debugging
- [Emulator Guide](emulator-guide.md) — Installation, CLI options, debugger, HostFS
- [Cross-Compilation Guide](cross-compilation-guide.md) — llvm-mos (C/C++, Rust, Zig)

## Community

- [Contributing Guide](contributing-guide.md) — How to contribute to X16Community repositories

---

*These docs aim to be comprehensive but are community-maintained. For the official programmer's reference, see [x16-docs](https://github.com/X16Community/x16-docs). For hardware documentation, see [x16-user-guide](https://github.com/X16Community/x16-user-guide).*
