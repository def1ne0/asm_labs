.model tiny
.code
org 100h
start:
    mov ah, 09h
    mov dx, offset message;
    int 21h

    mov ah, 02h
    mov dl, 07h
    int 21h

    ret

message db "Hello, world!", 0Dh, 0Ah, '$'

end start
