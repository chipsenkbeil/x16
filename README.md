# Commander X16 Development Environment

A comprehensive knowledge base, project scaffolding system, and development environment for the [Commander X16](https://www.commanderx16.com/) retro computer.

The Commander X16 is an actively-developed 8-bit computer built around the WDC 65C02S CPU at 8 MHz, with VERA FPGA-based graphics and audio, YM2151 FM synthesis, 512 KB banked RAM, SD card storage, and expansion slots. It is designed by a community led by David Murray (The 8-Bit Guy).

## Quick Start

```bash
# Clone this repo
git clone https://github.com/your-user/x16.git && cd x16

# Install toolchain (cc65, emulator, ROM)
make setup

# Create your first project
make new-project NAME=hello-world
```

## What's Inside

```
docs/               Comprehensive X16 documentation
  architecture-overview.md    System architecture & block diagram
  memory-map.md               Complete address space reference
  rom-reference.md            KERNAL API, BASIC, DOS, Monitor
  vera-programming-guide.md   VERA graphics & audio deep dive
  sound-programming.md        PSG, YM2151, PCM audio
  development-guide.md        Toolchains, building, debugging
  emulator-guide.md           Emulator usage & debugger
  hardware-reference.md       Expansion, cartridges, I/O, SMC
  game-development-guide.md   Game programming patterns
  contributing-guide.md       How to contribute to X16 repos
  cross-compilation-guide.md  llvm-mos, Rust, Zig for X16

templates/          Project templates
  cc65-c/                     C project template (default)
  ca65-asm/                   ca65 assembly template
  acme-asm/                   ACME assembly template
  basic/                      Interpreted BASIC template
  prog8/                      Prog8 compiled language template
  llvm-mos-c/                 llvm-mos C template
  rust-mos/                   Rust template (experimental)
  shared/                     Shared include files

projects/           Your projects (created via make new-project)

scripts/            Automation scripts
  setup.sh                    Install toolchain
  clone-repos.sh              Clone X16Community repos
  new-project.sh              Scaffold a new project
  run.sh                      Build & run in emulator

upstream/           Cloned X16Community repositories (gitignored)
```

## Make Targets

```
make help            Show all targets (default)
make setup           Install toolchain (cc65, emulator, ROM; use --prog8/--llvm-mos for extras)
make clone-upstream  Clone all X16Community repos into upstream/
make new-project     Scaffold new project (NAME=foo TEMPLATE=cc65-c)
make build           Build a project (PROJECT=projects/foo)
make run             Build + run in emulator (PROJECT=projects/foo)
make clean           Remove build artifacts
make list-templates  Show available templates
```

## Documentation

Start with the [documentation index](docs/README.md) for a guided tour of all available docs. Key references:

- [Architecture Overview](docs/architecture-overview.md) - How the X16 hardware fits together
- [Memory Map](docs/memory-map.md) - Complete address space reference
- [VERA Programming Guide](docs/vera-programming-guide.md) - Graphics and audio via VERA
- [Development Guide](docs/development-guide.md) - Setting up and building X16 software
- [Game Development Guide](docs/game-development-guide.md) - Patterns for building X16 games

## X16Community Repositories

| Repository | Description |
|---|---|
| [x16-emulator](https://github.com/X16Community/x16-emulator) | Official emulator |
| [x16-rom](https://github.com/X16Community/x16-rom) | KERNAL, BASIC, DOS, and other ROM components |
| [x16-docs](https://github.com/X16Community/x16-docs) | Official programmer's reference |
| [vera-module](https://github.com/X16Community/vera-module) | VERA FPGA module (Verilog) |
| [x16-smc](https://github.com/X16Community/x16-smc) | System Management Controller firmware |
| [x16-smc-bootloader](https://github.com/X16Community/x16-smc-bootloader) | SMC bootloader |
| [x16-demo](https://github.com/X16Community/x16-demo) | Demo programs and examples |
| [x16-flash](https://github.com/X16Community/x16-flash) | Flash utility for ROM updates |
| [x16-user-guide](https://github.com/X16Community/x16-user-guide) | User guide |
| [faq](https://github.com/X16Community/faq) | Frequently asked questions |

## License

[BSD-2-Clause](LICENSE)
