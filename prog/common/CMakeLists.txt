#[[
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
#]]

cmake_minimum_required(VERSION 3.10.0)

cmake_policy(SET CMP0076 NEW)

if(NOT DEFINED linkerscript)
    set(linkerscript ${CMAKE_CURRENT_LIST_DIR}/linker.ld)
endif()

target_compile_options(${target} PUBLIC
    -ffreestanding -nostdlib -nodefaultlibs -nostdinc -O2
    -march=rv32im_zicsr -mabi=ilp32
    -ffunction-sections
)

target_link_options(${target} PUBLIC
    -ffreestanding -nostdlib -nodefaultlibs
    -T${linkerscript}
    -Wl,--gc-sections -Wl,-L${CMAKE_CURRENT_LIST_DIR}
)

target_include_directories(${target} PUBLIC SYSTEM ${CMAKE_CURRENT_LIST_DIR}/system)
target_include_directories(${target} PUBLIC ${CMAKE_CURRENT_LIST_DIR}/include)

target_sources(${target} PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/asm/int64.S
    ${CMAKE_CURRENT_LIST_DIR}/asm/isr.S
    ${CMAKE_CURRENT_LIST_DIR}/asm/start.S
    
    ${CMAKE_CURRENT_LIST_DIR}/src/print.c
    ${CMAKE_CURRENT_LIST_DIR}/src/string.c
)
