; multiply 0x8100-0x8102
; let V1 = *(0x8100), V2 = *(0x8101), V3 = *(0x8102) be 1 byte,
; so that V1 * V2 * V3 <= 2^16 and V1 * V2 <= 2^16

kV1 equ $01
kV2 equ $02
kV3 equ $03

 org $8100
 fcb kV1
 org $8101
 fcb kV2
 org $8102
 fcb kV3

 org $8000

 clra
 clrb 

 ldaa $8100
 ldab $8101
 mul
 ldaa $8102
 mul
 ; res == D
 bra * 
