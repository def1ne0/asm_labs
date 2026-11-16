.model small
.stack 200h

.data
    NEWLINE           db 0Dh, 0Ah, '$'

    msg_hello         db "Lab 5, variant 8: normalize array by max", 0Dh, 0Ah, '$'
    msg_err_io        db "[ERR] io error", 0Dh, 0Ah, '$'
    msg_err_input     db "[ERR] input error, try again", 0Dh, 0Ah, '$'

    msg_input_arr_len db "Input array len (1..30): $"
    msg_input_arr_el  db "Input element: $"
    msg_max           db "Max element: $"
    msg_input_n       db "Input fraction digits (0..10): $"
    msg_result        db "Result:", 0Dh, 0Ah, '$'
    msg_zero_max      db "[ERR] max = 0, division by zero", 0Dh, 0Ah, '$'

    msg_elem          db "Element $"
    msg_colon         db ": $"
    msg_arrow         db " -> $"

    arr               dw 30 dup(0)
    arr_len           dw 0
    max_val           dw 0
    frac_digits_count dw 0

    tmp_int_part      dw 0
    tmp_sign          db 0
    frac_digits       db 12 dup(0)
    ten               dw 10

    out_buf           db 64 dup(0)

.code

; args:
; dx = (char*)str
; ret:
; CF
; Note: must be null_terminated
fn_print_stdout_null_terminated proc near
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov ah, 09h
    int 21h

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    clc
    ret
fn_print_stdout_null_terminated endp


; args: -
; ret: -
fn_print_newline proc near
    push dx

    lea dx, [NEWLINE]
    call fn_print_stdout_null_terminated

    pop dx
    ret
fn_print_newline endp


; args:
; -
; ret:
; al = (char)symbol
; CF
fn_scanc_stdin proc near
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov ah, 01h
    int 21h

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx

    clc
    ret
fn_scanc_stdin endp


; args: -
; ret: 0
; reads chars until Enter
fn_flush_stdin proc near
    push ax

@@_flush_lp:
    call fn_scanc_stdin

    cmp al, 13
    jne @@_flush_C1
    jmp @@_flush_done

@@_flush_C1:
    jmp @@_flush_lp

@@_flush_done:
    pop ax

    clc
    ret
fn_flush_stdin endp


; args: -
; ret:
; ax = (int16_t)inputed_num
; CF = 0 success
; CF = 1 format error/overflow
fn_read_signed_int proc near
; прост при вводе каждой цифры наше число BX = BX * 10 + новая цифра
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    xor bx, bx ; BX = модуль
    xor cx, cx ; CX = 0: положительное, 1: отрицательное
    xor si, si ; SI = количество введенных цифр
    xor di, di ; DI = 1, если уже был знак

; скипаем пробелы
@@_rsi_skip_ws:
    call fn_scanc_stdin

    cmp al, ' '
    jne @@_rsi_C1
    jmp @@_rsi_skip_ws

; скипаем каретки
@@_rsi_C1:
    cmp al, 13 ; каретка
    jne @@_rsi_C2
    jmp @@_rsi_err_empty

; если попался '-' нужно проверить
@@_rsi_C2:
    cmp al, '-'
    jne @@_rsi_C3
    jmp @@_rsi_sign_neg

; тож самое с '+' попался '-' нужно проверить
@@_rsi_C3:
    cmp al, '+'
    jne @@_rsi_C4
    jmp @@_rsi_sign_pos

; цифра должна быть >= 0
@@_rsi_C4:
    cmp al, '0'
    jae @@_rsi_C5
    jmp @@_rsi_err_fmt_flush

; и <= 9
@@_rsi_C5:
    cmp al, '9'
    jbe @@_rsi_C6
    jmp @@_rsi_err_fmt_flush

; первая цифра без знака
@@_rsi_C6:
    xor ah, ah
    sub al, '0'
    mov bx, ax
    inc si
    jmp @@_rsi_read_digits

; уже есть минус - некорректный ввод
@@_rsi_sign_neg:
    cmp di, 1
    jne @@_rsi_C7
    jmp @@_rsi_err_fmt_flush

; в противном случае все норм и CX = 1
@@_rsi_C7:
    mov cx, 1
    mov di, 1
    jmp @@_rsi_after_sign

; если он ввел '-+' - некорректно
@@_rsi_sign_pos:
    cmp di, 1
    jne @@_rsi_C8
    jmp @@_rsi_err_fmt_flush

@@_rsi_C8:
    mov di, 1

; читаем дальше циферки после знака
@@_rsi_after_sign:
    call fn_scanc_stdin

    cmp al, 13
    jne @@_rsi_C9
    jmp @@_rsi_err_empty

; опять проверка диапазонов
@@_rsi_C9:
    cmp al, '0'
    jae @@_rsi_C10
    jmp @@_rsi_err_fmt_flush

@@_rsi_C10:
    cmp al, '9'
    jbe @@_rsi_C11
    jmp @@_rsi_err_fmt_flush

; записывает первую цифру (не аски код) в bx
@@_rsi_C11:
    xor ah, ah
    sub al, '0'
    mov bx, ax
    inc si

; дальше тож самое с тем же проверками
; ток надо домножать BX на 10
@@_rsi_read_digits:
    call fn_scanc_stdin

    cmp al, 13
    jne @@_rsi_C12
    jmp @@_rsi_finish_num

@@_rsi_C12:
    cmp al, '0'
    jae @@_rsi_C13
    jmp @@_rsi_bad_char

@@_rsi_C13:
    cmp al, '9'
    jbe @@_rsi_C14
    jmp @@_rsi_bad_char

@@_rsi_C14:
    xor ah, ah
    sub al, '0'
    mov dx, ax ; DX = очередная цифра

    ; текущий модуль не должен быть > 3276
    ; так как рабочий диапазон [-32768; 32767]
    ; при умножении на 10 и добавлении цифры можно словить переполнение
    cmp bx, 0CCCh
    jbe @@_rsi_C15
    jmp @@_rsi_err_ovf

; BX = BX * 10 + DX
@@_rsi_C15:
    ; AX = BX
    ; BX = AX
    mov ax, bx
    mov bx, ax

    ; BX * 10 + DX = (BX * 5) * 2
    shl ax, 1 ; *2
    shl ax, 1 ; *4
    add ax, bx ; *5, AX = 5 * AX
    shl ax, 1 ; *10; AX = 10 * AX
    add ax, dx ; + DX

    ; аккуратно посмотреть по знаку чтоб не было переполнение
    ; из-за несимметричных границ [-32768; 32767]
    cmp cx, 1
    jne @@_rsi_C16
    jmp @@_rsi_neg_lim

; по модулю 32767 и положительно
; чекакем чтоб было <= 32767
@@_rsi_C16:
    cmp ax, 7FFFh
    jbe @@_rsi_C17
    jmp @@_rsi_err_ovf

@@_rsi_C17:
    jmp @@_rsi_store_digit

; по модулю 32768 и отрциательно
; чекакем чтоб было <= 32768
@@_rsi_neg_lim:
    cmp ax, 8000h       ; 32768
    jbe @@_rsi_C18
    jmp @@_rsi_err_ovf

@@_rsi_C18:

; сохраняем все в BX и дальше читаем
@@_rsi_store_digit:
    mov bx, ax
    inc si
    jmp @@_rsi_read_digits

@@_rsi_bad_char:
    call fn_flush_stdin
    jmp @@_rsi_err_format

; проверяем чтоб хотя б цифра была введена
@@_rsi_finish_num:
    cmp si, 0
    jne @@_rsi_C19
    jmp @@_rsi_err_empty

; в соотвествении со знаком выставляем доп код
@@_rsi_C19:
    cmp cx, 1
    jne @@_rsi_C20
    jmp @@_rsi_make_neg_path

; сохраняем в AX, очищаем CF и идем к хенделру конца
@@_rsi_C20:
    mov ax, bx
    clc
    jmp @@_rsi_done

; если число отрциательно но при этом по модулю ровно 327682
@@_rsi_make_neg_path:
    cmp bx, 8000h
    jne @@_rsi_C21
    jmp @@_rsi_special_neg

; дефолт neg
@@_rsi_C21:
    mov ax, bx
    neg ax
    clc
    jmp @@_rsi_done

; ничего тут делать не надо
@@_rsi_special_neg:
    mov ax, 8000h
    clc
    jmp @@_rsi_done

; ошибки - CF = 1
@@_rsi_err_empty:
    stc
    jmp @@_rsi_done

@@_rsi_err_fmt_flush:
    call fn_flush_stdin

@@_rsi_err_format:
    stc
    jmp @@_rsi_done

@@_rsi_err_ovf:
    call fn_flush_stdin
    stc

@@_rsi_done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx

    ret
fn_read_signed_int endp


; args:
; ax = uint16_t
; di = buffer
; ret:
; di указывает за последней цифрой
fn_utoa proc near
    push ax
    push bx
    push cx
    push dx

    xor cx, cx
    mov bx, 10

@@_utoa_div:
    xor dx, dx
    div bx
    push dx
    inc cx

    cmp ax, 0
    je @@_utoa_C1
    jmp @@_utoa_div

@@_utoa_C1:

@@_utoa_pop:
    pop dx
    add dl, '0'
    mov [di], dl
    inc di

    dec cx
    jnz @@_utoa_C2
    jmp @@_utoa_done

@@_utoa_C2:
    jmp @@_utoa_pop

@@_utoa_done:
    pop dx
    pop cx
    pop bx
    pop ax

    ret
fn_utoa endp


; args:
; ax = int16_t
; di = buffer
; ret:
; di указывает за последней цифрой
fn_write_signed proc near
    push ax
    push bx
    push cx
    push dx

    cmp ax, 0
    jns @@_ws_C1
    jmp @@_ws_neg

@@_ws_C1:
    jmp @@_ws_pos

@@_ws_neg:
    mov byte ptr [di], '-'
    inc di
    neg ax

@@_ws_pos:
    call fn_utoa

    pop dx
    pop cx
    pop bx
    pop ax

    ret
fn_write_signed endp


; args:
; ax = числитель, int16_t
; bx = знаменатель, int16_t, не 0
; cx = N, количество знаков дробной части
; di = buffer
; ret:
; строка в buffer, завершается '$'
fn_format_division proc near
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov [frac_digits_count], cx

    ; если числитель равен 0, результат 0.
    cmp ax, 0
    je @@_fd_C1
    jmp @@_fd_not_zero

@@_fd_C1:
    mov byte ptr [di], '0'
    inc di

    cmp word ptr [frac_digits_count], 0
    je @@_fd_C2
    jmp @@_fd_zero_frac

@@_fd_C2:
    jmp @@_fd_zero_end

@@_fd_zero_frac:
    mov byte ptr [di], '.'
    inc di

    mov cx, [frac_digits_count]

@@_fd_zero_loop:
    mov byte ptr [di], '0'
    inc di


    dec cx
    jnz @@_fd_C3
    jmp @@_fd_zero_end

@@_fd_C3:
    jmp @@_fd_zero_loop

@@_fd_zero_end:
    mov byte ptr [di], '$'
    jmp @@_fd_exit

@@_fd_not_zero:
    ; чекаем знаки
    mov dx, ax
    xor dx, bx

    mov byte ptr [tmp_sign], 0

    test dx, 8000h
    jz @@_fd_C4
    jmp @@_fd_sign_neg

@@_fd_C4:
    jmp @@_fd_sign_done

@@_fd_sign_neg:
    mov byte ptr [tmp_sign], 1

@@_fd_sign_done:
    cmp ax, 0
    jns @@_fd_C5
    jmp @@_fd_num_neg

@@_fd_C5:
    jmp @@_fd_num_abs

@@_fd_num_neg:
    neg ax

@@_fd_num_abs:
    cmp bx, 0
    jns @@_fd_C6
    jmp @@_fd_den_neg

@@_fd_C6:
    jmp @@_fd_den_abs

@@_fd_den_neg:
    neg bx

@@_fd_den_abs:
    ; целая часть: |AX| / |BX|.
    xor dx, dx
    div bx
    mov [tmp_int_part], ax

    ; вычислить N+1 цифр дробной части для округления.
    mov cx, [frac_digits_count]
    inc cx
    xor si, si

@@_fd_frac_loop:
    mov ax, dx          ; AX = текущий остаток
    xor dx, dx

    mul word ptr [ten]  ; DX:AX = AX * 10
    div bx              ; AX = очередная цифра 0..9, DX = новый остаток

    mov frac_digits[si], al
    inc si

    dec cx
    jnz @@_fd_C7
    jmp @@_fd_frac_done

@@_fd_C7:
    jmp @@_fd_frac_loop

@@_fd_frac_done:
    ; чекаем последнюю вычисленную цифру, индекс N
    mov si, [frac_digits_count]

    cmp byte ptr frac_digits[si], 5
    jae @@_fd_C8
    jmp @@_fd_no_round

@@_fd_C8:
    cmp word ptr [frac_digits_count], 0
    je @@_fd_C9
    jmp @@_fd_round_frac

@@_fd_C9:
    jmp @@_fd_round_int

@@_fd_round_frac:
    dec si

@@_fd_round_loop:
    inc byte ptr frac_digits[si]

    cmp byte ptr frac_digits[si], 10
    jb @@_fd_C10
    jmp @@_fd_round_carry_digit

@@_fd_C10:
    jmp @@_fd_no_carry

@@_fd_round_carry_digit:
    mov byte ptr frac_digits[si], 0

    dec si
    js @@_fd_C11
    jmp @@_fd_round_loop

@@_fd_C11:
    jmp @@_fd_round_carry_int

@@_fd_round_carry_int:
    inc word ptr [tmp_int_part]
    jmp @@_fd_no_round

@@_fd_round_int:
    inc word ptr [tmp_int_part]

@@_fd_no_carry:
@@_fd_no_round:
    ; если после округления результат равен 0, знак не выводим.
    cmp word ptr [tmp_int_part], 0
    je @@_fd_C12
    jmp @@_fd_do_sign

@@_fd_C12:
    mov cx, [frac_digits_count]

    or cx, cx
    jnz @@_fd_C13
    jmp @@_fd_is_zero

@@_fd_C13:
    xor si, si

@@_fd_check_zero:
    cmp byte ptr frac_digits[si], 0
    je @@_fd_C14
    jmp @@_fd_do_sign

@@_fd_C14:
    inc si

    dec cx
    jnz @@_fd_C15
    jmp @@_fd_is_zero

@@_fd_C15:
    jmp @@_fd_check_zero

@@_fd_is_zero:
    jmp @@_fd_write_int

@@_fd_do_sign:
    cmp byte ptr [tmp_sign], 1
    je @@_fd_C16
    jmp @@_fd_write_int

@@_fd_C16:
    mov byte ptr [di], '-'
    inc di

@@_fd_write_int:
    mov ax, [tmp_int_part]
    call fn_utoa

    cmp word ptr [frac_digits_count], 0
    je @@_fd_C17
    jmp @@_fd_write_frac

@@_fd_C17:
    jmp @@_fd_end_str

@@_fd_write_frac:
    mov byte ptr [di], '.'
    inc di

    xor si, si
    mov cx, [frac_digits_count]

@@_fd_frac_out:
    mov al, frac_digits[si]
    add al, '0'
    mov [di], al

    inc di
    inc si

    dec cx
    jnz @@_fd_C18
    jmp @@_fd_end_str

@@_fd_C18:
    jmp @@_fd_frac_out

@@_fd_end_str:
    mov byte ptr [di], '$'

@@_fd_exit:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret
fn_format_division endp

_start:
    mov ax, @data
    mov ds, ax

    lea dx, [msg_hello]
    call fn_print_stdout_null_terminated
    jnc @@_main_C1
    jmp _io_error

@@_main_C1:

@@_main_input_len:
    lea dx, [msg_input_arr_len]
    call fn_print_stdout_null_terminated
    jnc @@_main_C2
    jmp _io_error

@@_main_C2:
    call fn_read_signed_int
    jnc @@_main_C3
    jmp @@_main_len_bad

@@_main_C3:
    cmp ax, 1
    jge @@_main_C4
    jmp @@_main_len_bad

@@_main_C4:
    cmp ax, 30
    jle @@_main_C5
    jmp @@_main_len_bad

@@_main_C5:
    mov [arr_len], ax

    mov cx, [arr_len]
    xor si, si
    jmp @@_main_input_elem

@@_main_len_bad:
    lea dx, [msg_err_input]
    call fn_print_stdout_null_terminated
    jnc @@_main_C6
    jmp _io_error

@@_main_C6:
    jmp @@_main_input_len

@@_main_input_elem:
    lea dx, [msg_input_arr_el]
    call fn_print_stdout_null_terminated
    jnc @@_main_C7
    jmp _io_error

@@_main_C7:
    call fn_read_signed_int
    jnc @@_main_C8
    jmp @@_main_elem_bad

@@_main_C8:
    mov arr[si], ax
    add si, 2

    dec cx
    jnz @@_main_C9
    jmp @@_main_find_max

@@_main_C9:
    jmp @@_main_input_elem

@@_main_elem_bad:
    lea dx, [msg_err_input]
    call fn_print_stdout_null_terminated
    jnc @@_main_C10
    jmp _io_error

@@_main_C10:
    jmp @@_main_input_elem

@@_main_find_max:
    mov cx, [arr_len]
    xor si, si

    mov ax, arr[si]
    add si, 2

    dec cx
    jnz @@_main_C11
    jmp @@_main_max_done

@@_main_C11:
    jmp @@_main_max_loop

@@_main_max_loop:
    cmp ax, arr[si]
    jge @@_main_C12
    jmp @@_main_max_update

@@_main_C12:
    jmp @@_main_max_next

@@_main_max_update:
    mov ax, arr[si]

@@_main_max_next:
    add si, 2

    dec cx
    jnz @@_main_C13
    jmp @@_main_max_done

@@_main_C13:
    jmp @@_main_max_loop

@@_main_max_done:
    mov [max_val], ax

    lea dx, [msg_max]
    call fn_print_stdout_null_terminated
    jnc @@_main_C14
    jmp _io_error

@@_main_C14:
    mov ax, [max_val]
    lea di, [out_buf]

    call fn_write_signed
    mov byte ptr [di], '$'

    lea dx, [out_buf]
    call fn_print_stdout_null_terminated
    jnc @@_main_C15
    jmp _io_error

@@_main_C15:
    call fn_print_newline

    cmp word ptr [max_val], 0
    je @@_main_C16
    jmp @@_main_max_not_zero

@@_main_C16:
    lea dx, [msg_zero_max]
    call fn_print_stdout_null_terminated
    jnc @@_main_C17
    jmp _io_error

@@_main_C17:
    jmp _exit

@@_main_max_not_zero:

@@_main_input_n:
    lea dx, [msg_input_n]
    call fn_print_stdout_null_terminated
    jnc @@_main_C18
    jmp _io_error

@@_main_C18:
    call fn_read_signed_int
    jnc @@_main_C19
    jmp @@_main_n_bad

@@_main_C19:
    cmp ax, 0
    jge @@_main_C20
    jmp @@_main_n_bad

@@_main_C20:
    cmp ax, 10
    jle @@_main_C21
    jmp @@_main_n_bad

@@_main_C21:
    mov [frac_digits_count], ax
    jmp @@_main_n_ok

@@_main_n_bad:
    lea dx, [msg_err_input]
    call fn_print_stdout_null_terminated
    jnc @@_main_C22
    jmp _io_error

@@_main_C22:
    jmp @@_main_input_n

@@_main_n_ok:

    lea dx, [msg_result]
    call fn_print_stdout_null_terminated
    jnc @@_main_C23
    jmp _io_error

@@_main_C23:
    mov cx, [arr_len]
    xor si, si

@@_main_result_loop:
    ; Номер элемента: arr_len - cx + 1
    mov ax, [arr_len]
    sub ax, cx
    inc ax

    lea di, [out_buf]
    call fn_utoa
    mov byte ptr [di], '$'

    lea dx, [msg_elem]
    call fn_print_stdout_null_terminated
    jnc @@_main_C24
    jmp _io_error

@@_main_C24:
    lea dx, [out_buf]
    call fn_print_stdout_null_terminated
    jnc @@_main_C25
    jmp _io_error

@@_main_C25:
    lea dx, [msg_colon]
    call fn_print_stdout_null_terminated
    jnc @@_main_C26
    jmp _io_error

@@_main_C26:
    ; исходное значение
    mov ax, arr[si]
    lea di, [out_buf]

    call fn_write_signed
    mov byte ptr [di], '$'

    lea dx, [out_buf]
    call fn_print_stdout_null_terminated
    jnc @@_main_C27
    jmp _io_error

@@_main_C27:
    lea dx, [msg_arrow]
    call fn_print_stdout_null_terminated
    jnc @@_main_C28
    jmp _io_error

@@_main_C28:
    ; нормализованное значение
    push cx

    mov ax, arr[si]
    mov bx, [max_val]
    mov cx, [frac_digits_count]
    lea di, [out_buf]

    call fn_format_division

    pop cx

    lea dx, [out_buf]
    call fn_print_stdout_null_terminated
    jnc @@_main_C29
    jmp _io_error

@@_main_C29:
    call fn_print_newline

    add si, 2

    dec cx
    jnz @@_main_C30
    jmp _exit

@@_main_C30:
    jmp @@_main_result_loop

_io_error:
    lea dx, [msg_err_io]
    call fn_print_stdout_null_terminated

_exit:
    mov ax, 4C00h
    int 21h

end _start
