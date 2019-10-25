	org 100h
	cpu 8086

WDH:	in al, 0
	out 0, al
	shl al
	jnc NULL	; check if top bit is set (not carry)

	shr al		; top bit is set
	mov dl, al
	mov al, 255
	jmp FOR

NULL:	shr al		; top bit is unset
	mov dl, al
	mov al, 0
	

FOR:	out dl, al
	jmp WDH

