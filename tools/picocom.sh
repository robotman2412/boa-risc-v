#!/bin/sh

picocom -b 19200 --imap lfcrlf, --emap "" --omap crlf,ignlf, $*
