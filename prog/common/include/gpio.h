
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

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
    uint32_t volatile port;
    // Pin output enable.
    uint32_t volatile oe;
    // Padding.
    uint32_t volatile _padding[30];
    // Pin configuration.
    gpio_pin_t volatile cfg[32];
} gpio_t;

// PWM peripheral.
typedef struct {
    // PWM value.
    uint8_t volatile val;
    // PWM clock divider.
    uint8_t volatile div;
    // Padding.
    uint32_t volatile _padding[3];
} pwm_t;

// GPIO address.
extern gpio_t GPIO asm("__gpio_base");
// PWM address.
extern pwm_t  PWM[8] asm("__pwm_base");
