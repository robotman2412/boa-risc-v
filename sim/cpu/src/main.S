/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

_start:
    la x1, ohno
_jalr:
    jalr x2, 0(x1)
    nop
    nop
    nop
    nop
    nop
lolol:
    j lolol
ohno:
    j ohno
