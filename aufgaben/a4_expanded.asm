		org 100h
		cpu 8086

		jmp start

; Variablen
status          db 0                            ; Displays the current status to humans
play_mode	equ 1				; 1 if in play mode, 0 otherwise
record_mode	equ 2				; 1 if in record mode, 0 otherwise
;nothing	equ 4				; 
speaker_swing	equ 8                           ; 
sequence_fire	equ 16				; 
play_note	equ 32                          ; 
reset_done	equ 64                          ; 
clear_done	equ 128                         ; 

settings        db 0                            ; Reads input from humans
;play_mode	equ 1				; 1 if in play mode, 0 otherwise
;record_mode	equ 2				; 1 if in record mode, 0 otherwise
reset_counter   equ 4				; 
display_mode	equ 8                           ; 
memview_mode	equ 16				; 
mem_clear	equ 32                          ; 
silence 	equ 64                          ; 
breakpoint	equ 128                         ; 


data_index	dw 0		        	; index of currently played index
data_size	equ 408          		; length of data area

note_time	dw 0				; time current note is played, in ms
note_length	dw 0				; time current note is supposed to be played, in ms

last_input	db 0				; Last keyboad input

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


start:
		; Initialisierung
		call init			; Controller und Interruptsystem scharfmachen
		call clear_screen

                jmp main


; Hintergrundprogramm (ist immer aktiv, wenn im Service nichts zu tun ist)
; Hier sollten Ausgaben auf das Display getaetigt werden, Zaehlung der Teile, etc.

main:
                ; update switch states
		call check_switches
                test byte [settings], memview_mode
		jz .a
                jmp memview
 
.a:             ; show status
                mov byte al, [status]
                out leds, al
               
		; check for sequence interrupt
                test byte [status], sequence_fire
		jz .b
		
		call advance_sequence
                and byte [status], ~sequence_fire

.b:		; check for button press
		jmp check_button

; reads switches, sets play_mode and record_mode accordingly
check_switches:
		in al, schalter
                mov byte [settings], al

                ; write play- and rec-mode to status
                mov byte ah, al
                and ah, 3
                and byte [status], ~3
                or byte [status], ah

                ; reset data index and play_note
                and byte [status], ~reset_done
                test byte [settings], reset_counter
		jz .a
                mov word [data_index], 0
                or byte [status], reset_done
                and byte [status], ~play_note
                
                ; clear memory
.a:             and byte [status], ~clear_done
                test byte [settings], mem_clear
		jz .b
                mov word cx, data_size
.loop:          mov word bx, cx
                shl bx, 1
                mov word [song_notes+bx], 0
                mov word [song_times+bx], 0
                loop .loop

                mov word [song_notes], 0
                mov word [song_times], 0
                mov word [note_time], 0
                or byte [status], clear_done
.b:             test byte [settings], breakpoint
		jz return
break_func:     xchg bx, bx
        	ret

;               Dangling breakpoint instruchtion
;               Used for jumping to, when call is not possible
break_lbl:      call break_func
                jmp main



; reads is button was pressed, updates display,
check_button:
		in al, keybd

		cmp al, [last_input]            ; check if equal to last round
		je main                         ; leave if it's the exact same keycode

		mov byte ah, al
		and al, 7
		cmp al, 7			; 0bxxxxx111 means no button pressed
		jne .calc_button
                
                cmp byte [last_input], 0                       ; check if last round there was also no button press
                je main
                mov word [last_input], 0

                and byte [status], ~play_note
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
		shl bl, 1
		xor bh, bh
                mov word ax, [tonleiter+bx]
		mov word bx, ax
                mov word cx, ax

	        ; divide to get scaler
		shl bx, 1			; double to match freq / (f * 2) equasion
		; DX:AX = 1843200
		mov word dx, 001ch
		mov word ax, 2000h
		div bx

                ; display frequency
                test byte [settings], display_mode
		jz .freq
                mov word bx, ax
                call display_bx_right
                jmp .done
.freq:          mov word bx, cx
                call display_bx_right

                ; set scaler
.done:		mov word bx, ax
		call pit1setscaler

		; enable sound
                or byte [status], play_note

                mov word ax, cx


.record_note:	; AX contains current note

                ; check if it's being recorded
                test byte [settings], record_mode
		jz main
		
                ; load address to write to
                mov word bx, [data_index]

                ; display position
                call display_bx_left

                ; only record time if button was released
                cmp ax, 0
                je .time

                ;record silence before note
		mov word [song_notes+bx], 0
		mov word cx, [note_time]
                mov word [song_times+bx], cx
                add bx, 2
		mov word [note_time], 0

		; write note to ram
		mov word [song_notes+bx], ax
                jmp .wrap

                ; write note time to ram
.time:		mov word ax, [note_time]
                mov word [note_time], 0
		mov word [song_times+bx], ax
		add bx, 2

		; make the buffer wrap around
.wrap:		cmp bx, data_size
		jl .end
		mov word bx, 0

.end:     	mov word [data_index], bx	; store new index
		jmp main


clear_screen:
		push ax
		mov byte ah, clrscr		; Anzeige aus
		int conout
		pop ax
		ret


advance_sequence:
                test byte [settings], record_mode
		jz .play_mode
                inc word [note_time]
		ret

.play_mode:
		test byte [settings], play_mode
		jz return
                ; get and increment note time
                mov word ax, [note_time]
                inc ax
                mov word [note_time], ax

		; check if note needs to end
		cmp ax, [note_length]
		jl return

		; load new note
		mov word bx, [data_index]
 
                ; show index
                call display_bx_left

		; read note
		mov word ax, [song_notes+bx]

                ; check if note is silence
                cmp ax, 0
                jne .enable
                ; set scaler high and disable play note
                and byte [status], ~play_note
                jmp .skip
.enable:        or byte [status], play_note

                ; set frequency
                push bx
                call display_bx_right
                mov bx, ax

	        ; divide to get scaler
		shl bx, 1			; double to match freq / (f * 2) equasion
		; DX:AX = 1843200
		mov word dx, 001ch
		mov word ax, 2000h
		div bx
                mov word bx, ax

		call pit1setscaler
                ; restore address into bx
                pop bx

		; read length of note
.skip:		mov word ax, [song_times+bx]

                test byte [settings], display_mode
		jz .cont
                ; show note length
                xchg ax, bx
                call display_bx_left
                xchg ax, bx

.cont:		; increment index
                add bx, 2
                mov word [note_time], 0
		mov word [note_length], ax

		; make the buffer wrap around
		mov word [data_index], bx
		cmp bx, data_size
		jl return
		mov word [data_index], 0
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

memview:
                mov word bx, [data_index]
                mov word cx, bx

                mov byte al, bl
                shr al, 1
                out leds, al

                mov word ax, [song_notes+bx]
                xchg ax, bx
                call display_bx_right
                xchg ax, bx
                
                mov word ax, [song_times+bx]
                xchg ax, bx
                call display_bx_left

                mov byte ah, 1
                int 5
                cmp al, 17h                     ; bottom left
                jne .a
                sub cx, 2
.a:             cmp al, 00h                     ; middle left
                jne .b
                add cx, 2
.b:             
                mov word [data_index], cx

                jmp main






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
		mov byte al, 11111100b		; Kanal 0, 1 + 7 am PIC demaskieren
						; PIT K1, K2 und Lichttaster
		out ocw_1, al

; Interrupttabelle init.

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
                or byte [status], sequence_fire

.out:           				; Ausgang aus dem Service
		mov byte al, eoi		; EOI an PIC
		out ocw_2_3, al
		pop ax
		iret


isr_freqtimer:					; Timer fuer lautsprecher
		push ax
                ; jump to end if play_note is 0
                test byte [status], play_note
		jz .out
                test byte [settings], silence
		jz .run
                jmp .out

.run:           ; flip swing value
                in al, ppi_a
		xor al, ppi_pa3
                xor byte [status], ppi_pa3
		out ppi_a, al

.out:           				; Ausgang aus dem Service
		mov byte al, eoi		; EOI an PIC
		out ocw_2_3, al
		pop ax
		iret
		
; Ab hier garantiert nur gerade Speicheraddressen
align 16

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
song_notes      incbin "notes.bin"
song_times      incbin "times.bin"


; vim: set tabstop=8:set noexpandtab:set shiftwidth=8

