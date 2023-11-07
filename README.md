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

With the following CSRs present, all mandatory:
| CSR address | CSR name     | Default value | Features
| :---------- | :----------- | :------------ | :-------
| `0x300`     | `mstatus`    | `0x0000_0000` | MIE and MPIE bits
| `0x301`     | `misa`       | `0x4001_0100` | Read-only query of ISA
| `0x302`     | `medeleg`    | `0x0000_0000` | (unimplemented)
| `0x303`     | `mideleg`    | `0x0000_0000` | (unimplemented)
| `0x304`     | `mie`        | `0x0000_0000` | Read/write any interrupt enable
| `0x305`     | `mtvec`      | `0x0000_0000` | Read/write direct exception vector
| `0x310`     | `mstatush`   | `0x0000_0000` | (unimplemented)
| `0x344`     | `mip`        | `0x0000_0000` | Read-only quary of pending interrupts
| `0x340`     | `mscratch`   | `0x0000_0000` | Read/write any value
| `0x341`     | `mepc`       | `0x0000_0000` | Read/write any legal address
| `0x342`     | `mcause`     | `0x0000_0000` | WARL trap and exception cause
| `0x343`     | `mtval`      | `0x0000_0000` | (unimplemented)
| `0xf11`     | `mvendorid`  | `0x0000_0000` | (unimplemented)
| `0xf12`     | `marchid`    | `0x0000_0000` | (unimplemented)
| `0xf13`     | `mipid`      | `0x0000_0000` | (unimplemented)
| `0xf14`     | `mhartid`    | parameter     | Read-only query of CPU/HART ID
| `0xf15`     | `mconfigptr` | `0x0000_0000` | (unimplemented)



# License
Copyright © 2023, Julian Scheffers

<p xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/">This work ("Boa³²") is licensed under <a href="http://creativecommons.org/licenses/by-nc/4.0/?ref=chooser-v1" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">Attribution-NonCommercial 4.0 International

<img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1"><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1"><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/nc.svg?ref=chooser-v1"></a></p>

Corporate entities and for-profit organisations will need to contact Julian Scheffers (julian@scheffers.net) to negotiate a commercial license.

## Why the restrictive license?
First fo all: if you can't integrate this into an open-source project because of the license, please [contact me](mailto:julian@scheffers.net) so we can try to resolve that.

My CPUs are not licensed the same way I license my software. My software is usually licensed MIT so that anyone can do almost anything they want using it. My CPUs, on the other hand, are more restricted because I don't want to risk a for-profit entity selling it without myself getting a cut of the profit.

But you're probably not a for-profit entity, in which case this license lets you integrate it into your own design at no cost and without need for permission.

On the off chance that you *are* for-profit and looking for a CPU, [contact me :)](mailto:julian@scheffers.net)
