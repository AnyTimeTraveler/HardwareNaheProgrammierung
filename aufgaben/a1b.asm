	org 100h
	cpu 8086

	jmp START

BYTE1	db 32
TEXT1	db 'Hardwarenahes Programmieren'
	times 4 db 0,'1'
WORT1	dw 1,2,3,4,1234
	dd 1234h

START:	mov bx, BYTE1
WDH:	mov al, [bx]
	out 0, al
	inc bx
	jmp WDH

