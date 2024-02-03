
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#include "print.h"

#include "uart.h"



// Write raw data to the UART.
void write(void const *data, size_t len) {
    uint8_t const *ptr = data;
    for (size_t i = 0; i < len; i++) {
        UART0.fifo = ptr[i];
    }
}

// Print a character to the UART.
void putc(char c) {
    UART0.fifo = c;
}

// Print a C-string to the UART.
void print(char const *str) {
    while (*str) {
        UART0.fifo = *str;
        str++;
    }
}

// Print a decimal number to the UART.
void putd(unsigned long value, unsigned int decimals) {
    if (decimals > 10)
        decimals = 10;
    char buf[10];
    for (int i = 0; i < 10; i++) {
        buf[i]  = value % 10;
        value  /= 10;
    }
    for (int i = decimals - 1; i >= 0; i--) {
        UART0.fifo = '0' + buf[i];
    }
}

// Print a hexadecimal number to the UART.
void putx(unsigned long value, unsigned int decimals) {
    static char const hextab[] = "0123456789ABCDEF";
    if (decimals > 8)
        decimals = 8;
    for (int i = decimals * 4 - 4; i >= 0; i -= 4) {
        UART0.fifo = hextab[(value >> i) & 15];
        // int tmp = (value >> i) & 15;
        // if (tmp <= 9) {
        //     UART0.fifo = '0' + tmp;
        // } else {
        //     UART0.fifo = 'A' + tmp - 0xa;
        // }
    }
}
