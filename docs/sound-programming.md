# Sound Programming

## Table of Contents

## Audio Architecture

The X16 has three audio subsystems:
1. **VERA PSG** — 16-voice programmable sound generator (pulse, sawtooth, triangle, noise)
2. **VERA PCM** — Stereo PCM sample playback via FIFO
3. **YM2151 (OPM)** — 8-voice, 4-operator FM synthesis chip

All three output to the stereo audio mix. The PSG and PCM are built into VERA; the YM2151 is a separate chip.

## VERA PSG

16 voices, each with independent frequency, volume, waveform, and stereo panning.

### Register Layout
PSG registers are in VRAM at $1F9C0–$1F9FF (64 bytes total, 4 bytes per voice).

Voice N registers at VRAM $1F9C0 + (N × 4):

| Offset | Bits | Description |
|---|---|---|
| 0 | 7:0 | Frequency low byte |
| 1 | 7:0 | Frequency high byte |
| 2 | 7:6 | LR output (0=off, 1=left, 2=right, 3=both) |
| 2 | 5:0 | Volume (0=silent, 63=max) |
| 3 | 7:6 | Waveform (0=pulse, 1=sawtooth, 2=triangle, 3=noise) |
| 3 | 5:0 | Pulse width (0=12.5%, 32=50%, 63=99.6%) — only for pulse wave |

### Frequency Calculation
Frequency in Hz = FREQ_VALUE × 48828.125 / 65536

FREQ_VALUE = Hz × 65536 / 48828.125 ≈ Hz × 1.3422

Reference table:
| Note | Frequency | FREQ Value | Hex |
|---|---|---|---|
| C2 | 65.41 | 87 | $0057 |
| C3 | 130.81 | 175 | $00AF |
| C4 (Middle C) | 261.63 | 351 | $015F |
| A4 | 440.00 | 590 | $024E |
| C5 | 523.25 | 702 | $02BE |
| C6 | 1046.50 | 1404 | $057C |
| C7 | 2093.00 | 2809 | $0AF9 |

### PSG Programming Example (Assembly)

```asm
; Play a C major chord (C4, E4, G4) on voices 0, 1, 2
VERA_ADDR_L = $9F20
VERA_ADDR_M = $9F21
VERA_ADDR_H = $9F22
VERA_DATA0  = $9F23

.macro psg_set_voice voice, freq_l, freq_h, vol_lr, wave_pw
    ; Point to voice registers in VRAM
    lda #<($F9C0 + voice * 4)
    sta VERA_ADDR_L
    lda #>($F9C0 + voice * 4)
    sta VERA_ADDR_M
    lda #$11                ; increment=1, bit16=1
    sta VERA_ADDR_H
    lda #freq_l
    sta VERA_DATA0          ; frequency low
    lda #freq_h
    sta VERA_DATA0          ; frequency high
    lda #vol_lr
    sta VERA_DATA0          ; volume + LR
    lda #wave_pw
    sta VERA_DATA0          ; waveform + pulse width
.endmacro

    ; C4 = $015F, E4 = $01B5, G4 = $020E (approximate)
    psg_set_voice 0, $5F, $01, $FF, $00  ; C4, both channels, max vol, pulse
    psg_set_voice 1, $B5, $01, $FF, $00  ; E4
    psg_set_voice 2, $0E, $02, $FF, $00  ; G4
```

### PSG from C

```c
#include <cx16.h>

// Play a tone on a PSG voice
void psg_play(unsigned char voice, unsigned int freq,
              unsigned char vol, unsigned char waveform) {
    unsigned long addr = 0x1F9C0UL + voice * 4;
    // vpoke first byte with auto-increment (0x10 prefix = stride 1)
    vpoke(freq & 0xFF, 0x100000UL | addr);
    VERA.data0 = freq >> 8;              // freq high
    VERA.data0 = 0xC0 | (vol & 0x3F);   // both channels + volume
    VERA.data0 = (waveform << 6);        // waveform (0=pulse,1=saw,2=tri,3=noise)
}

// Silence a voice
void psg_stop(unsigned char voice) {
    vpoke(0, 0x1F9C2UL + voice * 4);  // set volume to 0
}

// Play C major chord
void play_chord(void) {
    psg_play(0, 0x015F, 63, 0);  // C4, pulse
    psg_play(1, 0x01B5, 63, 0);  // E4
    psg_play(2, 0x020E, 63, 0);  // G4
}
```

### Silencing a Voice

```asm
; Silence voice N: set volume to 0
lda #<($F9C0 + N * 4 + 2)
sta VERA_ADDR_L
lda #>($F9C0 + N * 4 + 2)
sta VERA_ADDR_M
lda #$11
sta VERA_ADDR_H
lda #$00            ; volume = 0
sta VERA_DATA0
```

## VERA PCM

Stereo PCM sample playback through a 4 KB FIFO buffer.

### Registers
| Register | Address | Description |
|---|---|---|
| AUDIO_CTRL | $9F3B | [7]=FIFO reset, [5]=16-bit, [4]=stereo, [3:0]=volume |
| AUDIO_RATE | $9F3C | Sample rate divider. Rate = value × 48828.125 / 65536 Hz. 0=paused |
| AUDIO_DATA | $9F3D | Write samples here (FIFO input) |

### Sample Rates

| AUDIO_RATE | Hz (approx) | Quality |
|---|---|---|
| 128 | 24,414 | Good for SFX |
| 171 | 32,552 | CD-like for 8-bit |
| 255 | 48,828 | Maximum |

### PCM Modes
- 8-bit mono: 1 byte per sample (unsigned, $80 = center)
- 8-bit stereo: 2 bytes per sample (left, right)
- 16-bit mono: 2 bytes per sample (signed little-endian)
- 16-bit stereo: 4 bytes per sample (left-L, left-H, right-L, right-H)

### AFLOW Interrupt
The AFLOW IRQ (VERA_IEN bit 2) fires when the FIFO drops below 25% full (~1024 bytes remaining). Use this to stream audio data from RAM/banked RAM into the FIFO during the ISR.

### PCM Playback Example

```asm
; Initialize PCM: 8-bit mono, volume 15
lda #$8F            ; reset FIFO
sta $9F3B
lda #$0F            ; unreset, 8-bit mono, vol=15
sta $9F3B

; Pre-fill FIFO (write some initial samples)
ldx #0
@prefill:
    lda sample_buffer,x
    sta $9F3D
    inx
    bne @prefill    ; 256 bytes

; Start playback at ~24 kHz
lda #$80
sta $9F3C

; In your IRQ handler, check AFLOW and feed more samples
```

### PCM from C

```c
#include <cx16.h>

#define AUDIO_CTRL  (*(volatile unsigned char*)0x9F3B)
#define AUDIO_RATE  (*(volatile unsigned char*)0x9F3C)
#define AUDIO_DATA  (*(volatile unsigned char*)0x9F3D)

void pcm_init(unsigned char rate) {
    AUDIO_CTRL = 0x8F;   // reset FIFO, 8-bit mono, vol=15
    AUDIO_CTRL = 0x0F;   // clear reset, keep settings
    AUDIO_RATE = rate;   // e.g., 0x80 for ~24 kHz
}

void pcm_feed(const unsigned char *data, unsigned int len) {
    unsigned int i;
    for (i = 0; i < len; i++) {
        AUDIO_DATA = data[i];
    }
}
```

## YM2151 FM Synthesis

The YM2151 (OPM — FM Operator Type-M) is a classic FM synthesis chip used in arcade machines and the Sharp X68000.

### Access
| Address | Name | Description |
|---|---|---|
| $9F40 | YM_ADDR | Write register number here |
| $9F41 | YM_DATA | Write register value / Read status |

**Important timing**: After writing to YM_DATA, you must wait for the busy flag (bit 7 of status read from $9F41) to clear before the next write. At 8 MHz, a simple `nop` or two is usually sufficient, but checking the flag is safest.

```asm
ym_write:
    ; A = register number, X = value
    sta $9F40       ; set register address
    ; wait (short delay)
    nop
    nop
    stx $9F41       ; write value
    rts
```

### Register Map

#### Global Registers

| Reg | Name | Description |
|---|---|---|
| $01 | Test | Test register (write $00) |
| $08 | Key On/Off | [6:4]=slot mask (OP4,OP3,OP2,OP1), [2:0]=channel (0-7). Set slot bits=1 to key-on |
| $0F | Noise | [7]=noise enable (CH7 only), [4:0]=noise frequency |
| $10–$17 | CLKA1 | Timer A period (high 8 bits), one per channel |
| $18 | CLKA2 | Timer A period (low 2 bits) |
| $19 | CLKB | Timer B period |
| $1B | CT/W | [7:6]=CT2/CT1 output pins, [1]=Timer B reset, [0]=Timer A reset |

#### Per-Channel Registers (channel = 0–7)

| Reg | Name | Description |
|---|---|---|
| $20+ch | RL/FB/CON | [7:6]=L/R output, [5:3]=feedback (0-7), [2:0]=algorithm (0-7) |
| $28+ch | KC | Key Code: [6:4]=octave (0-7), [3:0]=note (0-15, but only 0-11 valid for 12 notes) |
| $30+ch | KF | Key Fraction: [7:2]=fine tune (0-63) |
| $38+ch | PMS/AMS | [6:4]=PMS (pitch modulation sensitivity, 0-7), [1:0]=AMS (amplitude modulation sensitivity, 0-3) |

#### Per-Operator Registers (4 operators per channel)

Operator slot mapping: slot = [OP_number × 8 + channel]
- OP1 (M1): slots $00-$07
- OP2 (C1): slots $08-$0F
- OP3 (M2): slots $10-$17
- OP4 (C2): slots $18-$1F

| Reg | Name | Description |
|---|---|---|
| $40+slot | DT1/MUL | [6:4]=detune1 (0-7), [3:0]=frequency multiply (0-15) |
| $60+slot | TL | [6:0]=total level / attenuation (0=max, 127=silent) |
| $80+slot | KS/AR | [7:6]=key scaling (0-3), [4:0]=attack rate (0-31) |
| $A0+slot | AMS-EN/D1R | [7]=AMS enable, [4:0]=decay rate 1 (0-31) |
| $C0+slot | DT2/D2R | [7:6]=detune2 (0-3), [4:0]=decay rate 2 / sustain rate (0-31) |
| $E0+slot | D1L/RR | [7:4]=decay level 1 / sustain level (0-15), [3:0]=release rate (0-15) |

### Algorithms

The YM2151 has 8 algorithms (0–7) that define how the 4 operators connect:

```
Algorithm 0:  [OP1] → [OP2] → [OP3] → [OP4] → out
Algorithm 1:  [OP1] ─┐
              [OP2] ─┘→ [OP3] → [OP4] → out
Algorithm 2:  [OP1] ────────┐
              [OP2] → [OP3] ┘→ [OP4] → out
Algorithm 3:  [OP1] → [OP2] ┐
              [OP3] ─────────┘→ [OP4] → out
Algorithm 4:  [OP1] → [OP2] → out
              [OP3] → [OP4] → out
Algorithm 5:       ┌→ [OP2] → out
              [OP1]┤→ [OP3] → out
                   └→ [OP4] → out
Algorithm 6:  [OP1] → [OP2] → out
              [OP3] ────────→ out
              [OP4] ────────→ out
Algorithm 7:  [OP1] → out
              [OP2] → out
              [OP3] → out
              [OP4] → out
```

Lower algorithm numbers = more modulation (complex timbres). Higher = more additive (organ-like).

### ADSR Envelope

Each operator has a 4-stage envelope:
1. **Attack (AR)**: Time to reach maximum level
2. **Decay 1 (D1R)**: Time to decay from max to sustain level (D1L)
3. **Decay 2 (D2R)**: Time to decay from sustain to zero (while key held)
4. **Release (RR)**: Time to decay to zero after key-off

Rate values 0 = slowest (effectively off for AR), 31 = fastest. For RR, 0-15.

### Key Code Reference

| KC Value (low nibble) | Note |
|---|---|
| 0 | C# |
| 1 | D |
| 2 | D# |
| 4 | E |
| 5 | F |
| 6 | F# |
| 8 | G |
| 9 | G# |
| 10 | A |
| 12 | A# |
| 13 | B |
| 14 | C (of next octave) |

Note: values 3, 7, 11, 15 are duplicates of the next note.

### Playing a Note (Example)

```asm
; Play a sine-like tone on channel 0
; Algorithm 0 (serial), only OP4 as carrier, OP1-3 modulating

; Set algorithm and feedback
lda #$20            ; register $20 (channel 0)
ldx #%11000000      ; L+R output, feedback=0, algorithm=0
jsr ym_write

; Set OP4 (carrier) — slot = $18
; TL (volume) = 0 (loudest)
lda #$78            ; $60 + $18
ldx #$00
jsr ym_write

; AR = 31 (instant attack)
lda #$98            ; $80 + $18
ldx #$1F
jsr ym_write

; D1R = 0 (no decay)
lda #$B8            ; $A0 + $18
ldx #$00
jsr ym_write

; D1L = 0, RR = 7
lda #$F8            ; $E0 + $18
ldx #$07
jsr ym_write

; Silence other operators (TL = 127)
lda #$60            ; OP1 TL
ldx #$7F
jsr ym_write
lda #$68            ; OP2 TL
ldx #$7F
jsr ym_write
lda #$70            ; OP3 TL
ldx #$7F
jsr ym_write

; Set key code: octave 4, note A (KC value = $4A)
lda #$28            ; KC register, channel 0
ldx #$4A            ; octave 4, note 10 (A)
jsr ym_write

; Key on: all 4 operators on channel 0
lda #$08
ldx #%01111000      ; all 4 slots on, channel 0
jsr ym_write
```

### YM2151 from C

```c
#include <cx16.h>

// Write to YM2151 with busy-wait delay
void ym_write(unsigned char reg, unsigned char val) {
    unsigned char i;
    YM2151.reg = reg;       // $9F40 — register address
    YM2151.data = val;      // $9F41 — register data
    // Wait ~224 CPU cycles for YM2151 internal processing
    for (i = 0; i < 10; i++) { __asm__("nop"); }
}

void ym_reset(void) {
    unsigned int i;
    for (i = 0; i < 256; i++) ym_write(i, 0);
}

// Play A4 on channel 0 with a simple sine-like patch
void ym_play_note(void) {
    ym_write(0x20, 0xC0);        // Ch0: L+R output, algo 0, fb 0
    ym_write(0x60 + 0x18, 0x00); // OP4 TL=0 (carrier, loudest)
    ym_write(0x80 + 0x18, 0x1F); // OP4 AR=31 (instant attack)
    ym_write(0xE0 + 0x18, 0x07); // OP4 D1L=0, RR=7
    ym_write(0x60, 0x7F);        // OP1 TL=127 (silent modulator)
    ym_write(0x68, 0x7F);        // OP2 TL=127
    ym_write(0x70, 0x7F);        // OP3 TL=127
    ym_write(0x28, 0x4A);        // KC: octave 4, note A
    ym_write(0x08, 0x78);        // Key on: all 4 ops, channel 0
}
```

### Common Instrument Presets

Brief description of how to approximate common sounds:
- **Piano**: Algorithm 0, moderate feedback on OP1, fast attack, medium D1R, short sustain
- **Organ**: Algorithm 7 (all additive), different MUL on each op for harmonics
- **Brass**: Algorithm 4, slow attack, high feedback
- **Bass**: Algorithm 0, low MUL values, fast attack/decay
- **Drums**: Short envelope, noise on CH7, or very high modulation ratios

## Audio ROM API (Bank $0A)

The X16 ROM includes an audio API in bank $0A that provides high-level functions accessible from BASIC and assembly.

BASIC commands that use the audio API:
- FMINIT, FMNOTE, FMCHORD, FMFREQ, FMDRUM, FMINST, FMPAN, FMPLAY, FMPOKE, FMVIB, FMVOL
- PSGINIT, PSGNOTE, PSGCHORD, PSGFREQ, PSGPAN, PSGPLAY, PSGVOL, PSGWAV

These commands abstract the register-level details. For direct register control, use the register programming described above.

## ZSM Format

ZSM (ZSound Music) is the standard music file format for the X16. It stores a stream of register writes for both YM2151 and VERA PSG, enabling tracker-based music playback.

### Header (16 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| $00 | 2 | Magic | `zm` (0x7A, 0x6D) |
| $02 | 1 | Version | Format version (currently 1) |
| $03 | 3 | Loop Point | Byte offset to loop start (0 = no loop) |
| $06 | 3 | PCM Offset | Byte offset to PCM index table (0 = none) |
| $09 | 1 | FM Channel Mask | Bits 0-7 = which YM2151 channels are used |
| $0A | 2 | PSG Channel Mask | Bits 0-15 = which PSG voices are used |
| $0C | 2 | Tick Rate | Playback rate in Hz (typically 60) |
| $0E | 2 | Reserved | Set to zero |

### Stream Commands

| Byte Range | Type | Action |
|------------|------|--------|
| $00–$3F | PSG write | Write next byte to PSG register offset N (from $1F9C0) |
| $40 | EXTCMD | Extension command (PCM triggers, sync events, custom data) |
| $41–$7F | FM write | Write next N reg/value pairs to YM2151 |
| $80 | EOF | End of music data |
| $81–$FF | Delay | Wait (N & $7F) ticks |

### Playback from Assembly

```asm
; Load ZSM file to banked RAM, then play via VSYNC IRQ
; Uses a ZSM player library (zsound or ZSMKit)

; 1. Load ZSM file to banked RAM starting at bank 10
lda #10
sta RAM_BANK
lda #<zsm_filename
ldx #>zsm_filename
ldy #(zsm_filename_end - zsm_filename)
jsr load_file_to_bank  ; your file loading routine

; 2. Initialize player
lda #10              ; starting bank
ldx #<$A000          ; address within bank
ldy #>$A000
jsr zsm_init         ; player init (library-specific)

; 3. Hook VSYNC IRQ — call zsm_tick once per frame
; (See Music Engine Design section below)
```

### Player Libraries

- **[zsound](https://github.com/ZeroByteOrg/zsound)** — Original ZSM player, assembly library with simple API
- **[ZSMKit](https://github.com/mooinglemur/zsmkit)** — Newer player with multi-song support, PCM instrument playback, and priority system

ZSM files are headerless (no 2-byte PRG load address) — use headerless load mode when loading from disk.

## Music Engine Design

For game music, a typical approach:

1. **IRQ-driven playback**: Hook the VSYNC IRQ (60 Hz) to advance the music by one tick per frame
2. **Tick handler**: Read next events from music data, write register values to YM2151/PSG
3. **Priority system**: Reserve channels — e.g., YM ch 0-5 for music, ch 6-7 for SFX; PSG voices 0-7 for music, 8-15 for SFX
4. **Data format**: Use ZSM or a custom compact format stored in banked RAM

```asm
; Example: VSYNC IRQ handler for music
music_irq:
    pha
    phx
    phy

    ; Acknowledge VSYNC
    lda #$01
    sta $9F27       ; clear VSYNC flag

    ; Advance music
    jsr music_tick

    ply
    plx
    pla
    rti
```

## Pitch Systems

### PSG Pitch
PSG uses a linear 16-bit frequency register. For musical notes, pre-calculate a frequency table.

### YM2151 Pitch
YM2151 uses a logarithmic key code system (octave + note + fraction). This makes transposition easy (add/subtract octave value) but interpolation harder.

### MIDI-like Note Numbers
Map MIDI note numbers to YM2151 key codes:
- MIDI 60 (C4) → KC octave=4, note=14 (C), KF=0
- Each semitone = increment note portion of KC
- Each octave = increment octave portion of KC

Cross-reference: See [VERA Programming Guide](vera-programming-guide.md) for VERA register details. See [Game Development Guide](game-development-guide.md) for audio in games.
