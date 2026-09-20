; Result will be in register B
NUM1 equ 3
NUM2 equ 5
NUM3 equ 7
MY_COUNT equ 3

 org $8200
 fcb NUM1
 fcb NUM2
 fcb NUM3

 org $8000
_Start:
 ldd #$8200
 addd #MY_COUNT
 pshb
 psha
 pulx
 clra
 
_Clear_mem:
 staa 0,x
 inx
 cpx #$8300
 bne _Clear_mem

_Odd_count:
 clrb
 ldx #$8200
 
_Check_mem:
 ldaa 0,x
 anda #%00000001
 bne _Odd
 bra _Ret

_Odd:
 incb
 bra _Ret

_Ret:
 inx
 cpx #$8300
 bne _Check_mem
 bra *

