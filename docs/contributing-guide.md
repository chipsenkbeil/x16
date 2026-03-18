# Contributing Guide

## Table of Contents

## Community Overview

The Commander X16 is maintained by the X16Community organization on GitHub. The project welcomes contributions from developers, documentation writers, and testers. The community is active on:
- GitHub: [github.com/X16Community](https://github.com/X16Community)
- Forum: [cx16forum.com](https://cx16forum.com)
- Discord: Commander X16 Discord server

## Repository Guide

### x16-emulator
- **Purpose**: Official Commander X16 emulator
- **Language**: C
- **Build prerequisites**: C compiler (gcc/clang), SDL2 development libraries, GNU Make
- **Building**: `make` (ensure SDL2 is installed: `brew install sdl2` on macOS, `sudo apt install libsdl2-dev` on Linux)
- **Testing**: Run the emulator and verify behavior. Automated test suite uses `-test` flag for cycle-limited execution.
- **PR conventions**: Describe the change and test results. Include screenshots for visual changes.

### x16-rom
- **Purpose**: System ROM including KERNAL, BASIC, CMDR-DOS, GEOS, Monitor, and other components
- **Language**: ca65 assembly (cc65 toolchain)
- **Build prerequisites**: cc65 (ca65 + ld65), GNU Make, Python 3 (for build scripts)
- **Building**: `make` produces `build/x16/rom.bin`
- **Testing**: Load the built ROM in the emulator: `x16emu -rom build/x16/rom.bin`. Test the specific functionality you changed (BASIC commands, KERNAL calls, etc.).
- **PR conventions**: Each ROM component has its own subdirectory. Changes should be focused on one component. Include test steps in your PR description.

### x16-docs
- **Purpose**: Official Programmer's Reference Guide
- **Language**: Markdown
- **Build prerequisites**: None (pure Markdown, renders on GitHub)
- **Testing**: Preview Markdown rendering. Verify cross-references. Check code examples for accuracy.
- **PR conventions**: Follow existing document structure. Keep tables formatted consistently. Cross-reference register addresses with the source code.

### vera-module
- **Purpose**: VERA FPGA module source code
- **Language**: Verilog
- **Build prerequisites**: Yosys, nextpnr-ice40, or Lattice toolchain (for synthesis). Verilator for simulation.
- **Building**: See README in the repo for synthesis instructions.
- **Testing**: Simulation with test benches. Changes should be verified against the emulator's VERA implementation.
- **PR conventions**: Include timing analysis if modifying critical paths. Describe behavioral changes and backward compatibility.

### x16-smc
- **Purpose**: System Management Controller firmware (handles power, keyboard, LEDs)
- **Language**: Arduino/C++ (ATtiny816 target)
- **Build prerequisites**: Arduino IDE or arduino-cli, megaTinyCore board package
- **Building**: Compile through Arduino IDE targeting ATtiny816.
- **Testing**: Test on real hardware if possible. The SMC handles power sequencing, so changes can affect system stability.
- **PR conventions**: Be extremely careful with power-related changes. Include oscilloscope captures or logic analyzer traces for timing-critical changes.

### x16-smc-bootloader
- **Purpose**: Bootloader for SMC firmware updates
- **Language**: Arduino/C++ (ATtiny816 target)
- **Build prerequisites**: Same as x16-smc
- **Building**: Same as x16-smc
- **Testing**: Test firmware update path end-to-end. This is safety-critical — a bad bootloader can brick the SMC.
- **PR conventions**: Extreme caution. Changes should be minimal and well-tested.

### x16-demo
- **Purpose**: Demo programs showcasing X16 capabilities
- **Language**: Mixed (ca65 assembly, cc65 C, BASIC)
- **Build prerequisites**: cc65, GNU Make
- **Building**: Individual demos have their own Makefiles.
- **Testing**: Build and run each demo in the emulator.
- **PR conventions**: New demos should include a README, build instructions, and screenshots/descriptions.

### x16-flash
- **Purpose**: ROM and SMC flash update utility
- **Language**: ca65 assembly
- **Build prerequisites**: cc65 (ca65 + ld65)
- **Building**: `make`
- **Testing**: Test ROM update on real hardware (carefully). In the emulator, verify the UI and user flow.
- **PR conventions**: This is safety-critical software. Changes must be thoroughly tested.

### x16-user-guide
- **Purpose**: User-facing hardware guide and getting started documentation
- **Language**: Markdown / LaTeX (varies)
- **Build prerequisites**: Depends on format (may need LaTeX or a Markdown processor)
- **Testing**: Review formatting and accuracy.
- **PR conventions**: Focus on clarity for end users, not developers.

### faq
- **Purpose**: Frequently Asked Questions
- **Language**: Markdown
- **Build prerequisites**: None
- **Testing**: Verify accuracy of answers.
- **PR conventions**: New entries should address common questions from the forum or Discord.

## Development Environment Setup

### Full Setup (for ROM/Emulator Development)

```bash
# Clone all repos
./scripts/clone-repos.sh

# Install build dependencies
./scripts/setup.sh

# Build the ROM
cd upstream/x16-rom
make
# Produces build/x16/rom.bin

# Build the emulator
cd ../x16-emulator
make

# Test with your built ROM
./x16emu -rom ../x16-rom/build/x16/rom.bin
```

### Documentation-Only Setup

```bash
# Clone just the docs repo
git clone https://github.com/X16Community/x16-docs.git
cd x16-docs
# Edit Markdown files, preview on GitHub or with a local Markdown renderer
```

## Code Style

### Assembly (ca65) — ROM and Demos
- Use tabs for indentation in instruction columns
- Labels: lowercase_with_underscores
- Constants/equates: UPPERCASE
- Comments: semicolons, descriptive but not excessive
- One instruction per line
- Group related code with blank lines and section comments

### C — Emulator
- Follow existing style in the file you're modifying
- Use C99 or later
- 4-space indentation (or tabs, match the file)
- Braces on same line for functions

### Verilog — VERA
- Follow Verilog-2001 conventions
- Match existing naming patterns in the codebase

### General
- Keep commits atomic (one logical change per commit)
- Write clear commit messages
- Reference issue numbers where applicable

## Testing Checklist

Before submitting a PR:

- [ ] Code compiles without warnings
- [ ] Tested in the latest emulator release
- [ ] Tested with the latest ROM (if applicable)
- [ ] Existing functionality not broken (regression test)
- [ ] New functionality documented (if adding features)
- [ ] Code follows project conventions
- [ ] PR description includes test steps
- [ ] Screenshots included for visual changes

## Getting Help

- Check existing issues on the relevant repo
- Search the [CX16 Forum](https://cx16forum.com) for similar questions
- Ask in the Discord #development channel
- Reference the [Programmer's Reference](https://github.com/X16Community/x16-docs) for API questions

Cross-reference: See [Development Guide](development-guide.md) for toolchain setup. See [Architecture Overview](architecture-overview.md) for system understanding.
