/*
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
*/

#pragma once

#include "../riscv-tests/env/p/riscv_test.h"

// clang-format off

#undef RVTEST_CODE_END
#define RVTEST_CODE_END \
    .global test_end;   \
    li a0, 1;           \
    j test_end

#undef RVTEST_PASS
#define RVTEST_PASS     \
    .global test_end;   \
    li a1, 1;           \
    j test_end

#undef RVTEST_FAIL
#define RVTEST_FAIL     \
    .global test_end;   \
    li a0, 1;           \
    mv a1, TESTNUM;     \
    j test_end

// clang-format on
