# Boa³², my second attempt at RISC-V
Boa32 is a microcontroller-sized pipelined RISC-V CPU currently supporting up to `RV32IMC_Zicsr`. It is a personal learning project in my aspirations to become a CPU designer/engineer.

This core is decently compact for its features:
when implemented on an Artix-7 15T (with some MMIO peripherals), it consumes merely 4900 LUTs and 2600 FFs.

## History
Because my previous RISC-V CPU, [Axo32](https://github.com/robotman2412/Axolotl-Risc-V), successfully ran code but had crippling issues with the memory architecture, I decided to start my second generation early.

Boa32 is my second attempt at RISC-V, with a longer pipeline and simpler memory bus than Axo32 has. It will initially have the same features (RV32IM_Zicsr) but I plan to expand the scope later on (to RV32IMAC_Zicsr_Zifencei) to implement more RISC-V features.



# Specifications for CPU nerds
The current version of Boa32 implements up to RV32IMC_Zicsr:
| Instruction set | Meaning
| :-------------- | :------
| RV32I           | Base instruction set for 32-bit RISC-V
| M               | Multiply and division instructions
| C               | Compressed instruction set
| Zicsr           | Control and status register instructions

With the following CSRs present, all mandatory:
| CSR address | CSR name     | Default value | Features
| :---------- | :----------- | :------------ | :-------
| `0x300`     | `mstatus`    | `0x0000_0000` | MIE and MPIE bits
| `0x301`     | `misa`       | `0x4000_1104` | Read-only query of ISA (RV32IMC)
| `0x302`     | `medeleg`    | `0x0000_0000` | (unimplemented)
| `0x303`     | `mideleg`    | `0x0000_0000` | (unimplemented)
| `0x304`     | `mie`        | `0x0000_0000` | Read/write any interrupt enable
| `0x305`     | `mtvec`      | `0x0000_0000` | Read/write direct exception vector
| `0x310`     | `mstatush`   | `0x0000_0000` | (unimplemented)
| `0x344`     | `mip`        | `0x0000_0000` | Read-only query of pending interrupts
| `0x340`     | `mscratch`   | `0x0000_0000` | Read/write any value
| `0x341`     | `mepc`       | `0x0000_0000` | Read/write any legal PC
| `0x342`     | `mcause`     | `0x0000_0000` | WARL trap and exception cause
| `0x343`     | `mtval`      | `0x0000_0000` | (unimplemented)
| `0xf11`     | `mvendorid`  | `0x0000_0000` | (unimplemented)
| `0xf12`     | `marchid`    | `37`          | Serves as attribution for tapeouts and FPGA bitstreams
| `0xf13`     | `mipid`      | `0x0000_0000` | (unimplemented)
| `0xf14`     | `mhartid`    | parameter     | Read-only query of CPU/HART ID
| `0xf15`     | `mconfigptr` | `0x0000_0000` | (unimplemented)

Unsupported features on the TODO list:
- `Zifencei` extension
- Fusion of division and modulo by means of a cache
- More configurability
- Dynamic branch prediction
- `A` extension
- U-mode



# License
Copyright © 2023, Julian Scheffers

<p xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/">This work ("Boa³²") is licensed under <a href="http://creativecommons.org/licenses/by/4.0/" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">Creative Commons Attribution 4.0 International

<img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1"><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1"></a></p>

In the past this license was more restrictive but I decided to open it up as much as reasonable.
