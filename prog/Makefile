
.PHONY: all build clean

all:
	make -C test all
	make -C gpiotest all
	make -C uarttest all
	make -C divtest all
	make -C bootloader all
	make -C coremark all

build:
	make -C test build
	make -C gpiotest build
	make -C uarttest build
	make -C divtest build
	make -C bootloader build
	make -C coremark build

clean:
	make -C test clean
	make -C gpiotest clean
	make -C uarttest clean
	make -C divtest clean
	make -C bootloader clean
	make -C coremark clean
