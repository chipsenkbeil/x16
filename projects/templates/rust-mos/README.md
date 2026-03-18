# {{PROJECT_NAME}}

**EXPERIMENTAL** — A Commander X16 project built with Rust via rust-mos.

Created: {{DATE}}

## Building

```
make          # Build the .prg (requires Docker)
make run      # Build and run in emulator
make clean    # Remove build artifacts
```

## Project Structure

```
src/          Rust source files
.cargo/       Cargo configuration (target = mos-cx16-none)
assets/       Graphics, sounds, data files
build/        Build output (gitignored)
```

## ⚠ EXPERIMENTAL

rust-mos is a fork of the Rust compiler with an llvm-mos backend. It is not part of the official Rust project and has significant limitations:

- **`no_std` only** — no standard library, no heap allocator by default
- **Docker required** — rust-mos runs inside a Docker container
- **16-bit pointer issues** — some Rust patterns assume pointer sizes > 16 bits
- **Larger binaries** — Rust codegen overhead is noticeable on 6502
- **Limited community** — very few proven X16 examples exist

## Requirements

### Docker

```bash
# x86_64 / Intel Mac
docker pull mrkits/rust-mos

# ARM / Apple Silicon
docker pull mikaellund/rust-mos
```

## Resources

- [rust-mos](https://github.com/mrk-its/rust-mos) — Rust compiler fork
- [mos-hardware](https://github.com/mlund/mos-hardware) — Hardware register definitions (cx16 feature)
- [llvm-mos Rust wiki](https://llvm-mos.org/wiki/Rust) — Setup and usage guide
