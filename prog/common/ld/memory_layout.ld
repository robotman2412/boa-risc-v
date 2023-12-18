
/* Copyright © 2023, Julian Scheffers, see LICENSE for more information */

__start_rom     = 0x40001000;
__stop_rom      = 0x40002000;
__start_sram    = 0x40010000;
__stop_sram     = 0x40020000;
__start_peri    = 0x80000000;
__stop_peri     = 0x80001000;
__start_cpummio = 0xff000000;
__mtime         = __start_cpummio;
__mtimecmp      = __start_cpummio + 8;

__uart0_base = __start_peri + 0x000;
__pmu_base   = __start_peri + 0x100;
