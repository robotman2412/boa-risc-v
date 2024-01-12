
/* Copyright © 2024, Julian Scheffers, see LICENSE for more information */

__start_peri    = 0x20000000;
__stop_peri     = 0x20001000;
__start_cpummio = 0x30000000;
__start_rom     = 0x40000000;
__stop_rom      = 0x40001000;
__start_sram    = 0x50000000;
__stop_sram     = 0x50010000;
__start_xip     = 0x80000000;
__start_extram  = 0xc0000000;
__mtime         = __start_cpummio;
__mtimecmp      = __start_cpummio + 8;

__is_simulator_base = __start_peri + 0x310;
__memsize_base      = __start_peri + 0x314;
__xromctl_base      = __start_peri + 0x500;
__xramctl_base      = __start_peri + 0x600;

__uart0_base = __start_peri + 0x000;
__pmu_base   = __start_peri + 0x100;
__gpio_base  = __start_peri + 0x200;
__rng_base   = __start_peri + 0x300;
__pwm_base   = __start_peri + 0x480;
