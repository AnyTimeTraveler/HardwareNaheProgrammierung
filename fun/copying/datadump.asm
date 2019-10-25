	org 100h
	cpu 8086

	mov bx, 000h		; start address
START:	mov ah, 03
	mov dl, 7		; display pos
	int 6			; display current address

	push bx
	mov al, [bx]
	mov bl, al
	mov ah, 04
	mov dl, 1
	int 6
	pop bx

	mov cl, 0	
	call send
	mov cl, 2	
	call send
	mov cl, 4	
	call send
	mov cl, 6	
	call send
	
	inc bx
	test bx, 01ffh
	jnz START
DONE:	jmp DONE


send:	mov al, [bx]		; send procedure
	shr al, cl
	and al, 00000011b
	or  al, 00011000b	; set clock pin
	out 0, al		; send bottom nibble
	mov cx, 1000
SPLARG:	nop
	loop SPLARG
	mov al, 00010000b	; keep one pin always set for level fix!
	out 0, al		; reset clock pin
	mov cx, 1000
SPLAR:	nop
	loop SPLAR
	ret

