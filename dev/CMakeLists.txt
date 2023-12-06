#[[
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
#]]

cmake_minimum_required(VERSION 3.10.0)

set(CMAKE_C_COMPILER "riscv32-unknown-elf-gcc")
set(CMAKE_EXPORT_COMPILE_COMMANDS true)
set(target rom.elf)

project(axo_dev_rom C ASM)

add_compile_options(
    -ffreestanding -nostdlib -nodefaultlibs -nostdinc
    -march=rv32im_zicsr -mabi=ilp32
)

add_link_options(
    -ffreestanding -nostdlib -nodefaultlibs
    -T${CMAKE_CURRENT_LIST_DIR}/linker.ld
)

include_directories(SYSTEM include/system)
include_directories(include)

add_executable(${target}
    src/int64.S
    src/isr.S
    src/main.S
    
    src/main.c
)
