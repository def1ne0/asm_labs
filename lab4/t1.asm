; Default:
; ax - accumulator
; bx - base
; cx - counter
; dx - for data
; *********
; Segment:
; cs - code segment
; ds - data segment
; ss - stack segment
; es - extra segment
; Address:
; si - source
; di - dest
; bp - base ptr
; bx


.model small
.stack 100h

.data
    BUF_SIZE       EQU 200

    NEWLINE        db 0Dh, 0Ah, '$'
    S_INPUT_FULL   db "Input full string: $"
    S_INPUT_TARGET db "Input target string: $"
    S_RES          db "Result: $"
    S_ERR          db "[ERR] Target not found or there's no word before it $"
    S_ERR_IO       db "[ERR] io error"
    buf_full       db BUF_SIZE, ?, BUF_SIZE dup(?)
    buf_target     db BUF_SIZE, ?, BUF_SIZE dup(?)

.code
_start:
    mov ax, @data
    mov ds, ax
    mov es, ax
    cld

    mov ah, 09h
    lea dx, S_INPUT_FULL
    int 21h

    mov ah, 0Ah
    lea dx, buf_full
    int 21h

    mov ah, 09h
    lea dx, NEWLINE
    int 21h

    mov ah, 09h
    lea dx, S_INPUT_TARGET
    int 21h

    mov ah, 0Ah
    lea dx, buf_target
    int 21h

    mov ah, 09h
    lea dx, NEWLINE
    int 21h

    xor bx, bx
    mov bl, buf_target[1]
    cmp bx, 0
    jne _c1
    jmp _not_found

_c1:
    ; al = len(buf_full); bl = len(buf_target)
    ; if (al < bl) goto _not_found
    xor ax, ax
    mov al, buf_full[1]
    cmp ax, bx
    jge _c2
    jmp _not_found

_c2:
    ; cx = ax = len(buf_full) + len(buf_target) + 1
    ; si = &buf_full + 2
    sub ax, bx
    inc ax
    mov cx, ax
    lea si, buf_full[2]

_search_loop:
    push si
    push cx



    ; cx = 0
    ; cl = len(buf_target)
    ; di = &buf_target + 2
    xor cx, cx
    mov cl, buf_target[1]
    lea di, buf_target[2]
    repe cmpsb ; while CX != 0 && ZF == 1

    pop cx
    pop si
    je _bounds

_no_match:
    inc si
    loop _search_loop
    jmp _not_found

_bounds:
    cmp si, offset buf_full + 2
    je _bound_right
    cmp byte ptr [si - 1], ' '
    jne _no_match

_bound_right:
    mov ax, si
    xor bx, bx
    mov bl, buf_target[1]
    add ax, bx

    mov bx, offset buf_full + 2
    xor cx, cx
    mov cl, buf_full[1]
    add bx, cx

    cmp ax, bx
    je _match
    mov di, ax
    mov al, [di]
    cmp al, ' '
    je _match
    cmp al, 0Dh
    je _match
    jmp _no_match

_match:
    mov bx, si
    mov di, si
    dec di

_back_spaces:
    cmp di, offset buf_full + 2
    jb _no_prev
    cmp byte ptr [di], ' '
    jne _prev_end
    dec di
    jmp _back_spaces
_prev_end:
    mov si, di
_prev_start:
    cmp si, offset buf_full + 2
    je _have_del
    cmp byte ptr [si - 1], ' '
    je _have_del
    dec si
    jmp _prev_start
_have_del:
    mov dx, bx
    sub dx, si
    cmp dx, 0
    jle _no_prev

    mov di, si
    mov si, bx

    mov ax, offset buf_full + 2
    xor cx, cx
    mov cl, buf_full[1]
    add ax, cx
    sub ax, bx

    cmp ax, 0
    je _upd
    mov cx, ax
    cld
    rep movsb

_upd:
    xor ax, ax
    mov al, buf_full[1]
    sub ax, dx
    mov buf_full[1], al

    mov di, offset buf_full + 2
    add di, ax
    ; mov byte ptr [di], '$'
    jmp _print_result

_no_prev:
_not_found:
    mov ah, 09h
    lea dx, S_ERR
    int 21h
    jmp _exit

_print_result:
    mov ah, 09h
    lea dx, S_RES
    int 21h

    mov ah, 40h
    mov bx, 1
    xor cx, cx
    mov cl, buf_full[1]
    lea dx, buf_full[2]
    int 21h
    jc _io_error

    mov ah, 09h
    lea dx, NEWLINE
    int 21h
    jmp _exit

_io_error:
    mov ah, 09h
    lea dx, S_ERR_IO
    int 21h
    jmp _exit

_exit:
    mov ax, 4C00h
    int 21h
end _start
