		org 100h
		cpu 8086

		jmp start

; Variablen
last_input	db 0				; Last keyboad input
status          db 0                            ; Displays the current status to humans
play_mode	equ 1				; 1 if in play mode, 0 otherwise
record_mode	equ 2				; 1 if in record mode, 0 otherwise
;nothing	equ 4				; 
speaker_swing	equ 8                           ; 
sequence_fire	equ 16				; 
play_note	equ 32                          ; 
;nothing	equ 64                          ; 
;nothing	equ 128                         ; 

settings        db 0                            ; Reads input from humans
;play_mode	equ 1				; 1 if in play mode, 0 otherwise
;record_mode	equ 2				; 1 if in record mode, 0 otherwise
reset_counter   equ 4				; 
display_mode	equ 8                           ; 
memview_mode	equ 16				; 
;nothing	equ 32                          ; 
;nothing	equ 64                          ; 
breakpoint	equ 128                         ; 


data_start	equ song_data			; index of currently played byte
data_index	dw song_data			; index of currently played byte
data_end	equ song_data+256		; length of data area

note_time	dw 0				; time current note is played, in ms
note_length	dw 0				; time current note is supposed to be played, in ms

; Konstanten
int0            equ 0                           ; Addresse des Divisionsueberlaufs
intab0		equ 20h				; Adresse Interrupttabelle PIT, Kanal 1
intab1		equ intab0 + 1 * 4		; Adresse Interrupttabelle PIT, Kanal 2
intab7		equ intab0 + 7 * 4		; Adresse Interrupttabelle Lichttaster
eoi		equ 20h				; End Of Interrupt (EOI)
clrscr		equ 0				; Clear Screen
getkey		equ 1				; Funktion auf Tastatureingabe warten
ascii		equ 2				; Funktion ASCII-Zeichenausgabe
hexbyte		equ 4				; HEX-Byte Ausgabe
conin		equ 5				; Console IN
conout		equ 6				; Console OUT
pitc		equ 0a6h			; Steuerkanal PIT
pit1		equ 0a2h			; Counter 1 PIT
pit2		equ 0a4h			; Counter 2 PIT
ppi_ctl	        equ 0b6h			; Steuerkanal PPI (Parallelinterface)
ppi_a		equ 0b0h			; Kanal A PPI
ppi_pa0		equ 1				; LED 0
ppi_pa1		equ 2				; LED 1
ppi_pa2		equ 4				; LED 2
ppi_pa3		equ 8				; Lautsprecher
ppi_pa6		equ 1 << 6			; Servomotor
ppi_b		equ 0b2h			; Kanal B PPI
ppi_c		equ 0b4h			; Kanal C PPI
ocw_2_3		equ 0c0h			; PIC (Interruptcontroller), OCW2,3
ocw_1		equ 0c2h			; PIC (Interruptcontroller), OCW1
icw_1		equ 0c0h			; PIC (Interruptcontroller), ICW1
icw_2_4		equ 0c2h			; PIC (Interruptcontroller), ICW2,4
leds		equ 0				; LED Port
schalter	equ 0				; Schalterport
keybd		equ 80h				; SBC-86 Tastatur
gokey		equ 11h				; Taste "GO"
outkey		equ 15h				; Taste "OUT"
sseg7		equ 9eh				; Segmentanzeige 7
tcticks		equ 1843			; 1843200 Hz / 1843 = 1000 Hz =>  1 ms
						; Zeitkonstante fuer Sequencer-ISR
tcfreq		equ 18432			; 1843200 Hz / 18432 = 100 Hz => 10 ms


; Sets a status bit.
; arg1: bit
; Destroys al
%macro setStatusBit 1
  mov byte al, [status]
  or al, %1
  mov byte [status], al
%endmacro

; Clears a status bit.
; arg1: bit
; Destroys al
%macro clearStatusBit 1
  mov byte al, [status]
  and al, ~%1
  mov byte [status], al
%endmacro

; Jumps to label if bit is not set.
; arg1: bit
; arg2: label
; Destroys al
%macro checkStatusBit 2
  push ax
  mov byte al, [status]
  test al, %1
  pop ax
  jz %2
%endmacro

; Jumps to label if bit in al is not set.
; arg1: bit
; arg2: label
; Destroys al
%macro checkBit 2
  test al, %1
  jz %2
%endmacro



start:

; Initialisierung

		call init			; Controller und Interruptsystem scharfmachen
		call clear_screen

                mov word dx, break_func
                jmp main


; Hintergrundprogramm (ist immer aktiv, wenn im Service nichts zu tun ist)
; Hier sollten Ausgaben auf das Display getaetigt werden, Zaehlung der Teile, etc.

main:
                mov byte al, [status]
                out leds, al

		; check for sequence interrupt
                checkStatusBit sequence_fire,.b
		call advance_sequence
                clearStatusBit sequence_fire

.b:		; update switch states
		call check_switches
		; check for button press
		jmp check_button

; reads switches, sets play_mode and record_mode accordingly
check_switches:
		in al, schalter
                mov byte [settings], al

                ; write play- and rec-mode to status
                mov byte ah, al
                and al, 3
                mov byte bl, [status]
                and bl, ~3
                or bl, al
                mov byte [status], bl

                ; reset data index and play_note
                mov byte al, ah
                checkStatusBit reset_counter,.a
                mov word [data_index], data_start
                clearStatusBit play_note
.a:             
                checkStatusBit breakpoint,return
break_func:     xchg bx, bx
        	ret

;               Dangling breakpoint instruchtion
;               Used for jumping to, when call is not possible
break_lbl:      call break_func
                jmp main



; reads is button was pressed, updates display,
check_button:
		in al, keybd

		mov byte cl, [last_input]	; check if equal to last round
		cmp al, cl
                ; leave if it's the exact same keycode
		je main

		mov byte ah, al
		and al, 7
		cmp al, 7			; 0bxxxxx111 means no button pressed
		jne .calc_button
                
                cmp cl, 0                       ; check if last round there was also no button press
                je main
                mov word [last_input], 0

                clearStatusBit play_note
		call clear_screen
		mov word ax, 0			; mark for the recorder that there is no sound now
		jmp .record_note

.calc_button:    ; remember the last input
		mov byte [last_input], ah
		times 3 shr ah, 1		; ah=column and index for xlat

.shift_loop:	shr al, 1
		jnc .found_row
		add ah, 8
		jmp .shift_loop

.found_row:	; AH contains table index now
		; get tonleiter value calculate scaler
		mov byte bl, ah
		add bl, ah
		xor bh, bh
                mov word ax, [tonleiter+bx]
		mov word bx, ax

		; display frequency
                call display_bx_left

		; divide to get scaler
		shl bx, 1			; double to match freq / (f * 2) equasion
		; DX:AX = 1843200
		mov word dx, 28
		mov word ax, 8192
		div bx

		mov word bx, ax
		call pit1setscaler

		; enable sound
                setStatusBit play_note

                mov word ax, bx


.record_note:	; AX contains current note

                ; check if it's being recorded
                checkStatusBit record_mode,main
		
                ; load address to write to
                mov word bx, [data_index]

                ; display position
                sub bx, data_start
                call display_bx_right
                add bx, data_start

                cmp ax, 0
                je .time

		; write note to ram
		mov word [bx], ax
		times 2 inc bx
                jmp .wrap

                ; write note time to ram
.time:		mov word ax, [note_time]
		mov word [bx], ax
		times 2 inc bx

		; make the buffer wrap around
.wrap:		mov word ax, data_end
		cmp bx, ax
		jl .end
		mov word bx, data_start

.end:     	mov word [data_index], bx	; store new index
		jmp main


clear_screen:
		push ax
		mov byte ah, clrscr		; Anzeige aus
		int conout
		pop ax
		ret


; increment the time the note has been played
; stores note in ax
inc_and_get_note_time:
                mov word ax, [note_time]
		inc ax
		mov word [note_time], ax
		ret


advance_sequence:
                checkStatusBit record_mode,.play_mode
                call inc_and_get_note_time
		ret

.play_mode:
		checkStatusBit play_mode,return

                call inc_and_get_note_time

		; check if note needs to end
		mov word bx, [note_length]
		cmp ax, bx
		jl return

		; load new note
		mov word bx, [data_index]
                
                ; show index
                sub bx, data_start
                call display_bx_left
                add bx, data_start

		; write note to ram
		; read note
		mov word ax, [bx]
		times 2 inc bx

                ; check if note is silence
                cmp ax, 0
                jne .enable
                ; set scaler high and disable play note
                clearStatusBit play_note
                mov word ax, tcfreq
                jmp .set_scale
.enable:        setStatusBit play_note

                ; set frequency
.set_scale:     xchg bx, ax
		call pit1setscaler
                call display_bx_right
                ; restore address into bx
                mov word bx, ax

		; read length of note
		mov word ax, [bx]
		times 2 inc bx
		
                mov word [note_time], 0
		mov word [note_length], ax

		; make the buffer wrap around
		mov word [data_index], bx
		cmp bx, data_end
		jl return
		mov word [data_index], data_start
return:         ret

; displays note index coming from bx
display_bx_left:
                push dx
                mov byte dl, 7
                call display_bx_at_dl
                pop dx
                ret

display_bx_right:
                push dx
                mov byte dl, 3
                call display_bx_at_dl
                pop dx
                ret

display_bx_at_dl:
                push ax
                mov byte ah, 3
                int 6
                pop ax
                ret

; setPit1
; setzt Zeitkosntante für PIT1
; Parameter: BX => neuer scaler fuer kanal 1
pit1setscaler:
		push ax
		mov byte al, 01110110b		; Kanal 1, Mode 3, 16-Bit ZK
		out pitc, al			; Steuerkanal
		mov byte al, bl			; Low-Teil Zeitkonstante
		out pit1, al
		mov byte al, bh			; High-Teil Zeitkonstante
		out pit1, al
		pop ax
		ret


; Initialisierung Controller und Interruptsystem

init:
		cli				; Interrupts aus

; PIT-Init.

		mov byte al, 01110110b		; Kanal 1, Mode 3, 16-Bit ZK
		out pitc, al			; Steuerkanal
		mov byte al, tcfreq & 0xff	; Low-Teil Zeitkonstante
		out pit1, al
		mov byte al, tcfreq >> 8	; High-Teil Zeitkonstante
		out pit1, al

		mov byte al, 10110110b		; Kanal 2, Mode 3, 16-Bit ZK
		out pitc, al			; Steuerkanal
		mov byte al, tcticks & 0xff	; Low-Teil Zeitkonstante
		out pit2, al
		mov byte al, tcticks >> 8	; High-Teil Zeitkonstante
		out pit2, al


; PPI-Init.
		mov byte al, 10001011b		; PPI A/B/C Mode 0, A Output, sonst Input
		out ppi_ctl, al
		jmp short $+2		        	; I/O-Delay
		mov byte al, 0			; LED's aus (high aktiv)
		out ppi_a, al

; PIC-Init.
		mov byte al, 00010011b		; ICW1, ICW4 benoetigt, Bit 2 egal,
						; Flankentriggerung
		out icw_1, al
		jmp short $+2  			; I/O-Delay
		mov byte al, 00001000b		; ICW2, auf INT 8 gemapped
		out icw_2_4, al
		jmp short $+2			        ; I/O-Delay
		mov byte al, 00010001b		; ICW4, MCS-86, EOI, non-buffered,
						; fully nested
		out icw_2_4, al
		jmp short $+2			        ; I/O-Delay
		mov byte al, 01111100b		; Kanal 0, 1 + 7 am PIC demaskieren
						; PIT K1, K2 und Lichttaster
		out ocw_1, al

; Interrupttabelle init.

		mov word [intab0], break_lbl    ; Interrupttabelle (Divisionsueberlauf)
						; initialisieren (Offset)
		mov word [intab0 + 2], cs	; (Segmentadresse)

		mov word [intab0], isr_freqtimer; Interrupttabelle (Timer K1)
						; initialisieren (Offset)
		mov word [intab0 + 2], cs	; (Segmentadresse)

		mov word [intab1], isr_sequencer; Interrupttabelle (Timer K2)
						; initialisieren (Offset)
		mov word [intab1 + 2], cs	; (Segmentadresse)

		sti				; ab jetzt Interrupts
                
		mov byte al, 0
		out ppi_a, al

		ret

;------------------------ Serviceroutinen -----------------------------------

isr_sequencer:					; Timer fuer abspielen der Tonfolge
		push ax
                setStatusBit sequence_fire

.out:           				; Ausgang aus dem Service
		mov byte al, eoi		; EOI an PIC
		out ocw_2_3, al
		pop ax
		iret


isr_freqtimer:					; Timer fuer lautsprecher
		push ax
                ; jump to end if play_note is 0
                checkStatusBit play_note,.out

                ; flip swing value
		mov byte al, [status]
		xor al, ppi_pa3
		mov byte [status], al
                ; isolate it
                and al, ppi_pa3
		out ppi_a, al

.out:           				; Ausgang aus dem Service
		mov byte al, eoi		; EOI an PIC
		out ocw_2_3, al
		pop ax
		iret

section .data

;Frequenzen in zwei Oktaven von c4 bis b5 in Hertz (Hz)
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

; song data is here
;
; Format:
;	dw	0; duration
;	dw	0; scaler
;
song_data	dw 1000, 3517
        	dw 1000, 0
                dw 1000, 2220
                dw 1000, 0
                dw 1000, 2220
                dw 1000, 0
                times 116 dw 0
;song_data	resw 128

; incbin "music.bin"

; vim: set tabstop=8:set noexpandtab:set shiftwidth=8

