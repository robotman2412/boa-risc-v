#[[
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
#]]

cmake_minimum_required(VERSION 3.10.0)

cmake_policy(SET CMP0076 NEW)

target_compile_options(${target} PUBLIC
    -ffreestanding -nostdlib -nodefaultlibs -nostdinc
    -march=rv32im_zicsr -mabi=ilp32
    -ffunction-sections
)

target_link_options(${target} PUBLIC
    -ffreestanding -nostdlib -nodefaultlibs
    -T${CMAKE_CURRENT_LIST_DIR}/linker.ld
    -Wl,--gc-sections
)

target_include_directories(${target} PUBLIC SYSTEM ${CMAKE_CURRENT_LIST_DIR}/system)
target_include_directories(${target} PUBLIC ${CMAKE_CURRENT_LIST_DIR}/include)

target_sources(${target} PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/src/int64.S
    ${CMAKE_CURRENT_LIST_DIR}/src/isr.S
    ${CMAKE_CURRENT_LIST_DIR}/src/start.S
)
