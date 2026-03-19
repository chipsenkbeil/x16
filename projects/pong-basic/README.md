# pong-basic

Two-player Pong game for the Commander X16, written in BASIC. This is a BASIC port of the assembly and C versions in `projects/pong-asm/` and `projects/pong-c/`.

## Controls

- **Player 1 (left paddle):** A = up, Z = down
- **Player 2 (right paddle):** Cursor Up = up, Cursor Down = down
- First to 9 points wins. Press any key to restart.

## Features

- 3 hardware sprites (2 paddles + ball)
- PSG sound effects (bounce + score)
- Variable ball angle based on paddle hit position
- Text-layer score display and center line
- Interpreted BASIC — no compilation step needed

## Running

```
make run      # Launch in emulator
```

## Project Structure

```
src/          Source code (main.bas)
assets/       Graphics, sounds, data files
build/        Build output (gitignored)
```
