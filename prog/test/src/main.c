
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#include "print.h"
#include "rng.h"
#include "uart.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <string.h>

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
    } else if (rxlen == sizeof(rxbuf) - 1) {
        done = true;
    } else {
        rxbuf[rxlen++] = c;
    }
}

void main() {
    // Set up interrupts.
    asm("csrs mie, %0" ::"r"(0x00020000));
    asm("csrsi mstatus, 8");
    while (!done) continue;
    done = false;
    print("Hello, what's your name?\n> ");
    while (!done) continue;
    print("Hello, ");
    print((char const *)rxbuf);
    print("!\nYour name is ");
    int len = strlen((char const *)rxbuf);
    putd(len, 3);
    print(" bytes long!\n");
    if (len > 100) {
        print("That's a long name!\n");
    }
}
