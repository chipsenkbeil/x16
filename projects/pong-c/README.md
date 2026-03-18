# pong-c

Two-player Pong game for the Commander X16, written in C (cc65). This is a C port of the ca65 assembly version in `projects/pong-asm/`.

<img width="752" height="620" alt="Screenshot 2026-03-18 at 18 45 48" src="https://github.com/user-attachments/assets/9cd2d5d7-3cad-4c9a-86f1-dedafcd95514" />

## Controls

- **Player 1 (left paddle):** A = up, Z = down
- **Player 2 (right paddle):** Cursor Up = up, Cursor Down = down
- First to 9 points wins. Press any key to restart.

## Features

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
src/          Source code (main.c, vera.h)
assets/       Graphics, sounds, data files
build/        Build output (gitignored)
```
