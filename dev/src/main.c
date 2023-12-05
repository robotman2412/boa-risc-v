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

void print(char const *str) __attribute__((noinline));
void print(char const *str) {
    while (*str) {
        UART0.fifo = *str;
        str++;
    }
}

void main() {
    print("Hello, World!\n");
}
