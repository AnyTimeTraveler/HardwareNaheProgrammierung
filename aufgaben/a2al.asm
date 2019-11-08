cpu 8086
org 100h

	;ADDRESS dd 90h, 92h, 94h, 96h, 98h, 9ah, 9ch, 9eh

START:	call CLEAR
	in al,0
	mov ah, al	
	times 4 shr al,1 ;== shr al,1 shr al,1 shr al,1 shr al,1
	AND ah, 00001111b
	ADD al, ah
	
	cmp al, 10h
	JL LOWERBITS
	
	
LOWERBITS:
	push ax
	AND al, 00001111b
	mov bx, CHARS
	xlat
	mov dx, 90h
	out dx, al
	
	jmp START


CLEAR:
	mov cx, 10h
	mov al, 0
GOHERE:	mov dx, cx
	add dx, 90h
	out dx, al
	dec cx	
	loop GOHERE
	ret

CHARS   db 63, 6, 91, 79, 102, 109, 125, 7, 127, 111, 119, 124, 57, 94, 121, 113
