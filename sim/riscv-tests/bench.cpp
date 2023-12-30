
#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtop.h"

#include <stdio.h>
#include <stdlib.h>

#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <termios.h>
#include <unistd.h>
#include <vector>

int            stdin_orig_flags;
struct termios stdin_orig_term;

void atexit_func() {
    // Restore stdin.
    fcntl(fileno(stdin), F_SETFL, stdin_orig_flags);
    tcsetattr(fileno(stdin), TCSANOW, &stdin_orig_term);
}

int main(int argc, char **argv) {
    int ec = 0;

    // Add exit handlers.
    atexit(atexit_func);

    // Set UART to nonblocking.
    stdin_orig_flags = fcntl(0, F_GETFL);
    fcntl(fileno(stdin), F_SETFL, stdin_orig_flags | O_NONBLOCK);
    // Set TTY to character break.
    tcgetattr(fileno(stdin), &stdin_orig_term);
    struct termios new_term  = stdin_orig_term;
    new_term.c_lflag        &= ~ICANON & ~ECHO & ~ECHOE;
    tcsetattr(fileno(stdin), TCSANOW, &new_term);

    // Create contexts.
    VerilatedContext *contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop          *top   = new Vtop{contextp};
    VerilatedFstC *trace = new VerilatedFstC();

    // Set up the trace.
    contextp->traceEverOn(true);
    top->trace(trace, 5);
    trace->open("obj_dir/sim.fst");

    // Run a number of clock cycles.
    for (int i = 0; !contextp->gotFinish(); i++) {
        // Run a simulation tick.
        top->eval();
        trace->dump(i * 10);
        top->clk ^= 1;

        if (top->is_ecall && top->clk) {
            int a0 = top->regs[10];
            int a7 = top->regs[17];
            if (a7 != 93) {
                continue;
            } else if (a0 != 0) {
                printf("Case #%d failed\n", a0 >> 1);
                ec = a0;
            } else {
                printf("Test succeeded\n");
                ec = 0;
            }
            break;
        }

        // Check input.
        if (getc(stdin) == 4) {
            printf("Test cancelled\n");
            ec = -2;
            break;
        }
    }

    // Clean up.
    trace->close();

    return ec;
}
