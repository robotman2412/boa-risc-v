/*
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
*/

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// UART status register.
typedef struct {
    // System reset.
    uint32_t rst       : 1;
    // System shutdown.
    uint32_t shdn      : 1;
    // Padding.
    uint32_t _padding0 : 30;
} pmu_status_t;

// UART peripheral.
typedef struct {
    // Status register.
    pmu_status_t volatile status;
} pmu_t;

// PMU address.
extern pmu_t PMU asm("__pmu_base");
