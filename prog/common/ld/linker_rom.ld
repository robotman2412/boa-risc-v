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
    INCLUDE sect_rw.ld
    
    __start_free_sram = .;
    __stop_free_sram = __stop_sram;
    
    __start_data_rom = __stop_rodata;
    __stop_data_rom  = __start_data_rom + __stop_data - __start_data;
}

ENTRY(_start)
