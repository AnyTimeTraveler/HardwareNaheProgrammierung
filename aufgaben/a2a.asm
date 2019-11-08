      org 100h
      cpu 8086

WDH:  mov al, 0             ; Reset screen
      mov dx, [DISP_L]
      out dx, al
      mov dx, [DISP_H]
      out dx, al

      mov dx, [LED]
      in al, dx             ; Read input from switches
      mov ah, al            ; Backup input
      and al, 15            ; Cut off high nibble from al
      times 4 shr ah, 1     ; Shift out low nibble from ah
      add al, ah            ; Merge ah and al
      out dx, al            ; Write to LEDs
      
      cmp al, 10h           ; Check if need to print 2 digits
      jl LOWB
      
      ; Write to high nibble
      push ax               ; Save al
      times 4 shr al, 1     ; Cut off low nibble
      mov bx, CHARS         ; Load char table for xlat
      xlat                  ; Translate through chars
      mov dx, [DISP_H]
      out dx, al            ; Write to display
      pop ax                ; Restore al
      and al, 15            ; Cut off high nibble

      ; Write low nibble
LOWB: mov bx, CHARS         ; Load char table for xlat
      xlat                  ; Translate through chars
      mov dx, [DISP_L]
      out dx, al            ; Write to display
      jmp WDH

LED     dw 0
DISP_L  dw 90h
DISP_H  dw 92h

CHARS   db 63, 6, 91, 79, 102, 109, 125, 7, 127, 111, 119, 124, 57, 94, 121, 113


