; example usage: .\t1.exe <filename> <target_word>

.model small
.stack 100h

BUF_SIZE equ 1024
MAX_WORD equ 50
MAX_PATH equ 127

.data
; we use asciiz format (zero-terminated strings)
msg_banner  db 'Finds count of lines which do not contain target word',13,10,0
msg_usage   db 'Correct usage: lab6.exe <file> <word>',13,10
            db '       word: 1..50 chars, delimiters: space/tab/EOL',13,10,0
msg_plong   db 'ERROR: file path is too long.',13,10,0
msg_wlong   db 'ERROR: word is longer than 50 characters.',13,10,0
msg_extra   db 'ERROR: too many parameters.',13,10,0
msg_file    db 'Input file : ',0
msg_word    db 'Search word: ',0
msg_open    db 'Opening file...',13,10,0
msg_openok  db 'File opened. Reading and processing...',13,10,0
msg_close   db 'End of file. Closing file...',13,10,0
msg_closeok db 'File closed.',13,10,0
msg_total   db 'Total lines        : ',0
msg_without db 'Lines WITHOUT word : ',0
msg_with    db 'Lines WITH word    : ',0
msg_done    db 'Done.',13,10,0
msg_eopen   db 'ERROR: open failed, code=',0
msg_eread   db 'ERROR: read failed, code=',0
msg_eclose  db 'ERROR: close failed, code=',0
msg_crlf    db 13,10,0

file_path   db MAX_PATH + 1 dup(0)
target_word db MAX_WORD + 1 dup(0)
word_len    dw 0

handle      dw 0
buffer      db BUF_SIZE dup(?)

cur_word    db MAX_WORD + 1 dup(0)
cur_len     dw 0
line_found  db 0 ; 1 == curr line contains word
line_open   db 0 ; 1 == after end of the line there was chars
prev_cr     db 0 ; 1 == previous char was CR

total_lines   dd 0
lines_without dd 0

.code
start:
    mov ax, @data
    mov ds, ax
    cld

    mov dx, offset msg_banner
    call puts

    ; command line parsing
    call parse_cmd
    jnc args_ok
    jmp quit_err
args_ok:
    push ds
    pop  es ; ES = DS

    mov dx, offset msg_file
    call puts
    mov dx, offset file_path
    call puts
    call newline
    mov dx, offset msg_word
    call puts
    mov dx, offset target_word
    call puts
    call newline

    ; file opening
    mov dx, offset msg_open
    call puts
    mov ax, 3D00h ; 3D=open, 00=read only
    mov dx, offset file_path
    int 21h
    jnc opened
    jmp err_open
opened:
    mov handle, ax
    mov dx, offset msg_openok
    call puts

read_loop:
    mov ah, 3Fh
    mov bx, handle
    mov cx, BUF_SIZE
    mov dx, offset buffer
    int 21h
    jnc read_ok
    jmp err_read
read_ok:
    test ax, ax ; <-> cmp ax, 0
    jnz have_data
    jmp read_done
have_data:
    mov cx, ax
    call process_buffer
    jmp read_loop

read_done:
    cmp line_open, 0
    je  file_close
    call end_line

file_close:
    mov dx, offset msg_close
    call puts
    mov ah, 3Eh
    mov bx, handle
    int 21h
    jnc closed
    jmp err_close
closed:
    mov dx, offset msg_closeok
    call puts

    mov dx, offset msg_total
    call puts
    mov ax, word ptr total_lines
    mov dx, word ptr total_lines + 2
    call print_u32
    call newline

    mov dx, offset msg_without
    call puts
    mov ax, word ptr lines_without
    mov dx, word ptr lines_without + 2
    call print_u32
    call newline

    mov dx, offset msg_with
    call puts
    mov ax, word ptr total_lines
    mov dx, word ptr total_lines + 2
    sub ax, word ptr lines_without
    sbb dx, word ptr lines_without + 2
    call print_u32
    call newline

    mov dx, offset msg_done
    call puts
    mov ax, 4C00h ; exit with code 0
    int 21h

err_open:
    mov bx, ax
    mov dx, offset msg_eopen
    call puts
    mov ax, bx
    call print_hex16
    call newline
    jmp quit_err

err_read:
    mov bx, ax
    mov dx, offset msg_eread
    call puts
    mov ax, bx
    call print_hex16
    call newline
    mov ah, 3Eh ; file close
    mov bx, handle
    int 21h
    jmp quit_err

err_close:
    mov bx, ax
    mov dx, offset msg_eclose
    call puts
    mov ax, bx
    call print_hex16
    call newline
quit_err:
    mov ax, 4C01h ; exit with code 0
    int 21h

; (PSP: ES:0080h — len, ES:0081h — text)

; skip_delims: skip ws/tabs in ES:SI; CX — bytes remainder
skip_delims proc
sd_loop:
    jcxz sd_ret
    mov al, es:[si]
    cmp al, ' '
    je  sd_adv
    cmp al, 9 ; TAB
    jne sd_ret
sd_adv:
    inc si
    dec cx
    jmp sd_loop
sd_ret:
    ret
skip_delims endp

; get_param: parses next parameter -> ASCIZ-buf DS:DI
;  args:  ES:SI — pos, CX — remainder, BX — max len
;  ret: CF = 0: AX = len; CF = 1: AX = 0 — no params, AX = 1 — overflow (> max len)
get_param proc
    call skip_delims
    jcxz gp_none
    cmp byte ptr es:[si], 0Dh ; 0Dh end of cmd
    jne gp_begin
gp_none:
    xor ax, ax
    stc
    ret
gp_begin:
    xor dx, dx ; DX = param len
gp_copy:
    jcxz gp_end
    mov al, es:[si]
    cmp al, ' '
    je  gp_end
    cmp al, 9 ; TAB
    je  gp_end
    cmp al, 0Dh ; cmd end
    je  gp_end
    cmp dx, bx
    jb  gp_store
    mov ax, 1 ; overflow of param
    stc
    ret
gp_store:
    mov [di], al
    inc di
    inc dx
    inc si
    dec cx
    jmp gp_copy
gp_end:
    mov byte ptr [di], 0
    mov ax, dx
    clc
    ret
get_param endp

; parse_cmd: <path> <word>
; CF == 1 error
parse_cmd proc
    xor cx, cx
    mov cl, es:[80h] ; length of command line
    mov si, 81h ; start of the text

    lea di, file_path
    mov bx, MAX_PATH
    call get_param
    jnc got_path
    jmp bad_first
got_path:
    mov di, offset target_word ; param 2 = target word
    mov bx, MAX_WORD
    call get_param
    jnc got_word
    jmp bad_second
got_word:
    mov word_len, ax
    call skip_delims
    jcxz pc_ok ; make sure there's no 3 params
    cmp byte ptr es:[si], 0Dh
    je  pc_ok
    jmp pc_extra
pc_ok:
    clc
    ret

bad_first:
    test ax, ax ; 0 = no param; 1 = len overflow
    jnz first_long
    jmp pc_usage
first_long:
    mov dx, offset msg_plong
    call puts
    jmp pc_usage
bad_second:
    test ax, ax
    jnz second_long
    jmp pc_usage
second_long:
    mov dx, offset msg_wlong
    call puts
    jmp pc_usage
pc_extra:
    mov dx, offset msg_extra
    call puts
pc_usage:
    mov dx, offset msg_usage
    call puts
    stc
    ret
parse_cmd endp

; si = (char*) cur_word
; di = (char*) target_word
end_word proc
    push ax
    mov ax, cur_len
    test ax, ax
    jz ew_done ; no word here
    cmp ax, word_len
    jne ew_reset ; different length
    push cx
    push si
    push di
    mov cx, ax
    mov si, offset cur_word
    mov di, offset target_word
    cld
    repe cmpsb
    pop di
    pop si
    pop cx
    jne ew_reset
    mov line_found, 1
ew_reset:
    mov cur_len, 0
ew_done:
    pop ax
    ret
end_word endp

end_line proc
    call end_word
    add word ptr total_lines, 1
    adc word ptr total_lines + 2, 0
    cmp line_found, 0
    jne el_reset
    add word ptr lines_without, 1
    adc word ptr lines_without + 2, 0
el_reset:
    mov line_found, 0
    mov line_open, 0
    ret
end_line endp

; process_buffer: processes CX bytes from buffer
; end of lines: CR, LF, CRLF
process_buffer proc
    push ax
    push bx
    push cx
    push si
    mov si, offset buffer
    test cx, cx
    jnz pb_next
    jmp pb_ret
pb_next:
    lodsb ; == mov al, ds:[si];
    cmp al, 10
    je  pb_lf
    cmp al, 13
    je  pb_cr
    mov prev_cr, 0
    mov line_open, 1
    cmp al, ' '
    je  pb_delim
    cmp al, 9
    je  pb_delim

    cmp cur_len, MAX_WORD
    ja  pb_cont
    mov bx, cur_len
    mov cur_word[bx], al
    inc cur_len
pb_cont:
    loop pb_next
    jmp pb_ret

pb_lf:
    cmp prev_cr, 0
    je  pb_eol
    mov prev_cr, 0
    jmp pb_cont
pb_cr:
    call end_line
    mov prev_cr, 1
    jmp pb_cont
pb_delim:
    call end_word
    jmp pb_cont
pb_eol:
    call end_line
    jmp pb_cont
pb_ret:
    pop si
    pop cx
    pop bx
    pop ax
    ret
process_buffer endp

; puts: ASCIZ-str DS:DX -> STDOUT (40h, handle 1)
puts proc
    push ax
    push bx
    push cx
    push si
    mov si, dx
    xor cx, cx
puts_len:
    cmp byte ptr [si], 0
    je  puts_wr
    inc si
    inc cx
    jmp puts_len
puts_wr:
    jcxz puts_ret
    mov ah, 40h
    mov bx, 1
    int 21h
puts_ret:
    pop si
    pop cx
    pop bx
    pop ax
    ret
puts endp

newline proc
    push dx
    mov dx, offset msg_crlf
    call puts
    pop dx
    ret
newline endp

; print_u32: DX:AX
print_u32 proc
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, 10
    xor cx, cx
pu_div:
    push ax
    mov ax, dx
    xor dx, dx
    div bx
    mov si, ax
    pop ax
    div bx
    push dx
    inc cx
    mov dx, si
    mov si, ax
    or  si, dx
    jnz pu_div
pu_out:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop pu_out
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_u32 endp

; print_hex16:
print_hex16 proc
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    mov cx, 4
ph_nib:
    rol bx, 1
    rol bx, 1
    rol bx, 1
    rol bx, 1
    mov dl, bl
    and dl, 0Fh
    cmp dl, 9
    jbe ph_dec
    add dl, 7
ph_dec:
    add dl, '0'
    mov ah, 02h
    int 21h
    loop ph_nib
    mov dl, 'h'
    mov ah, 02h
    int 21h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_hex16 endp

end start
