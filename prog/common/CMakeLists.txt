#[[
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
#]]

cmake_minimum_required(VERSION 3.10.0)

cmake_policy(SET CMP0076 NEW)
cmake_policy(SET CMP0054 NEW)
cmake_policy(SET CMP0057 NEW)

if(NOT DEFINED memory_layout)
    set(memory_layout ram)
endif()

if(NOT DEFINED linkerscript)
    set(linkerscript ${CMAKE_CURRENT_LIST_DIR}/ld/linker_${memory_layout}.ld)
endif()

if(${memory_layout} EQUAL "ram")
    target_compile_definitions(${target} PUBLIC
        -DROM_PROGRAM
    )
endif()

target_compile_options(${target} PUBLIC
    -ffreestanding -nostdlib -nodefaultlibs -nostdinc -O2
    -march=rv32imc_zicsr -mabi=ilp32
    -ffunction-sections
)

target_link_options(${target} PUBLIC
    -ffreestanding -nostdlib -nodefaultlibs
    -T${linkerscript}
    -Wl,--gc-sections -Wl,-L${CMAKE_CURRENT_LIST_DIR}/ld
)

target_include_directories(${target} PUBLIC ${CMAKE_CURRENT_LIST_DIR}/system)
target_include_directories(${target} PUBLIC ${CMAKE_CURRENT_LIST_DIR}/include)

if(NOT DEFINED nodefaultsrc)
    target_sources(${target} PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}/asm/int64.S
        ${CMAKE_CURRENT_LIST_DIR}/asm/isr.S
        ${CMAKE_CURRENT_LIST_DIR}/asm/start.S
        
        ${CMAKE_CURRENT_LIST_DIR}/src/print.c
        ${CMAKE_CURRENT_LIST_DIR}/src/string.c
    )
endif()
