	org 100h
	cpu 8086

      mov ah, 0
      int 6
WDH:	mov dx, [LED]
    	in al, dx 
    	mov ah, al
    	and al, 15
    	times 4 shr ah, 1
    	add al, ah
    	out dx, al
      mov bl, al
      mov ah, 4
      mov dl, 1
  	  int 6
    	jmp WDH

LED	  dw 0
DISP	dw 90h
      

