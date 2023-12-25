
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`include "boa_defines.sv"



module top(
    input logic clk
);
    wire rst = 0;
    reg[7:0] cycle;
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
    
    logic       csr_we;
    logic[11:0] csr_addr;
    logic[31:0] csr_wdata;
    logic       csr_present;
    logic[31:0] csr_rdata;
    
    boa_pmp_bus pmp_bus[1]();
    assign pmp_bus[0].m_mode = 0;
    
    boa_pmp#(.checkers(1)) pmp(
        clk, rst,
        csr_we, csr_addr, csr_wdata, csr_present, csr_rdata,
        pmp_bus
    );
    
    always @(*) begin
        case (cycle)
            default: begin csr_we = 0; csr_addr = 0; csr_wdata = 0; pmp_bus[0].addr = 32'h0000_0000; end
            1:  begin csr_we = 1; csr_addr = `RV_CSR_PMPADDR0; csr_wdata = 32'h0000_0003;       pmp_bus[0].addr = 30'h0000_0000; end
            2:  begin csr_we = 1; csr_addr = `RV_CSR_PMPADDR1; csr_wdata = 32'h0000_000B;       pmp_bus[0].addr = 30'h0000_0000; end
            3:  begin csr_we = 1; csr_addr = `RV_CSR_PMPCFG0;  csr_wdata = 8'b0_00_01_011 << 8; pmp_bus[0].addr = 30'h0000_0000; end
            10: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0000; end
            11: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0001; end
            12: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0002; end
            13: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0003; end
            14: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0004; end
            15: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0005; end
            16: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0006; end
            17: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0007; end
            18: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0008; end
            19: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_0009; end
            20: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_000A; end
            21: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_000B; end
            22: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_000C; end
            23: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_000D; end
            24: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_000E; end
            25: begin csr_we = 0; csr_addr = 12'h000;          csr_wdata = 32'h0000_0000;       pmp_bus[0].addr = 30'h0000_000F; end
        endcase
    end
endmodule
