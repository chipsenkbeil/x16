/*
 * main.c - Commander X16 Hello World (llvm-mos C)
 *
 * A simple starter program demonstrating basic console I/O
 * on the Commander X16 using llvm-mos C compiler.
 *
 * Build: make
 * Run:   make run
 */

#include <stdio.h>
#include <cx16.h>

int main(void) {
    printf("Hello from {{PROJECT_NAME}}!\n\n");
    printf("Built with llvm-mos\n");
    printf("Commander X16 - 65C02 @ 8MHz\n\n");
    printf("Press any key...\n");

    // Wait for key using KERNAL GETIN
    while (!cbm_k_getin())
        ;

    return 0;
}
