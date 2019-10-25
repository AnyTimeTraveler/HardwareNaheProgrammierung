	org 100h
	cpu 8086

	jmp WDH

LED	dw 0
DISP	dw 90h

CHARS	db 0, 6, 91, 69, 102, 109, 125, 7, 127, 111, 119, 124, 57, 94, 121, 113

WDH:	mov dx, [LED]
	in al, dx 
	mov ah, al
	and al, 15
	times 4 shr ah, 1
	add al, ah
	out dx, al
	mov bx, CHARS
	xlat
	mov dx, [DISP]
	out dx, al
	jmp WDH

