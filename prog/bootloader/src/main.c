
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#include "gpio.h"
#include "is_simulator.h"
#include "mtime.h"
#include "pmp.h"
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

// Entrypoint function.
extern void _start() __attribute__((noreturn));
// ISR handler.
extern void __isr_handler();
// Stop el CPU and power off.
extern void halt();

// P_WHO response value.
char const ident[] = "cpus=1,cpu='Boa32',isa='RV32I"
#ifdef __riscv_m
                     "M"
#endif
#ifdef __riscv_a
                     "A"
#endif
#ifdef __riscv_f
                     "F"
#endif
#ifdef __riscv_d
                     "D"
#endif
#ifdef __riscv_q
                     "Q"
#endif
#ifdef __riscv_c
                     "C"
#endif
                     "_Zicsr_Zifencei',maxdata=4096";



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

// Write address.
void  *waddr;
// Write length.
size_t wlen;



// Send a packet.
void send_packet(phdr_t const *header, void const *data) {
    UART0.fifo   = 2;
    uint8_t xsum = 2;

    uint8_t const *tx_ptr = (uint8_t const *)header;
    for (size_t i = 0; i < sizeof(phdr_t); i++) {
        xsum       += tx_ptr[i];
        UART0.fifo  = tx_ptr[i];
    }

    tx_ptr = (uint8_t const *)data;
    for (size_t i = 0; i < header->length; i++) {
        xsum       += tx_ptr[i];
        UART0.fifo  = tx_ptr[i];
    }

    UART0.fifo = xsum;
}

// Send an ACK packet with a cause.
void send_ack1(uint8_t ack_type, uint32_t cause) {
    phdr_t header = {
        .type   = P_ACK,
        .length = sizeof(p_ack_t),
    };
    p_ack_t ack = {
        .ack_type = ack_type,
        .cause    = cause,
    };
    send_packet(&header, &ack);
}

// Send an ACK packet.
void send_ack(uint8_t ack_type) {
    send_ack1(ack_type, 0);
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

// Handle a P_SPEED packet.
void p_speed() {
    if (header.length != sizeof(p_speed_t)) {
        send_ack(A_NCAP);
        return;
    }

    // Determine appropriate divider.
    uint32_t divider = UART_BASE_FREQ / data.p_speed.speed;
    if (divider < 4 || divider > 65535) {
        send_ack(A_NSPEED);
        return;
    } else {
        send_ack(A_ACK);
    }

    // Wait for UART to finish sending.
    while (UART0.status.tx_busy || UART0.status.rx_hasdat)
        ;
    // Configure new frequency.
    UART0.clk_div = divider;
}

// Handle a P_WRITE packet.
void p_write() {
    if (header.length != sizeof(data.p_write)) {
        send_ack(A_NCAP);
        return;
    }
    waddr = (void *)data.p_write.addr;
    wlen  = data.p_write.length;
    send_ack(A_ACK);
}

// Handle a P_READ packet.
void p_read() {
    if (header.length != sizeof(data.p_read)) {
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
    send_ack(A_ACK);
}

// Handle a P_JUMP packet.
void p_jump() {
    if (header.length != sizeof(data.p_jump)) {
        send_ack(A_NCAP);
        return;
    }
    send_ack(A_ACK);
    asm("csrci mstatus, 8");
    asm("csrc mie, %0" ::"r"(0xffffffff));
    asm("fence");
    asm("fence.i");
    ((void (*)())data.p_jump.addr)();
    asm("csrci mstatus, 8");
    asm("csrc mie, %0" ::"r"(0xffffffff));
    _start();
}

// Handle a P_CALL packet.
void p_call() {
    if (header.length != sizeof(data.p_call)) {
        send_ack(A_NCAP);
        return;
    }
    send_ack(A_ACK);
    asm("fence");
    asm("fence.i");
    ((void (*)())data.p_call.addr)();
}



// Handle a received byte.
void handle_rx(uint8_t rxd) {
    if (rx_type == RX_NONE) {
        xsum = rxd;
        if (rxd == 2) {
            rx_len  = 0;
            rx_type = RX_PHDR;
            rx_ptr  = (uint8_t *)&header;
        }
    } else if (rx_type == RX_PHDR) {
        rx_ptr[rx_len++] = rxd;
        if (rx_len == sizeof(phdr_t)) {
            rx_len = 0;
            if (header.length == 0) {
                rx_type = RX_XSUM;
            } else if (header.type == P_WDATA) {
                rx_type = RX_DATA;
                rx_ptr  = (uint8_t *)waddr;
            } else if (header.length > sizeof(data)) {
                rx_type = RX_NCAP;
            } else {
                rx_type = RX_DATA;
                rx_ptr  = (uint8_t *)&data;
            }
        }
        xsum += rxd;
    } else if (rx_type == RX_NCAP) {
        xsum += rxd;
        rx_len++;
        if (rx_len == header.length) {
            rx_type = RX_XSUM;
        }
    } else if (rx_type == RX_DATA) {
        rx_ptr[rx_len++]  = rxd;
        xsum             += rxd;
        if (rx_len == header.length) {
            rx_type = RX_XSUM;
        }
    } else if (rx_type == RX_XSUM) {
        if (xsum != rxd) {
            send_ack1(A_XSUM, (rxd << 8) | xsum);
        } else if (header.type != P_WDATA && header.length > sizeof(data)) {
            send_ack(A_NCAP);
        } else {
            switch (header.type) {
                case P_PING: p_ping(); break;
                case P_WHO: p_who(); break;
                case P_SPEED: p_speed(); break;
                case P_WRITE: p_write(); break;
                case P_READ: p_read(); break;
                case P_WDATA: p_wdata(); break;
                case P_JUMP: p_jump(); break;
                case P_CALL: p_call(); break;
                default: send_ack(A_NCAP); break;
            }
        }
        rx_type = RX_NONE;
    }
}



// The trapper.
void isr() {
    long mcause;
    asm("csrr %0, mcause" : "=r"(mcause));
    if (mcause < 0) {
        print("Interrupt ");
        putd(mcause & 31, 2);
        print("\n");
    } else {
        print("Trap ");
        putd(mcause, 2);
        print("\n");
    }
    halt();
}

// Does stuff?
void main() {
    // Blink the LED red at startup.
    if (!IS_SIMULATOR) {
        mtime     = 0;
        GPIO.oe   = 1 << 8;
        GPIO.port = 1 << 8;
        while (mtime < 100000) continue;
        GPIO.oe   = 0;
        GPIO.port = 0;
    }

    while (1) {
        if (UART0.status.rx_hasdat) {
            handle_rx(UART0.fifo);
        }
    }
}
