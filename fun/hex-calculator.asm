	org 100h
	cpu 8086

WDH:  call clear

      mov dl, 7
      call read_word_to_ax_at_dl
    	mov bx, ax
      
      call read_operation_to_cx
      
      call clear

      mov dl, 7
      call write_word_in_bx_to_dl

      mov dl, 3
      call read_word_to_ax_at_dl
      
      call clear

      call perform_operation

      mov dl, 5
      call write_word_in_bx_to_dl
      
      call get_key
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
      jnz r1
      call return

r1:   cmp al, 08h                 ; Addition
      jnz r2
      mov bx, T_ADD
      call print_string_from_bx

r2:   cmp al, 09h                 ; Subtraction
      jnz r3
      mov bx, T_SUB
      call print_string_from_bx

r3:   cmp al, 0ah                 ; Multiplication
      jnz r4
      mov bx, T_OR
      call print_string_from_bx

r4:   cmp al, 0bh                 ; Division
      jnz r5
      mov bx, T_AND
      call print_string_from_bx

r5:   cmp al, 0ch                 ; XOR
      jnz r_rep
      mov bx, T_XOR
      call print_string_from_bx

      jmp r_rep


return:
      mov cx, bx
      pop ax ; return address
      pop dx
      pop bx
      pop ax
      ret

perform_operation:                ; Expects operants in AX and BX and operation in CX
      cmp cx, T_ADD                ; Addition
      jnz a1
      add bx, ax
      ret

a1:   cmp cx, T_SUB                 ; Subtraction
      jnz a2
      sub bx, ax
      ret

a2:   cmp cx, T_OR                 ; Multiplication
      jnz a3
      or bx, ax
      ret

a3:   cmp cx, T_AND                 ; Division
      jnz a4
      and bx, ax
      ret

a4:   cmp cx, T_XOR                 ; XOR
      jnz end
      xor bx, ax

end:  ret


P_ACT   db  "Action", 0

T_ADD   db  "add", 0
T_SUB   db  "sub", 0
T_OR    db  "or", 0
T_AND   db  "and", 0
T_XOR   db  "xor", 0

