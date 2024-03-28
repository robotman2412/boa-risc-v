
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// VGA timing parameters.
typedef struct {
    // Front porch width minus one.
    uint32_t volatile fp_width;
    // Video width minus one.
    uint32_t volatile vid_width;
    // Back porch width minus one.
    uint32_t volatile bp_width;
    // Sync width minus one.
    uint32_t volatile sync_width;
} vga_timing_t;

// Clock divider and enable.
typedef struct {
    // VGA enable.
    uint32_t enable  : 1;
    // Clock divider value minus one.
    uint32_t clk_div : 6;
} vga_clkcfg_t;

// VGA controller peripheral.
typedef struct {
    // Clock divider and enable.
    vga_clkcfg_t volatile clk;
    // Pixel coordinate shift right.
    uint32_t volatile coord_shr;
    // Horizontal timing parameters.
    vga_timing_t htiming;
    // Vertical timing parameters.
    vga_timing_t vtiming;
} vga_t;

// VGA controller address.
extern vga_t    VGA asm("__vgactl_base");
// VRAM address.
extern uint16_t VRAM[] asm("__start_extperi");
