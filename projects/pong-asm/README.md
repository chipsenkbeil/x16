# pong-asm

Two-player Pong game for the Commander X16, written in ca65 assembly.

- 3 hardware sprites (2 paddles + ball)
- PSG sound effects (bounce + score)
- Variable ball angle based on paddle hit position
- Text-layer score display and center line


<img width="752" height="620" alt="Screenshot 2026-03-18 at 18 41 07" src="https://github.com/user-attachments/assets/932d5c1f-99a0-4461-a590-1b21d32dc416" />


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
