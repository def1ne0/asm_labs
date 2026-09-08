; 55350120 % 14 == 8 
; 8 variant
; example: 00001111_11110000 -> 11110000_00001111 

kValue equ %0000111111110000

 org $8000
 clra
 clrb
 ; for example, load something (constant kValue) into X
 ldx #kValue
 ; we need to load the first byte in A, the second in B,
 ; then push B firstly, and then push A
 ; finally, pop X
 pshx ; stack: 0...<SP>[00001111][11110000]... stack grow down
 pula ; A = 00001111, stack: 0...<SP>11110000...
 pulb ; B = 11110000, stack: 0...<SP>...
 psha ; stack: 0...<SP>00001111...
 pshb ; stack: 0...<SP>[11110000][00001111]...
 pulx ; X = 1111000000001111
 bra *
