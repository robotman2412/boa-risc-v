/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

    .global _start
_start:
    li x1, 0
    li x2, 1
    li x3, 0
fibs:
    add x3, x1, x2
    mv x1, x2
    mv x2, x3
    j fibs
