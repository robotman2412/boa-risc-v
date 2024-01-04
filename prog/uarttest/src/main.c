
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#include "print.h"
#include "rng.h"
#include "uart.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <string.h>

extern void halt();

void isr() {
    long mcause;
    asm("csrr %0, mcause" : "=r"(mcause));
    if (mcause < 0) {
        // Interrupt.
        mcause &= 31;
        // Unhandled interrupt.
        print("Interrupt ");
        putd(mcause, 2);
        print("\n");
        // halt();

    } else {
        // Trap.
        print("Trap ");
        putd(mcause, 2);
        print("\n");
        // halt();
    }
}

void main() {
    // Set UART to 115200 baud.
    UART0.clk_div = 104;
    // Wait for a UART receive.
    while (!UART0.status.rx_hasdat);
    // Print a funny message.
    print("Hello, World at 115200 baud! I'm making this message extra long just to make sure it all gets received "
          "properly.\n");
}
