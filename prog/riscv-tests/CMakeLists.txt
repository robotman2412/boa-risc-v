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
    src/test_end.c
    src/test_end.S
    $ENV{TEST_PATH}
)
target_include_directories(${target} PUBLIC include)
target_include_directories(${target} PUBLIC riscv-tests/isa/macros/scalar)

target_compile_options(${target} PUBLIC -mno-relax)

set(linkerscript ${CMAKE_CURRENT_LIST_DIR}/linker.ld)
target_compile_definitions(${target} PUBLIC -DSTART_NAME=__real_start)
target_compile_definitions(${target} PUBLIC -DMAIN_NAME=_start)
include(${CMAKE_CURRENT_LIST_DIR}/../common/CMakeLists.txt)
