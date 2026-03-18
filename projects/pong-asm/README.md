# pong-asm

Two-player Pong game for the Commander X16, written in ca65 assembly.

- 3 hardware sprites (2 paddles + ball)
- PSG sound effects (bounce + score)
- Variable ball angle based on paddle hit position
- Text-layer score display and center line

## Building

```
make          # Build the .prg
make run      # Build and run in emulator
make clean    # Remove build artifacts
```

## Project Structure

```
src/          Assembly source code (.s files)
include/      Include files (.inc equates, macros)
assets/       Graphics, sounds, data files
build/        Build output (gitignored)
```
