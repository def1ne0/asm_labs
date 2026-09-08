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

 ldaa $8100 ; let V1 = 0xFF
 ldab $8101 ; let V2 = 0xFF
 mul ; D = V1 * V2 = [11111110][00000001]

 staa _Temp_H ; store temporary high byte (=11111110)
 stab _Low ; store low byte (=00000001)

 ldaa _Temp_H ; 
 ldab $8102 
 mul ; D = [11111110] * V3 = [11111101][00000010] 

 staa _High ; (=11111101)
 stab _Mid ; (=00000010)

 ldaa _Low 
 ldab $8102
 mul ; D = [00000001] * V3 = [00000000][11111111]

 stab _Low ; (=11111111)
 adda _Mid ; _Mid = [00000000] + _Mid = [00000000] + [00000010] = [00000010]
 staa _Mid 
 bcc Done
 inc _High ; carry flag not triggered

 ; So, res = [11111101][00000010][11111111] = 255 * 255 * 255 = 16_581_375
Done:
 bra * 