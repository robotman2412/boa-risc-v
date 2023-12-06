/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

// Replacement for stdlib's <stdbool.h>

#pragma once

#ifndef __cplusplus__
#define bool  _Bool
#define true  ((_Bool) + 1u)
#define false ((_Bool) + 0u)
#endif
