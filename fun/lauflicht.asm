	org 100h
	cpu 8086

start:	mov cx, 8
	mov dx, 9eh
	mov si, text
start1:	mov bx, si
start2:	mov al, [bx]
	out dx, al
	sub dx, 2
	inc bx
	loop start2
	mov cx, 0d000h
	loop $
	mov cx, 8
	mov dx, 9eh
	inc si
	cmp si, text1
	jne start1
	jmp start

text:	db 01101101b, 01111100b, 01011000b, 01000000b, 01111111b,
	db 01111101b, 0, 0
text1:	db 01101101b, 01111100b, 01011000b, 01000000b, 01111111b,
	db 01111101b, 0, 0

