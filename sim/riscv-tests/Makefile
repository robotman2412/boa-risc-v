
MAKEFLAGS += --silent --no-print-directory

.PHONY: all build clean run wave

HDL = 	hdl/top.sv \
		../dev/hdl/raw_block_ram.sv \
 		$(shell find ../../dev/hdl -name '*.sv') \
 		$(shell find ../../hdl -name '*.sv')
PROG ?= build/riscv-tests/isa/rv32ui/simple.S.mem

all: run wave

build:
	verilator -Wall -Wno-fatal -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-WIDTH -Wno-UNUSED \
		--trace --trace-fst --trace-depth 20 --trace-max-array 128 --trace-max-width 128 \
		-sv --cc --exe --build \
		-I../../hdl/include \
		--top-module top \
		-j $(shell nproc) bench.cpp $(HDL) -o sim

clean:
	rm -rf obj_dir

run: build
	ln -sTf $(shell realpath $(PROG)) obj_dir/rom.mem
	./obj_dir/sim

wave:
	gtkwave obj_dir/sim.fst
