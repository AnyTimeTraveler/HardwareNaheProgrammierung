	org 100h
	cpu 8086

WDH:  call clear

      mov dl, 7
      call read_word_to_ax_at_dl
    	mov bx, ax
      
      call clear

      mov dl, 7
      call write_word_in_bx_to_dl

      mov dl, 3
      call read_word_to_ax_at_dl
      
      call clear

      add bx, ax
      mov dl, 5
      call write_word_in_bx_to_dl
      
      mov ah, 1
      int 5
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
