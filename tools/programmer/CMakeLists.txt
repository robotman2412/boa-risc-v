#[[
    Copyright © 2023, Julian Scheffers

    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:

    https://creativecommons.org/licenses/by-nc/4.0/
#]]

cmake_minimum_required(VERSION 3.10.0)
set(CMAKE_EXPORT_COMPILE_COMMANDS true)

project(boaprog C)
set(target boaprog)

add_definitions(
    -DKBELF_CROSS
    -DKBELF_MACHINE=KBELF_MACHINE_RISCV
    -DKBELF_RISCV_HOST_RVC=0
    -DKBELF_RISCV_HOST_FABI=KBELF_RISCV_FLAG_FABI_SOFT
    -DKBELF_RISCV_HOST_RVE=0
    -DKBELF_DEBUG
    -DDATA_MAX=65536
)
add_subdirectory(kbelf)

add_executable(${target}
    src/kbelfx.c
    src/main.c
)
target_include_directories(${target} PRIVATE include)
target_link_libraries(${target} PRIVATE kbelf)
