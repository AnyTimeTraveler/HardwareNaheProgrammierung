  org 100h
  cpu 8086

WDH:  call clear

      mov dl, 7
      call read_word_to_ax_at_dl    ; read first operand into bx
      mov bx, ax

      call read_operation_to_cx     ; read operation into cx

      call clear                    ; clear screen

      mov dl, 7
      call write_word_in_bx_to_dl   ; display first operand on the left part

      mov dl, 3
      call read_word_to_ax_at_dl    ; read second operant on the right part into ax
      mov dx, ax

      call clear                    ; clear screen again

      mov ax, A_ACTS
      add al, cl
      call ax                       ; perform calculation

      mov dl, 5
      call write_word_in_bx_to_dl   ; display output at the center of the screen

      call get_key                  ; wait for user to push a key to restart
      jmp WDH

read_word_to_ax_at_dl:
      push bx
      mov ah, 2
      mov bx, 0
      int 5
      pop bx
      ret

write_word_in_bx_to_dl:
      push ax
      mov ah, 3
      int 6
      pop ax
      ret

clear:
      push ax
      mov ah, 0
      int 6
      pop ax
      ret

get_key:
      mov ah, 1
      int 5
      ret

print_string_from_bx:
      push ax
      mov ah, 2
      int 6
      pop ax
      ret

read_operation_to_cx:
      push ax
      push bx
      push dx

      call clear

      mov bx, P_ACT
      mov dl, 7
      call print_string_from_bx

r_rep:call get_key

      call clear
      mov dl, 5

      cmp al, 10h
      jz exit

      sub al, 08h

      mov bx, S_OPTS
      add bl, al
      call print_string_from_bx
      jmp r_rep

exit: sub al, 08h
      mov cx, ax
      pop dx
      pop bx
      pop ax
      ret

a_add:add bx, ax
      ret

a_sub:sub bx, ax
      ret

a_or: or bx, ax
      ret

a_and:and bx, ax
      ret

a_xor:xor bx, ax
      ret

A_ACTS  dw  a_add, a_sub, a_or, a_and, a_xor
S_OPTS  dw  T_ADD, T_SUB, T_OR, T_AND, T_XOR

P_ACT   db  "Action", 0

T_ADD   db  "add", 0
T_SUB   db  "sub", 0
T_OR    db  "or", 0
T_AND   db  "and", 0
T_XOR   db  "xor", 0

