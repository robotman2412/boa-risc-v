/*
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
*/

#include "uart.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

void print(char const *str) {
    while (*str) {
        UART0.fifo = *str;
        str++;
    }
}

void putd(long value, int decimals) {
    for (int i = 0; i < decimals; i++) {
        UART0.fifo  = '0' + value % 10;
        value      /= 10;
    }
}

void main() {
    print("Hello, World!\n");
    putd(123, 4);
    print("\n");
}
