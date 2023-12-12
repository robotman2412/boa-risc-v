/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

__start_rom  = 0x4000f000;
__stop_rom   = 0x40010000;
__start_sram = 0x40010000;
__stop_sram  = 0x40020000;
__start_peri = 0x80000000;
__stop_peri  = 0x80001000;

__uart0_base = __start_peri + 0x000;
__pmu_base   = __start_peri + 0x100;
