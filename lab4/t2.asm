.model small
.stack 100h

.data
    SZ      EQU 64

    msg     db "Hello World!$"
    NEWLINE db 0Ah, 0Dh, '$'
    buf     db SZ, ?, SZ dup(?)
    char    db ?, 0Ah, 0Dh ; len = 1

.code
_start:
    mov ax, @data
    mov ds, ax
    mov es, ax
    std

    lea si, [msg + 13]
    lea di, [buf + 15]
    mov cx, 13
    rep movsb

    mov ah, 09h
    lea dx, [buf + 2]
    int 21h
_exit:
    mov ax, 4C00h
    int 21h
end _start
