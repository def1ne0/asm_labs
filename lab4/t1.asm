.model small
.stack 100h

.data
    BUF_SIZE EQU 200
    NEWLINE        db 0Ah, 0Dh, '$'

    S_INPUT_FULL   db "Input full string: $"
    S_INPUT_TARGET db "Input target string: $"
    S_RES          db "Result: $"
    S_ERR          db "[ERR] Target not found or there's no word before it $"

    buf_full       db BUF_SIZE, 0, BUF_SIZE dup(' ')
    buf_target     db BUF_SIZE, 0, BUF_SIZE dup(' ')

.code
_start:
    mov ax, @data
    mov ds, ax
    mov es, ax              ; ВАЖНО: ES должен быть равен DS для строковых операций

    ; --- Ввод исходной строки ---
    mov ah, 09h
    lea dx, S_INPUT_FULL
    int 21h

    mov ah, 0Ah
    lea dx, buf_full
    int 21h

    mov bl, buf_full[1]
    mov bh, 0
    mov byte ptr [buf_full + 2 + bx], '$'

    mov ah, 09h
    lea dx, NEWLINE
    int 21h

    ; --- Ввод искомого слова ---
    mov ah, 09h
    lea dx, S_INPUT_TARGET
    int 21h

    mov ah, 0Ah
    lea dx, buf_target
    int 21h

    mov bl, buf_target[1]
    mov bh, 0
    mov byte ptr [buf_target + 2 + bx], '$'

    mov ah, 09h
    lea dx, NEWLINE
    int 21h

    ; --- Проверка на пустоту ---
    mov bl, buf_target[1]
    cmp bl, 0
    je _not_found

    mov bh, buf_full[1]
    cmp bh, bl
    jl _not_found

    ; --- Цикл поиска ---
    mov cl, bh
    mov ch, 0               ; Замена movzx cx, bh
    sub cl, bl
    inc cx
    mov si, 2

_search_loop:
    push si
    push cx
    mov cx, bx
    mov di, offset buf_target + 2  ; ВАЖНО: Указываем DI, с чем сравнивать
    repe cmpsb
    pop cx
    pop si
    je _check_boundaries

_no_match:
    inc si
    loop _search_loop
    jmp _not_found

_check_boundaries:
    ; Проверка левой границы
    cmp si, 2
    je _check_right_boundary
    mov al, [si - 1]
    cmp al, ' '
    jne _no_match

_check_right_boundary:
    ; Проверка правой границы
    mov ax, si
    add ax, bx              ; ИСПРАВЛЕНО: было 'mov ax, bx', что затирало si
    mov dx, offset buf_full + 2
    mov bl, buf_full[1]
    mov bh, 0
    add dx, bx
    cmp ax, dx
    je _match_confirmed

    mov al, [si + bx]
    cmp al, ' '
    je _match_confirmed
    cmp al, 13
    je _match_confirmed
    cmp al, 10
    je _match_confirmed
    jmp _no_match

_match_confirmed:
    push bx                 ; СОХРАНЯЕМ длину искомого слова, т.к. BX будет испорчен ниже

    mov bp, si
    sub bp, offset buf_full + 2
    dec bp

_skip_spaces_back:
    cmp bp, 0
    jl _no_prev_word_pop
    mov al, buf_full[bp + 2]
    cmp al, ' '
    je _is_space_prev
    jmp _found_end_prev

_is_space_prev:
    dec bp
    jmp _skip_spaces_back

_found_end_prev:
    mov dx, bp

_find_start_prev:
    cmp dx, 0
    jl _start_found_prev
    mov bx, dx              ; Здесь BX перезаписывается, поэтому мы сохранили его в стек выше
    mov al, buf_full[bx + 2]
    cmp al, ' '
    je _start_found_prev
    dec dx
    jmp _find_start_prev

_start_found_prev:
    mov ax, si
    sub ax, offset buf_full + 2
    mov cx, ax
    sub cx, dx
    dec cx                  ; CX = длина удаляемого фрагмента

    cmp cx, 0
    jle _no_prev_word_pop

    pop bx                  ; ВОССТАНАВЛИВАЕМ длину искомого слова

    ; Настраиваем SI (источник) и DI (приемник) для сдвига
    mov si, offset buf_full + 2
    add si, ax
    add si, bx

    mov di, offset buf_full + 2
    add di, dx
    inc di

    ; Считаем длину "хвоста", который нужно сдвинуть
    mov dl, buf_full[1]
    mov dh, 0
    sub dx, ax
    sub dx, bx              ; DX = длина хвоста

    cmp dx, 0
    jle _do_update_length

    push cx                 ; Сохраняем длину удаляемого фрагмента
    mov cx, dx              ; CX = длина хвоста для rep movsb
    cld
    rep movsb
    pop cx                  ; Восстанавливаем длину удаляемого фрагмента

_do_update_length:
    ; Обновляем фактическую длину строки
    mov bl, buf_full[1]
    mov bh, 0
    sub bx, cx
    mov buf_full[1], bl

    ; Ставим '$' в новый конец строки
    mov di, offset buf_full + 2
    add di, bx
    mov byte ptr [di], '$'

    jmp _print_result

_no_prev_word_pop:
    pop bx                  ; Балансируем стек, если перешли по ошибке
_no_prev_word:
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
