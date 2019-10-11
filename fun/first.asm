	org 100h
	cpu 8086
START:	mov al, 8
	mov bl, 20
	add al, bl
	jmp START

