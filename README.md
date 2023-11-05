# Boa³², my second attempt at RISC-V
Because my previous RISC-V CPU, [Axo32](https://github.com/robotman2412/Axolotl-Risc-V), successfully ran code but had crippling issues with the memory architecture, I decided to start my second generation early.

Boa32 is my second attempt at RISC-V, with a longer pipeline and simpler memory bus than Axo32 has. It will initially have the same features (RV32IM_Zicsr) but I plan to expand the scope later on (to RV32IMAC_Zicsr_Zifencei) to implement more RISC-V features.



# Specifications for CPU nerds
The current version of Boa32 will implement RV32IM_Zicsr:
| Instruction set | Meaning
| :-------------- | :------
| RV32I           | Base instruction set for 32-bit RISC-V
| M               | Multiply and division instructions
| Zicsr           | Control and status register instructions

With the following CSRs implemented:
| CSR address | CSR name     | Default value | Features
| :---------- | :----------- | :------------ | :-------
| `0x300`     | `mstatus`    | `0x000000000` | MIE and MPIE bits
| `0x301`     | `misa`       | `0x000000000` | Read-only query of ISA
| `0x302`     | `medeleg`    | `0x000000000` | Read-only
| `0x303`     | `mideleg`    | `0x000000000` | Read-only
| `0x304`     | `mie`        | `0x000000000` | Read/write any interrupt enable
| `0x305`     | `mtvec`      | `0x000000000` | Read/write direct exception vector
| `0x310`     | `mstatush`   | `0x000000000` | Read-only
| `0x344`     | `mip`        | `0x000000000` | Read-only quary of pending interrupts
| `0x340`     | `mscratch`   | `0x000000000` | Read/write any value
| `0x341`     | `mepc`       | `0x000000000` | Read/write any legal address
| `0x342`     | `mcause`     | `0x000000000` | WARL trap and exception cause
| `0x343`     | `mtval`      | `0x000000000` | Read-only
| `0xf11`     | `mvendorid`  | `0x000000000` | Read-only
| `0xf12`     | `marchid`    | `0x000000000` | Read-only
| `0xf13`     | `mipid`      | `0x000000000` | Read-only
| `0xf14`     | `mhartid`    | `0x000000000` | Read-only
| `0xf15`     | `mconfigptr` | `0x000000000` | Read-only



# License
Copyright © 2023, Julian Scheffers

<a rel="license" href="https://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work ("Boa³²") is licensed under a <a rel="license" href="https://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

Corporate entities and for-profit organisations will need to contact Julian Scheffers (julian@scheffers.net) to negotiate a commercial license.

## Why the restrictive license?
First fo all: if you can't integrate this into an open-source project because of the license, please [contact me](mailto:julian@scheffers.net) so we can try to resolve that.

My CPUs are not licensed the same way I license my software. My software is usually licensed MIT so that anyone can do almost anything they want using it. My CPUs, on the other hand, are more restricted because I don't want to risk a for-profit entity selling it without myself getting a cut of the profit.

But you're probably not a for-profit entity, in which case this license lets you integrate it into your own design at no cost and without need for permission.

On the off chance that you *are* for-profit and looking for a CPU, [contact me :)](mailto:julian@scheffers.net)
