
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#include "print.h"
#include "uart.h"
#include "vga.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <string.h>

extern void halt();
extern void reset();


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

void main() {
    while (!UART0.status.rx_hasdat) continue;
    VGA.clk.enable = true;
    print("CLKCFG:   ");
    putx(*(uint32_t *)&VGA.clk, 8);
    putc('\n');
    print("SHR:      ");
    putx(VGA.coord_shr, 8);
    putc('\n');
    print("H FP:     ");
    putx(VGA.htiming.fp_width, 8);
    putc('\n');
    print("H VID:    ");
    putx(VGA.htiming.vid_width, 8);
    putc('\n');
    print("H BP:     ");
    putx(VGA.htiming.bp_width, 8);
    putc('\n');
    print("H SYNC:   ");
    putx(VGA.htiming.sync_width, 8);
    putc('\n');
    print("V FP:     ");
    putx(VGA.vtiming.fp_width, 8);
    putc('\n');
    print("V VID:    ");
    putx(VGA.vtiming.vid_width, 8);
    putc('\n');
    print("V BP:     ");
    putx(VGA.vtiming.bp_width, 8);
    putc('\n');
    print("V SYNC:   ");
    putx(VGA.vtiming.sync_width, 8);
    putc('\n');
    VRAM[0] = 0xfff;
    VRAM[1] = 0xf00;
    VRAM[2] = 0x0f0;
    VRAM[3] = 0x00f;
    VRAM[4] = 0x000;
    while (1) continue;
}
