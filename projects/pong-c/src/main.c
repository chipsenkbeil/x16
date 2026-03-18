/*
 * main.c - Two-Player Pong for Commander X16 (cc65 C port)
 *
 * Player 1: A key = up, Z key = down (left paddle)
 * Player 2: Cursor Up = up, Cursor Down = down (right paddle)
 * First to 9 points wins. Press any key to restart after game over.
 *
 * Uses 3 hardware sprites (2 paddles + ball), text layer for score,
 * and PSG voices 14-15 for sound effects.
 *
 * Build: make
 * Run:   make run
 */

#include <cx16.h>
#include <conio.h>
#include <joystick.h>
#include "vera.h"

/* Implemented in wait_vblank.s — WAI instruction for vsync */
extern void wait_vblank(void);

/* Game constants */
#define PADDLE_SPEED      3
#define BALL_SPEED_INIT   2
#define P1_X              16
#define P2_X              296
#define PADDLE_HEIGHT     32
#define PADDLE_WIDTH      8
#define BALL_SIZE         8
#define TOP_WALL          8
#define BOTTOM_WALL       232
#define PADDLE_MIN_Y      8
#define PADDLE_MAX_Y      200
#define BALL_START_X      156
#define BALL_START_Y      116
#define WIN_SCORE         9
#define PADDLE_HIT_LEFT   24
#define PADDLE_HIT_RIGHT  296
#define POST_SCORE_PAUSE  60

/* VRAM addresses */
#define VRAM_PADDLE_GFX   0x10000UL
#define VRAM_BALL_GFX     0x10080UL
#define VRAM_SPR0_ATTR    0x1FC00UL
#define VRAM_SPR1_ATTR    0x1FC08UL
#define VRAM_SPR2_ATTR    0x1FC10UL
#define VRAM_PSG_V14      0x1F9F8UL
#define VRAM_PSG_V15      0x1F9FCUL

/* SFX durations in frames */
#define BOUNCE_SFX_DUR    4
#define SCORE_SFX_DUR     20

/* Text layer direct VRAM access */
#define TEXT_VRAM_BASE    0x1B000UL
#define TEXT_COLOR        0x61        /* white(1) on blue(6) */

/* Game state */
static unsigned int  ball_x;
static unsigned char ball_y;
static unsigned char ball_dx, ball_dy;
static unsigned char ball_dir_x;   /* 0=right, 1=left */
static unsigned char ball_dir_y;   /* 0=down, 1=up */
static unsigned char p1_y, p2_y;
static unsigned char p1_score, p2_score;
static unsigned char sfx_bounce_timer, sfx_score_timer;
static unsigned char frame_count, pause_timer, game_over;
static unsigned char joy_data;

/* Forward declarations */
static void upload_sprite_data(void);
static void setup_sprite_attrs(void);
static void init_game_state(void);
static void reset_ball(void);
static void read_input(void);
static void move_paddles(void);
static void move_ball(void);
static void check_collisions(void);
static void adjust_ball_angle(unsigned char paddle_y);
static void score_point(unsigned char player);
static void update_sprites(void);
static void draw_scores(void);
static void draw_center_line(void);
static void play_bounce_sfx(void);
static void play_score_sfx(void);
static void update_sfx(void);
static void silence_voice14(void);
static void silence_voice15(void);
static void show_game_over(void);
static void vram_clear(void);

void main(void)
{
    joy_install(cx16_std_joy);

    for (;;) {
        /* Set 40-column text mode, override to 320x240 */
        videomode(2);
        VERA_CTRL &= 0xF9;         /* DCSEL=0 before DC register writes */
        VERA_DC_HSCALE = 0x40;
        VERA_DC_VSCALE = 0x40;
        VERA_DC_BORDER = 0x00;
        vram_clear();

        upload_sprite_data();
        setup_sprite_attrs();

        /* Enable sprites: ensure DCSEL=0, then set bit 6 of DC_VIDEO */
        VERA_CTRL &= 0xF9;
        VERA_DC_VIDEO |= 0x40;

        init_game_state();
        draw_scores();
        draw_center_line();

        /* Inner game loop */
        for (;;) {
            wait_vblank();
            ++frame_count;

            if (game_over) {
                show_game_over();
                break;
            }

            if (pause_timer) {
                --pause_timer;
                update_sfx();
                update_sprites();
                continue;
            }

            read_input();
            move_paddles();
            move_ball();
            check_collisions();
            update_sprites();
            update_sfx();
        }
    }
}

static void upload_sprite_data(void)
{
    unsigned char i;

    /* Paddle: 128 bytes of 0x11 at VRAM_PADDLE_GFX */
    VERA_CTRL &= 0xFE;
    VERA_SET_ADDR(VRAM_PADDLE_GFX, VERA_STRIDE_1);
    for (i = 0; i < 128; ++i) {
        VERA_DATA0 = 0x11;
    }

    /* Ball: 32 bytes of 0x11 at VRAM_BALL_GFX */
    VERA_SET_ADDR(VRAM_BALL_GFX, VERA_STRIDE_1);
    for (i = 0; i < 32; ++i) {
        VERA_DATA0 = 0x11;
    }
}

static void setup_sprite_attrs(void)
{
    VERA_CTRL &= 0xFE;

    /* Sprite 0: Paddle 1 */
    VERA_SET_ADDR(VRAM_SPR0_ATTR, VERA_STRIDE_1);
    VERA_DATA0 = 0x00;   /* addr low: $10000>>5 = $0800, low byte = $00 */
    VERA_DATA0 = 0x08;   /* addr high = $08, mode = 4bpp */
    VERA_DATA0 = (unsigned char)(P1_X & 0xFF);
    VERA_DATA0 = (unsigned char)(P1_X >> 8);
    VERA_DATA0 = 104;    /* Y low */
    VERA_DATA0 = 0;      /* Y high */
    VERA_DATA0 = 0x0C;   /* Z-depth in front of both layers */
    VERA_DATA0 = 0x80;   /* height=32(10), width=8(00) */

    /* Sprite 1: Paddle 2 */
    VERA_SET_ADDR(VRAM_SPR1_ATTR, VERA_STRIDE_1);
    VERA_DATA0 = 0x00;
    VERA_DATA0 = 0x08;
    VERA_DATA0 = (unsigned char)(P2_X & 0xFF);
    VERA_DATA0 = (unsigned char)(P2_X >> 8);
    VERA_DATA0 = 104;
    VERA_DATA0 = 0;
    VERA_DATA0 = 0x0C;
    VERA_DATA0 = 0x80;

    /* Sprite 2: Ball */
    VERA_SET_ADDR(VRAM_SPR2_ATTR, VERA_STRIDE_1);
    VERA_DATA0 = 0x04;   /* addr low: $10080>>5 = $0804, low = $04 */
    VERA_DATA0 = 0x08;   /* addr high = $08, mode = 4bpp */
    VERA_DATA0 = (unsigned char)(BALL_START_X & 0xFF);
    VERA_DATA0 = (unsigned char)(BALL_START_X >> 8);
    VERA_DATA0 = (unsigned char)(BALL_START_Y & 0xFF);
    VERA_DATA0 = (unsigned char)(BALL_START_Y >> 8);
    VERA_DATA0 = 0x0C;
    VERA_DATA0 = 0x00;   /* 8x8 */
}

static void init_game_state(void)
{
    p1_score = 0;
    p2_score = 0;
    p1_y = 104;
    p2_y = 104;
    sfx_bounce_timer = 0;
    sfx_score_timer = 0;
    frame_count = 0;
    pause_timer = 0;
    game_over = 0;
    reset_ball();
}

static void reset_ball(void)
{
    ball_x = BALL_START_X;
    ball_y = BALL_START_Y;
    ball_dx = BALL_SPEED_INIT;
    ball_dy = BALL_SPEED_INIT;
    ball_dir_x = frame_count & 0x01;
    ball_dir_y = (frame_count >> 1) & 0x01;
}

static void read_input(void)
{
    joy_data = joy_read(0);
}

static void move_paddles(void)
{
    unsigned char new_y;

    /* Player 1: JOY_BTN_B = A key = up, JOY_BTN_A = Z key = down */
    if (JOY_BTN_B(joy_data)) {
        if (p1_y < PADDLE_SPEED + PADDLE_MIN_Y) {
            p1_y = PADDLE_MIN_Y;
        } else {
            p1_y -= PADDLE_SPEED;
        }
    } else if (JOY_BTN_A(joy_data)) {
        new_y = p1_y + PADDLE_SPEED;
        if (new_y > PADDLE_MAX_Y) {
            new_y = PADDLE_MAX_Y;
        }
        p1_y = new_y;
    }

    /* Player 2: cursor up/down */
    if (JOY_UP(joy_data)) {
        if (p2_y < PADDLE_SPEED + PADDLE_MIN_Y) {
            p2_y = PADDLE_MIN_Y;
        } else {
            p2_y -= PADDLE_SPEED;
        }
    } else if (JOY_DOWN(joy_data)) {
        new_y = p2_y + PADDLE_SPEED;
        if (new_y > PADDLE_MAX_Y) {
            new_y = PADDLE_MAX_Y;
        }
        p2_y = new_y;
    }
}

static void move_ball(void)
{
    /* Move X */
    if (ball_dir_x == 0) {
        ball_x += ball_dx;
    } else {
        if (ball_x < ball_dx) {
            ball_x = 0;
        } else {
            ball_x -= ball_dx;
        }
    }

    /* Move Y */
    if (ball_dir_y == 0) {
        ball_y += ball_dy;
    } else {
        if (ball_y < ball_dy) {
            ball_y = 0;
        } else {
            ball_y -= ball_dy;
        }
    }
}

static void check_collisions(void)
{
    unsigned char ball_bottom;
    unsigned char paddle_bottom;
    unsigned int ball_right;

    /* Top wall */
    if (ball_y < TOP_WALL) {
        ball_y = TOP_WALL;
        ball_dir_y = 0;
        play_bounce_sfx();
    }
    /* Bottom wall */
    else if (ball_y >= BOTTOM_WALL) {
        ball_y = BOTTOM_WALL;
        ball_dir_y = 1;
        play_bounce_sfx();
    }

    /* Left paddle (P1) - only when moving left */
    if (ball_dir_x == 1) {
        if (ball_x <= PADDLE_HIT_LEFT && ball_x >= P1_X) {
            /* In paddle X zone - check Y overlap */
            ball_bottom = ball_y + BALL_SIZE;
            paddle_bottom = p1_y + PADDLE_HEIGHT;
            if (ball_y < paddle_bottom && ball_bottom > p1_y) {
                /* Hit! Bounce right */
                ball_dir_x = 0;
                ball_x = PADDLE_HIT_LEFT;
                adjust_ball_angle(p1_y);
                play_bounce_sfx();
                return;
            }
        }
        if (ball_x < P1_X) {
            score_point(2);
            return;
        }
    }

    /* Right paddle (P2) - only when moving right */
    if (ball_dir_x == 0) {
        ball_right = ball_x + BALL_SIZE;
        if (ball_right >= PADDLE_HIT_RIGHT) {
            /* Check if past paddle entirely */
            if (ball_right >= (unsigned int)(P2_X + PADDLE_WIDTH)) {
                score_point(1);
                return;
            }
            /* In paddle X zone - check Y overlap */
            ball_bottom = ball_y + BALL_SIZE;
            paddle_bottom = p2_y + PADDLE_HEIGHT;
            if (ball_y < paddle_bottom && ball_bottom > p2_y) {
                /* Hit! Bounce left */
                ball_dir_x = 1;
                ball_x = PADDLE_HIT_RIGHT - BALL_SIZE;
                adjust_ball_angle(p2_y);
                play_bounce_sfx();
                return;
            }
            /* Missed paddle in Y - score */
            score_point(1);
            return;
        }
    }
}

static void adjust_ball_angle(unsigned char paddle_y)
{
    int dist;

    dist = ((int)ball_y + (BALL_SIZE / 2)) - ((int)paddle_y + (PADDLE_HEIGHT / 2));
    if (dist < 0) {
        dist = -dist;
    }

    if (dist < 5) {
        ball_dy = 1;
        ball_dx = 3;
    } else if (dist < 10) {
        ball_dy = 2;
        ball_dx = 2;
    } else {
        ball_dy = 3;
        ball_dx = 2;
    }
}

static void score_point(unsigned char player)
{
    if (player == 1) {
        ++p1_score;
        if (p1_score >= WIN_SCORE) {
            game_over = 1;
            draw_scores();
            play_score_sfx();
            return;
        }
    } else {
        ++p2_score;
        if (p2_score >= WIN_SCORE) {
            game_over = 2;
            draw_scores();
            play_score_sfx();
            return;
        }
    }
    draw_scores();
    play_score_sfx();
    reset_ball();
    pause_timer = POST_SCORE_PAUSE;
}

static void update_sprites(void)
{
    VERA_CTRL &= 0xFE;

    /* Sprite 0 (P1 paddle): write X,Y at attr+2 */
    VERA_SET_ADDR(VRAM_SPR0_ATTR + 2, VERA_STRIDE_1);
    VERA_DATA0 = (unsigned char)(P1_X & 0xFF);
    VERA_DATA0 = (unsigned char)(P1_X >> 8);
    VERA_DATA0 = p1_y;
    VERA_DATA0 = 0;

    /* Sprite 1 (P2 paddle) */
    VERA_SET_ADDR(VRAM_SPR1_ATTR + 2, VERA_STRIDE_1);
    VERA_DATA0 = (unsigned char)(P2_X & 0xFF);
    VERA_DATA0 = (unsigned char)(P2_X >> 8);
    VERA_DATA0 = p2_y;
    VERA_DATA0 = 0;

    /* Sprite 2 (Ball) */
    VERA_SET_ADDR(VRAM_SPR2_ATTR + 2, VERA_STRIDE_1);
    VERA_DATA0 = (unsigned char)(ball_x & 0xFF);
    VERA_DATA0 = (unsigned char)(ball_x >> 8);
    VERA_DATA0 = ball_y;
    VERA_DATA0 = 0;
}

/* Convert PETSCII character to screen code */
static unsigned char petscii_to_screencode(unsigned char ch)
{
    if (ch >= 0xC1 && ch <= 0xDA) return ch - 0xC0;  /* shifted uppercase A-Z */
    if (ch >= 0x41 && ch <= 0x5A) return ch - 0x40;   /* unshifted uppercase A-Z */
    if (ch >= 0x60 && ch < 0x80)  return ch - 0x20;   /* graphics chars */
    return ch;                                         /* digits, space, punctuation */
}

/* Write a single character (screen code) + color to the text layer */
static void vram_putc(unsigned char col, unsigned char row,
                      unsigned char screencode, unsigned char color)
{
    unsigned long addr = TEXT_VRAM_BASE + ((unsigned int)row << 8)
                       + ((unsigned int)col << 1);
    VERA_CTRL &= 0xFE;
    VERA_SET_ADDR(addr, VERA_STRIDE_1);
    VERA_DATA0 = screencode;
    VERA_DATA0 = color;
}

/* Write a PETSCII string to the text layer */
static void vram_puts(unsigned char col, unsigned char row, const char *str)
{
    unsigned long addr = TEXT_VRAM_BASE + ((unsigned int)row << 8)
                       + ((unsigned int)col << 1);
    VERA_CTRL &= 0xFE;
    VERA_SET_ADDR(addr, VERA_STRIDE_1);
    while (*str) {
        VERA_DATA0 = petscii_to_screencode((unsigned char)*str);
        VERA_DATA0 = TEXT_COLOR;
        ++str;
    }
}

/* Clear visible text area (40x30) with spaces in our colors */
static void vram_clear(void)
{
    unsigned char row, col;
    VERA_CTRL &= 0xFE;
    for (row = 0; row < 30; ++row) {
        VERA_SET_ADDR(TEXT_VRAM_BASE + ((unsigned int)row << 8), VERA_STRIDE_1);
        for (col = 0; col < 40; ++col) {
            VERA_DATA0 = 0x20;      /* space */
            VERA_DATA0 = TEXT_COLOR;
        }
    }
}

static void draw_scores(void)
{
    /* P1:X    P2:X at column 12, row 0 — sequential VRAM write */
    unsigned long addr = TEXT_VRAM_BASE + ((unsigned int)12 << 1);
    VERA_CTRL &= 0xFE;
    VERA_SET_ADDR(addr, VERA_STRIDE_1);
    VERA_DATA0 = 0x10; VERA_DATA0 = TEXT_COLOR;              /* P */
    VERA_DATA0 = 0x31; VERA_DATA0 = TEXT_COLOR;              /* 1 */
    VERA_DATA0 = 0x3A; VERA_DATA0 = TEXT_COLOR;              /* : */
    VERA_DATA0 = 0x30 + p1_score; VERA_DATA0 = TEXT_COLOR;   /* score */
    VERA_DATA0 = 0x20; VERA_DATA0 = TEXT_COLOR;              /* spaces */
    VERA_DATA0 = 0x20; VERA_DATA0 = TEXT_COLOR;
    VERA_DATA0 = 0x20; VERA_DATA0 = TEXT_COLOR;
    VERA_DATA0 = 0x20; VERA_DATA0 = TEXT_COLOR;
    VERA_DATA0 = 0x10; VERA_DATA0 = TEXT_COLOR;              /* P */
    VERA_DATA0 = 0x32; VERA_DATA0 = TEXT_COLOR;              /* 2 */
    VERA_DATA0 = 0x3A; VERA_DATA0 = TEXT_COLOR;              /* : */
    VERA_DATA0 = 0x30 + p2_score; VERA_DATA0 = TEXT_COLOR;   /* score */
}

static void draw_center_line(void)
{
    unsigned char row;
    for (row = 1; row < 30; ++row) {
        vram_putc(20, row, (row & 0x01) ? 0x20 : 0x5E, TEXT_COLOR);
    }
}

static void play_bounce_sfx(void)
{
    VERA_CTRL &= 0xFE;
    VERA_SET_ADDR(VRAM_PSG_V14, VERA_STRIDE_1);
    VERA_DATA0 = 0x7C;   /* freq low */
    VERA_DATA0 = 0x0A;   /* freq high (~1000 Hz) */
    VERA_DATA0 = 0xF0;   /* vol=48, LR=both */
    VERA_DATA0 = 0x20;   /* pulse wave, pw=32 */
    sfx_bounce_timer = BOUNCE_SFX_DUR;
}

static void play_score_sfx(void)
{
    VERA_CTRL &= 0xFE;
    VERA_SET_ADDR(VRAM_PSG_V15, VERA_STRIDE_1);
    VERA_DATA0 = 0x25;   /* freq low */
    VERA_DATA0 = 0x03;   /* freq high (~300 Hz) */
    VERA_DATA0 = 0xF0;   /* vol=48, LR=both */
    VERA_DATA0 = 0x80;   /* triangle wave */
    sfx_score_timer = SCORE_SFX_DUR;
}

static void update_sfx(void)
{
    if (sfx_bounce_timer) {
        --sfx_bounce_timer;
        if (sfx_bounce_timer == 0) {
            silence_voice14();
        }
    }
    if (sfx_score_timer) {
        --sfx_score_timer;
        if (sfx_score_timer == 0) {
            silence_voice15();
        }
    }
}

static void silence_voice14(void)
{
    VERA_CTRL &= 0xFE;
    VERA_SET_ADDR(VRAM_PSG_V14 + 2, VERA_STRIDE_1);
    VERA_DATA0 = 0x00;
}

static void silence_voice15(void)
{
    VERA_CTRL &= 0xFE;
    VERA_SET_ADDR(VRAM_PSG_V15 + 2, VERA_STRIDE_1);
    VERA_DATA0 = 0x00;
}

static void show_game_over(void)
{
    if (game_over == 1) {
        vram_puts(13, 13, "PLAYER 1 WINS!");
    } else {
        vram_puts(13, 13, "PLAYER 2 WINS!");
    }
    vram_puts(10, 15, "PRESS ANY KEY TO PLAY");

    for (;;) {
        wait_vblank();
        update_sfx();
        if (kbhit()) {
            cgetc();
            break;
        }
    }

    silence_voice14();
    silence_voice15();
}
