
/* Copyright © 2024, Julian Scheffers, see LICENSE for more information */

PHDRS {
    codeseg   PT_LOAD;
}

SECTIONS {
    /DISCARD/ : { *(.note.gnu.build-id) }
    
    . = 0x10000;
    .text : AT(0) {
        *(.text)
    } :codeseg
}

ENTRY(_start)
