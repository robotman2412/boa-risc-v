#!/bin/sh

picocom -b 9 --imap lfcrlf, --emap "" --omap crlf,ignlf, $*
