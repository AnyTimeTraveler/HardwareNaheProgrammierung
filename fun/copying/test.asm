	org 100h
	cpu 8086

	mov al, 00010000b ; reset
	out 0, al

	mov al, 00011011b
	out 0, al
	mov al, 00010000b
	out 0, al

	mov al, 00011010b
	out 0, al
	mov al, 00010000b
	out 0, al

	mov al, 00011001b
	out 0, al
	mov al, 00010000b
	out 0, al

	mov al, 00011000b
	out 0, al
	mov al, 00010000b
	out 0, al

	nop
	nop

	mov cl, 0



start:	mov al, 6		; send procedure
	shr al, cl
	and al, 00000011b
	or al, 4		; set clock pin
	out 0, al		; send bottom nibble
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	mov al, 0
	out 0, al		; reset clock pin
	inc cl
	inc cl
	jmp start
