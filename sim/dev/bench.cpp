
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

// UART clock divider value.
#define UART_CLK_DIV 4

// Original fcntl flags.
int            orig_flags;
// Original termios config.
struct termios orig_term;

void atexit_func() {
    // Restore stdin.
    fcntl(0, F_SETFL, orig_flags);
    // Restore TTY.
    tcsetattr(0, TCSANOW, &orig_term);
}

// Clock divider value for DUT TX pin.
int               tx_div;
// Pending bits to receive from DUT TX pin.
std::vector<bool> tx_pending;
// Clock divider value for DUT RX pin.
int               rx_div;
// Pending bits to send to DUT RX pin.
std::vector<bool> rx_pending;

// Send a byte to DUT RX pin.
void uart_add_rx_pending(uint8_t value) {
    rx_pending.push_back(1);
    rx_pending.push_back(0);
    for (int i = 0; i < 8; i++) {
        rx_pending.push_back((value >> i) & 1);
    }
}

int main(int argc, char **argv) {
    // Add exit handlers.
    atexit(atexit_func);

    // Set stdin to nonblocking.
    orig_flags = fcntl(0, F_GETFL);
    fcntl(0, F_SETFL, orig_flags | O_NONBLOCK);
    // Set TTY to character break.
    tcgetattr(0, &orig_term);
    struct termios new_term  = orig_term;
    new_term.c_lflag        &= ~ICANON & ~ECHO & ~ECHOE;
    tcsetattr(0, TCSANOW, &new_term);

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
    top->rx = 1;
    for (int i = 0; !contextp->gotFinish(); i++) {
        // Run a simulation tick.
        top->eval();
        trace->dump(i * 10);
        top->clk ^= 1;

        // Check input.
        int c = getc(stdin);
        if (c == 4) {
            break;
        } else if (c >= 0) {
            uart_add_rx_pending(c);
        }

        // UART logic.
        if (top->clk) {
            tx_div = (tx_div + 1) % UART_CLK_DIV;
            rx_div = (rx_div + 1) % UART_CLK_DIV;

            // Send a bit to DUT RX pin.
            if (rx_div == 0) {
                if (rx_pending.size()) {
                    top->rx = rx_pending.front();
                    rx_pending.erase(rx_pending.begin());
                } else {
                    top->rx = 1;
                }
            }
            // Receive a bit from RUT TX pin.
            if (tx_pending.size() == 0) {
                if (!top->tx) {
                    tx_pending.push_back(1);
                    tx_div = UART_CLK_DIV / 2;
                }
            } else if (tx_div == 0) {
            }
        }
    }

    // Clean up.
    trace->close();

    return 0;
}
