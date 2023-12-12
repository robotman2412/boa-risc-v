/*
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
*/

#pragma once

#include <stdint.h>

extern uint64_t volatile mtime asm("__mtime");
extern uint64_t volatile mtimecmp asm("__mtimecmp");
