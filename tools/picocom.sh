#!/bin/sh

picocom --imap lfcrlf, --emap "" --omap crlf,ignlf, $*
