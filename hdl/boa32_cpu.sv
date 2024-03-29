
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



/*
    Boa³² RV32IMC_Zicsr_Zifencei processor.
    
    Pipeline:           5 stages (IF, ID, EX, MEM, WB)
    IPC:                0.33 min, ?.?? avg, 1.00 max
    Interrupts:         16 external, 1 internal
    Privileges:         M-mode, U-mode
    Memory protection:  PMP
    
    Implemented CSRs:
        0x300   mstatus
        0x301   misa        (read or read/write)
        0x302   medeleg     (0)
        0x303   mideleg     (0)
        0x304   mie
        0x305   mtvec
        0x310   mstatush    (0)
        
        0x344   mip
        0x340   mscratch
        0x341   mepc
        0x342   mcause
        0x343   mtval
        
        0xf11   mvendorid   (0)
        0xf12   marchid     (37)
        0xf13   mimpid      (derived from parameters)
        0xf14   mhartid     (parameter)
        0xf15   mconfigptr  (0)
        
        0x3a0   pmpcfg0
        ...     ...         ...
        0x3af   pmpcfg15
        0x3b0   pmpaddr0
        ...     ...         ...
        0x3ef   pmpaddr63
    
    Implemented MMIO:
        cpummio + 0x000     mtime
        cpummio + 0x008     mtimecmp
*/
module boa32_cpu#(
    // Entrypoint address.
    parameter entrypoint    = 32'h4000_0000,
    // CPU-local memory-mapped I/O address.
    parameter cpummio       = 32'hff00_0000,
    // CSR mhartid value (CPU number).
    parameter hartid        = 32'h0000_0000,
    // Print debug messages about CPU state.
    parameter debug         = 0,
    // Divider latency, 0 to 33.
    // Only applicable if has_m is 1.
    parameter div_latency   = 2,
    // Divider pipeline register distribution.
    // Only applicable if has_m is 1.
    parameter div_distr     = "center",
    // Multiplier latency, 0 or 1.
    // Only applicable if has_m is 1.
    parameter mul_latency   = 0,
    // Enable additional latch in IF branch address.
    parameter if_branch_reg = 0,
    // Enable additional latch for RMW AMOs.
    // Only applicable if has_a is 1.
    parameter rmw_amo_reg   = 0,
    // Support configurability through misa.
    parameter misa_we       = 0,
    // Support user mode.
    parameter has_u_mode    = 1,
    // Number of implemented PMPs, 0, 16 or 64.
    parameter pmp_depth     = 16,
    // If PMP is implemented: PMP granularity, 2-30.
    parameter pmp_grain     = 2,
    // Support M (multiply/divide) instructions.
    parameter has_m         = 1,
    // Support A (atomic memory operation) instructions.
    parameter has_a         = 1,
    // Support C (compressed) instructions.
    parameter has_c         = 1
)(
    // CPU clock.
    input  logic    clk,
    // Timekeeping clock, must not be faster than CPU clock.
    input  logic    rtc_clk,
    // Synchronous reset.
    input  logic    rst,
    
    // Program memory bus.
    boa_mem_bus.CPU pbus,
    // Data memory bus.
    boa_mem_bus.CPU dbus,
    
    // Perform a release data fence.
    output logic    fence_rl,
    // Perform an acquire data fence.
    output logic    fence_aq,
    // Perform an acquire instruction fence.
    output logic    fence_i,
    
    // Current memory access is an AMO (disable caches).
    // Always 0 if A extension isn't enabled.
    output logic    amo_en,
    // Atomic reservation bus for LR/SC sequences.
    // Never used if A extension isn't enabled.
    boa_amo_bus.CPU resv_bus,
    
    // External interrupts 16 to 31.
    input  logic[31:16] irq
);
    genvar x;
    
    // Current privilege mode.
    logic[1:0]  cur_priv;
    
    /* ==== Pipeline barriers ==== */
    // IF: Exception occurred.
    logic       fw_exception;
    // IF: Exception vector.
    logic[31:2] fw_tvec;
    
    // IF/ID: Result valid.
    logic       if_id_valid;
    // IF/ID: Current instruction PC.
    logic[31:1] if_id_pc;
    // IF/ID: Current instruction word.
    logic[31:0] if_id_insn;
    // IF/ID: Trap raised.
    logic       if_id_trap;
    // IF/ID: Trap cause.
    logic[3:0]  if_id_cause;
    
    // ID/EX: Result valid.
    logic       id_ex_valid;
    // ID/EX: Current instruction PC.
    logic[31:1] id_ex_pc;
    // ID/EX: Current instruction word.
    logic[31:0] id_ex_insn;
    // ID/EX: Is 32-bit instruction.
    logic       id_ex_ilen;
    // ID/EX: Stores to register RD.
    logic       id_ex_use_rd;
    // ID/EX: Value from RS1 register.
    logic[31:0] id_ex_rs1_val;
    // ID/EX: Value from RS2 register.
    logic[31:0] id_ex_rs2_val;
    // ID/EX: Conditional branch.
    logic       id_ex_branch;
    // ID/EX: Branch prediction result.
    logic       id_ex_branch_predict;
    // ID/EX: Trap raised.
    logic       id_ex_trap;
    // ID/EX: Trap cause.
    logic[3:0]  id_ex_cause;
    
    // EX/MEM: Result valid.
    logic       ex_mem_valid;
    // EX/MEM: Current instruction PC.
    logic[31:1] ex_mem_pc;
    // EX/MEM: Current instruction word.
    logic[31:0] ex_mem_insn;
    // EX/MEM: Stores to register RD.
    logic       ex_mem_use_rd;
    // EX/MEM: Value from RS1 register / ALU result / memory address.
    logic[31:0] ex_mem_rs1_val;
    // EX/MEM: Value from RS2 register / memory write data.
    logic[31:0] ex_mem_rs2_val;
    // EX/MEM: Trap raised.
    logic       ex_mem_trap;
    // EX/MEM: Trap cause.
    logic[3:0]  ex_mem_cause;
    
    // MEM/WB: Result valid.
    logic       mem_wb_valid;
    // MEM/WB: Current instruction PC.
    logic[31:1] mem_wb_pc;
    // MEM/WB: Current instruction word.
    logic[31:0] mem_wb_insn;
    // MEM/WB: Stores to register RD.
    logic       mem_wb_use_rd;
    // MEM/WB: Value to store to register Rd.
    logic[31:0] mem_wb_rd_val;
    // MEM/WB: Trap raised.
    logic       mem_wb_trap;
    // MEM/WB: Trap cause.
    logic[3:0]  mem_wb_cause;
    // Virtual address for traps.
    logic[31:0] mem_vaddr;
    
    // WB: Result valid.
    logic       wb_valid;
    // WB: Stores to register RD.
    logic       wb_use_rd;
    // WB: Value to store to register RD.
    logic[31:0] wb_rd_val;
    // WB: Current instruction word.
    logic[31:0] wb_insn;
    
    // Stall IF stage.
    logic       fw_stall_if;
    // Stall ID stage.
    logic       fw_stall_id;
    // Stall EX stage.
    logic       fw_stall_ex;
    // Stall MEM stage.
    logic       fw_stall_mem;
    // Stall request from EX stage.
    logic       ex_stall_req;
    // Stall request from MEM stage.
    logic       mem_stall_req;
    
    
    /* ==== CSR logic ==== */
    // CSR misa: M-mode ISA description.
    logic[31:0] csr_misa;
    // CSR status.MIE: M-mode interrupt enable.
    logic       csr_status_mie;
    // CSR status.SIE: S-mode interrupt enable.
    logic       csr_status_sie;
    // CSR status.MPRV: Modify M-mode memory access privilege.
    logic       csr_status_mprv;
    // CSR status.MPP: M-mode previous privilege.
    logic[1:0]  csr_status_mpp;
    // One of the PMPs is being locked.
    logic       pmp_locking;
    
    boa_csr_bus csr();
    boa_csr_ex_bus csr_ex();
    boa_pmp_bus pmpbus[2]();
    generate
        if (pmp_depth) begin: csr_with_pmp
            // CSR mux.
            boa_csr_bus csr_mux_bus[2]();
            boa_csr_overlay#(2) csr_mux(csr, csr_mux_bus);
            // PMP unit.
            boa_pmp#(
                .grain(pmp_grain),
                .depth(pmp_depth),
                .checkers(2)
            ) pmp (
                clk, rst,
                csr_mux_bus[1], pmpbus,
                pmp_locking
            );
            // CSR register file.
            boa32_csrs#(
                .hartid(hartid),
                .misa_we(misa_we),
                .has_u_mode(has_u_mode),
                .has_m(has_m),
                .has_a(has_a),
                .has_c(has_c)
            ) csrs (
                clk, rst,
                csr_mux_bus[0], csr_ex,
                csr_misa,
                csr_status_mie,
                csr_status_sie,
                csr_status_mprv,
                csr_status_mpp
            );
        end else begin: csr_without_pmp
            // PMP stubs.
            boa_pmp_stub pmpstub0(pmpbus[0]);
            boa_pmp_stub pmpstub1(pmpbus[1]);
            assign pmp_locking = 0;
            // CSR register file.
            boa32_csrs#(
                .hartid(hartid),
                .misa_we(misa_we),
                .has_u_mode(has_u_mode),
                .has_m(has_m),
                .has_a(has_a),
                .has_c(has_c)
            ) csrs (
                clk, rst,
                csr, csr_ex,
                csr_misa,
                csr_status_mie,
                csr_status_sie,
                csr_status_mprv,
                csr_status_mpp
            );
        end
    endgenerate
    
    // Privilege mode switching logic.
    assign csr_ex.ex_pp = cur_priv;
    generate
        if (has_u_mode) begin: priv_with_u
            always @(posedge clk) begin
                if (rst) begin
                    // Reset.
                    cur_priv <= 3;
                    
                end else if (csr_ex.ex_trap || csr_ex.ex_irq) begin
                    // Exception.
                    cur_priv <= 3;
                    
                end else if (csr_ex.ret) begin
                    // Exception return.
                    cur_priv <= csr_ex.ret_pp;
                end
            end
        end else begin: priv_without_u
            // Always M.
            assign cur_priv = 3;
        end
    endgenerate
    
    
    /* ==== Control transfer logic ==== */
    // Clear results from IF.
    logic       clear_if;
    // Clear results from ID.
    logic       clear_id;
    // Clear results from EX.
    logic       clear_ex;
    // Clear results from MEM.
    logic       clear_mem;
    
    // MRET or SRET instruction.
    logic       is_xret;
    // Is SRET instead of MRET.
    logic       is_sret;
    // Unconditional jump (JAL or JALR).
    logic       is_jump;
    // Conditional branch.
    logic       is_branch;
    // Branch predicted.
    logic       branch_predict;
    // Branch target address.
    logic[31:1] branch_target;
    
    // Predicted branch or unconditional control transfer.
    logic       fw_branch_predict;
    // Target address of control transfer.
    logic[31:1] fw_branch_target;
    // Address of the next instruction.
    logic[31:1] if_next_pc;
    // Mispredicted branch.
    logic       fw_branch_correct;
    // Branch correction address.
    logic[31:1] fw_branch_alt;
    
    always @(posedge clk) begin
        if (is_branch) begin
            fw_branch_alt <= fw_branch_predict ? if_next_pc : fw_branch_target;
        end
    end
    
    always @(*) begin
        if (fw_branch_correct && debug) begin
            $strobe("Branch correction to %x", fw_branch_alt<<1);
        end
        if (id_ex_valid && !fw_stall_id && is_xret) begin
            // MRET.
            csr_ex.ret          = 1;
            fw_branch_predict   = 1;
            fw_branch_target    = csr_ex.ret_epc;
            if (debug) $strobe("MRET from %x to %x", id_ex_pc<<1, fw_branch_target<<1);
        end else if (id_ex_valid && is_jump) begin
            // JAL or JALR.
            csr_ex.ret          = 0;
            fw_branch_predict   = 1;
            fw_branch_target    = branch_target;
            if (debug) $strobe("JAL(R) from %x to %x", id_ex_pc<<1, fw_branch_target<<1);
        end else if (id_ex_valid && is_branch) begin
            // Branch opcodes.
            csr_ex.ret          = 0;
            fw_branch_predict   = branch_predict;
            fw_branch_target    = branch_target;
            if (debug) $strobe("BRANCH from %x to %x", id_ex_pc<<1, fw_branch_target<<1);
        end else if (pmp_locking) begin
            // PMP being locked.
            // Send instruction in ID back to IF to have its permissions checked again.
            csr_ex.ret          = 0;
            fw_branch_predict   = 1;
            fw_branch_target    = id_ex_pc;
        end else begin
            // Not a control transfer.
            csr_ex.ret          = 0;
            fw_branch_predict   = 0;
            fw_branch_target    = 'bx;
        end
    end
    
    
    /* ==== Data hazard avoidance ==== */
    // Is an instruction fetch fence instruction.
    logic       is_fencei;
    
    // EX uses RS1 value.
    logic       use_rs1_ex;
    // EX uses RS2 value.
    logic       use_rs2_ex;
    // MEM uses RS1 value.
    logic       use_rs1_mem;
    // MEM uses RS2 value.
    logic       use_rs2_mem;
    // Branch target address uses RS1 value.
    logic       use_rs1_bt;
    
    // Can forward from EX.
    logic       fw_rd_ex;
    // Forwarding output from EX.
    wire [31:0] fw_out_ex  = ex_mem_rs1_val;
    // Forwarding output from MEM.
    wire [31:0] fw_out_mem = mem_wb_rd_val;
    
    // Forward RS1 to branch target address.
    logic       fw_rs1_bt;
    // Forward RS1 to EX.
    logic       fw_rs1_ex;
    // Forward RS2 to EX.
    logic       fw_rs2_ex;
    // Forward RS1 to MEM.
    logic       fw_rs1_mem;
    // Forward RS2 to MEM.
    logic       fw_rs2_mem;
    
    // Forwarding input to branch target address.
    logic[31:0] fw_in_bt;
    // Forwarding input to EX RS1.
    logic[31:0] fw_in_rs1_ex;
    // Forwarding input to EX RS2.
    logic[31:0] fw_in_rs2_ex;
    // Forwarding input to MEM RS1.
    logic[31:0] fw_in_rs1_mem;
    // Forwarding input to MEM RS2.
    logic[31:0] fw_in_rs2_mem;
    
    // RS1 for branch target matches RD for EX.
    wire eq_bt_rs1_ex_rd    = use_rs1_bt  && id_ex_valid  && ex_mem_valid && ex_mem_use_rd && (id_ex_insn[19:15] != 0)  && (id_ex_insn[19:15]  == ex_mem_insn[11:7]);
    // RS1 for branch target matches RD for MEM.
    wire eq_bt_rs1_mem_rd   = use_rs1_bt  && id_ex_valid  && mem_wb_valid && mem_wb_use_rd && (id_ex_insn[19:15] != 0)  && (id_ex_insn[19:15]  == mem_wb_insn[11:7]);
    
    // RS1 for EX matches RD for EX.
    wire eq_ex_rs1_ex_rd    = use_rs1_ex  && id_ex_valid  && ex_mem_valid && ex_mem_use_rd && (id_ex_insn[19:15] != 0)  && (id_ex_insn[19:15]  == ex_mem_insn[11:7]);
    // RS2 for EX matches RD for EX.
    wire eq_ex_rs2_ex_rd    = use_rs2_ex  && id_ex_valid  && ex_mem_valid && ex_mem_use_rd && (id_ex_insn[24:20] != 0)  && (id_ex_insn[24:20]  == ex_mem_insn[11:7]);
    // RS1 for EX matches RD for MEM.
    wire eq_ex_rs1_mem_rd   = use_rs1_ex  && id_ex_valid  && mem_wb_valid && mem_wb_use_rd && (id_ex_insn[19:15] != 0)  && (id_ex_insn[19:15]  == mem_wb_insn[11:7]);
    // RS2 for EX matches RD for MEM.
    wire eq_ex_rs2_mem_rd   = use_rs2_ex  && id_ex_valid  && mem_wb_valid && mem_wb_use_rd && (id_ex_insn[24:20] != 0)  && (id_ex_insn[24:20]  == mem_wb_insn[11:7]);
    
    // RS1 for MEM matches RD for MEM.
    wire eq_mem_rs1_mem_rd  = use_rs1_mem && ex_mem_valid && mem_wb_valid && mem_wb_use_rd && (ex_mem_insn[19:15] != 0) && (ex_mem_insn[19:15] == mem_wb_insn[11:7]);
    // RS2 for MEM matches RD for MEM.
    wire eq_mem_rs2_mem_rd  = use_rs2_mem && ex_mem_valid && mem_wb_valid && mem_wb_use_rd && (ex_mem_insn[24:20] != 0) && (ex_mem_insn[24:20] == mem_wb_insn[11:7]);
    // RS1 for MEM matches RD for WB.
    wire eq_mem_rs1_wb_rd   = use_rs1_mem && ex_mem_valid && wb_valid     && wb_use_rd     && (ex_mem_insn[19:15] != 0) && (ex_mem_insn[19:15] == wb_insn[11:7]);
    // RS2 for MEM matches RD for WB.
    wire eq_mem_rs2_wb_rd   = use_rs2_mem && ex_mem_valid && wb_valid     && wb_use_rd     && (ex_mem_insn[24:20] != 0) && (ex_mem_insn[24:20] == wb_insn[11:7]);
    
    // Forward RD from EX to RS1 from branch target.
    wire fw_bt_rs1_ex_rd    = eq_bt_rs1_ex_rd   && fw_rd_ex;
    // Forward RD from MEM to RS1 from branch target.
    wire fw_bt_rs1_mem_rd   = eq_bt_rs1_mem_rd;
    
    // Forward RD from EX to RS1 from EX.
    wire fw_ex_rs1_ex_rd    = eq_ex_rs1_ex_rd   && fw_rd_ex;
    // Forward RD from EX to RS2 from EX.
    wire fw_ex_rs2_ex_rd    = eq_ex_rs2_ex_rd   && fw_rd_ex;
    // Forward RD from MEM to RS1 from EX.
    wire fw_ex_rs1_mem_rd   = eq_ex_rs1_mem_rd;
    // Forward RD from MEM to RS2 from EX.
    wire fw_ex_rs2_mem_rd   = eq_ex_rs2_mem_rd;
    
    // Forward RD from MEM to RS1 from MEM.
    wire fw_mem_rs1_mem_rd  = eq_mem_rs1_mem_rd;
    // Forward RD from MEM to RS2 from MEM.
    wire fw_mem_rs2_mem_rd  = eq_mem_rs2_mem_rd;
    // Forward RD from WB to RS1 from MEM.
    wire fw_mem_rs1_wb_rd   = eq_mem_rs1_wb_rd;
    // Forward RD from WB to RS2 from MEM.
    wire fw_mem_rs2_wb_rd   = eq_mem_rs2_wb_rd;
    
    // Hazard avoidance logic.
    boa_stage_ex_fw  st_ex_fw (id_ex_insn,  use_rs1_ex,  use_rs2_ex);
    boa_stage_mem_fw st_mem_fw(ex_mem_insn, use_rs1_mem, use_rs2_mem);
    assign fence_i = is_fencei && !fw_stall_id;
    always @(*) begin
        fw_stall_mem = mem_stall_req;
        fw_stall_ex  = ex_stall_req;
        fw_stall_id  = 0;
        fw_stall_if  = 0;
        
        // Forwarding logic.
        fw_rs1_bt     = fw_bt_rs1_ex_rd || fw_bt_rs1_mem_rd;
        fw_in_bt      = fw_bt_rs1_ex_rd ? fw_out_ex : fw_out_mem;
        fw_rs1_ex     = fw_ex_rs1_ex_rd || fw_ex_rs1_mem_rd;
        fw_in_rs1_ex  = fw_ex_rs1_ex_rd ? fw_out_ex : fw_out_mem;
        fw_rs2_ex     = fw_ex_rs2_ex_rd || fw_ex_rs2_mem_rd;
        fw_in_rs2_ex  = fw_ex_rs2_ex_rd ? fw_out_ex : fw_out_mem;
        fw_rs1_mem    = fw_mem_rs1_mem_rd || fw_mem_rs1_wb_rd;
        fw_in_rs1_mem = fw_mem_rs1_mem_rd ? fw_out_mem : wb_rd_val;
        fw_rs2_mem    = fw_mem_rs2_mem_rd || fw_mem_rs2_wb_rd;
        fw_in_rs2_mem = fw_mem_rs2_mem_rd ? fw_out_mem : wb_rd_val;
        
        // Stalling logic.
        if (is_xret && st_mem.csr_we) begin
            // ID contains an MRET, which has a data dependency on CSRs.
            // Stall ID so that the current CSR write takes effect.
            fw_stall_id = 1;
        end
        if ((eq_ex_rs1_ex_rd && !fw_rd_ex) || (eq_ex_rs2_ex_rd && !fw_rd_ex)) begin
            // EX will next need something that has to be processed by MEM first.
            // Stall ID so that this instruction doesn't enter EX until a result is available.
            fw_stall_id = 1;
        end
        if (eq_bt_rs1_ex_rd && !fw_rd_ex) begin
            // Branch target address needs something that has to be processed by EX or MEM first.
            // Stall ID so that MEM will produce a result that may then be used by the branch target address.
            fw_stall_id = 1;
        end
        if (is_fencei && (ex_mem_valid || mem_wb_valid)) begin
            // A fence.i instruction requires the rest of the pipeline to be emptied.
            // Wait for the instructions in EX and MEM to either trap or finish.
            fw_stall_id = 1;
        end
        if (misa_we && st_mem.csr_we && csr.addr == `RV_CSR_MISA) begin
            // A write to misa is in progress and misa is writeable, so ID cannot validate instructions.
            // Wait for the CSR write to complete so the next instruction is validated correctly.
            fw_stall_id = 1;
        end
        
        fw_stall_ex |= fw_stall_mem;
        fw_stall_id |= fw_stall_ex;
        fw_stall_if |= fw_stall_id;
        
        fw_stall_mem &= !fw_exception;
        fw_stall_ex  &= !fw_exception;
        fw_stall_id  &= !fw_exception;
        fw_stall_if  &= !fw_exception;
    end
    
    
    /* ==== Exception logic ==== */
    assign csr_ex.ex_priv       = 1;
    assign csr_ex.ex_epc[31:1]  = mem_wb_pc[31:1];
    assign csr_ex.ex_vaddr      = mem_vaddr;
    assign csr_ex.ex_inst       = mem_wb_insn;
    assign csr_ex.ret_priv      = 1;
    logic  mtime_irq;
    
    // Interrupt latching logic.
    always @(posedge clk) begin
        csr_ex.irq_ip[31:16] <= irq[31:16];
        csr_ex.irq_ip[15:8]  <= 0;
        csr_ex.irq_ip[7]     <= mtime_irq;
        csr_ex.irq_ip[6:0]   <= 0;
    end
    
    // Interrupt prioritization logic.
    wire [31:0] irq_mask = csr_ex.irq_ip & csr_ex.irq_mie;
    logic[31:0] irq_pri;
    logic[4:0]  irq_cause;
    generate
        assign irq_pri[0] = irq_mask[0];
        for (x = 1; x < 32; x = x + 1) begin
            assign irq_pri[x] = irq_mask[x] && (irq_mask[x-1:0] == 0);
        end
    endgenerate
    always @(*) begin
        integer i;
        irq_cause = 0;
        for (i = 0; i < 32; i = i + 1) begin
            irq_cause |= irq_pri[i] ? i : 0;
        end
    end
    
    // Interrupt enable logic.
    localparam p_mie_depth = 2;
    logic[p_mie_depth-1:0] p_mie;
    wire fw_irq_en = (p_mie == (1 << p_mie_depth) - 1) && csr_status_mie;
    always @(posedge clk) begin
        p_mie <= (p_mie << 1) | csr_status_mie;
    end
    
    // Exception dispatch logic.
    assign fw_exception = csr_ex.ex_irq | csr_ex.ex_trap;
    assign fw_tvec      = csr_ex.ex_tvec;
    always @(*) begin
        if (irq_cause != 0 && fw_irq_en && st_mem.r_valid) begin
            // Interrupt triggered.
            csr_ex.ex_irq       = 1;
            csr_ex.ex_trap      = 0;
            csr_ex.ex_cause     = irq_cause;
            csr_ex.ex_epc[31:2] = mem_wb_pc[31:2];
            if (debug) $display("Interrupt triggered");
            
        end else if (mem_wb_trap) begin
            // Trap raised.
            csr_ex.ex_irq       = 0;
            csr_ex.ex_trap      = 1;
            csr_ex.ex_cause     = mem_wb_cause;
            csr_ex.ex_epc[31:2] = mem_wb_pc[31:2];
            if (debug) $display("Trap raised");
            
        end else begin
            // Nothing is happening.
            csr_ex.ex_irq       = 0;
            csr_ex.ex_trap      = 0;
            csr_ex.ex_cause     = 'bx;
            csr_ex.ex_epc[31:2] = 'bx;
        end
    end
    
    assign clear_if  = fw_exception;
    assign clear_id  = fw_exception | fw_branch_correct;
    assign clear_ex  = fw_exception;
    assign clear_mem = fw_exception;
    
    
    /* ==== CPU memory mapped I/O ==== */
    // Internal memory overlay.
    boa_mem_bus dbus_out[2]();
    boa_mem_bus dbus_in();
    boa_mem_overlay overlay(dbus_in, dbus_out);
    
    // External memory connection.
    assign dbus.re           = dbus_out[0].re;
    assign dbus.we           = dbus_out[0].we;
    assign dbus.addr         = dbus_out[0].addr;
    assign dbus.wdata        = dbus_out[0].wdata;
    assign dbus_out[0].ready = dbus.ready;
    assign dbus_out[0].rdata = dbus.rdata;
    
    // Machine-level timer.
    boa_mtime#(.addr(cpummio)) mtime(clk, rtc_clk, rst, dbus_out[1], mtime_irq);
    
    
    /* ==== Pipeline stages ==== */
    boa_stage_if#(.entrypoint(entrypoint), .if_branch_reg(if_branch_reg)) st_if(
        clk, rst, clear_if, cur_priv,
        // Memory buses.
        pbus, pmpbus[0],
        // Pipeline output.
        if_id_valid, if_id_pc, if_id_insn, if_id_trap, if_id_cause,
        // Instruction fetch fence.
        is_fencei,
        // Control transfer.
        fw_branch_predict, fw_branch_target, if_next_pc, fw_branch_correct, fw_branch_alt, fw_exception, fw_tvec,
        // Data hazard avoicance.
        fw_stall_if, pmp_locking
    );
    boa_stage_id#(.debug(debug), .has_m(has_m), .has_c(has_c)) st_id(
        clk, rst, clear_id, cur_priv,
        // Pipeline input.
        if_id_valid && !fw_stall_if, if_id_pc, if_id_insn, if_id_trap && !fw_stall_if, if_id_cause,
        // Pipeline output.
        id_ex_valid, id_ex_pc, id_ex_insn, id_ex_ilen, id_ex_use_rd, id_ex_rs1_val, id_ex_rs2_val, id_ex_branch, id_ex_branch_predict, id_ex_trap, id_ex_cause,
        // Miscellaneous.
        is_fencei, csr_misa,
        // Control transfer.
        is_xret, is_sret, is_jump, is_branch, branch_predict, branch_target,
        // Write-back.
        mem_wb_valid && mem_wb_use_rd && !fw_stall_mem, mem_wb_insn[11:7], mem_wb_rd_val,
        // Data hazard avoidance.
        fw_stall_id, use_rs1_bt, fw_rs1_bt, fw_in_bt
    );
    boa_stage_ex#(.div_latency(div_latency), .div_distr(div_distr), .mul_latency(mul_latency), .has_m(has_m)) st_ex (
        clk, rst, clear_ex, cur_priv,
        // Pipeline input.
        id_ex_valid && !fw_stall_id, id_ex_pc, id_ex_insn, id_ex_ilen, id_ex_use_rd, fw_rs1_ex ? fw_in_rs1_ex : id_ex_rs1_val, fw_rs2_ex ? fw_in_rs2_ex : id_ex_rs2_val, id_ex_branch, id_ex_branch_predict, id_ex_trap && !fw_stall_id, id_ex_cause,
        // Pipeline output.
        ex_mem_valid, ex_mem_pc, ex_mem_insn, ex_mem_use_rd, ex_mem_rs1_val, ex_mem_rs2_val, ex_mem_trap, ex_mem_cause,
        // Data hazard avoidance.
        fw_branch_correct, fw_stall_ex, fw_rd_ex, ex_stall_req
    );
    boa_stage_mem#(.has_a(has_a), .rmw_amo_reg(rmw_amo_reg)) st_mem(
        clk, rst, clear_mem, cur_priv, csr_status_mprv ? csr_status_mpp : cur_priv,
        // Memory buses.
        dbus_in, pmpbus[1], csr, amo_en, resv_bus,
        // Data fence.
        fence_rl, fence_aq,
        // Pipeline input.
        ex_mem_valid && !fw_stall_ex, ex_mem_pc, ex_mem_insn, ex_mem_use_rd, fw_rs1_mem ? fw_in_rs1_mem : ex_mem_rs1_val, fw_rs2_mem ? fw_in_rs2_mem : ex_mem_rs2_val, ex_mem_trap && !fw_stall_ex, ex_mem_cause,
        // Pipeline output.
        mem_wb_valid, mem_wb_pc, mem_wb_insn, mem_wb_use_rd, mem_wb_rd_val, mem_wb_trap, mem_wb_cause,
        // Data hazard avoidance.
        fw_stall_mem, mem_stall_req,
        // Trap virtual address.
        mem_vaddr
    );
    always @(posedge clk) begin
        if (!fw_stall_mem) begin
            wb_valid  <= mem_wb_valid;
            wb_use_rd <= mem_wb_use_rd;
            wb_rd_val <= mem_wb_rd_val;
            wb_insn   <= mem_wb_insn;
        end
    end
endmodule



// Boa³² CSR register file.
module boa32_csrs#(
    // CSR mhartid value.
    parameter hartid        = 32'h0000_0000,
    // Support configurability through misa.
    parameter misa_we       = 1,
    // Support user mode.
    parameter has_u_mode    = 0,
    // Support M (multiply/divide) instructions.
    parameter has_m         = 1,
    // Support A (atomic memory operation) instructions.
    parameter has_a         = 1,
    // Support C (compressed) instructions.
    parameter has_c         = 1
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    // CSR bus.
    boa_csr_bus.CSR     csr,
    // CSR exception bus.
    boa_csr_ex_bus.CSR  ex,
    
    // CSR misa: M-mode ISA description.
    output logic[31:0]  csr_misa,
    // CSR status.MIE: M-mode interrupt enable.
    output logic        csr_status_mie,
    // CSR status.SIE: S-mode interrupt enable.
    output logic        csr_status_sie,
    // CSR status.MPRV: Modify M-mode memory access privilege.
    output logic        csr_status_mprv,
    // CSR status.MPP: M-mode previous privilege.
    output logic[1:0]   csr_status_mpp
);
    /* ==== CSR STORAGE ==== */
    // CSR misa: Enable A instructions.
    logic       csr_misa_a;
    // CSR misa: Enable C instructions.
    logic       csr_misa_c;
    // CSR misa: Enable M instructions.
    logic       csr_misa_m;
    
    // CSR status: S-mode previous privilege.
    logic       csr_status_spp;
    // CSR status: M-mode previous interrupt enable.
    logic       csr_status_mpie;
    // CSR status: S-mode previous interrupt enable.
    logic       csr_status_spie;
    
    // CSR mcause: Interrupt number / trap number.
    logic[4:0]  csr_mcause_no;
    // CSR mcause: Is an interrupt.
    logic       csr_mcause_int;
    
    
    // CSR mstatus: M-mode status.
    logic[31:0] csr_mstatus;
    // CSR medeleg: M-mode trap delegation.
    wire [31:0] csr_medeleg     = 0;
    // CSR medeleg: M-mode interrupt delegation.
    wire [31:0] csr_mideleg     = 0;
    // CSR mie: M-mode per-interrupt enable.
    logic[31:0] csr_mie;
    // CSR mtvec: M-mode trap and interrupt vector.
    logic[31:2] csr_mtvec;
    // CSR mstatush: M-mode status.
    wire [31:0] csr_mstatush    = 0;
    // CSR mip: M-mode interrupts pending.
    wire [31:0] csr_mip         = ex.irq_ip & csr_mie;
    // CSR mscratch: M-mode scratch pad register.
    logic[31:0] csr_mscratch;
    // CSR mepc: M-mode exception program counter.
    logic[31:1] csr_mepc;
    // CSR mcause: M-mode interrupt / trap cause.
    wire [31:0] csr_mcause      = (csr_mcause_int << 31) | csr_mcause_no;
    // CSR mtval: M-mode trap value.
    logic[31:0] csr_mtval;
    // CSR mvendorid: M-mode vendor ID.
    wire [31:0] csr_mvendorid   = 0;
    // CSR marchid: M-mode architecture ID.
    // This CSR serves as attribution for tapeouts and FPGAs.
    // It must not be modified and must be readable to any M-mode software.
    wire [31:0] csr_marchid     = 37;
    // CSR mimpid: M-mode implementation ID.
    logic[31:0] csr_mimpid;
    // CSR mhartid: M-mode HART ID.
    wire [31:0] csr_mhartid     = hartid;
    // CSR mconfigptr: M-mode configuration pointer.
    wire [31:0] csr_mconfigptr  = 0;
    
    
    /* ==== CSR misa value ==== */
    // Instruction set extensions.
    assign csr_misa[0]     = csr_misa_a;
    assign csr_misa[1]     = 0;
    assign csr_misa[2]     = csr_misa_c;
    assign csr_misa[7:3]   = 0;
    assign csr_misa[8]     = 1; // I
    assign csr_misa[11:9]  = 0;
    assign csr_misa[12]    = csr_misa_m;
    assign csr_misa[25:13] = 0;
    // Reserved.
    assign csr_misa[29:26] = 0;
    // MXLEN (32).
    assign csr_misa[31:30] = 2'b01;
    
    // CSR misa storage.
    generate
        if (misa_we) begin: misa_rw
            // Configurable MISA.
            initial begin
                // Start with all supported extensions enabled.
                csr_misa_a = has_a;
                csr_misa_c = has_c;
                csr_misa_m = has_m;
            end
            always @(posedge clk) begin
                if (csr.we && csr.addr == `RV_CSR_MISA) begin
                    // Update enabled extensions.
                    csr_misa_a <= has_a && csr.wdata[0];
                    csr_misa_c <= has_c && csr.wdata[2];
                    csr_misa_m <= has_m && csr.wdata[12];
                end
            end
        end else begin: misa_ro
            // Static MISA: present supported extensions.
            assign csr_misa_a = has_a;
            assign csr_misa_c = has_c;
            assign csr_misa_m = has_m;
        end
    endgenerate
    
    
    /* ==== CSR status value ==== */
    // CSR mstatus value.
    assign csr_mstatus[0]       = 0;
    assign csr_mstatus[1]       = csr_status_sie;
    assign csr_mstatus[2]       = 0;
    assign csr_mstatus[3]       = csr_status_mie;
    assign csr_mstatus[4]       = 0;
    assign csr_mstatus[5]       = csr_status_spie;
    assign csr_mstatus[6]       = 0;
    assign csr_mstatus[7]       = csr_status_mpie;
    assign csr_mstatus[8]       = csr_status_spp;
    assign csr_mstatus[10:9]    = 0;
    assign csr_mstatus[12:11]   = csr_status_mpp;
    assign csr_mstatus[16:13]   = 0;
    assign csr_mstatus[17]      = csr_status_mprv;
    assign csr_mstatus[31:18]   = 0;
    
    assign csr_status_sie  = 0;
    assign csr_status_spie = 0;
    assign csr_status_spp  = 0;
    
    // CSR status storage.
    generate
        if (has_u_mode) begin: status_with_u
            always @(posedge clk) begin
                if (rst) begin
                    // Reset.
                    csr_status_mpp    <= 3;
                    csr_status_mprv   <= 0;
                    
                end else if (ex.ex_trap || ex.ex_irq) begin
                    // CSR changes on trap or interrupt.
                    csr_status_mpp    <= ex.ex_pp;
                    
                end else if (ex.ret) begin
                    // CSR changes on xret instruction.
                    csr_status_mprv <= csr_status_mprv && csr_status_mpp == 3;
                    
                end else if (csr.we) begin
                    // CSR write logic.
                    case (csr.addr)
                        default:            /* No action required. */;
                        `RV_CSR_MSTATUS:    begin csr_status_mprv <= csr.wdata[17]; csr_status_mpp <= (csr.wdata[12:11] != 0) ? 3 : 0; end
                    endcase
                end
            end
        end else begin: status_without_u
            assign csr_status_mpp    = 3;
            assign csr_status_mprv   = 0;
        end
    endgenerate
    
    /* ==== CSR mimpid value ==== */
    // Semantic versioning PATCH.
    assign csr_mimpid[3:0]   = 0;
    // Semantic versioning MINOR.
    assign csr_mimpid[7:4]   = 1;
    // Semantic versioning MAJOR.
    assign csr_mimpid[15:8]  = 2;
    // Reserved.
    assign csr_mimpid[30:16] = 0;
    // Is a fork of Boa-RISC-V.
    assign csr_mimpid[31]    = 0;
    
    
    /* ==== CSR ACCESS LOGIC ==== */
    assign csr.priv         = 'bx;
    assign ex.ret_epc       = csr_mepc;
    assign ex.ret_pp        = csr_status_mpp;
    assign ex.ex_tvec       = csr_mtvec;
    assign ex.irq_mie       = csr_mie;
    assign ex.irq_medeleg   = 'bx;
    assign ex.irq_mideleg   = 'bx;
    assign ex.irq_sie       = 'bx;
    always @(*) begin
        // CSR read and permission logic.
        case(csr.addr)
            `RV_CSR_MSTATUS:    begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_mstatus; end
            `RV_CSR_MISA:       begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_misa; end
            `RV_CSR_MEDELEG:    begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_medeleg; end
            `RV_CSR_MIDELEG:    begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_mideleg; end
            `RV_CSR_MIE:        begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_mie; end
            `RV_CSR_MTVEC:      begin csr.exists = 1; csr.rdonly = 0; csr.rdata[31:2] = csr_mtvec[31:2]; csr.rdata[1:0] = 0; end
            `RV_CSR_MSTATUSH:   begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_mstatush; end
            `RV_CSR_MIP:        begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_mip; end
            `RV_CSR_MSCRATCH:   begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_mscratch; end
            `RV_CSR_MEPC:       begin csr.exists = 1; csr.rdonly = 0; csr.rdata[31:1] = csr_mepc[31:1]; csr.rdata[0] = 0; end
            `RV_CSR_MCAUSE:     begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_mcause; end
            `RV_CSR_MTVAL:      begin csr.exists = 1; csr.rdonly = 0; csr.rdata = csr_mtval; end
            `RV_CSR_MVENDORID:  begin csr.exists = 1; csr.rdonly = 1; csr.rdata = csr_mvendorid; end
            `RV_CSR_MARCHID:    begin csr.exists = 1; csr.rdonly = 1; csr.rdata = csr_marchid; end
            `RV_CSR_MIMPID:     begin csr.exists = 1; csr.rdonly = 1; csr.rdata = csr_mimpid; end
            `RV_CSR_MHARTID:    begin csr.exists = 1; csr.rdonly = 1; csr.rdata = csr_mhartid; end
            `RV_CSR_MCONFIGPTR: begin csr.exists = 1; csr.rdonly = 1; csr.rdata = csr_mconfigptr; end
            default:            begin csr.exists = 0; csr.rdonly = 'bx; csr.rdata = 'bx; end
        endcase
    end
    
    always @(posedge clk) begin
        if (rst) begin
            // Rset CSRs to default values.
            csr_status_mpie <= 0;
            csr_status_mie  <= 0;
            csr_mcause_int  <= 0;
            csr_mcause_no   <= 0;
            csr_mtval       <= 0;
            csr_mie         <= 0;
            csr_mtvec       <= 0;
            csr_mscratch    <= 0;
            csr_mepc        <= 0;
            
        end else if (ex.ex_trap || ex.ex_irq) begin
            // CSR changes on trap or interrupt.
            csr_status_mpie <= csr_status_mie;
            csr_status_mie  <= 0;
            csr_mcause_int  <= ex.ex_irq;
            csr_mcause_no   <= ex.ex_cause;
            csr_mepc        <= ex.ex_epc;
            
            case (ex.ex_cause)
                default:                csr_mtval <= 0;
                `RV_ECAUSE_IALIGN:      csr_mtval <= ex.ex_epc;
                `RV_ECAUSE_IACCESS:     csr_mtval <= ex.ex_epc;
                `RV_ECAUSE_IILLEGAL:    csr_mtval <= ex.ex_inst;
                `RV_ECAUSE_EBREAK:      csr_mtval <= 0;
                `RV_ECAUSE_LALIGN:      csr_mtval <= ex.ex_vaddr;
                `RV_ECAUSE_LACCESS:     csr_mtval <= ex.ex_vaddr;
                `RV_ECAUSE_SALIGN:      csr_mtval <= ex.ex_vaddr;
                `RV_ECAUSE_SACCESS:     csr_mtval <= ex.ex_vaddr;
                `RV_ECAUSE_U_ECALL:     csr_mtval <= 0;
                `RV_ECAUSE_S_ECALL:     csr_mtval <= 0;
                `RV_ECAUSE_M_ECALL:     csr_mtval <= 0;
                `RV_ECAUSE_IPAGE:       csr_mtval <= ex.ex_epc;
                `RV_ECAUSE_LPAGE:       csr_mtval <= ex.ex_vaddr;
                `RV_ECAUSE_SPAGE:       csr_mtval <= ex.ex_vaddr;
            endcase
            
        end else if (ex.ret) begin
            // CSR changes on xret instruction.
            csr_status_mie     <= csr_status_mpie;
            
        end else if (csr.we) begin
            // CSR write logic.
            case (csr.addr)
                default:            /* No action required. */;
                `RV_CSR_MSTATUS:    begin csr_status_mpie <= csr.wdata[7]; csr_status_mie <= csr.wdata[3]; end
                `RV_CSR_MIE:        begin csr_mie <= csr.wdata; end
                `RV_CSR_MTVEC:      begin csr_mtvec[31:2] <= csr.wdata[31:2]; end
                `RV_CSR_MSCRATCH:   begin csr_mscratch <= csr.wdata; end
                `RV_CSR_MEPC:       begin csr_mepc[31:1] <= csr.wdata[31:1]; end
                `RV_CSR_MCAUSE:     begin csr_mcause_int <= csr.wdata[31]; csr_mcause_no <= csr.wdata[4:0]; end
                `RV_CSR_MTVAL:      begin csr_mtval <= csr.wdata; end
            endcase
        end
    end
endmodule
