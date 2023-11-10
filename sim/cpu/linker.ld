/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

PHDRS
{
	codeseg   PT_LOAD;
	rodataseg PT_LOAD;
	dataseg   PT_LOAD;
}

SECTIONS
{
	/DISCARD/ : { *(.note.gnu.build-id) }
    
    __start_rom  = 0x00000000;
    __stop_rom   = 0x00000400;
    __start_sram = 0x00000400;
    __stop_sram  = 0x00000800;
    __start_peri = 0x00000800;
    __stop_peri  = 0x00000C00;
    
    . = __start_rom;
    __start_text = .;
    .text : AT(0) { *(.text) } :codeseg
    . = ALIGN(16);
    __stop_text = .;
    
    __start_rodata = .;
    .rodata : AT(__stop_text - __start_text) { *(.rodata) *(.srodata) } :rodataseg
    . = ALIGN(16);
    __stop_rodata = .;
    
    . = __start_sram;
    __start_data = .;
    .data : AT(__stop_rodata - __start_text) { *(.data) *(.sdata) } :dataseg
    . = ALIGN(16);
    __stop_data = .;
    __global_pointer$ = .;
    
    __start_bss = .;
    .bss : { *(.bss) *(.sbss) } :NONE
    . = ALIGN(16);
    __stop_bss = .;
    
    __start_data_rom = __stop_rodata;
    __stop_data_rom  = __start_data_rom + __stop_data - __start_data;
}

ENTRY(_start)