	org 100h
	cpu 8086

	mov ax, 8
	mov bx, 20
	add ax, bx
	nop
	mov ax, 8
	mov bx, 20
	sub ax, bx
	nop
	mov ax, -8
	mov bx, 13
	and ax, bx
	nop
	mov ax, -8
	mov bx, 13
	or ax, bx
	nop
	mov ax, -1
	mov bx, -1
	add ax, bx
	nop
	mov ax, -1
	mov bx, -1
	xor ax, bx

