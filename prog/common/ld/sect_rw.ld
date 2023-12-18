
/* Copyright © 2023, Julian Scheffers, see LICENSE for more information */

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
