/*
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
*/

#pragma once

#include <stddef.h>

// Write raw data to the UART.
void write(void const *data, size_t len);
// Print a character to the UART.
void putc(char c);
// Print a C-string to the UART.
void print(char const *str);
// Print a decimal number to the UART.
void putd(unsigned long value, unsigned int decimals);
