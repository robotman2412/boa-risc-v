
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Hardware random number generator address.
extern uint32_t volatile RNG asm("__rng_base");
