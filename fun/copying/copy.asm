	org 100h
	cpu 8086

	mov dx, 0
WDH:	in ax, 0
	out dx, ax
	jmp WDH

