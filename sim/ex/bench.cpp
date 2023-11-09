
#include "Vtop.h"
#include "verilated.h"
#include "verilated_fst_c.h"

int main(int argc, char** argv) {
    // Create contexts.
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop* top = new Vtop{contextp};
    VerilatedFstC *trace = new VerilatedFstC();
    
    // Set up the trace.
    contextp->traceEverOn(true);
    top->trace(trace, 5);
    trace->open("obj_dir/sim.fst");
    
    // Run a number of clock cycles.
    for (int i = 0; i <= 100 && !contextp->gotFinish(); i++) {
        top->clk ^= 1;
        top->eval();
        trace->dump(i*10);
    }
    // while (!contextp->gotFinish()) { top->eval(); }
    
    // Clean up.
    trace->close();
    
    return 0;
}
