/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

PHDRS {
	codeseg   PT_LOAD;
	rodataseg PT_LOAD;
	dataseg   PT_LOAD;
}

SECTIONS {
	/DISCARD/ : { *(.note.gnu.build-id) }
    
    INCLUDE memory_layout.ld
    
    . = __start_rom;
    __start_text = .;
    .text : AT(0) { *(.boot.text) *(.text) } :codeseg
    . = ALIGN(16);
    __stop_text = .;
    
    __start_rodata = .;
    .rodata : AT(__stop_text - __start_rom) { *(.rodata) *(.srodata) } :rodataseg
    . = ALIGN(16);
    __stop_rodata = .;
    
    . = __stop_sram - 8192;
    __start_data = .;
    __start_data_rom = __stop_rodata;
    .data : AT(__stop_rodata - __start_rom) { *(.data) *(.sdata) } :dataseg
    . = ALIGN(16);
    __stop_data = .;
    __global_pointer$ = .;
    
    __start_bss = .;
    .bss : { *(.bss) *(.sbss) } :NONE
    . = ALIGN(16);
    __stop_bss = .;
    __start_free_sram = __start_sram;
    __stop_free_sram = __start_data;
    
    __start_data_rom = __stop_rodata;
    __stop_data_rom  = __start_data_rom + __stop_data - __start_data;
}

ENTRY(_start)
