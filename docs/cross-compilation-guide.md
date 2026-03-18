# Cross-Compilation Guide

## Table of Contents

## Overview

While cc65 is the traditional C compiler for 6502 targets, modern alternatives offer significantly better optimization and support for C++, Rust, and other languages through the LLVM-based [llvm-mos](https://llvm-mos.org/) project.

## cc65 (Standard Path)

cc65 is the most widely used and best-supported toolchain for X16 development.

### Installation
See [Development Guide](development-guide.md) for installation instructions.

### Usage
```bash
# Compile and link in one step
cl65 -t cx16 -o game.prg src/main.c

# Separate compilation
cc65 -t cx16 -O -o main.s src/main.c
ca65 -t cx16 -o main.o main.s
ld65 -t cx16 -o game.prg main.o cx16.lib
```

### Strengths
- Mature, stable, well-documented
- Excellent X16 support (cx16 target)
- Large library of headers (cx16.h, cbm.h, conio.h, joystick.h, etc.)
- Easy inline assembly
- Active community using cc65 for X16

### Limitations
- Limited optimization (register allocation, constant folding, but no advanced optimization)
- C89-only (no C99/C11 features beyond a few extensions)
- Generates noticeably slower code than hand-written assembly or llvm-mos
- No C++ support

## llvm-mos C/C++

[llvm-mos](https://llvm-mos.org/) is an LLVM backend targeting 6502-family CPUs. It brings modern compiler technology to 8-bit development.

### Installation

Download pre-built SDK from [llvm-mos releases](https://github.com/llvm-mos/llvm-mos-sdk/releases):

```bash
# Download and extract (example for macOS)
curl -LO https://github.com/llvm-mos/llvm-mos-sdk/releases/latest/download/llvm-mos-macos.tar.xz
tar xf llvm-mos-macos.tar.xz
export PATH="$PWD/llvm-mos/bin:$PATH"
```

Or build from source (requires CMake, LLVM build deps):
```bash
git clone https://github.com/llvm-mos/llvm-mos-sdk.git
cd llvm-mos-sdk
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/llvm-mos
make -j$(nproc)
make install
```

### Usage

```bash
# Compile C for Commander X16
mos-cx16-clang -O2 -o game.prg src/main.c

# Compile C++
mos-cx16-clang++ -O2 -o game.prg src/main.cpp

# With specific options
mos-cx16-clang -Os -o game.prg src/main.c  # optimize for size
```

### Differences from cc65

| Feature | cc65 | llvm-mos |
|---|---|---|
| Language | C89 | C11, C++20 |
| Optimization | Basic | Full LLVM pipeline |
| Code speed | ~3-5x slower than hand ASM | ~1.5-2x slower than hand ASM |
| Binary size | Larger | Generally smaller |
| Inline ASM | `__asm__("...")` | `__asm__("...")` (GCC syntax) |
| Headers | cx16.h, cbm.h, conio.h | Partial cx16 support, growing |
| Community | Large, X16-focused | Growing |
| Maturity | Very stable | Active development |

### llvm-mos X16 Headers

llvm-mos provides its own headers for X16 targets. The API is similar but not identical to cc65:

```c
#include <cx16.h>    // X16-specific definitions
#include <cbm.h>     // Commodore-compatible functions
#include <stdio.h>   // Standard I/O

int main(void) {
    // VERA access
    VERA.ctrl = 0;
    VERA.addr_hi = 0x11;  // auto-increment 1, bank 1
    VERA.addr_mid = 0x00;
    VERA.addr_lo = 0x00;
    VERA.data0 = 0xFF;    // write to VRAM
    return 0;
}
```

### Mixing C and Assembly

```c
// Inline assembly (GCC extended syntax)
void chrout(char c) {
    __asm__ volatile (
        "jsr $FFD2"
        : // no outputs
        : "a"(c)  // input: c in A register
        : // no clobbers
    );
}
```

### Linker Scripts

llvm-mos uses linker scripts similar to ld65 configs but in LLVM/LLD format. The default cx16 target provides a working configuration.

## Prog8

[Prog8](https://prog8.readthedocs.io) is a compiled, structured programming language specifically designed for 8-bit 6502/65C02 machines. It has first-class Commander X16 support.

### What is Prog8?

Prog8 is not a C-family language or BASIC — it is its own compiled language with structured syntax (no line numbers, no GOTO). It compiles to optimized 6502 assembly via the 64tass assembler. Prog8 was designed specifically for retro computers and understands their constraints natively.

### Installation

**macOS (Homebrew):**
```bash
brew install prog8
```

**Other platforms:**
Prog8 requires Java 11+ and the 64tass assembler. Download the latest release JAR from [GitHub](https://github.com/irmen/prog8/releases), or use the setup script:
```bash
./scripts/setup.sh --prog8
```

### Usage

```bash
# Compile for Commander X16
prog8c -target cx16 -out build src/main.p8

# Run in emulator
x16emu -prg build/main.prg -run
```

### Example

```prog8
%import textio
%import math
%zeropage basicsafe

main {
    sub start() {
        txt.clear_screen()
        txt.print("hello from prog8!\n")

        ; Direct VERA access
        cx16.VERA_CTRL = 0
        cx16.VERA_ADDR_L = $00
        cx16.VERA_ADDR_M = $00
        cx16.VERA_ADDR_H = $11  ; auto-increment 1, bank 1

        ; Wait for keypress
        repeat {
            cx16.r0L = cbm.GETIN()
            if cx16.r0L != 0
                break
        }
    }
}
```

### Key Features

- Structured syntax with `if`, `when`, `for`, `repeat`, `while`
- Built-in libraries: `textio`, `graphics`, `math`, `syslib`, `floats`
- First-class X16 hardware access (`cx16.VERA_*`, `cx16.r0`-`cx16.r15`)
- Floating-point and fixed-point math
- Inline assembly blocks for performance-critical code
- Compiles to efficient 6502 assembly via 64tass

### Comparison to cc65 C

| Feature | cc65 C | Prog8 |
|---|---|---|
| Language style | C89 | Custom structured |
| Learning curve | Moderate (know C) | Low (purpose-built) |
| X16 integration | Via headers | Built-in |
| Output quality | Moderate | Good |
| Inline assembly | `__asm__()` | `%asm {{ }}` |
| Libraries | Standard C + cx16 | Purpose-built retro |
| Community | Large | Growing |

## rust-mos (Rust for 6502)

Rust can target 6502 through [rust-mos](https://github.com/mrk-its/rust-mos), a **fork of the Rust compiler** with an llvm-mos backend. This is not standard Rust — it requires a custom toolchain distributed via Docker.

### Setup

rust-mos is distributed as a Docker image. There is no native install.

```bash
# x86_64 / Intel Mac
docker pull mrkits/rust-mos

# ARM / Apple Silicon
docker pull mikaellund/rust-mos
```

Or use the setup script:
```bash
./scripts/setup.sh --rust-mos
```

### Project Setup

Create `.cargo/config.toml`:
```toml
[build]
target = "mos-cx16-none"

[unstable]
build-std = ["core"]
```

### Example

```rust
#![no_std]
#![no_main]

use core::panic::PanicInfo;

const CHROUT: usize = 0xFFD2;
const GETIN: usize = 0xFFE4;

#[no_mangle]
pub extern "C" fn main() -> u8 {
    let msg = b"HELLO FROM RUST!\r";
    for &byte in msg {
        unsafe {
            let chrout: extern "C" fn(u8) = core::mem::transmute(CHROUT);
            chrout(byte);
        }
    }
    0
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
```

### Building

```bash
# Build inside the Docker container
docker run --rm -v "$(pwd)":/src -w /src mrkits/rust-mos \
    cargo build --release

# Output at: target/mos-cx16-none/release/<project-name>
x16emu -prg target/mos-cx16-none/release/my-project -run
```

### Hardware Access

The [mos-hardware](https://github.com/mlund/mos-hardware) crate provides typed register definitions for X16 hardware (VERA, VIA, YM2151) via the `cx16` feature:

```toml
[dependencies]
mos-hardware = { version = "0.4", features = ["cx16"] }
```

### Limitations

- **`no_std` only** — no standard library, no heap allocator by default
- **Docker required** — the rust-mos compiler runs inside a container
- **16-bit pointer issues** — some Rust patterns assume pointer sizes > 16 bits
- **Larger binaries** — Rust codegen overhead is noticeable on 6502 vs C
- **No X16 community adoption** — very few proven X16 projects exist in Rust
- **Not official Rust** — rust-mos is a compiler fork, not an upstream target

### Resources

- [rust-mos](https://github.com/mrk-its/rust-mos) — Compiler fork
- [mos-hardware](https://github.com/mlund/mos-hardware) — Hardware register crate
- [llvm-mos Rust wiki](https://llvm-mos.org/wiki/Rust) — Setup and usage guide

## llvm-mos Zig

Zig can also target 6502 through llvm-mos, though support is experimental.

### Overview

```zig
const std = @import("std");

export fn main() u8 {
    const CHROUT: *volatile fn(u8) void = @ptrFromInt(0xFFD2);
    const msg = "HELLO FROM ZIG!\r";
    for (msg) |byte| {
        CHROUT(byte);
    }
    return 0;
}
```

### Status
- Very experimental
- Requires custom Zig build with llvm-mos backend
- Limited testing on X16 target
- Promising for the future but not recommended for production use today

## Comparison Table

| Feature | cc65 | llvm-mos C | llvm-mos C++ | Prog8 | rust-mos | llvm-mos Zig |
|---|---|---|---|---|---|---|
| Maturity | Production | Beta | Beta | Production | Experimental | Experimental |
| Language std | C89 | C11 | C++20 | Custom | Rust 2021 (no_std) | Zig 0.11+ |
| Optimization | Basic | Excellent | Excellent | Good | Excellent | Excellent |
| X16 support | Full | Partial | Partial | First-class | Minimal (crate) | None |
| Inline ASM | Yes | Yes (GCC) | Yes (GCC) | Yes | Yes (asm!) | Yes |
| Binary size | Larger | Smaller | Moderate | Moderate | Larger | Moderate |
| Dependencies | cc65 | llvm-mos SDK | llvm-mos SDK | Java + 64tass | Docker | Custom Zig |
| Community | Large | Growing | Growing | Growing | Tiny | Tiny |
| Recommended | Yes | Yes | Caution | Yes | Experimental | Experimental |

## Practical Considerations

### Binary Size

llvm-mos generally produces smaller binaries than cc65 due to better optimization:
- A simple "hello world" may be 200-500 bytes with llvm-mos vs 1-2 KB with cc65
- The difference grows with code complexity
- For very small programs, the difference is less significant

### Mixing C and Assembly

All toolchains support inline assembly and linking with external .s files:

**cc65**: Natural integration with ca65 assembly files
**llvm-mos**: Uses GCC-style inline assembly, can link with ca65 .o files via a compatibility layer

### KERNAL Calls

Regardless of language, you'll use the same KERNAL API:
- Set up parameters in registers or virtual registers (r0-r15)
- Call the jump table address
- Read return values

The mechanism differs by language:
- **cc65 C**: Use wrapper functions or inline assembly
- **llvm-mos C**: Use inline assembly with register constraints
- **Rust**: Use `unsafe` blocks with transmuted function pointers
- **Zig**: Use `@ptrFromInt` for KERNAL addresses

### Which Toolchain Should I Use?

- **Just getting started?** → cc65. Best documentation, most examples, easiest setup.
- **Want a high-level language without C?** → Prog8. Purpose-built for retro, excellent X16 integration.
- **Need better performance from C?** → llvm-mos C. Drop-in improvement for most code.
- **Want C++ features?** → llvm-mos C++. Only option for 6502 C++.
- **Rust enthusiast?** → rust-mos. Doable but expect rough edges and Docker overhead.
- **Just exploring?** → Any of the above. The X16 is a great platform for learning.

Cross-reference: See [Development Guide](development-guide.md) for cc65 setup and usage. See [ROM Reference](rom-reference.md) for KERNAL API details.
