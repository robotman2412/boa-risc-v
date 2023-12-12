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
    
    . = __start_sram;
    INCLUDE sect_r.ld
    INCLUDE sect_rw.ld
    
    __start_free_sram = .;
    __stop_free_sram = __stop_sram;
}

ENTRY(_start)
