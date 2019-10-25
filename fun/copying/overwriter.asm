	org 100h
	cpu 8086

	mov bx, 0120h
	mov ax, 0
START:	mov [bx], ax
	inc bx
	test bx, 0ffffh
	jnz START
	mov al, 255
	out 0, al
DONE:	jmp DONE

