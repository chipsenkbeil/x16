# {{PROJECT_NAME}}

A Commander X16 project built with Prog8.

Created: {{DATE}}

## Building

```
make          # Compile .p8 to .prg
make run      # Build and run in emulator
make clean    # Remove build artifacts
```

## Project Structure

```
src/          Prog8 source files (.p8)
assets/       Graphics, sounds, data files
build/        Build output (gitignored)
```

## About Prog8

[Prog8](https://prog8.readthedocs.io) is a compiled, structured programming language targeting 6502/65C02 machines with first-class Commander X16 support. It compiles to optimized 6502 assembly.

### Installation

**macOS (Homebrew):**
```bash
brew install prog8
```

**Other platforms:**
Prog8 requires Java 11+ and 64tass assembler. Download the latest release JAR from [GitHub](https://github.com/irmen/prog8/releases).

### Key Features

- Structured syntax (no line numbers, no GOTO)
- Built-in libraries: `textio`, `graphics`, `math`, `syslib`
- First-class VERA and X16 hardware support
- Compiles to optimized 6502 assembly via 64tass
- Floating point and fixed-point math support
