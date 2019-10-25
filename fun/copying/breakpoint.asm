	org 100h
	cpu 8086

	mov cx, 0ffffh
SPLARG:	nop
	loop SPLARG
	int 5
