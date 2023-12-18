
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

/* Demultiplexer arbitration algorithms. */
// Round-robin arbiter.
`define BOA_ARBITER_RR      0
// Static prioritization arbiter.
`define BOA_ARBITER_STATIC  1



// RISC-V opcodes.
`define RV_OP_LOAD          'b00000
`define RV_OP_LOAD_FP       'b00001
`define RV_OP_custom_0      'b00010
`define RV_OP_MISC_MEM      'b00011
`define RV_OP_OP_IMM        'b00100
`define RV_OP_AUIPC         'b00101
`define RV_OP_OP_IMM_32     'b00110
`define RV_OP_STORE         'b01000
`define RV_OP_STORE_FP      'b01001
`define RV_OP_custom_1      'b01010
`define RV_OP_AMO           'b01011
`define RV_OP_OP            'b01100
`define RV_OP_LUI           'b01101
`define RV_OP_OP_32         'b01110
`define RV_OP_MADD          'b10000
`define RV_OP_MSUB          'b10001
`define RV_OP_NMSUB         'b10010
`define RV_OP_NMADD         'b10011
`define RV_OP_OP_FP         'b10100
`define RV_OP_custom_2      'b10110
`define RV_OP_BRANCH        'b11000
`define RV_OP_JALR          'b11001
`define RV_OP_JAL           'b11011
`define RV_OP_SYSTEM        'b11100
`define RV_OP_custom_3      'b11110

// RISC-V branch FUNCT3 values.
`define RV_BRANCH_BEQ       'b000
`define RV_BRANCH_BNE       'b001
`define RV_BRANCH_BLT       'b100
`define RV_BRANCH_BGE       'b101
`define RV_BRANCH_BLTU      'b110
`define RV_BRANCH_BGEU      'b111

// RISC-V ALU FUNCT3 values.
`define RV_ALU_ADD          'b000
`define RV_ALU_SLL          'b001
`define RV_ALU_SLT          'b010
`define RV_ALU_SLTU         'b011
`define RV_ALU_XOR          'b100
`define RV_ALU_SRL          'b101
`define RV_ALU_OR           'b110
`define RV_ALU_AND          'b111

// RISC-V MULDIV FUNCT3 values.
`define RV_MULDIV_MUL       'b000
`define RV_MULDIV_MULH      'b001
`define RV_MULDIV_MULHSU    'b010
`define RV_MULDIV_MULHU     'b011
`define RV_MULDIV_DIV       'b100
`define RV_MULDIV_DIVU      'b101
`define RV_MULDIV_REM       'b110
`define RV_MULDIV_REMU      'b111

// RISC-V SYSTEM FUNCT3 values.
`define RV_SYSTEM_ECALL     'b000
`define RV_SYSTEM_CSRRW     'b001
`define RV_SYSTEM_CSRRS     'b010
`define RV_SYSTEM_CSRRC     'b011
`define RV_SYSTEM_CSRRWI    'b101
`define RV_SYSTEM_CSRRSI    'b110
`define RV_SYSTEM_CSRRCI    'b111



// RISC-V misa CSR values.
`define RV_MISA_A           (1 << 0)
`define RV_MISA_B           (1 << 1)
`define RV_MISA_C           (1 << 2)
`define RV_MISA_D           (1 << 3)
`define RV_MISA_E           (1 << 4)
`define RV_MISA_F           (1 << 5)
`define RV_MISA_G           (1 << 6)
`define RV_MISA_H           (1 << 7)
`define RV_MISA_I           (1 << 8)
`define RV_MISA_J           (1 << 9)
`define RV_MISA_K           (1 << 10)
`define RV_MISA_L           (1 << 11)
`define RV_MISA_M           (1 << 12)
`define RV_MISA_N           (1 << 13)
`define RV_MISA_O           (1 << 14)
`define RV_MISA_P           (1 << 15)
`define RV_MISA_Q           (1 << 16)
`define RV_MISA_R           (1 << 17)
`define RV_MISA_S           (1 << 18)
`define RV_MISA_T           (1 << 19)
`define RV_MISA_U           (1 << 20)
`define RV_MISA_V           (1 << 21)
`define RV_MISA_W           (1 << 22)
`define RV_MISA_X           (1 << 23)
`define RV_MISA_Y           (1 << 24)
`define RV_MISA_Z           (1 << 25)



/* RISC-V trap causes. */
// Instruction access misaligned.
`define RV_ECAUSE_IALIGN    5'h00
// Instruction access fault.
`define RV_ECAUSE_IACCESS   5'h01
// Illegal instruction.
`define RV_ECAUSE_IILLEGAL  5'h02
// Trace / breakpoint trap.
`define RV_ECAUSE_EBREAK    5'h03
// Load access misaligned.
`define RV_ECAUSE_LALIGN    5'h04
// Load access fault.
`define RV_ECAUSE_LACCESS   5'h05
// Store / AMO access misaligned.
`define RV_ECAUSE_SALIGN    5'h06
// Store / AMO access fault.
`define RV_ECAUSE_SACCESS   5'h07
// ECALL from U-mode.
`define RV_ECAUSE_U_ECALL   5'h08
// ECALL from S-mode.
`define RV_ECAUSE_S_ECALL   5'h09
// ECALL from M-mode.
`define RV_ECAUSE_M_ECALL   5'h0B
// Instruction page fault.
`define RV_ECAUSE_IPAGE     5'h0C
// Load page fault.
`define RV_ECAUSE_LPAGE     5'h0D
// Store / AMO page fault.
`define RV_ECAUSE_SPAGE     5'h0F



// Defined RISC-V CSR addresses.
`define RV_CSR_FFLAGS       12'h001
`define RV_CSR_FRM          12'h002
`define RV_CSR_FCSR         12'h003

`define RV_CSR_SSTATUS      12'h100
`define RV_CSR_SIE          12'h104
`define RV_CSR_STVEC        12'h105
`define RV_CSR_SENVCFG      12'h10A
`define RV_CSR_SSCRATCH     12'h140
`define RV_CSR_SEPC         12'h141
`define RV_CSR_SCAUSE       12'h142
`define RV_CSR_STVAL        12'h143
`define RV_CSR_SIP          12'h144
`define RV_CSR_SATP         12'h180

`define RV_CSR_MSTATUS      12'h300
`define RV_CSR_MISA         12'h301
`define RV_CSR_MEDELEG      12'h302
`define RV_CSR_MIDELEG      12'h303
`define RV_CSR_MIE          12'h304
`define RV_CSR_MTVEC        12'h305
`define RV_CSR_MENVCFG      12'h30A
`define RV_CSR_MSTATUSH     12'h310
`define RV_CSR_MENVCFGH     12'h31A
`define RV_CSR_MSCRATCH     12'h340
`define RV_CSR_MEPC         12'h341
`define RV_CSR_MCAUSE       12'h342
`define RV_CSR_MTVAL        12'h343
`define RV_CSR_MIP          12'h344
`define RV_CSR_MINST        12'h34A
`define RV_CSR_MTVAL2       12'h34B
`define RV_CSR_MSECCFG      12'h747
`define RV_CSR_MSECCFGH     12'h757
`define RV_CSR_MVENDORID    12'hF11
`define RV_CSR_MARCHID      12'hF12
`define RV_CSR_MIPID        12'hF13
`define RV_CSR_MHARTID      12'hF14
`define RV_CSR_MCONFIGPTR   12'hF15

`define RV_CSR_PMPCFG0      12'h3A0
`define RV_CSR_PMPCFG1      12'h3A1
`define RV_CSR_PMPCFG2      12'h3A2
`define RV_CSR_PMPCFG3      12'h3A3
`define RV_CSR_PMPCFG4      12'h3A4
`define RV_CSR_PMPCFG5      12'h3A5
`define RV_CSR_PMPCFG6      12'h3A6
`define RV_CSR_PMPCFG7      12'h3A7
`define RV_CSR_PMPCFG8      12'h3A8
`define RV_CSR_PMPCFG9      12'h3A9
`define RV_CSR_PMPCFG10     12'h3AA
`define RV_CSR_PMPCFG11     12'h3AB
`define RV_CSR_PMPCFG12     12'h3AC
`define RV_CSR_PMPCFG13     12'h3AD
`define RV_CSR_PMPCFG14     12'h3AE
`define RV_CSR_PMPCFG15     12'h3AF

`define RV_CSR_PMPADDR0     12'h3B0
`define RV_CSR_PMPADDR1     12'h3B1
`define RV_CSR_PMPADDR2     12'h3B2
`define RV_CSR_PMPADDR3     12'h3B3
`define RV_CSR_PMPADDR4     12'h3B4
`define RV_CSR_PMPADDR5     12'h3B5
`define RV_CSR_PMPADDR6     12'h3B6
`define RV_CSR_PMPADDR7     12'h3B7
`define RV_CSR_PMPADDR8     12'h3B8
`define RV_CSR_PMPADDR9     12'h3B9
`define RV_CSR_PMPADDR10    12'h3BA
`define RV_CSR_PMPADDR11    12'h3BB
`define RV_CSR_PMPADDR12    12'h3BC
`define RV_CSR_PMPADDR13    12'h3BD
`define RV_CSR_PMPADDR14    12'h3BE
`define RV_CSR_PMPADDR15    12'h3BF
`define RV_CSR_PMPADDR16    12'h3C0
`define RV_CSR_PMPADDR17    12'h3C1
`define RV_CSR_PMPADDR18    12'h3C2
`define RV_CSR_PMPADDR19    12'h3C3
`define RV_CSR_PMPADDR20    12'h3C4
`define RV_CSR_PMPADDR21    12'h3C5
`define RV_CSR_PMPADDR22    12'h3C6
`define RV_CSR_PMPADDR23    12'h3C7
`define RV_CSR_PMPADDR24    12'h3C8
`define RV_CSR_PMPADDR25    12'h3C9
`define RV_CSR_PMPADDR26    12'h3CA
`define RV_CSR_PMPADDR27    12'h3CB
`define RV_CSR_PMPADDR28    12'h3CC
`define RV_CSR_PMPADDR29    12'h3CD
`define RV_CSR_PMPADDR30    12'h3CE
`define RV_CSR_PMPADDR31    12'h3CF
`define RV_CSR_PMPADDR32    12'h3D0
`define RV_CSR_PMPADDR33    12'h3D1
`define RV_CSR_PMPADDR34    12'h3D2
`define RV_CSR_PMPADDR35    12'h3D3
`define RV_CSR_PMPADDR36    12'h3D4
`define RV_CSR_PMPADDR37    12'h3D5
`define RV_CSR_PMPADDR38    12'h3D6
`define RV_CSR_PMPADDR39    12'h3D7
`define RV_CSR_PMPADDR40    12'h3D8
`define RV_CSR_PMPADDR41    12'h3D9
`define RV_CSR_PMPADDR42    12'h3DA
`define RV_CSR_PMPADDR43    12'h3DB
`define RV_CSR_PMPADDR44    12'h3DC
`define RV_CSR_PMPADDR45    12'h3DD
`define RV_CSR_PMPADDR46    12'h3DE
`define RV_CSR_PMPADDR47    12'h3DF
`define RV_CSR_PMPADDR48    12'h3E0
`define RV_CSR_PMPADDR49    12'h3E1
`define RV_CSR_PMPADDR50    12'h3E2
`define RV_CSR_PMPADDR51    12'h3E3
`define RV_CSR_PMPADDR52    12'h3E4
`define RV_CSR_PMPADDR53    12'h3E5
`define RV_CSR_PMPADDR54    12'h3E6
`define RV_CSR_PMPADDR55    12'h3E7
`define RV_CSR_PMPADDR56    12'h3E8
`define RV_CSR_PMPADDR57    12'h3E9
`define RV_CSR_PMPADDR58    12'h3EA
`define RV_CSR_PMPADDR59    12'h3EB
`define RV_CSR_PMPADDR60    12'h3EC
`define RV_CSR_PMPADDR61    12'h3ED
`define RV_CSR_PMPADDR62    12'h3EE
`define RV_CSR_PMPADDR63    12'h3EF



// PMP addressing modes.
`define RV_PMP_OFF          2'b00
`define RV_PMP_TOR          2'b01
`define RV_PMP_NA4          2'b10
`define RV_PMP_NAPOT        2'b11
