/*
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
*/

#pragma once

#include <stddef.h>
#include <stdint.h>


#ifndef DATA_MAX
#define DATA_MAX 16
#endif

// Ping packet, can be used to tell if the connection is alive.
#define P_PING  0x00
// Ping response packet, echoes the data sent in the corresponding ping.
#define P_PONG  0x01
// Request acknowledgement.
#define P_ACK   0x02
// Identity request.
#define P_WHO   0x03
// Identity response.
#define P_IDENT 0x04
// Prepare for a memory write.
#define P_WRITE 0x10
// Request a memory read.
#define P_READ  0x11
// Data associated with P_WRITE.
#define P_WDATA 0x12
// Data associated with P_READ.
#define P_RDATA 0x13
// Jump to a specified memory as 2nd stage boot.
#define P_JUMP  0x20
// Call a specified address as a function.
#define P_CALL  0x21

// The operation was successful.
#define A_ACK    0x00
// The operation is possible, but not allowed.
#define A_NACK   0x01
// Packet checksum mismatch.
#define A_XSUM   0x02
// The request is not supported.
#define A_NCAP   0x03
// The address range is not supported.
#define A_ADDR   0x04
// The address range is read-only.
#define A_RDONLY 0x05
// The address range is not executable.
#define A_NOEXEC 0x06

// Packet header structure.
typedef struct {
    // Describes the request or data stored in this packet.
    uint32_t type;
    // Length of the remaining data.
    uint32_t length;
} phdr_t;

// P_PING and P_PONG data format.
typedef struct {
    // Arbitrary data.
    uint8_t nonce[16];
} p_ping_t;

// P_ACK data format.
typedef struct {
    // Acknowledgement type.
    uint8_t  ack_type;
    // Cause of potential errors.
    uint32_t cause;
} p_ack_t;

// P_WRITE data format.
typedef struct {
    // Base address to write to.
    uint32_t addr;
    // Length to write.
    uint32_t length;
} p_write_t;

// P_READ data format.
typedef struct {
    // Base address to read from.
    uint32_t addr;
    // Length to read.
    uint32_t length;
} p_read_t;

// P_JUMP data format.
typedef struct {
    // Address to jump to.
    uint32_t addr;
} p_jump_t;

// P_CALL data format.
typedef struct {
    // Address to call.
    uint32_t addr;
} p_call_t;

// Packet data union.
typedef union {
    p_ping_t  p_ping;
    p_ack_t   p_ack;
    p_write_t p_write;
    p_read_t  p_read;
    p_jump_t  p_jump;
    p_call_t  p_call;
    uint8_t   raw[DATA_MAX];
} p_data_t;
