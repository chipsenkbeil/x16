/*
 * main.c - Commander X16 Hello World (cc65 C)
 *
 * A simple starter program demonstrating basic console I/O
 * on the Commander X16 using cc65's cx16 target libraries.
 *
 * Build: make
 * Run:   make run
 */

#include <stdio.h>
#include <cx16.h>
#include <cbm.h>
#include <conio.h>

int main(void) {
    clrscr();
    textcolor(COLOR_WHITE);
    bgcolor(COLOR_BLUE);
    clrscr();

    printf("Hello from {{PROJECT_NAME}}!\n\n");
    printf("Commander X16 - 65C02 @ 8MHz\n");
    printf("VERA Graphics & Audio\n");
    printf("512KB Banked RAM\n\n");
    printf("Press any key to continue...\n");

    cgetc();
    return 0;
}
