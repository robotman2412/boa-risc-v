
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



// Boa PMP address checker interface.
interface boa_pmp_bus#(
    // Width of address to check.
    parameter alen = 32
);
    // CPU->PMP: Address to check.
    logic[alen-1:2] addr;
    // CPU->PMP: Check is running in M-mode.
    logic           m_mode;
    // PMP->CPU: Read permission result.
    logic           r;
    // PMP->CPU: Write permission result.
    logic           w;
    // PMP->CPU: Execute permission result.
    logic           x;
    
    // Interface from CPU perspective.
    modport CPU (output addr, m_mode, input r, w, x);
    // Interface from PMP perspective.
    modport PMP (output r, w, x, input addr, m_mode);
endinterface

// Boa PMP stub.
module boa_pmp_stub(
    boa_pmp_bus.PMP bus
);
    assign bus.r = 1;
    assign bus.w = 1;
    assign bus.x = 1;
endmodule

// Parametric implementation of RISC-V physical memory protection.
module boa_pmp#(
    // Address width, grain+2 to 34.
    parameter int alen     = 32,
    // Number of ignored lower address bits (granularity), 2 to alen-2.
    parameter int grain    = 2,
    // Number of implemented PMPs, either 16 or 64.
    parameter int depth    = 64,
    // Number of address checking ports.
    parameter int checkers = 2
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    // CSR bus.
    boa_csr_bus.CSR     csr,
    
    // Access checking ports.
    boa_pmp_bus.PMP     check_ports[checkers],
    
    // One of the PMPs is being locked.
    output logic        locking
);
    // PMP lock bits.
    reg                 pmplock[depth];
    // PMP configuration storage.
    reg  [4:0]          pmpcfg[depth];
    // PMP address storage.
    reg  [alen-1:grain] pmpaddr[depth];
    
    // Effective writeability of PMPs.
    logic               writeable[depth];
    always @(*) begin
        integer i;
        for (i = 0; i < depth - 1; i = i + 1) begin
            writeable[i] = !pmplock[i] && !(pmplock[i+1] && pmpcfg[i+1][4:3] == `RV_PMP_TOR);
        end
        writeable[depth-1] = !pmplock[depth-1];
    end
    
    // Locking detection.
    always @(*) begin
        locking = 0;
        if (csr.we && csr.addr >= `RV_CSR_PMPCFG0 && csr.addr < `RV_CSR_PMPCFG0 + (depth + 3) / 4) begin
            if (writeable[4 * csr.addr[3:0]] && csr.wdata[7])   locking = 1;
            if (writeable[4 * csr.addr[3:0]+1] && csr.wdata[15]) locking = 1;
            if (writeable[4 * csr.addr[3:0]+2] && csr.wdata[23]) locking = 1;
            if (writeable[4 * csr.addr[3:0]+3] && csr.wdata[31]) locking = 1;
        end
    end
    
    // CSR read interface.
    always @(*) begin
        csr.rdata   = 0;
        csr.exists  = 0;
        if (csr.addr >= `RV_CSR_PMPCFG0 && csr.addr < `RV_CSR_PMPCFG0 + (depth + 3) / 4) begin
            // PMP config CSRs.
            csr.rdata[4:0]      = pmpcfg[4 * csr.addr[3:0]];
            csr.rdata[12:8]     = pmpcfg[4 * csr.addr[3:0]+1];
            csr.rdata[20:16]    = pmpcfg[4 * csr.addr[3:0]+2];
            csr.rdata[28:24]    = pmpcfg[4 * csr.addr[3:0]+3];
            csr.rdata[7]        = pmplock[4 * csr.addr[3:0]];
            csr.rdata[15]       = pmplock[4 * csr.addr[3:0]+1];
            csr.rdata[23]       = pmplock[4 * csr.addr[3:0]+2];
            csr.rdata[31]       = pmplock[4 * csr.addr[3:0]+3];
            csr.exists          = 1;
            
        end else if (csr.addr >= `RV_CSR_PMPADDR0 && csr.addr < `RV_CSR_PMPADDR0 + depth) begin
            // PMP address CSRs.
            csr.rdata[grain-2:0]        = pmpcfg[csr.addr - `RV_CSR_PMPADDR0][4:3] == 3 ? 32'hffff_ffff : 0;
            csr.rdata[alen-3:grain-2]   = pmpaddr[csr.addr - `RV_CSR_PMPADDR0][alen-1:grain];
            csr.exists                  = 1;
        end
    end
    
    // CSR write interface.
    always @(posedge clk) begin
        if (rst) begin
            integer i;
            for (i = 0; i < depth; i = i + 1) begin
                pmpcfg[i]  <= 0;
                pmpaddr[i] <= 0;
            end
        end else if (csr.we) begin
            if (csr.addr >= `RV_CSR_PMPCFG0 && csr.addr < `RV_CSR_PMPCFG0 + (depth + 3) / 4) begin
                bit[31:0] wdata;
                wdata = csr.wdata;
                if (grain != 2) begin
                    wdata[3   ] |= csr.wdata[4   ];
                    wdata[3+8 ] |= csr.wdata[4+8 ];
                    wdata[3+16] |= csr.wdata[4+16];
                    wdata[3+24] |= csr.wdata[4+24];
                end
                // PMP config CSRs.
                if (writeable[4 * csr.addr[3:0]])   pmpcfg[4 * csr.addr[3:0]]   <= wdata[4:0];
                if (writeable[4 * csr.addr[3:0]+1]) pmpcfg[4 * csr.addr[3:0]+1] <= wdata[12:8];
                if (writeable[4 * csr.addr[3:0]+2]) pmpcfg[4 * csr.addr[3:0]+2] <= wdata[20:16];
                if (writeable[4 * csr.addr[3:0]+3]) pmpcfg[4 * csr.addr[3:0]+3] <= wdata[28:24];
                pmplock[4 * csr.addr[3:0]]   <= pmplock[4 * csr.addr[3:0]]   | csr.wdata[7];
                pmplock[4 * csr.addr[3:0]+1] <= pmplock[4 * csr.addr[3:0]+1] | csr.wdata[15];
                pmplock[4 * csr.addr[3:0]+2] <= pmplock[4 * csr.addr[3:0]+2] | csr.wdata[23];
                pmplock[4 * csr.addr[3:0]+3] <= pmplock[4 * csr.addr[3:0]+3] | csr.wdata[31];
                
            end else if (csr.addr >= `RV_CSR_PMPADDR0 && csr.addr < `RV_CSR_PMPADDR0 + depth) begin
                // PMP address CSRs.
                if (writeable[csr.addr - `RV_CSR_PMPADDR0]) begin
                    pmpaddr[csr.addr - `RV_CSR_PMPADDR0][alen-1:grain] <= csr.wdata[alen-3:grain-2];
                end
            end
        end
    end
    
    // Access checkers.
    generate
        genvar x;
        for (x = 0; x < checkers; x = x + 1) begin
            boa_pmp_checker#(alen, grain, depth) pmp_checker(pmplock, pmpcfg, pmpaddr, check_ports[x]);
        end
    endgenerate
endmodule

// PMP access checker.
module boa_pmp_checker#(
    // Address width, grain+2 to 34.
    parameter int alen     = 32,
    // Number of ignored lower address bits (granularity), 2 to alen-2.
    parameter int grain    = 2,
    // Number of implemented PMPs, either 16 or 64.
    parameter int depth    = 64
)(
    // PMP lock status.
    input  logic                pmplock[depth],
    // PMP configuration storage.
    input  logic[4:0]           pmpcfg[depth],
    // PMP address storage.
    input  logic[alen-1:grain]  pmpaddr[depth],
    
    // Access checking port.
    boa_pmp_bus.PMP             bus
);
    genvar x;
    
    // PMPs that contain this memory address.
    logic[depth-1:0] pmp_contains;
    boa_pmp_contains#(alen, grain) cont0(bus.addr[alen-1:grain], pmpcfg[0], pmpaddr[0], 0, pmp_contains[0]);
    generate
        for (x = 1; x < depth; x = x + 1) begin
            boa_pmp_contains#(alen, grain) contx(bus.addr[alen-1:grain], pmpcfg[x], pmpaddr[x], pmpaddr[x-1], pmp_contains[x]);
        end
    endgenerate
    
    // Filter PMPs by whether they apply to the current privilege mode.
    logic[depth-1:0] pmp_filter;
    generate
        for (x = 0; x < depth; x = x + 1) begin
            assign pmp_filter[x] = pmp_contains[x] && (!bus.m_mode || pmplock[x]);
        end
    endgenerate
    
    // The highest priority PMP that matches.
    logic[depth-1:0] pmp_active;
    assign pmp_active[0] = pmp_filter[0];
    generate
        for (x = 1; x < depth; x = x + 1) begin
            assign pmp_active[x] = pmp_filter[x] && pmp_filter[x-1:0] == 0;
        end
    endgenerate
    
    // Report the result.
    always @(*) begin
        integer i;
        if (pmp_contains == 0 && bus.m_mode) begin
            bus.r = 1;
            bus.w = 1;
            bus.x = 1;
        end else begin
            bus.r = 0;
            bus.w = 0;
            bus.x = 0;
            for (i = 0; i < depth; i = i + 1) begin
                bus.r |= pmp_active[i] && pmpcfg[i][0];
                bus.w |= pmp_active[i] && pmpcfg[i][1];
                bus.x |= pmp_active[i] && pmpcfg[i][2];
            end
        end
    end
endmodule

// Checks if an address is within the range specified by a PMP.
module boa_pmp_contains#(
    // Address width, grain+2 to 34.
    parameter int alen     = 32,
    // Number of ignored lower address bits (granularity), 2 to alen-2.
    parameter int grain    = 2
)(
    // Memory address to check.
    input  logic[alen-1:grain]  addr,
    
    // PMP configuration.
    input  logic[4:0]           pmpcfg,
    // PMP address.
    input  logic[alen-1:grain]  pmpaddr,
    // Previous PMP address.
    input  logic[alen-1:grain]  base,
    
    // PMP contains this memory address.
    output logic                contains
);
    genvar x;
    
    // NAPOT bit mask generation.
    /* verilator lint_off UNOPTFLAT */
    logic[alen-1:grain] napot_mask;
    logic[alen-1:grain] napot_bit;
    assign napot_mask[grain] =  pmpaddr[grain];
    assign napot_bit[grain]  = !pmpaddr[grain];
    generate
        for (x = grain+1; x < alen; x = x + 1) begin
            assign napot_mask[x] = napot_mask[x-1] &&  pmpaddr[x];
            assign napot_bit[x]  = napot_mask[x-1] && !pmpaddr[x];
        end
    endgenerate
    /* verilator lint_on UNOPTFLAT */
    
    always @(*) begin
        case (pmpcfg[4:3])
            `RV_PMP_OFF:    contains = 0;
            `RV_PMP_TOR:    contains = addr >= base && addr < pmpaddr;
            `RV_PMP_NA4:    contains = grain == 2 && pmpaddr == addr;
            `RV_PMP_NAPOT:  contains = (addr | napot_mask | napot_bit) == (pmpaddr | napot_bit);
        endcase
    end
endmodule
