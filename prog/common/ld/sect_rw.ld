/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

__start_data = .;
__start_data_rom = __stop_rodata;
.data : AT(__stop_rodata - __start_rom) { *(.data) *(.data.*) *(.sdata) *(.sdata.*) } :dataseg
. = ALIGN(16);
__stop_data = .;
__global_pointer$ = .;

__start_bss = .;
.bss : { *(.bss) *(.bss.*) *(.sbss) *(.sbss.*) } :NONE
. = ALIGN(16);
__stop_bss = .;
