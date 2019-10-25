	org 100h
	cpu 8086

WDH:	in al, 0
	out 0, al
	shl al, 1
	jnc NULL	; check if top bit is set (not carry)

	shr al, 1	; top bit is set
	mov dl, al
	mov al, 255
	jmp FOR

NULL:	shr al, 1	; top bit is unset
	mov dl, al
	mov al, 0
	

FOR:	out dx, al
	jmp WDH

