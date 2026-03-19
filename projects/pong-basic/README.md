# pong-basic

Two-player Pong game for the Commander X16, written in CBM BASIC V2. This is a BASIC port of the assembly and C versions in `projects/pong-asm/` and `projects/pong-c/`.

<img width="752" height="620" alt="Screenshot 2026-03-18 at 23 01 54" src="https://github.com/user-attachments/assets/78329657-94fd-42ce-af70-53507ee20a14" />

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
