
/* Copyright © 2024, Julian Scheffers, see LICENSE for more information */

PHDRS {
    codeseg   PT_LOAD;
    rodataseg PT_LOAD;
    dataseg   PT_LOAD;
}

SECTIONS {
    /DISCARD/ : { *(.note.gnu.build-id) }
    
    INCLUDE memory_layout.ld
    __sect_align = 1024;
    
    . = __start_sram;
    INCLUDE sect_r.ld
    INCLUDE sect_rw.ld
    
    __start_free_sram = .;
    __stop_free_sram = __stop_sram;
}

ENTRY(_start)
