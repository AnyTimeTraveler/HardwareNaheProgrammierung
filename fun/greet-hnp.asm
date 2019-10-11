	org 100h
	cpu 8086

	mov dx, 144
	mov bx, Mine
WDH:	mov ax, [bx] 
	out dx, ax
	mov cx, 60000
SPLARG:	nop
	nop
	nop
	loop SPLARG
	inc dx
	inc bx
	jmp WDH


Mine	dw	115,84,118,63,56,56,121,118


