
/* Copyright © 2024, Julian Scheffers, see LICENSE for more information */

PROVIDE(__start_peri    = 0x20000000);
PROVIDE(__stop_peri     = 0x20001000);
PROVIDE(__start_cpummio = 0x30000000);
PROVIDE(__stop_cpummio  = 0x30000010);
PROVIDE(__start_rom     = 0x40000000);
PROVIDE(__stop_rom      = 0x40001000);
PROVIDE(__start_sram    = 0x50000000);
PROVIDE(__stop_sram     = 0x50010000);
PROVIDE(__start_extrom  = 0x80000000);
PROVIDE(__start_extram  = 0xc0000000);

PROVIDE(__mtime         = __start_cpummio);
PROVIDE(__mtimecmp      = __start_cpummio + 8);

PROVIDE(__is_simulator_base = __start_peri + 0x310);
PROVIDE(__xromctl_base      = __start_peri + 0x500);
PROVIDE(__xramctl_base      = __start_peri + 0x600);

PROVIDE(__uart0_base = __start_peri + 0x000);
PROVIDE(__pmu_base   = __start_peri + 0x100);
PROVIDE(__gpio_base  = __start_peri + 0x200);
PROVIDE(__rng_base   = __start_peri + 0x300);
PROVIDE(__pwm_base   = __start_peri + 0x480);
