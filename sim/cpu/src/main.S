/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

_start:
    addi x1, x0, 3
    addi x2, x0, 5
    nop
    nop
    nop
    nop
    nop
_br:
    bgt x1, x2, _start
nono:
    j nono
    nop
lolol:
    j lolol
