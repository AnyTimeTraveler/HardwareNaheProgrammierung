		org 100h
		cpu 8086

		jmp start

; Variablen

status		db 00000000b	; Statusbyte
;		   xxxxx xx
;		   ||||| ||
;		   ||||| |+--------> Ton (1, an) / (0, aus)
;		   ||||| +---------> Tonfolge (1, an) / (0, aus)
;		   +++++-----------> Aktuelle note (0-23 =>c4-b5)

next_action     dw main


; Konstanten
intab0		equ 20h		; Adresse Interrupttabelle PIT, Kanal 1
intab1		equ intab0 + 1 * 4	; Adresse Interrupttabelle PIT, Kanal 2
intab7		equ intab0 + 7 * 4	; Adresse Interrupttabelle Lichttaster
eoi		equ 20h		; End Of Interrupt (EOI)
clrscr		equ 0		; Clear Screen
getkey		equ 1		; Funktion auf Tastatureingabe warten
ascii		equ 2		; Funktion ASCII-Zeichenausgabe
hexbyte		equ 4		; HEX-Byte Ausgabe
conin		equ 5		; Console IN
conout		equ 6		; Console OUT
pitc		equ 0a6h	; Steuerkanal PIT
pit1		equ 0a2h	; Counter 1 PIT
pit2		equ 0a4h	; Counter 2 PIT
ppi_ctl		equ 0b6h	; Steuerkanal PPI (Parallelinterface)
ppi_a		equ 0b0h	; Kanal A PPI
ppi_pa0		equ 1		; LED 0
ppi_pa1		equ 2		; LED 1
ppi_pa2		equ 4		; LED 2
ppi_pa3		equ 8		; Lautsprecher
ppi_pa6		equ 1 << 6	; Servomotor
ppi_b		equ 0b2h	; Kanal B PPI
ppi_c		equ 0b4h	; Kanal C PPI
ocw_2_3		equ 0c0h	; PIC (Interruptcontroller), OCW2,3
ocw_1		equ 0c2h	; PIC (Interruptcontroller), OCW1
icw_1		equ 0c0h	; PIC (Interruptcontroller), ICW1
icw_2_4		equ 0c2h	; PIC (Interruptcontroller), ICW2,4
leds		equ 0		; LED Port
schalter	equ 0		; Schalterport
keybd		equ 80h		; SBC-86 Tastatur
gokey		equ 11h		; Taste "GO"
outkey		equ 15h		; Taste "OUT"
sseg7		equ 9eh		; Segmentanzeige 7
tcticks		equ 1843	; 1843200 Hz / ????? = 1000 Hz => 1 ms
				; Zeitkonstante fuer Sequencer-ISR
tcfreq          equ 0           ; unknown

start:

; Initialisierung

	call init		; Controller und Interruptsystem scharfmachen

	mov ah, clrscr		; Anzeige aus
	int conout
	
	mov byte [status], 20h	; Init. Statusbyte und alle LEDs
	mov al, 0
	out ppi_a, al
	out leds, al
	mov cx, 0
; Hintergrundprogramm (ist immer aktiv, wenn im Service nichts zu tun ist)
; Hier sollten Ausgaben auf das Display getÃ¤tigt werden, ZÃ¤hlung der Teile, etc.

main:
        jmp check_button

check_button:
        xor dx, dx
        mov dl, 0x80
        in al, dx
        mov ah, al
        and al, 7
        test al, 7              ; 0b00000111
        je main                ; if no button pressed
        
        times 3 shr ah, 1       ; ah=column and index for xlat

        push ax
        mov bl, al
        mov ah, 4
        mov dl, 7
        int 6
        pop ax
        push ax
        mov bl, ah
        mov ah, 4
        mov dl, 4
        int 6
        pop ax

shift_loop:
        shr al, 1
        jnc found_row
        add ah, 8
        jmp shift_loop

found_row:
        mov al, ah
        mov bx, tonleiter
        xlat
        mov bl, al
        mov dl, 1
        mov ah, 4
        int 6
        
        jmp main




; setPit1 
; setzt Zeitkosntante für PIT1
; Parameter: BX => neuer scaler fÃ¼r kanal 1
; Zerstört al und bl
pit1setscaler: 
	mov al, 0b01110110	; Kanal 1, Mode 3, 16-Bit ZK
	out pitc, al		; Steuerkanal
	mov al, bl	; Low-Teil Zeitkonstante
	out pit1, al
	mov al, bh	; High-Teil Zeitkonstante
	out pit1, al
	ret

		
; Initialisierung Controller und Interruptsystem

init:
	cli			; Interrupts aus

; PIT-Init.

	mov al, 01110110b	; Kanal 1, Mode 3, 16-Bit ZK
	out pitc, al		; Steuerkanal
	mov al, tcfreq & 0ffh	; Low-Teil Zeitkonstante
	out pit1, al
	mov al, tcfreq >> 8	; High-Teil Zeitkonstante
	out pit1, al

	mov al, 10110110b	; Kanal 2, Mode 3, 16-Bit ZK
	out pitc, al		; Steuerkanal
	mov al, tcticks & 0ffh	; Low-Teil Zeitkonstante
	out pit2, al
	mov al, tcticks >> 8	; High-Teil Zeitkonstante
	out pit2, al


; PPI-Init.
	mov al, 10001011b	; PPI A/B/C Mode 0, A Output, sonst Input
	out ppi_ctl, al
	jmp short $+2		; I/O-Delay
	mov al, 0		; LED's aus (high aktiv)
	out ppi_a, al
	
; PIC-Init.
	mov al, 00010011b	; ICW1, ICW4 benoetigt, Bit 2 egal, 
				; Flankentriggerung
	out icw_1, al
	jmp short $+2		; I/O-Delay
	mov al, 00001000b	; ICW2, auf INT 8 gemapped
	out icw_2_4, al
	jmp short $+2		; I/O-Delay
	mov al, 00010001b	; ICW4, MCS-86, EOI, non-buffered,
				; fully nested
	out icw_2_4, al
	jmp short $+2		; I/O-Delay
	mov al, 01111100b	; Kanal 0, 1 + 7 am PIC demaskieren
				; PIT K1, K2 und Lichttaster
	out ocw_1, al
	
; Interrupttabelle init.	
	
	mov word [intab0], isr_freqtimer	; Interrupttabelle (Timer K1) 
					; initialisieren (Offset)
	mov [intab0 + 2], cs		; (Segmentadresse)
	
	mov word [intab1], isr_sequencer	; Interrupttabelle (Timer K2) 
					; initialisieren (Offset)
	mov [intab1 + 2], cs		; (Segmentadresse)
	
	sti				; ab jetzt Interrupts
	ret

;------------------------ Serviceroutinen -----------------------------------

isr_sequencer: ; Timer fuer abspielen der Tonfolge
	push ax

isr_sequencer_out: ; Ausgang aus dem Service
	mov al, eoi		; EOI an PIC
	out ocw_2_3, al
	pop ax
	iret
	
	
isr_freqtimer: ; Timer fuer lautsprecher
	push ax	

isr_freqtimer_out: ; Ausgang aus dem Service
	mov al, eoi		; EOI an PIC
	out ocw_2_3, al
	pop ax
	iret


;Frequenzen in zwei oktaven von c4 bis b5 in Hertz (Hz)
tonleiter	dw 262 ; c4   0
		dw 277 ; c#4  1
		dw 294 ; d4   2 
		dw 311 ; d#4  3
		dw 329 ; e4   4
		dw 349 ; f4   5
		dw 370 ; f#4  6
		dw 392 ; g4   7
		dw 415 ; g#4  8
		dw 440 ; a4   9
		dw 466 ; a#4  10
		dw 493 ; b4   11
		dw 523 ; c5   12
		dw 554 ; c#5  13 
		dw 572 ; d5   14
		dw 622 ; d#5  15
		dw 659 ; e5   16
		dw 698 ; f5   17 
		dw 740 ; f#5  18
		dw 784 ; g5   19
		dw 830 ; g#5  20
		dw 880 ; a5   21
		dw 932 ; a#5  22 
		dw 987 ; b5   23

