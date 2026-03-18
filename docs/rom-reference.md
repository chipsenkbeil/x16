# ROM Reference

## Table of Contents

- [Overview](#overview)
- [KERNAL API](#kernal-api)
  - [Channel I/O](#channel-io)
  - [Memory](#memory)
  - [Graphics (VERA Helpers)](#graphics-vera-helpers)
  - [Framebuffer API](#framebuffer-api)
  - [Console API](#console-api)
  - [Sprites API](#sprites-api)
  - [Keyboard](#keyboard)
  - [Mouse](#mouse)
  - [Joystick / Game Controller](#joystick--game-controller)
  - [I2C](#i2c)
  - [Clock](#clock)
  - [Misc](#misc)
- [Virtual Registers r0-r15](#virtual-registers-r0r15)
- [Bank Switching Patterns](#bank-switching-patterns)
  - [Accessing Banked RAM](#accessing-banked-ram)
  - [Calling KERNAL from Non-Zero ROM Bank](#calling-kernal-from-non-zero-rom-bank)
  - [Copying Between RAM Banks](#copying-between-ram-banks)
- [BASIC V2 Commands](#basic-v2-commands)
  - [Standard BASIC Commands](#standard-basic-commands)
  - [X16 Extensions](#x16-extensions)
- [CMDR-DOS Commands](#cmdr-dos-commands)
- [Machine Language Monitor](#machine-language-monitor)

## Overview

The X16 ROM contains KERNAL, BASIC, CMDR-DOS, GEOS, an ML Monitor, and other components across 32 banks. The KERNAL provides a comprehensive API accessed through a jump table at $FF00-$FFF9, ensuring forward compatibility.

## KERNAL API

The KERNAL API is accessed through fixed jump table addresses. Parameters are typically passed in registers (A, X, Y) and/or the virtual registers r0-r15 at $02-$21.

The X16 KERNAL extends the C64 KERNAL and adds new calls in the $FE80-$FF3F range and uses the standard C64 addresses for compatible calls.

### Channel I/O

| Address | Name | Description |
|---------|------|-------------|
| $FFB7 | READST | Read I/O status byte. Returns: A = status |
| $FFBA | SETLFS | Set logical file params. Input: A = logical file#, X = device#, Y = secondary addr |
| $FFBD | SETNAM | Set filename. Input: A = name length, X/Y = pointer to name (low/high) |
| $FFC0 | OPEN | Open logical file. Uses SETLFS/SETNAM params. Returns: C=1 on error, A = error code |
| $FFC3 | CLOSE | Close logical file. Input: A = logical file# |
| $FFC6 | CHKIN | Set input channel. Input: X = logical file# |
| $FFC9 | CHKOUT | Set output channel. Input: X = logical file# |
| $FFCC | CLRCHN | Restore default I/O channels |
| $FFCF | CHRIN | Read byte from input channel. Returns: A = byte |
| $FFD2 | CHROUT | Write byte to output channel. Input: A = byte |
| $FFD5 | LOAD | Load file to memory. Input: A = 0 (load) or 1 (verify), X/Y = address (if secondary addr = 0). Returns: C=1 error, X/Y = end address |
| $FFD8 | SAVE | Save memory to file. Input: A = ZP pointer to start addr, X/Y = end address+1 |
| $FFE7 | CLALL | Close all files, restore default I/O |

### Memory

| Address | Name | Description |
|---------|------|-------------|
| $FF68 | MEMORY_FILL | Fill memory region. Input: r0 = address, r1 = size, A = fill value |
| $FF6B | MEMORY_COPY | Copy memory. Input: r0 = source, r1 = dest, r2 = size |
| $FF6E | MEMORY_CRC | CRC of memory region. Input: r0 = address, r1 = size. Returns: r2 = CRC |
| $FF71 | MEMORY_DECOMPRESS | Decompress LZSA2 data. Input: r0 = source, r1 = dest |
| $FE00 | FETCH | Read byte from any RAM/ROM bank. Input: (virtual reg setup) |
| $FE03 | STASH | Write byte to any RAM bank |

### Graphics (VERA Helpers)

| Address | Name | Description |
|---------|------|-------------|
| $FF11 | screen_set_charset | Set character set. Input: A = charset (0=ISO, 1=PetSCII UC, 2=PetSCII LC), X/Y = custom charset pointer (if A=128) |
| $FF5F | screen_mode | Set/get screen mode. Input: C=0 set, C=1 get. A = mode (0=80x60, 1=80x30, 2=40x60, 3=40x30, etc.). Returns: X = columns, Y = rows |
| $FF62 | screen_set_mode | (Alias for screen_mode with C=0) |

### Framebuffer API

| Address | Name | Description |
|---------|------|-------------|
| $FEF6 | FB_INIT | Init framebuffer |
| $FEF9 | FB_GET_INFO | Get framebuffer info. Returns: r0 = width, r1 = height, A = BPP |
| $FEFC | FB_SET_PALETTE | Set palette from memory. Input: r0 = palette data pointer, A = start index, X = count |
| $FEFF | FB_CURSOR_POSITION | Set cursor position. Input: r0 = x, r1 = y |
| $FF02 | FB_CURSOR_NEXT_LINE | Move cursor to start of next line. Input: r0 = x position |
| $FF05 | FB_GET_PIXEL | Get pixel at cursor. Returns: A = color index |
| $FF08 | FB_GET_PIXELS | Get multiple pixels. Input: r0 = buffer, r1 = count |
| $FF0B | FB_SET_PIXEL | Set pixel at cursor. Input: A = color index |
| $FF0E | FB_SET_PIXELS | Set multiple pixels. Input: r0 = buffer, r1 = count |
| $FF14 | FB_FILL_PIXELS | Fill pixels. Input: r0 = count, A = color index |
| $FF17 | FB_FILTER_PIXELS | Apply filter. Input: r0 = count, r1 = filter function |
| $FF1A | FB_MOVE_PIXELS | Move pixel region. Input: r0 = dest, r1 = count |

### Console API

| Address | Name | Description |
|---------|------|-------------|
| $FEDB | console_init | Initialize console. Input: r0 = x, r1 = y, r2 = width, r3 = height |
| $FEDE | console_put_char | Write character. Input: A = char, C=0 wrap |
| $FEE1 | console_put_image | Draw image. Input: r0 = image data, r1 = width, r2 = height |
| $FEE4 | console_set_paging_message | Set page message. Input: r0 = message pointer (0 = disable) |

### Sprites API

| Address | Name | Description |
|---------|------|-------------|
| $FEF0 | sprite_set_image | Set sprite image in VRAM. Input: r0 = image data, r1 = VRAM addr, A = bpp |
| $FEF3 | sprite_set_position | Set sprite position. Input: r0 = sprite index, r1 = x, r2 = y |

### Keyboard

| Address | Name | Description |
|---------|------|-------------|
| $FEBD | kbdbuf_peek | Peek at keyboard buffer. Returns: A = next char (0 if empty), X = buffer count |
| $FEC0 | kbdbuf_get_modifiers | Get modifier key state. Returns: A = modifier bitmask (bit 0=shift, 1=alt, 2=ctrl, 3=Win/Cmd, 4=caps) |
| $FEC3 | kbdbuf_put | Put character into keyboard buffer. Input: A = char |
| $FFE4 | GETIN | Get character from keyboard buffer. Returns: A = char (0 if none) |

### Mouse

| Address | Name | Description |
|---------|------|-------------|
| $FF68 | mouse_config | Configure mouse. Input: A = 0 off, 1 on (visible cursor), $FF on (hidden). X = scale (screen mode) |
| $FF6B | mouse_get | Get mouse state. Input: X = offset into r0-r4 for results. Returns: rx = X pos, rx+1 = Y pos, A = button state |
| $FF71 | mouse_scan | Scan mouse (called by IRQ handler) |

### Joystick / Game Controller

| Address | Name | Description |
|---------|------|-------------|
| $FF53 | joystick_scan | Scan joysticks (called automatically by KERNAL IRQ) |
| $FF56 | joystick_get | Get joystick state. Input: A = joystick# (0=keyboard, 1-4=SNES ports). Returns: A = buttons[7:0], X = buttons[15:8], Y = present flag |

SNES button bits (active-low, 0 = pressed):

- Bit 0: B, Bit 1: Y, Bit 2: Select, Bit 3: Start
- Bit 4: Up, Bit 5: Down, Bit 6: Left, Bit 7: Right
- Bit 8: A, Bit 9: X, Bit 10: L, Bit 11: R

### I2C

| Address | Name | Description |
|---------|------|-------------|
| $FEC6 | i2c_read_byte | Read byte from I2C device. Input: X = device addr, Y = register. Returns: A = data |
| $FEC9 | i2c_write_byte | Write byte to I2C device. Input: X = device addr, Y = register, A = data |
| $FECC | i2c_batch_read | Batch I2C read. Input: X = device addr, Y = register, r0 = buffer, r1 = count |
| $FECF | i2c_batch_write | Batch I2C write |

### Clock

| Address | Name | Description |
|---------|------|-------------|
| $FF4D | clock_set_date_time | Set RTC. Input: r0L=year(0-99), r0H=month(1-12), r1L=day, r1H=hours, r2L=minutes, r2H=seconds, r3L=jiffies |
| $FF50 | clock_get_date_time | Get RTC. Returns: same registers as above |

### Misc

| Address | Name | Description |
|---------|------|-------------|
| $FF44 | macptr | Read multiple bytes from peripheral. Input: A = count (0=256), X/Y = destination |
| $FF47 | enter_basic | Return to BASIC prompt |
| $FF5C | CINT | Initialize screen editor |
| $FF81 | SCINIT | Initialize screen (alias) |
| $FF84 | IOINIT | Initialize I/O devices |
| $FF87 | RAMTAS | Initialize RAM, tape buffer, screen |
| $FF8A | RESTOR | Restore KERNAL vectors to defaults |
| $FF8D | VECTOR | Set/read KERNAL vectors. Input: C=0 set from (X/Y), C=1 read to (X/Y) |
| $FF90 | SETMSG | Set KERNAL message mode. Input: A = mode |
| $FF93 | SECOND | Send secondary address |
| $FF96 | TKSA | Send talk secondary |
| $FF99 | MEMTOP | Get/set top of memory. Input: C=0 set X/Y, C=1 get. Returns: X/Y = address |
| $FF9C | MEMBOT | Get/set bottom of memory |
| $FFA5 | ACPTR | Read from serial bus |
| $FFA8 | CIOUT | Write to serial bus |
| $FFAB | UNTLK | Untalk serial device |
| $FFAE | UNLSN | Unlisten serial device |
| $FFB1 | LISTEN | Send LISTEN to serial device. Input: A = device# |
| $FFB4 | TALK | Send TALK to serial device. Input: A = device# |
| $FFE1 | STOP | Check STOP key. Returns: Z=1 if pressed |
| $FFF0 | PLOT | Set/get cursor position. Input: C=0 set (Y=col, X=row), C=1 get. Returns: Y=col, X=row |

## Virtual Registers r0-r15

The X16 KERNAL introduces 16 virtual 16-bit registers at zero page $02-$21. Each occupies 2 bytes (low, high).

```
r0  = $02/$03    r4  = $0A/$0B    r8  = $12/$13    r12 = $1A/$1B
r1  = $04/$05    r5  = $0C/$0D    r9  = $14/$15    r13 = $1C/$1D
r2  = $06/$07    r6  = $0E/$0F    r10 = $16/$17    r14 = $1E/$1F
r3  = $08/$09    r7  = $10/$11    r11 = $18/$19    r15 = $20/$21
```

In cc65 C code, access as `r0`, `r0L`, `r0H`, etc. (from `<cx16.h>`).
In assembly, reference directly: `lda $02` / `sta $02` for r0L.

KERNAL calls may clobber any of these -- check docs per call.

## Bank Switching Patterns

### Accessing Banked RAM

```asm
; Save current bank, switch, access, restore
lda RAM_BANK     ; $00
pha
lda #5           ; bank 5
sta RAM_BANK
; ... access $A000-$BFFF ...
lda $A000        ; read from bank 5
pla
sta RAM_BANK     ; restore previous bank
```

### Calling KERNAL from Non-Zero ROM Bank

```asm
; When running code in banked ROM (e.g., cartridge bank 32+),
; KERNAL calls via the jump table handle bank switching automatically.
; But if you need to call into a specific ROM bank:
lda ROM_BANK     ; $01
pha
lda #4           ; switch to BASIC bank
sta ROM_BANK
jsr $C000        ; call into BASIC
pla
sta ROM_BANK     ; restore
```

### Copying Between RAM Banks

```asm
; Copy 256 bytes from bank 3 offset $A100 to bank 7 offset $A200
; Using MEMORY_COPY or manual loop:
src_bank = 3
dst_bank = 7
    ldx #0
@loop:
    lda #src_bank
    sta RAM_BANK
    lda $A100,x
    pha
    lda #dst_bank
    sta RAM_BANK
    pla
    sta $A200,x
    inx
    bne @loop
```

## BASIC V2 Commands

The X16 extends Commodore BASIC V2 with additional commands.

### Standard BASIC Commands

PRINT, INPUT, GET, IF...THEN, FOR...NEXT, GOTO, GOSUB...RETURN, READ, DATA, RESTORE, DIM, DEF FN, REM, LET, POKE, PEEK, SYS, WAIT, OPEN, CLOSE, CMD, LOAD, SAVE, VERIFY, CLR, NEW, LIST, RUN, STOP, END, CONT

### X16 Extensions

| Command | Description |
|---------|-------------|
| VPEEK(bank,addr) | Read VERA VRAM byte |
| VPOKE bank,addr,val | Write VERA VRAM byte |
| BLOAD "file",device,bank,addr | Binary load to specific bank/address |
| BVLOAD "file",device,vaddr | Binary load directly to VRAM |
| VLOAD "file",device,bank,addr | (Alias for BVLOAD) |
| FMCHORD ... | Play FM chord |
| FMDRUM ... | Play FM drum |
| FMFREQ ... | Set FM frequency |
| FMINIT | Initialize FM (YM2151) |
| FMINST ... | Load FM instrument |
| FMNOTE ... | Play FM note |
| FMPAN ... | Set FM pan |
| FMPLAY ... | Play FM sequence |
| FMPOKE reg,val | Write FM register |
| FMVIB ... | Set FM vibrato |
| FMVOL ... | Set FM volume |
| PSGCHORD ... | Play PSG chord |
| PSGFREQ ... | Set PSG frequency |
| PSGINIT | Initialize PSG |
| PSGNOTE ... | Play PSG note |
| PSGPAN ... | Set PSG pan |
| PSGPLAY ... | Play PSG sequence |
| PSGVOL ... | Set PSG volume |
| PSGWAV ... | Set PSG waveform |
| SCREEN mode | Set screen mode |
| MOUSE mode | Enable/disable mouse |
| COLOR fg[,bg] | Set text colors |
| RESET | Reset system |
| BOOT | Boot from SD card |
| LOCATE row,col | Position cursor |
| DOS "command" | Send DOS command |
| DOS | Show DOS status |
| MON | Enter Machine Language Monitor |
| OLD | Recover NEW'd program |
| BINPUT#file,var | Binary input |
| BLOAD/BSAVE | Binary load/save |
| EXEC | Execute BASIC program as typed input |
| HELP | Show error line |
| KEYMAP "layout" | Set keyboard layout |
| LINE x1,y1,x2,y2,color | Draw line |
| RECT x1,y1,x2,y2,color | Draw rectangle |
| FRAME x1,y1,x2,y2,color | Draw rectangle frame |
| CHAR x,y,"string" | Draw text at pixel position |
| SLEEP n | Sleep n jiffies |
| TILE x,y,tile | Set tile |
| SPRITE ... | Configure sprite |

## CMDR-DOS Commands

CMDR-DOS provides a FAT32-compatible filesystem. Commands are sent via `OPEN 15,8,15,"command"`:

| Command | Description |
|---------|-------------|
| I | Initialize drive |
| V | Validate (check) filesystem |
| S:filename | Scratch (delete) file |
| R:newname=oldname | Rename file |
| C:dest=source | Copy file |
| CD:dirname | Change directory |
| CD:/ | Change to root |
| CD:← | Go up one directory (← = $5F) |
| MD:dirname | Make directory |
| RD:dirname | Remove directory |
| $[=path] | Directory listing |
| T-RA | Time: read (ASCII) |
| T-WA:YYYY-MM-DD HH:MM:SS | Time: write (ASCII) |

Reading directory:

```basic
10 OPEN 1,8,0,"$"
20 GET#1,A$,B$: REM skip load address
30 GET#1,A$,B$: REM skip link pointer
40 GET#1,A$,B$: PRINT ASC(A$)+256*ASC(B$);" ";: REM block size
50 GET#1,A$: IF A$<>"" THEN PRINT A$;: GOTO 50
60 PRINT: IF ST=0 GOTO 30
70 CLOSE 1
```

## Machine Language Monitor

Enter with `MON` from BASIC or Ctrl+M. Commands:

| Command | Description |
|---------|-------------|
| A addr opcode | Assemble instruction |
| D [addr1 [addr2]] | Disassemble |
| M [addr1 [addr2]] | Memory dump (hex + ASCII) |
| : addr byte [byte...] | Modify memory |
| R | Show registers |
| ; PC SR AC XR YR SP | Set registers |
| G [addr] | Go (execute from addr) |
| J [addr] | JSR (call, returns to monitor) |
| F addr1 addr2 byte | Fill memory |
| H addr1 addr2 byte... | Hunt (search) memory |
| T addr1 addr2 dest | Transfer (copy) memory |
| C addr1 addr2 dest | Compare memory |
| L ["file"[,device]] | Load file |
| S "file",device,addr1,addr2 | Save memory region |
| X | Exit to BASIC |
| O | Toggle ROM bank display |
| B [bank] | Set/show RAM bank for $A000-$BFFF |
| K [bank] | Set/show ROM bank for $C000-$FFFF |

Cross-reference: See [Memory Map](memory-map.md) for address details. See [Development Guide](development-guide.md) for debugging with the emulator's built-in debugger.
