	org 100h
	cpu 8086


WDH:	mov ax, 255
	out dx, al
	mov cx, 10000
SPLARG:	nop
	loop SPLARG
	mov ax, dx
	out 0, al
	inc dx
HOLD:	in al, 0
	and al, 1
	jnz HOLD
	jmp WDH

