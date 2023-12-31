
.PHONY: all build clean

all:
	make -C test all
	make -C gpiotest all
	make -C uarttest all
	make -C bootloader all

build:
	make -C test build
	make -C gpiotest build
	make -C uarttest build
	make -C bootloader build

clean:
	make -C test clean
	make -C gpiotest clean
	make -C uarttest clean
	make -C bootloader clean
