TARGET equ %01010101

 org $8000
_Start:
 clra
 clrb
 ldx #8
 ldaa #TARGET

_Loop:
 lsra
 rolb
 dex
 bne _Loop
 bra *

