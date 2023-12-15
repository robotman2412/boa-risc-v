/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/


__start_text = .;
.text : AT(0) { *(.boot.text) *(.text) *(.text.*) } :codeseg
. = ALIGN(16);
__stop_text = .;

__start_rodata = .;
.rodata : AT(__stop_text - __start_rom) { *(.rodata) *(.rodata.*) *(.srodata) *(.srodata.*) } :rodataseg
. = ALIGN(16);
__stop_rodata = .;
