
MAKEFLAGS += --silent --no-print-directory

.PHONY: all build clean run wave

HDL = 	hdl/top.sv \
 		$(shell find ../../hdl -name '*.sv')
SRC =   src/main.S

all: wave

obj_dir/rom.svh: $(SRC) linker.ld
	mkdir -p obj_dir
	riscv32-unknown-elf-gcc \
		-march=rv32im_zicsr -mabi=ilp32 -ffreestanding \
		-nostdlib -nodefaultlibs -Tlinker.ld \
		-o $@.elf $(SRC)
	riscv32-unknown-elf-objcopy -O binary $@.elf $@.bin
	../../tools/bin2rom.py $@.bin $@ rom 32
	riscv32-unknown-elf-objdump -t $@.elf

build: $(HDL) bench.cpp obj_dir/rom.svh
	verilator -Wall -Wno-fatal -Werror-PINNOCONNECT -Werror-IMPLICIT -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-WIDTH -Wno-UNUSED \
		--trace --trace-fst --trace-depth 20 --trace-max-array 128 --trace-max-width 128 \
		-sv --cc --exe --build \
		-I../../hdl/include -Iobj_dir \
		--top-module top \
		-j $(shell nproc) bench.cpp $(HDL) -o sim

clean:
	rm -rf obj_dir

run: build
	./obj_dir/sim

wave: run
	gtkwave obj_dir/sim.fst
