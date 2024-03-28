
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



module top(
    input  wire  clk
);
    `include "insn_rvc.svh"
    `include "insn.svh"
    integer decompfd, validfd;
    
    logic[15:0] comp;
    logic[31:0] decomp;
    logic       valid;
    boa_insn_decomp insn_decomp(
        0, 32'hffff_ffff,
        comp,
        decomp, valid
    );
    
    reg[31:0] div = 0;
    assign comp = insn_rvc[div][15:0];
    
    initial begin
        decompfd = $fopen("obj_dir/decomp.bin", "wb");
        validfd = $fopen("obj_dir/valid.txt", "w");
    end
    always @(posedge clk) begin
        $fwrite(decompfd, "%c", decomp[7:0]);
        $fwrite(decompfd, "%c", decomp[15:8]);
        $fwrite(decompfd, "%c", decomp[23:16]);
        $fwrite(decompfd, "%c", decomp[31:24]);
        $fwrite(validfd, "%d", valid);
        
        div <= div + 1;
        if (div == insn_rvc_len) begin
            $fclose(decompfd);
            $fclose(validfd);
            $finish;
        end
    end
endmodule
