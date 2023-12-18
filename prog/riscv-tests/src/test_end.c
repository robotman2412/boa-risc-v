
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

#include "print.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static char const *const desc[] = {
    "Instruction access misaligned",
    "Instruction access fault",
    "Illegal instruction",
    "Trace / breakpoint trap",
    "Load access misaligned",
    "Load access fault",
    "Store / AMO access misaligned",
    "Store / AMO access fault",
    "ECALL from U-mode",
    "ECALL from S-mode",
    "Trap #10",
    "ECALL from M-mode",
    "Instruction page fault",
    "Load page fault",
    "Trap #14",
    "Store / AMO page fault",
};

extern void halt() __attribute__((noreturn));

void real_test_end(long arg, long testnum) {
    long mcause;
    asm("csrr %0, mcause" : "=r"(mcause));

    if (mcause == 11) {
        if (arg == 1) {
            print("TEST END\n");
        } else if (arg == 2) {
            print("TEST PASS\n");
        } else if (arg == 3) {
            print("TEST #");
            putd(testnum, 3);
            print(" FAIL\n");
        }
    } else {
        if (mcause < 0) {
            mcause &= 31;
            print("Interrupt #");
            putd(mcause, 2);
            print("\n");
        } else {
            print(desc[mcause]);
            print("\n");
        }

        long mepc;
        asm("csrr %0, mepc" : "=r"(mepc));
        print("PC=0x");
        putx(mepc, 8);
        print("\n");
    }

    halt();
}
