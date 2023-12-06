/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

// Replacement for stdlib's <stddef.h>

#pragma once

typedef __PTRDIFF_TYPE__ ptrdiff_t;
typedef __SIZE_TYPE__    size_t;
typedef __WCHAR_TYPE__   wchar_t;

#ifdef __cplusplus
#define NULL 0
#else
#define NULL ((void *)0)
#endif

#define offsetof(a, b) __builtin_offsetof(a, b)
#define alignof(a)     __builtin_alignof(a)
