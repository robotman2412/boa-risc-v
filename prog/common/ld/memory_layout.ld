
/* Copyright © 2024, Julian Scheffers, see LICENSE for more information */

__start_rom     = 0x40001000;
__stop_rom      = 0x40002000;
__start_sram    = 0x40010000;
__stop_sram     = 0x40020000;
__start_peri    = 0x20000000;
__stop_peri     = 0x20001000;
__start_xip     = 0x80000000;
__stop_xip      = 0x80800000;
__start_extram  = 0x80800000;
__stop_extram   = 0x81000000;
__start_cpummio = 0xff000000;
__mtime         = __start_cpummio;
__mtimecmp      = __start_cpummio + 8;

__is_simulator_base = __start_peri + 0x310;

__uart0_base = __start_peri + 0x000;
__pmu_base   = __start_peri + 0x100;
__gpio_base  = __start_peri + 0x200;
__rng_base   = __start_peri + 0x300;
__pwm_base   = __start_peri + 0x480;
