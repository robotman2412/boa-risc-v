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
    INCLUDE sect_r.ld
    
    . = __start_sram;
    __start_data = .;
    __start_data_rom = __stop_rodata;
    .data : AT(__stop_rodata - __start_rom) { *(.data) *(.data.*) *(.tohost) *(.tohost.*) *(.sdata) *(.sdata.*) } :dataseg
    . = ALIGN(16);
    __stop_data = .;
    __global_pointer$ = .;
    
    __start_bss = .;
    .bss : { *(.bss) *(.bss.*) *(.sbss) *(.sbss.*) } :NONE
    . = ALIGN(16);
    __stop_bss = .;
    
    __start_free_sram = .;
    __stop_free_sram = __stop_sram;
    
    __start_data_rom = __stop_rodata;
    __stop_data_rom  = __start_data_rom + __stop_data - __start_data;
}

ENTRY(_start)
