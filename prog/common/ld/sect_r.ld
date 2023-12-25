
/* Copyright © 2023, Julian Scheffers, see LICENSE for more information */

__start_text = .;
.text : AT(0) { *(.boot.text) *(.text) *(.text.*) } :codeseg
. = ALIGN(16);
__stop_text = .;

__start_rodata = .;
.rodata : AT(__stop_text - __start_rom) { *(.rodata) *(.rodata.*) *(.srodata) *(.srodata.*) } :rodataseg
. = ALIGN(16);
__stop_rodata = .;
