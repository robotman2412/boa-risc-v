
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

#include "gpio.h"
#include "mtime.h"
#include "print.h"
#include "rng.h"
#include "uart.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <string.h>

// Delay of 1/256 increment of PWM in microseconds.
#define PWM_DELAY 10

extern void halt();
extern void reset();

uint8_t volatile pwm_r = 0;
uint8_t volatile pwm_g = 0;
uint8_t volatile pwm_b = 0;

void handle_mtime() {
    static uint8_t pwm_state = 1;

    // Update GPIO pins.
    uint32_t cur = GPIO.port;
    pwm_state++;
    if (pwm_state == 0) {
        cur |= (0b111 << 8);
    }
    if (pwm_r == pwm_state)
        cur &= ~(1 << 8);
    if (pwm_g == pwm_state)
        cur &= ~(1 << 9);
    if (pwm_b == pwm_state)
        cur &= ~(1 << 10);
    GPIO.port = cur;

    // Update timer.
    mtimecmp += PWM_DELAY;
}

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

static inline uint64_t time_us() {
    return mtime;
}

static void delay(uint64_t us) {
    uint64_t limit = time_us() + us;
    while (time_us() < limit);
}

void main() {
    // Set mtime to 0.
    mtime = 0;

    // Configure the LEDs to PWM signals.
    GPIO.cfg[8]  = (gpio_pin_t){.ext = true, .signal = 0};
    GPIO.cfg[9]  = (gpio_pin_t){.ext = true, .signal = 1};
    GPIO.cfg[10] = (gpio_pin_t){.ext = true, .signal = 2};

    while (1) {
        bool r = RNG & 1;
        bool g = RNG & 2;
        bool b = RNG & 4;
        for (int i = 0; i < 256; i++) {
            PWM[0].val = r * i;
            PWM[1].val = g * i;
            PWM[2].val = b * i;
            delay(2000);
        }
        for (int i = 255; i >= 0; i--) {
            PWM[0].val = r * i;
            PWM[1].val = g * i;
            PWM[2].val = b * i;
            delay(2000);
        }
    }
}
