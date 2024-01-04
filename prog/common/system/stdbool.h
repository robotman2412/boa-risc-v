
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

// Replacement for stdlib's <stdbool.h>

#pragma once

#ifndef __cplusplus__
#define bool  _Bool
#define true  ((_Bool) + 1u)
#define false ((_Bool) + 0u)
#endif
