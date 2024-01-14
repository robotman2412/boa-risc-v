
MAKEFLAGS += --silent --no-print-directory

.PHONY: all build clean

all: build

build:
	mkdir -p build
	$(MAKE) -C coremark PORT_DIR=$(shell realpath port) compile
	cp build/coremark.elf build/rom.elf
	riscv32-unknown-elf-objcopy -O binary build/rom.elf build/rom.bin
	../../tools/bin2mem.py build/rom.bin build/rom.mem 32

clean:
	rm -rf build
