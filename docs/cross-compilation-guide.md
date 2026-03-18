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

## llvm-mos Rust

Rust can target 6502 through llvm-mos, but this requires `no_std` development.

### Setup

```bash
# Install llvm-mos Rust support
# (Requires the llvm-mos SDK and a custom Rust toolchain)
# See: https://github.com/llvm-mos/llvm-mos-rs

# Install mos-platform for Rust
cargo install mos-platform
```

### Example

```rust
#![no_std]
#![no_main]

use core::panic::PanicInfo;

const CHROUT: *const () = 0xFFD2 as *const ();

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

### Considerations
- `no_std` only — no standard library allocator, no heap by default
- Must manage memory manually (or bring a simple allocator)
- Core library types (Option, Result, iterators) work fine
- The compiler generates very efficient code
- Community support is nascent but growing

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

| Feature | cc65 | llvm-mos C | llvm-mos C++ | llvm-mos Rust | llvm-mos Zig |
|---|---|---|---|---|---|
| Maturity | Production | Beta | Beta | Alpha | Experimental |
| Language std | C89 | C11 | C++20 | Rust 2021 | Zig 0.11+ |
| Optimization | Basic | Excellent | Excellent | Excellent | Excellent |
| X16 headers | Full | Partial | Partial | Minimal | None |
| Inline ASM | Yes | Yes (GCC) | Yes (GCC) | Yes (asm!) | Yes |
| Binary size | Larger | Smaller | Moderate | Moderate | Moderate |
| Community | Large | Growing | Growing | Small | Tiny |
| Recommended | Yes | Yes | Caution | Experimental | Experimental |

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
- **Need better performance from C?** → llvm-mos C. Drop-in improvement for most code.
- **Want C++ features?** → llvm-mos C++. Only option for 6502 C++.
- **Rust enthusiast?** → llvm-mos Rust. Doable but expect rough edges.
- **Just exploring?** → Any of the above. The X16 is a great platform for learning.

Cross-reference: See [Development Guide](development-guide.md) for cc65 setup and usage. See [ROM Reference](rom-reference.md) for KERNAL API details.
