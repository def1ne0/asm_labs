.model small
.stack 100h

.data
    BUF_SIZE EQU 200
    NEWLINE        db 0Dh, 0Ah, '$'
    S_INPUT_FULL   db "Input full string: $"
    S_INPUT_TARGET db "Input target string: $"
    S_RES          db "Result: $"
    S_ERR          db "[ERR] Target not found or there's no word before it $"
    buf_full       db BUF_SIZE, 0, BUF_SIZE dup(' ')
    buf_target     db BUF_SIZE, 0, BUF_SIZE dup(' ')
    full_len       dw 0
    tgt_len        dw 0

.code
_start:
    mov ax, @data
    mov ds, ax
    mov es, ax
    cld

    ; --- ввод исходной строки ---
    mov ah, 09h
    lea dx, S_INPUT_FULL
    int 21h
    mov ah, 0Ah
    lea dx, buf_full
    int 21h
    xor bx, bx
    mov bl, buf_full[1]
    mov full_len, bx
    mov ah, 09h
    lea dx, NEWLINE
    int 21h

    ; --- ввод искомого слова ---
    mov ah, 09h
    lea dx, S_INPUT_TARGET
    int 21h
    mov ah, 0Ah
    lea dx, buf_target
    int 21h
    xor bx, bx
    mov bl, buf_target[1]
    mov tgt_len, bx
    mov ah, 09h
    lea dx, NEWLINE
    int 21h

    ; --- проверки ---
    mov bx, tgt_len
    cmp bx, 0
    jne _c1
    jmp _not_found
_c1:
    mov ax, full_len
    cmp ax, bx
    jge _c2
    jmp _not_found
_c2:
    sub ax, bx
    inc ax                  ; AX = число стартовых позиций
    mov cx, ax              ; внешний счётчик
    mov si, offset buf_full + 2     ; ТОЛЬКО абсолютный адрес

_search_loop:
    push si
    push cx
    mov cx, tgt_len
    mov di, offset buf_target + 2
    repe cmpsb
    pop cx
    pop si
    je _bounds
_no_match:
    inc si
    loop _search_loop
    jmp _not_found

_bounds:                    ; SI = адрес найденного вхождения
    cmp si, offset buf_full + 2
    je _bound_right
    cmp byte ptr [si - 1], ' '
    jne _no_match
_bound_right:
    mov ax, si
    add ax, tgt_len                 ; адрес сразу после слова
    mov bx, offset buf_full + 2
    add bx, full_len                ; адрес CR = конец строки
    cmp ax, bx
    je _match
    mov di, ax
    mov al, [di]
    cmp al, ' '
    je _match
    cmp al, 0Dh
    je _match
    jmp _no_match

_match:                     ; BX = адрес искомого слова (храним!)
    mov bx, si
    mov di, si
    dec di                          ; символ перед словом
_back_spaces:
    cmp di, offset buf_full + 2
    jb _no_prev                     ; слово первое в строке
    cmp byte ptr [di], ' '
    jne _prev_end
    dec di
    jmp _back_spaces
_prev_end:                  ; DI = последний символ пред. слова
    mov si, di
_prev_start:
    cmp si, offset buf_full + 2
    je _have_del                    ; пред. слово с начала буфера
    cmp byte ptr [si - 1], ' '
    je _have_del
    dec si
    jmp _prev_start
_have_del:                  ; SI = начало удаляемого, BX = начало искомого
    mov dx, bx
    sub dx, si                      ; DX = длина удаляемого (>=1)
    cmp dx, 0
    jle _no_prev
    mov di, si                      ; приёмник
    mov si, bx                      ; источник = начало искомого слова
    mov ax, offset buf_full + 2
    add ax, full_len
    sub ax, bx                      ; AX = длина хвоста
    cmp ax, 0
    je _upd
    mov cx, ax
    rep movsb
_upd:
    mov ax, full_len
    sub ax, dx                      ; новая длина
    mov full_len, ax
    mov byte ptr buf_full[1], al
    mov di, offset buf_full + 2
    add di, ax
    mov byte ptr [di], '$'          ; терминатор для вывода
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
    mov ah, 09h
    lea dx, NEWLINE
    int 21h
    mov ah, 09h
    lea dx, buf_full + 2
    int 21h

_exit:
    mov ax, 4C00h
    int 21h
end _start
