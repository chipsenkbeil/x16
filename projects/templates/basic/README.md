# {{PROJECT_NAME}}

A Commander X16 BASIC program.

Created: {{DATE}}

## Running

```
make run      # Run in emulator (x16emu -bas src/main.bas -run)
```

BASIC programs are interpreted directly by the X16 ROM — no compiler or assembler needed. The emulator's `-bas` flag loads a text BASIC file as if you typed it in.

## Project Structure

```
src/          BASIC source files (.bas)
assets/       Graphics, sounds, data files
```

## BASIC Development Tips

- Line numbers are required (10, 20, 30, ...)
- Use `SCREEN 0` for 80-column text mode, `SCREEN 2` for 320x240 graphics
- `VPOKE bank,addr,value` writes directly to VERA VRAM
- `VPEEK(bank,addr)` reads from VERA VRAM
- `BVLOAD "file",8,bank,addr` loads binary data to VRAM

## BASLOAD

For line-number-free BASIC development, consider [BASLOAD](https://github.com/stefan-b-jakobsson/basload-x16). BASLOAD lets you write BASIC without line numbers and compiles labels into line numbers. Install separately.
