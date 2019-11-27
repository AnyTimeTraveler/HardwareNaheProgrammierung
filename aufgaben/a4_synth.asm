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

last_input      db 0            ; Last keyboad input
play_note       db 0            ; 1 if note should be played, 0 otherwise
speaker_swing   db 0            ; speaker swing 'direction'

sequence_fire   db 0            ; 1 if tonfolge should advance
speaker_fire    db 0            ; 1 if speaker should swing
record_mode	db 0		; 1 if in record mode
play_mode	db 0		; 1 if in play mode

data_index	dw 0		; index of currently played byte
data_length	dw 1024		; length of data area
index_counter	dw 0		; milliseconds in the current index
index_length	dw 500		; length of a takt in ms

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


tcfreq          equ 18430           ; not needed for now (tonfolge)

start:

; Initialisierung

	call init		; Controller und Interruptsystem scharfmachen

        call clear_screen
	
	mov byte [status], 20h	; Init. Statusbyte und alle LEDs
	mov al, 0
	out ppi_a, al
	out leds, al

	mov cx, 23
	
divide:	mov bx, cx
	add bx, cx
	mov word ax, [tonleiter+bx] ; for division
        mov bx, ax
	add bx, ax
	
	; divide to get scaler
        ; DX:AX = 1843200
        mov dx, 28
        mov ax, 8192
        div bx
	mov bx, cx
	add bx, cx
        mov [tonleiter+bx], ax
	loop divide

        mov bx, tcticks
        call pit1setscaler


        
; Hintergrundprogramm (ist immer aktiv, wenn im Service nichts zu tun ist)
; Hier sollten Ausgaben auf das Display getaetigt werden, Zaehlung der Teile, etc.

main:
	; check for speaker swing interrupt
	mov byte al, [speaker_fire]
	cmp al, 0
	je main_a
	call swing
	mov byte [speaker_fire], 0

main_a: ; check for sequence interrupt
	mov byte al, [sequence_fire]
	cmp al, 0
	je main_b
	call advance_sequence
	mov byte [sequence_fire], 0
	
main_b:	; update switch states
	call read_switches
	
	; check for button press
        jmp check_button





check_switches:
	mov byte [record_mode], 0
	mov byte [play_mode], 0
	in al, schalter
	shr al, 1
	jnc check_a
	mov byte [record_mode], 1
check_a:shr al, 1
	jnc check_b
	mov byte [play_mode], 1
check_b:ret


	



check_button:
        in al, keybd
        
        mov byte cl, [last_input]    ; check if equal to last round
        cmp al, cl
        je main
        mov byte [last_input], al

        mov byte ah, al
        and al, 7
        cmp al, 7               ; 0b00000111
        jne calc_button         ; if no button pressed
	
	mov byte [play_note], 0
        call clear_screen
        jmp main

calc_button:
        times 3 shr ah, 1       ; ah=column and index for xlat

	; display row and column
	mov dx, 0
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
	; AH contains table index now
        mov bl, ah
        xor bh, bh
        mov dl, 1
        mov ah, 4
        int 6
	; BL contains table index now
	
	xor bh, bh
	add bl, bl
        mov word ax, [tonleiter+bx] ; for division
        mov bx, ax
	add bx, ax
	
	; divide to get scaler
        ; DX:AX = 1843200
        mov dx, 28
        mov ax, 8192
        div bx
        mov bx, ax
	
	call pit1setscaler

	; enable sound
	mov byte [play_note], 1
        jmp main



clear_screen:
        push ax
	mov ah, clrscr		; Anzeige aus
	int conout
        pop ax
        ret


swing:
	mov al, [play_note]
        cmp al, 0
        je swing_ret		; jump to end if play_note is 0

        mov al, [speaker_swing]
        xor al, ppi_pa3
        mov [speaker_swing], al
        out ppi_a, al

swing_ret:
	ret


advance_sequence:
	mov al, [record_mode]
	cmp al, 0
	je advance_sequence_play_mode
	
	mov al, [in]

	ret

advance_sequence_play_mode:
	mov al, [play_mode]
	cmp al, 0
	jne advance_ret


advance_ret:
	ret


; setPit1 
; setzt Zeitkosntante für PIT1
; Parameter: BX => neuer scaler fuer kanal 1
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

	mov al, 0b01110110	; Kanal 1, Mode 3, 16-Bit ZK
	out pitc, al		; Steuerkanal
	mov al, tcfreq & 0xff	; Low-Teil Zeitkonstante
	out pit1, al
	mov al, tcfreq >> 8	; High-Teil Zeitkonstante
	out pit1, al

	mov al, 0b10110110	; Kanal 2, Mode 3, 16-Bit ZK
	out pitc, al		; Steuerkanal
	mov al, tcticks & 0xff	; Low-Teil Zeitkonstante
	out pit2, al
	mov al, tcticks >> 8	; High-Teil Zeitkonstante
	out pit2, al


; PPI-Init.
	mov al, 0b10001011	; PPI A/B/C Mode 0, A Output, sonst Input
	out ppi_ctl, al
	jmp short $+2		; I/O-Delay
	mov al, 0		; LED's aus (high aktiv)
	out ppi_a, al
	
; PIC-Init.
	mov al, 0b00010011	; ICW1, ICW4 benoetigt, Bit 2 egal, 
				; Flankentriggerung
	out icw_1, al
	jmp short $+2		; I/O-Delay
	mov al, 0b00001000	; ICW2, auf INT 8 gemapped
	out icw_2_4, al
	jmp short $+2		; I/O-Delay
	mov al, 0b00010001	; ICW4, MCS-86, EOI, non-buffered,
				; fully nested
	out icw_2_4, al
	jmp short $+2		; I/O-Delay
	mov al, 0b01111100	; Kanal 0, 1 + 7 am PIC demaskieren
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
	mov byte [sequence_fire], 1

isr_sequencer_out: ; Ausgang aus dem Service
	mov al, eoi		; EOI an PIC
	out ocw_2_3, al
	pop ax
	iret

	

isr_freqtimer: ; Timer fuer lautsprecher
	push ax
	mov byte [speaker_fire], 1

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


song_data	db 0	; song data goes here

