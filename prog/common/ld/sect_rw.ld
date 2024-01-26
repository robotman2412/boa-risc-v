
/* Copyright © 2024, Julian Scheffers, see LICENSE for more information */

__start_data = .;
__start_data_rom = __stop_rodata;
.data : AT(__stop_rodata - __start_text) { *(.data) *(.data.*) *(.sdata) *(.sdata.*) } :dataseg
. = ALIGN(__sect_align);
__stop_data = .;
__global_pointer$ = .;

__start_bss = .;
.bss : { *(.bss) *(.bss.*) *(.sbss) *(.sbss.*) } :NONE
. = ALIGN(__sect_align);
__stop_bss = .;

__start_noinit = .;
.noinit : { *(.noinit) *(.noinit.*) } :NONE
. = ALIGN(__sect_align);
__stop_noinit = .;
