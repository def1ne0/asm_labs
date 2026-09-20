; multiply 0x8100-0x8102
; let V1 = *(0x8100), V2 = *(0x8101), V3 = *(0x8102) be 1 byte,

kV1 equ $FF
kV2 equ $FF
kV3 equ $FF

_Low equ $00
_Mid equ $01
_High equ $02
_Temp_H equ $03

 org $8100
 fcb kV1
 org $8101
 fcb kV2
 org $8102
 fcb kV3

 org $8000
 clra
 clrb 
 clr _Mid
 clr _High
 ldaa $8100
 ldab $8101
 mul
 staa _Temp_H
 stab _Low
 ldaa _Temp_H 
 ldab $8102 
 mul 
 staa _High
 stab _Mid 
 ldaa _Low 
 ldab $8102
 mul
 stab _Low
 adda _Mid
 staa _Mid 
 bcc Done
 inc _High
Done:
 bra * 


