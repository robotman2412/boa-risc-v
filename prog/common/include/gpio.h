
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// GPIO pin configuration value.
typedef struct {
    // External signal select.
    uint32_t signal   : 16;
    // External signal enable.
    uint32_t ext      : 1;
    // Padding.
    uint32_t _padding : 15;
} gpio_pin_t;

// GPIO peripheral.
typedef struct {
    // Pin I/O.
    volatile uint32_t   port;
    // Pin output enable.
    volatile uint32_t   oe;
    // Padding.
    volatile uint32_t   _padding[30];
    // Pin configuration.
    volatile gpio_pin_t cfg[32];
} gpio_t;

// GPIO address.
extern gpio_t GPIO asm("__gpio_base");
