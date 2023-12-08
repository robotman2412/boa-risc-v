/*
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
*/

#include "print.h"
#include "protocol.h"
#include "uart.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// First unused SRAM address.
extern char const __start_free_sram[];
// Last unused SRAM address.
extern char const __stop_free_sram[];
// First SRAM address.
extern char const __start_sram[];
// Last SRAM address.
extern char const __stop_sram[];

// Currently receiving nothing.
#define RX_NONE 0
// Currently receiving header.
#define RX_PHDR 1
// Currently receiving data.
#define RX_DATA 2
// Currently receiving checksum.
#define RX_XSUM 3
// Currently waiting; too much data.
#define RX_NCAP 5

// Stop el CPU and power off.
extern void halt();

// P_WHO response value.
char const ident[] = "cpus=1,cpu0='Boa32',isa0='RV32IM_Zicsr',maxdata=4096";



// Currently receiving.
int      rx_type;
// Receive count.
size_t   rx_len;
// Packet data pointer.
uint8_t *rx_ptr;
// Packet header buffer.
phdr_t   header;
// Packet data buffer.
p_data_t data;
// Current checksum.
uint8_t  xsum;



// Send a packet.
void send_packet(phdr_t const *header, void const *data) {
    UART0.fifo   = 2;
    uint8_t xsum = 2;

    uint8_t const *tx_ptr = (uint8_t const *)header;
    for (size_t i = 0; i < sizeof(phdr_t); i++) {
        xsum       ^= tx_ptr[i];
        UART0.fifo  = tx_ptr[i];
    }

    tx_ptr = (uint8_t const *)data;
    for (size_t i = 0; i < header->length; i++) {
        xsum       ^= tx_ptr[i];
        UART0.fifo  = tx_ptr[i];
    }

    UART0.fifo = xsum;
}

// Send an ACK packet.
void send_ack(uint8_t ack_type) {
    phdr_t header = {
        .type   = P_ACK,
        .length = sizeof(p_ack_t),
    };
    p_ack_t ack = {.ack_type = ack_type};
    send_packet(&header, &ack);
}



// Handle a P_PING packet.
void p_ping() {
    if (header.length != sizeof(data.p_ping)) {
        send_ack(A_NCAP);
        return;
    }
    phdr_t header = {
        .type   = P_PONG,
        .length = sizeof(p_ping_t),
    };
    p_ping_t ping = data.p_ping;
    send_packet(&header, &ping);
}

// Handle a P_WHO packet.
void p_who() {
    if (header.length != 0) {
        send_ack(A_NCAP);
        return;
    }
    phdr_t header = {
        .type   = P_IDENT,
        .length = sizeof(ident) - 1,
    };
    send_packet(&header, ident);
}

// Handle a P_WRITE packet.
void p_write() {
    if (header.length != sizeof(data.p_write)) {
        send_ack(A_NCAP);
        return;
    }
    if (data.p_write.addr < (size_t)__start_sram || data.p_write.addr + data.p_write.length > __stop_sram) {
        send_ack(A_NCAP);
        return;
    }
}

// Handle a P_READ packet.
void p_read() {
    if (header.length != sizeof(data.p_read)) {
        send_ack(A_NCAP);
        return;
    }
    if (data.p_read.addr < (size_t)__start_free_sram || data.p_read.addr + data.p_read.length > __stop_free_sram) {
        send_ack(A_NCAP);
        return;
    }
    phdr_t header = {
        .type   = P_RDATA,
        .length = data.p_read.length,
    };
    send_packet(&header, (void const *)data.p_read.addr);
}

// Handle a P_WDATA packet.
void p_wdata() {
}

// Handle a P_JUMP packet.
void p_jump() {
    if (header.length != sizeof(data.p_jump)) {
        send_ack(A_NCAP);
        return;
    }
}

// Handle a P_CALL packet.
void p_call() {
    if (header.length != sizeof(data.p_call)) {
        send_ack(A_NCAP);
        return;
    }
}



// Handle a received byte.
void handle_rx(uint8_t data) {
    if (rx_type == RX_NONE) {
        xsum = data;
        if (data == 2) {
            rx_type = RX_PHDR;
            rx_ptr  = (uint8_t *)&header;
        }
    } else if (rx_type == RX_PHDR) {
        rx_ptr[rx_len++] = data;
        if (rx_len == sizeof(phdr_t)) {
            rx_len = 0;
            if (rx_len == 0) {
                rx_type = RX_XSUM;
            } else if (header.length > sizeof(data)) {
                rx_type = RX_NCAP;
            } else {
                rx_type = RX_DATA;
                rx_ptr  = (uint8_t *)&data;
            }
        }
        xsum += data;
    } else if (rx_type == RX_NCAP) {
        rx_len++;
        if (rx_len == header.length)
            rx_type = RX_XSUM;
    } else if (rx_type == RX_DATA) {
        rx_ptr[rx_len++]  = data;
        xsum             += data;
        if (rx_len == header.length)
            rx_type = RX_XSUM;
    } else if (rx_type == RX_XSUM) {
        if (xsum != data) {
            send_ack(A_XSUM);
        } else if (header.length > sizeof(data)) {
            send_ack(A_NCAP);
        } else {
            switch (header.type) {
                case P_PING: p_ping(); break;
                case P_WHO: p_who(); break;
                case P_WRITE: p_write(); break;
                case P_READ: p_read(); break;
                case P_WDATA: p_wdata(); break;
                case P_JUMP: p_jump(); break;
                case P_CALL: p_call(); break;
            }
        }
    }
}



// The trapper.
void isr() {
    long mcause;
    asm("csrr %0, mcause" : "=r"(mcause));
    print("Trap ");
    putd(mcause, 2);
    print("\n");
    halt();
}

// Does stuff?
void main() {
}
