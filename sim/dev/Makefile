
MAKEFLAGS += --silent --no-print-directory

.PHONY: all build clean run wave

HDL   = $(shell find hdl -name '*.sv') \
		$(shell find ../../dev/hdl -name '*.sv') \
		$(shell find ../../hdl -name '*.sv')
SRC   = src/main.S
PROG ?= bootloader

all: wave

build:
	mkdir -p obj_dir
	$(MAKE) -C ../../prog build
	ln -sTf ../../../prog/$(PROG)/build/rom.mem obj_dir/rom.mem
	verilator -Wall -Wno-fatal -Werror-PINNOCONNECT -Werror-IMPLICIT -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-WIDTH -Wno-UNUSED \
		--trace --trace-fst --trace-depth 20 --trace-max-array 256 --trace-max-width 128 \
		-sv --cc --exe --build \
		-I../../hdl/include \
		--top-module top \
		-j $(shell nproc) bench.cpp $(HDL) -o sim

clean:
	$(MAKE) -C ../../prog clean
	rm -rf obj_dir

run: build
	./obj_dir/sim

wave: run
	gtkwave obj_dir/sim.fst
