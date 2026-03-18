/*
 * vera.h - VERA register defines and convenience macros for C
 *
 * Provides direct access to all VERA registers and helper macros
 * for common graphics operations on the Commander X16.
 *
 * Usage:
 *   #include "vera.h"
 */

#ifndef _VERA_H_
#define _VERA_H_

/* ---------------------------------------------------------------------------
 * VERA Register Addresses
 * --------------------------------------------------------------------------- */
#define VERA_ADDR_L      (*(volatile unsigned char *)0x9F20)  /* Address bits 0-7    */
#define VERA_ADDR_M      (*(volatile unsigned char *)0x9F21)  /* Address bits 8-15   */
#define VERA_ADDR_H      (*(volatile unsigned char *)0x9F22)  /* Addr hi + stride    */
#define VERA_DATA0       (*(volatile unsigned char *)0x9F23)  /* Data port 0         */
#define VERA_DATA1       (*(volatile unsigned char *)0x9F24)  /* Data port 1         */
#define VERA_CTRL        (*(volatile unsigned char *)0x9F25)  /* Control register    */
#define VERA_IEN         (*(volatile unsigned char *)0x9F26)  /* Interrupt enable    */
#define VERA_ISR         (*(volatile unsigned char *)0x9F27)  /* Interrupt status    */
#define VERA_IRQLINE_L   (*(volatile unsigned char *)0x9F28)  /* IRQ raster line lo  */
#define VERA_DC_VIDEO    (*(volatile unsigned char *)0x9F29)  /* Video output mode   */
#define VERA_DC_HSCALE   (*(volatile unsigned char *)0x9F2A)  /* Horizontal scale    */
#define VERA_DC_VSCALE   (*(volatile unsigned char *)0x9F2B)  /* Vertical scale      */
#define VERA_DC_BORDER   (*(volatile unsigned char *)0x9F2C)  /* Border color        */
#define VERA_L0_CONFIG   (*(volatile unsigned char *)0x9F2D)  /* Layer 0 config      */
#define VERA_L0_MAPBASE  (*(volatile unsigned char *)0x9F2E)  /* Layer 0 map base    */
#define VERA_L0_TILEBASE (*(volatile unsigned char *)0x9F2F)  /* Layer 0 tile base   */
#define VERA_L0_HSCROLL_L (*(volatile unsigned char *)0x9F30) /* L0 H-scroll lo      */
#define VERA_L0_HSCROLL_H (*(volatile unsigned char *)0x9F31) /* L0 H-scroll hi      */
#define VERA_L0_VSCROLL_L (*(volatile unsigned char *)0x9F32) /* L0 V-scroll lo      */
#define VERA_L0_VSCROLL_H (*(volatile unsigned char *)0x9F33) /* L0 V-scroll hi      */
#define VERA_L1_CONFIG   (*(volatile unsigned char *)0x9F34)  /* Layer 1 config      */
#define VERA_L1_MAPBASE  (*(volatile unsigned char *)0x9F35)  /* Layer 1 map base    */
#define VERA_L1_TILEBASE (*(volatile unsigned char *)0x9F36)  /* Layer 1 tile base   */
#define VERA_L1_HSCROLL_L (*(volatile unsigned char *)0x9F37) /* L1 H-scroll lo      */
#define VERA_L1_HSCROLL_H (*(volatile unsigned char *)0x9F38) /* L1 H-scroll hi      */
#define VERA_L1_VSCROLL_L (*(volatile unsigned char *)0x9F39) /* L1 V-scroll lo      */
#define VERA_L1_VSCROLL_H (*(volatile unsigned char *)0x9F3A) /* L1 V-scroll hi      */
#define VERA_AUDIO_CTRL  (*(volatile unsigned char *)0x9F3B)  /* Audio control       */
#define VERA_AUDIO_RATE  (*(volatile unsigned char *)0x9F3C)  /* Audio sample rate   */
#define VERA_AUDIO_DATA  (*(volatile unsigned char *)0x9F3D)  /* Audio FIFO data     */
#define VERA_SPI_DATA    (*(volatile unsigned char *)0x9F3E)  /* SPI data            */
#define VERA_SPI_CTRL    (*(volatile unsigned char *)0x9F3F)  /* SPI control         */

/* ---------------------------------------------------------------------------
 * Auto-increment stride values for VERA_ADDR_H (bits 4-7)
 * --------------------------------------------------------------------------- */
#define VERA_STRIDE_0     0x00   /* No increment    */
#define VERA_STRIDE_1     0x10   /* Increment by 1  */
#define VERA_STRIDE_2     0x20   /* Increment by 2  */
#define VERA_STRIDE_4     0x30   /* Increment by 4  */
#define VERA_STRIDE_8     0x40   /* Increment by 8  */
#define VERA_STRIDE_16    0x50   /* Increment by 16 */
#define VERA_STRIDE_32    0x60   /* Increment by 32 */
#define VERA_STRIDE_64    0x70   /* Increment by 64 */
#define VERA_STRIDE_128   0x80   /* Increment by 128 */
#define VERA_STRIDE_256   0x90   /* Increment by 256 */
#define VERA_STRIDE_512   0xA0   /* Increment by 512 */

/* ---------------------------------------------------------------------------
 * VERA_SET_ADDR - Set VERA VRAM address with auto-increment stride
 * --------------------------------------------------------------------------- */
/* addr: 17-bit VRAM address (0x00000 - 0x1FFFF)
 * stride: auto-increment value (use VERA_STRIDE_* constants)
 */
#define VERA_SET_ADDR(addr, stride) do { \
    VERA_ADDR_L = (unsigned char)((addr) & 0xFF);        \
    VERA_ADDR_M = (unsigned char)(((addr) >> 8) & 0xFF); \
    VERA_ADDR_H = (unsigned char)((((addr) >> 16) & 0x01) | (stride)); \
} while (0)

/* ---------------------------------------------------------------------------
 * VERA PEEK / POKE helpers
 * --------------------------------------------------------------------------- */
/* Read a single byte from VRAM at the given address */
#define VERA_PEEK(addr) ( \
    VERA_SET_ADDR((addr), VERA_STRIDE_0), \
    VERA_DATA0 \
)

/* Write a single byte to VRAM at the given address */
#define VERA_POKE(addr, val) do { \
    VERA_SET_ADDR((addr), VERA_STRIDE_0); \
    VERA_DATA0 = (val); \
} while (0)

/* ---------------------------------------------------------------------------
 * Layer configuration constants
 * --------------------------------------------------------------------------- */
/* Color depth (bits 0-1 of layer CONFIG register) */
#define VERA_COLOR_DEPTH_1BPP   0x00
#define VERA_COLOR_DEPTH_2BPP   0x01
#define VERA_COLOR_DEPTH_4BPP   0x02
#define VERA_COLOR_DEPTH_8BPP   0x03

/* Map size (bits 4-5 for width, bits 6-7 for height of layer CONFIG register) */
#define VERA_MAP_WIDTH_32       0x00
#define VERA_MAP_WIDTH_64       0x10
#define VERA_MAP_WIDTH_128      0x20
#define VERA_MAP_WIDTH_256      0x30
#define VERA_MAP_HEIGHT_32      0x00
#define VERA_MAP_HEIGHT_64      0x40
#define VERA_MAP_HEIGHT_128     0x80
#define VERA_MAP_HEIGHT_256     0xC0

/* Mode select (bit 2 of layer CONFIG register): 0 = tile mode, 1 = bitmap mode */
#define VERA_MODE_TILE          0x00
#define VERA_MODE_BITMAP        0x04

/* T256C - 256 color text mode (bit 3 of layer CONFIG register) */
#define VERA_T256C              0x08

/* ---------------------------------------------------------------------------
 * Sprite attribute structure (8 bytes per sprite at VRAM $1FC00)
 * --------------------------------------------------------------------------- */
typedef struct {
    unsigned int  addr;        /* bits 0-11: address/32, bit 15: mode (4/8bpp) */
    unsigned int  x;           /* X position (10-bit signed)                   */
    unsigned int  y;           /* Y position (10-bit signed)                   */
    unsigned char flags;       /* collision mask, Z-depth, V-flip, H-flip      */
    unsigned char size;        /* bits 4-5: height, bits 6-7: width            */
} vera_sprite_t;

/* Sprite Z-depth values (bits 2-3 of flags) */
#define VERA_SPRITE_DISABLED    0x00
#define VERA_SPRITE_BEHIND_ALL  0x04
#define VERA_SPRITE_BEHIND_L1   0x08
#define VERA_SPRITE_IN_FRONT    0x0C

/* Sprite flip flags */
#define VERA_SPRITE_HFLIP       0x01
#define VERA_SPRITE_VFLIP       0x02

/* Sprite sizes (width/height) */
#define VERA_SPRITE_8           0x00
#define VERA_SPRITE_16          0x01
#define VERA_SPRITE_32          0x02
#define VERA_SPRITE_64          0x03

/* Sprite size helpers for the size byte */
#define VERA_SPRITE_WIDTH(s)    ((s) << 4)
#define VERA_SPRITE_HEIGHT(s)   ((s) << 6)

/* Sprite base address in VRAM */
#define VERA_SPRITE_ATTR_BASE   0x1FC00

#endif /* _VERA_H_ */
