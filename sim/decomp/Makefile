
MAKEFLAGS += --silent --no-print-directory

.PHONY: all build clean run wave

HDL    = hdl/top.sv \
         $(shell find ../../hdl -name '*.sv')
SRC    = src/main.S
CC     = riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -nostdinc -nodefaultlibs -nostartfiles -nostdlib
OCP    = riscv32-unknown-elf-objcopy
DISAS  = riscv32-unknown-elf-objdump -m riscv -b binary --no-show-raw-insn -D
FILTER = | sed 1,7d | sed -E 's/^\s*[0-9a-fA-F]+:\s*//g'

all: wave

build: $(HDL) bench.cpp $(SRC)
	mkdir -p obj_dir
	$(CC) -DRVC -o obj_dir/insn_rvc.elf $(SRC) -Tlinker.ld
	$(CC)       -o obj_dir/insn.elf     $(SRC) -Tlinker.ld
	$(OCP) -O binary obj_dir/insn_rvc.elf obj_dir/insn_rvc.bin
	$(OCP) -O binary obj_dir/insn.elf     obj_dir/insn.bin
	../../tools/bin2rom.py obj_dir/insn_rvc.bin obj_dir/insn_rvc.svh insn_rvc 32
	../../tools/bin2rom.py obj_dir/insn.bin     obj_dir/insn.svh     insn     32
	verilator -Wall -Wno-fatal -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-WIDTH -Wno-UNUSED \
		--trace --trace-fst --trace-depth 20 --trace-max-array 128 --trace-max-width 128 \
		-sv --cc --exe --build \
		-I../../hdl/include -Iobj_dir \
		--top-module top \
		-j $(shell nproc) bench.cpp $(HDL) -o sim

clean:
	rm -rf obj_dir

run: build
	./obj_dir/sim
	$(DISAS) obj_dir/decomp.bin   $(FILTER) > obj_dir/decomp.asm
	$(DISAS) obj_dir/insn_rvc.bin $(FILTER) > obj_dir/insn_rvc.asm
	$(DISAS) obj_dir/insn.bin     $(FILTER) > obj_dir/insn.asm
	./analisys.py

wave: run
	gtkwave obj_dir/sim.fst
