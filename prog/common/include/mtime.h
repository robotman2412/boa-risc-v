
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

#pragma once

#include <stdint.h>

extern uint64_t volatile mtime asm("__mtime");
extern uint64_t volatile mtimecmp asm("__mtimecmp");
