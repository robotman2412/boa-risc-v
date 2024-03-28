
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#include "mtime.h"
#include "print.h"
#include "uart.h"
#include "vga.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <string.h>

extern void halt();
extern void reset();
extern void softreset();


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
        halt();

    } else {
        // Trap.
        print("Trap ");
        putd(mcause, 2);
        print("\n");
        halt();
    }
}

static inline uint16_t col_rgb(int r, int g, int b) {
    return ((r & 15) << 8) | ((g & 15) << 4) | (b & 15);
}

static inline void setpix(int x, int y, uint16_t col) {
    VRAM[x + y * 256] = col;
}

void main() {
    mtime                  = 0;
    VGA.htiming.fp_width   = 39;
    VGA.htiming.vid_width  = 799;
    VGA.htiming.sync_width = 127;
    VGA.htiming.bp_width   = 87;
    VGA.vtiming.fp_width   = 0;
    VGA.vtiming.vid_width  = 599;
    VGA.vtiming.sync_width = 3;
    VGA.vtiming.bp_width   = 22;
    VGA.clk.enable         = true;
    for (int y = 0; y < 150; y++) {
        for (int x = 0; x < 200; x++) {
            setpix(x, y, col_rgb(x, y, 0));
        }
    }
    for (int i = 0; i < 10; i++) {
        while (mtime < i * 500000) continue;
        setpix(i, i, 0xfff);
    }
    softreset();
}
