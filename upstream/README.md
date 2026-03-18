# Upstream Repositories

This directory holds cloned copies of the official X16Community GitHub repositories. These are used as reference material for development and documentation, and are **not** checked into this repo (see `.gitignore`).

## Populating This Directory

Run the clone script to fetch all repositories:

```bash
# Full clones (recommended for development)
./scripts/clone-repos.sh

# Shallow clones (faster, for reference only)
./scripts/clone-repos.sh --shallow
```

Or use the Makefile target:

```bash
make clone-upstream
```

## Repositories

| Repository | Description | URL |
|---|---|---|
| x16-emulator | Official X16 emulator (C, SDL2) | https://github.com/X16Community/x16-emulator |
| x16-rom | KERNAL, BASIC, DOS, GEOS, and other ROM banks (ca65 assembly) | https://github.com/X16Community/x16-rom |
| x16-docs | Official Programmer's Reference Guide (Markdown) | https://github.com/X16Community/x16-docs |
| vera-module | VERA FPGA module source (Verilog) | https://github.com/X16Community/vera-module |
| x16-smc | System Management Controller firmware (Arduino/C++) | https://github.com/X16Community/x16-smc |
| x16-smc-bootloader | SMC bootloader firmware | https://github.com/X16Community/x16-smc-bootloader |
| x16-demo | Demo programs and code examples | https://github.com/X16Community/x16-demo |
| x16-flash | ROM flash update utility | https://github.com/X16Community/x16-flash |
| x16-user-guide | User Guide documentation | https://github.com/X16Community/x16-user-guide |
| faq | Frequently Asked Questions | https://github.com/X16Community/faq |

## Usage

Once cloned, you can:
- Browse source code for reference
- Build the emulator or ROM locally
- Cross-reference documentation with implementation
- Study demo programs for coding patterns

See [docs/contributing-guide.md](../docs/contributing-guide.md) for details on building and contributing to each repo.
