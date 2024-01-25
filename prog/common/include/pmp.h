
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#pragma once

#ifndef __ASSEMBLER__
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// PMP addressing modes.
typedef enum {
    PMP_A_OFF   = 0,
    PMP_A_TOR   = 1,
    PMP_A_NA4   = 2,
    PMP_A_NAPOT = 3,
} pmp_a_t;

// PMP config entry.
typedef union {
    struct {
        // Allow reads.
        uint8_t r : 1;
        // Allow writes.
        uint8_t w : 1;
        // Allow exec.
        uint8_t x : 1;
        // Addressing mode.
        uint8_t a : 2;
        uint8_t   : 2;
        // Locked.
        uint8_t l : 1;
    };
    // Packed value.
    uint8_t val;
} pmpcfg_t;
#endif

#define PMPCFG_LOCK  0x80
#define PMPCFG_R     0x01
#define PMPCFG_RW    0x03
#define PMPCFG_RX    0x05
#define PMPCFG_RWX   0x07
#define PMPCFG_TOR   0x08
#define PMPCFG_NA4   0x10
#define PMPCFG_NAPOT 0x18

#if __LONG_MAX__ == 0x7fffffffL
#define _pmp_shr2(x) (((x) >> 2) & 0x3fffffff)
#define _pmp_shr3(x) (((x) >> 3) & 0x1fffffff)
#else
#define _pmp_shr2(x) (((x) >> 2) & 0x3fffffffffffffff)
#define _pmp_shr3(x) (((x) >> 3) & 0x1fffffffffffffff)
#endif
// Compute a NAPOT address value.
#define _pmp_addr_napot(_addr, _pot) (_pmp_shr2(_addr) & ~_pmp_shr3(_pot) | (_pmp_shr3(_pot) - 1))
#ifdef __ASSEMBLER__
// Clear a PMP config.
#define pmp_clear_cfg(i, tempreg)                                                                                      \
    li tempreg, 0xff << ((i) % 4 * 8);                                                                                 \
    csrc 0x3A0 + (i) / 4, tempreg
// Set a PMP config.
#define pmp_set_cfg(i, val, tempreg)                                                                                   \
    li tempreg, (val) << ((i) % 4 * 8);                                                                                \
    csrs 0x3A0 + (i) / 4, tempreg
// Write a PMP config.
#define pmp_write_cfg(i, val, tempreg)                                                                                 \
    pmp_clear_cfg(i, tempreg);                                                                                         \
    pmp_set_cfg(i, val, tempreg)
// Write a PMP address.
#define pmp_write_addr(i, val, tempreg)                                                                                \
    li tempreg, _pmp_shr2(val);                                                                                        \
    csrw 0x3B0 + (i), tempreg
// Write a NAPOT address (8 byte or larger regions).
#define pmp_write_addr_napot(i, addr, pot, tempreg)                                                                    \
    li tempreg, _pmp_addr_napot(addr, pot);                                                                            \
    csrw 0x3B0 + (i), tempreg
#else
// Validate a PMP index.
#define pmp_idx(i) _Static_assert((i) >= 0 && (i) <= 63, "Invalid PMP index")
// Clear a PMP config.
#define pmp_clear_cfg(i)                                                                                               \
    do {                                                                                                               \
        pmp_idx(i);                                                                                                    \
        asm("csrc 0x3A0+" #i "/4, %0" ::"r"(0xff << ((i) % 4 * 8)));                                                   \
    } while (0)
// Set a PMP config.
#define pmp_set_cfg(i, cfg)                                                                                            \
    do {                                                                                                               \
        pmp_idx(i);                                                                                                    \
        asm("csrs 0x3A0+" #i "/4, %0" ::"r"((cfg) << ((i) % 4 * 8)));                                                  \
    } while (0)
// Write a PMP config.
#define pmp_write_cfg(i, cfg)                                                                                          \
    do {                                                                                                               \
        pmp_idx(i);                                                                                                    \
        asm("csrc 0x3A0+" #i "/4, %0" ::"r"(0xff << ((i) % 4 * 8)));                                                   \
        asm("csrs 0x3A0+" #i "/4, %0" ::"r"((cfg) << ((i) % 4 * 8)));                                                  \
    } while (0)

// Write a PMP address.
#define _pmp_write_addr(i, addr)                                                                                       \
    do {                                                                                                               \
        pmp_idx(i);                                                                                                    \
        asm("csrw 0x3B0+" #i ", %0" ::"r"(addr));                                                                      \
    } while (0)
// Write a PMP address.
#define pmp_write_addr(i, addr) _pmp_write_addr(i, (unsigned long long)(addr) >> 2)
// Write a NAPOT address (8 byte or larger regions).
#define pmp_write_addr_napot(i, addr, pot)                                                                             \
    do {                                                                                                               \
        unsigned long long _addr = (addr);                                                                             \
        unsigned long      _pot  = (pot);                                                                              \
        _pmp_write_addr(i, _pmp_addr_napot(_addr, _pot));                                                              \
    } while (0)
#endif
