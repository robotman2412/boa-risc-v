
MAKEFLAGS += --silent --no-print-directory

.PHONY: all build clean run wave

HDL = 	hdl/top.sv \
 		$(shell find ../../hdl -name '*.sv')

all: wave

build: $(HDL) bench.cpp
	verilator -Wall -Wno-fatal -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-WIDTH -Wno-UNUSED \
		--trace-fst -sv --cc --exe --build \
		-I../../hdl/include \
		--top-module top \
		-j $(shell nproc) bench.cpp $(HDL) -o sim

clean:
	rm -rf obj_dir

run: build
	./obj_dir/sim

wave: run
	gtkwave obj_dir/sim.fst
