#[[
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
#]]

cmake_minimum_required(VERSION 3.10.0)

set(CMAKE_C_COMPILER "riscv32-unknown-elf-gcc")
set(CMAKE_EXPORT_COMPILE_COMMANDS true)

project(axo_test_rom C ASM)
set(target rom.elf)

add_executable(${target}
    src/main.c
)
target_include_directories(${target} PUBLIC include)

set(memory_layout bootloader)
include(${CMAKE_CURRENT_LIST_DIR}/../common/CMakeLists.txt)
