
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Unbuffered supersampling UART transmitter.
// Divides the clock by clk_div for transmitting.
module unbuffered_uart_tx#(
    // Number of bits for the clock divider input.
    parameter dlen = 8
)(
    // Undivided clock.
    input  logic            clk,
    // Synchronous reset.
    input  logic            rst,
    // Clock divider setting.
    input  logic[dlen-1:0]  clk_div,
    
    // Byte to transmit.
    input  logic[7:0]       tx_byte,
    // Send trigger.
    input  logic            tx_trig,
    // Send acknowledgement.
    output logic            tx_ack,
    // UART transmit wire.
    output logic            txd,
    // UART is currently transmitting.
    output logic            tx_busy
);
    // Clock division counter.
    logic[dlen-1:0] timer   = 1;
    // Counts number of sent bits.
    logic[3:0]      state;
    // Buffer for sending data.
    logic[8:0]      tx_buf  = 9'h1ff;
    // TX data is LSB of TX buffer.
    assign          txd     = tx_buf[0];
    // Transmitter is busy if state is nonzero.
    assign          tx_busy = state != 0;
    
    always @(posedge clk) begin
        if (rst) begin
            // Reset.
            timer   <= 1;
            state   <= 0;
            tx_buf  <= 9'h1ff;
            tx_ack  <= 0;
        end else if (timer == 1) begin
            timer <= clk_div ? clk_div : 1;
            if (state == 0 && tx_trig) begin
                // Initialise transmitter state.
                tx_buf[0]   <= 0;
                tx_buf[8:1] <= tx_byte;
                state       <= 1;
                tx_ack      <= 1;
            end else if (state == 9) begin
                // Finalise transmitter state.
                state       <= 0;
                tx_buf      <= (tx_buf >> 1) | 9'h100;
                tx_ack      <= tx_ack && tx_trig;
            end else if (state != 0) begin
                // Shift send buffer.
                state       <= state + 1;
                tx_buf      <= (tx_buf >> 1) | 9'h100;
                tx_ack      <= tx_ack && tx_trig;
            end
        end else begin
            timer   <= timer - 1;
            tx_ack  <= tx_ack && tx_trig;
        end
    end
endmodule

// Unbuffered supersampling UART receiver.
// Divides the clock by clk_div for receiving.
module unbuffered_uart_rx#(
    // Number of bits for the clock divider input.
    parameter dlen = 8
)(
    // Undivided clock.
    input  logic            clk,
    // Synchronous reset.
    input  logic            rst,
    // Clock divider setting.
    input  logic[dlen-1:0]  clk_div,
    
    // Byte just received.
    output logic[7:0]       rx_byte,
    // A byte has been fully received.
    output logic            rx_trig,
    // Acknowledge and clear rx_trig.
    input  logic            rx_ack,
    // UART receive wire.
    input  logic            rxd,
    // UART is currently receiving.
    output logic            rx_busy
);
    // Clock division counter.
    logic[dlen-1:0] timer   = 1;
    // Counts number of received bits.
    logic[3:0]      state;
    // Buffer for receiving data.
    logic[7:0]      rx_buf;
    // RX is busy if state is nonzero.
    assign          rx_busy = state != 0;
    
    always @(posedge clk) begin
        if (rst) begin
            // Reset.
            timer   <= 1;
            state   <= 0;
            rx_buf  <= 0;
            rx_trig <= 0;
        end else if (state == 0 && !rxd) begin
            // UART start bit.
            state   <= 1;
            timer   <= (clk_div >> 1) ? (clk_div >> 1) : 1;
            rx_trig <= rx_trig && !rx_ack;
        end else if (state != 0 && timer == 1) begin
            timer <= clk_div ? clk_div : 1;
            if (state == 10) begin
                // UART stop bit.
                if (rxd) begin
                    rx_trig <= rxd;
                    rx_byte <= rx_buf;
                end else begin
                    rx_trig <= rx_trig && !rx_ack;
                end
                state   <= 0;
            end else begin
                // Shift receive buffer.
                rx_buf  <= {rxd, rx_buf[7:1]};
                state   <= state + 1;
                rx_trig <= rx_trig && !rx_ack;
            end
        end else if (state != 0) begin
            timer <= timer - 1;
            rx_trig <= rx_trig && !rx_ack;
        end else begin
            rx_trig <= rx_trig && !rx_ack;
        end
    end
endmodule

// Basic UART with FIFO peripheral.
// Configurable clock divider.
module boa_peri_uart#(
    // Base address to respond to.
    parameter addr          = 32'h8000_0000,
    // TX buffer depth, must be a power of 2 >= 4.
    parameter tx_depth      = 4,
    // RX buffer depth, must be a power of 2 >= 4.
    parameter rx_depth      = 4,
    // Stall writes on TX buffer full.
    parameter tx_full_stall = 1,
    // Number of bits for the clock divider input.
    parameter dlen          = 16,
    // Default clock divider value.
    parameter init_div      = 1250
)(
    // Peripheral bus clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    // Peripheral bus interface.
    boa_mem_bus.MEM     bus,
    
    // Transmitted data pin.
    output logic        txd,
    // Received data pin.
    input  logic        rxd,
    
    // UART transmit buffer has emptied.
    output logic        tx_empty,
    // UART receive buffer is no longer empty.
    output logic        rx_full
);
    genvar x;
    localparam tx_exp = $clog2(tx_depth) - 1;
    localparam rx_exp = $clog2(rx_depth) - 1;
    
    // Clock divider logic.
    logic[dlen-1:0] clk_div = init_div;
    always @(posedge clk) begin
        if (rst) begin
            clk_div <= init_div;
        end else if (bus.addr == addr[bus.dlen-1:2]+2 && bus.we == 4'b1111) begin
            clk_div <= bus.wdata;
        end
    end
    
    // Transmitter logic.
    logic tx_trig, tx_fifo_we;
    logic tx_ack, tx_fifo_has_dat, tx_fifo_full, tx_busy;
    logic[7:0] tx_byte;
    // TX FIFO.
    param_fifo#(tx_depth, 8, 0) tx_fifo(clk, rst, tx_fifo_we, bus.wdata[7:0], tx_ack, tx_byte, tx_fifo_has_dat, tx_fifo_full);
    // Transmitter.
    unbuffered_uart_tx#(dlen) tx_phy(clk, rst, clk_div, tx_byte, tx_trig, tx_ack, txd, tx_busy);
    assign tx_trig      = tx_fifo_has_dat && !tx_ack;
    assign tx_fifo_we   = bus.addr == addr[bus.dlen-1:2] && bus.we[0];
    
    // Receiver logic.
    logic rx_fifo_re;
    logic rx_trig, rx_fifo_has_dat, rx_fifo_full, rx_busy;
    logic[7:0] rx_byte;
    logic[7:0] rx_fifo_rdata;
    // RX FIFO.
    param_fifo#(rx_depth, 8, 1) rx_fifo(clk, rst, rx_trig, rx_byte, rx_fifo_re, rx_fifo_rdata, rx_fifo_has_dat, rx_fifo_full);
    // Receiver.
    unbuffered_uart_rx#(dlen) rx_phy(clk, rst, clk_div, rx_byte, rx_trig, rx_trig, rxd, rx_busy);
    assign rx_fifo_re   = bus.addr == addr[bus.dlen-1:2] && bus.re;
    
    // IRQ logic.
    assign tx_empty = !tx_fifo_has_dat;
    assign rx_full  = rx_fifo_has_dat;
    
    // Response logic.
    logic[31:0] status;
    assign status[0]        = tx_busy;
    assign status[1]        = tx_fifo_has_dat;
    assign status[2]        = !tx_fifo_full;
    assign status[15:3]     = 0;
    assign status[16]       = rx_busy;
    assign status[17]       = rx_fifo_has_dat;
    assign status[18]       = !rx_fifo_full;
    assign status[31:19]    = 0;
    always @(posedge clk) begin
        if (bus.addr == addr[bus.dlen-1:2] && tx_fifo_full && bus.we[0]) begin
            // UART write stall.
            bus.ready <= !tx_full_stall;
            bus.rdata <= rx_fifo_rdata;
            
        end else if (bus.addr == addr[bus.dlen-1:2] && bus.re) begin
            // UART read.
            bus.ready <= 1;
            bus.rdata <= rx_fifo_rdata;
            
        end else if (bus.addr == addr[bus.dlen-1:2]+1) begin
            // UART status.
            bus.ready <= 1;
            bus.rdata <= status;
            
        end else if (bus.addr == addr[bus.dlen-1:2]+2) begin
            // UART clock divider.
            bus.ready <= 1;
            bus.rdata <= clk_div;
            
        end else begin
            // Nothing to wait for.
            bus.ready <= 1;
            bus.rdata <= 0;
        end
    end 
endmodule
