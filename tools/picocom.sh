#!/bin/sh

picocom -b 9600 --imap lfcrlf, --emap "" --omap crlf,ignlf, $*
