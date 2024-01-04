
/* Copyright © 2024, Julian Scheffers, see LICENSE for more information */

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
    
    . = __stop_sram - 8192;
    INCLUDE sect_rw.ld
    
    __start_free_sram = __start_sram;
    __stop_free_sram = __stop_sram - 8192;
    
    __start_data_rom = __stop_rodata;
    __stop_data_rom  = __start_data_rom + __stop_data - __start_data;
}

ENTRY(_start)
