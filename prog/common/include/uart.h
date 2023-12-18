
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// UART status register.
typedef struct {
    // Transmitter is currently sending.
    uint32_t tx_busy   : 1;
    // Transmitter has data in its buffer.
    uint32_t tx_hasdat : 1;
    // Transmitter can accept more data.
    uint32_t tx_hascap : 1;
    // Padding.
    uint32_t _padding0 : 13;
    // Receiver is currently receiving.
    uint32_t rx_busy   : 1;
    // Receiver has data in its buffer.
    uint32_t rx_hasdat : 1;
    // Receiver can accept more data.
    uint32_t rx_hascap : 1;
    // Padding.
    uint32_t _padding1 : 13;
} uart_status_t;

// UART peripheral.
typedef struct {
    // Write to send data, read to receive.
    uint8_t volatile fifo;
    // Padding.
    uint8_t volatile _padding0[3];
    // Status register.
    uart_status_t volatile status;
} uart_t;

// UART 0 address.
extern uart_t UART0 asm("__uart0_base");
