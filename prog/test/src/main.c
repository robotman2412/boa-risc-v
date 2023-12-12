/*
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
*/

#include "print.h"
#include "uart.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

extern void halt();

size_t rxlen = 0;
char volatile rxbuf[256];
bool volatile done = false;
void isr() {
    // This ISR is triggered when there is an RX byte available.
    char c     = UART0.fifo;
    UART0.fifo = c;
    if (c == '\n') {
        done = true;
    } else {
        rxbuf[rxlen++] = c;
    }
}

void main() {
    // Set up interrupts.
    asm("csrs mie, %0" ::"r"(0x00020000));
    asm("csrsi mstatus, 8");
    while (!done);
    done = false;
    print("Hello, what's your name?\n> ");
    while (!done);
    print("Hello, ");
    print((char const *)rxbuf);
    print("!\n");
}
