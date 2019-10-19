        org 100h
        cpu 8086

        mov cx, FFFFh
START:  mov dx, [cx]
        push cx
        mov cx, 16
SEND:   mov ax, dx
        and al, 00000001b
        out DataPin, al
        out ClockPin, FFh

        nop
        nop
        nop
        nop
        nop

        out ClockPin, 0
        rcr dx
        loop SEND
        pop cx
        loop START


DataPin db 100
ClockPin db 101