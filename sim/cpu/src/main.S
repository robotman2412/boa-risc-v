/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

    .global _start
_start:
    lui x1, 0xdeadc
    addi x1, x1, 0xfffffeef
    
    sb x1, 3(x0)
    sh x1, 6(x0)
    sw x1, 8(x0)
    
    sh x1, 7(x0)
    sw x1, 9(x0)
