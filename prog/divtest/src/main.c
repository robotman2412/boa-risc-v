
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#include "print.h"
#include "rng.h"
#include "uart.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <string.h>

extern void halt();

// Print a hexadecimal number to the UART.
void safe_putx(unsigned long value, unsigned int decimals) {
    static char const hextab[] = "0123456789ABCDEF";
    if (decimals > 8)
        decimals = 8;
    for (int i = decimals * 4 - 4; i >= 0; i -= 4) {
        // UART0.fifo = hextab[(value >> i) & 15];
        int tmp = (value >> i) & 15;
        if (tmp <= 9) {
            UART0.fifo = '0' + tmp;
        } else {
            UART0.fifo = 'A' + tmp - 0xa;
        }
    }
}

void isr() {
    long mcause, mepc, mtval;
    asm("csrr %0, mepc" : "=r"(mepc));
    asm("csrr %0, mcause" : "=r"(mcause));
    asm("csrr %0, mtval" : "=r"(mtval));
    print("MEPC  = 0x");
    safe_putx(mepc, 8);
    print("\nMTVAL = 0x");
    safe_putx(mtval, 8);
    print("\n");
    if (mcause < 0) {
        print("Interrupt 0x");
        safe_putx(mcause & 31, 2);
        print("\n");
    } else {
        print("Trap 0x");
        safe_putx(mcause, 2);
        print("\n");
    }
    while (1) continue;
    halt();
}

#define DIV_TEST(lhs, rhs)                                                                                             \
    {                                                                                                                  \
        long tmp;                                                                                                      \
        print(#lhs " / " #rhs);                                                                                        \
        asm("divu %0, %1, %2" : "=r"(tmp) : "r"(lhs), "r"(rhs));                                                       \
        print(" = 0x");                                                                                                \
        putx(tmp, 8);                                                                                                  \
        print(" (expected 0x");                                                                                        \
        putx(rhs == 0 ? -1 : lhs / rhs, 8);                                                                            \
        print(")\n");                                                                                                  \
        print(#lhs " % " #rhs);                                                                                        \
        asm("remu %0, %1, %2" : "=r"(tmp) : "r"(lhs), "r"(rhs));                                                       \
        print(" = 0x");                                                                                                \
        putx(tmp, 8);                                                                                                  \
        print(" (expected 0x");                                                                                        \
        putx(rhs == 0 ? lhs : lhs % rhs, 8);                                                                           \
        print(")\n");                                                                                                  \
    }

void main() {
    // Wait for an UART byte.
    while (!UART0.status.rx_hasdat) continue;

    DIV_TEST(0x00000000, 0xffffffff)
    DIV_TEST(0xffffffff, 0x00000000)
    DIV_TEST(0x00000f0f, 0x00000003)
    DIV_TEST(0x00000f0f, 0x00000000)
    DIV_TEST(0x0000000f, 0x00000100)
    DIV_TEST(0x00000009, 0x00000004)
}
