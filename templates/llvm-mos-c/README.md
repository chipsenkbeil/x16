# {{PROJECT_NAME}}

A Commander X16 project built with llvm-mos C.

Created: {{DATE}}

## Building

```
make          # Build the .prg
make run      # Build and run in emulator
make clean    # Remove build artifacts
```

## Project Structure

```
src/          C source files
assets/       Graphics, sounds, data files
build/        Build output (gitignored)
```

## About llvm-mos

[llvm-mos](https://llvm-mos.org/) is an LLVM backend targeting 6502 CPUs. It provides modern C11/C++20 support with superior optimization compared to cc65.

### Installation

Download the pre-built SDK from [llvm-mos releases](https://github.com/llvm-mos/llvm-mos-sdk/releases):

```bash
# macOS
curl -LO https://github.com/llvm-mos/llvm-mos-sdk/releases/latest/download/llvm-mos-macos.tar.xz
tar xf llvm-mos-macos.tar.xz
export PATH="$PWD/llvm-mos/bin:$PATH"

# Linux
curl -LO https://github.com/llvm-mos/llvm-mos-sdk/releases/latest/download/llvm-mos-linux.tar.xz
tar xf llvm-mos-linux.tar.xz
export PATH="$PWD/llvm-mos/bin:$PATH"
```

### Differences from cc65

- Supports C11 and C++20 (cc65 is C89-only)
- Full LLVM optimization pipeline (2-5x faster output than cc65)
- Generally smaller binaries
- Uses `mos-cx16-clang` instead of `cl65`
- No `-t cx16` flag needed (target is in the binary name)

See [Cross-Compilation Guide](../../../docs/cross-compilation-guide.md) for details.
