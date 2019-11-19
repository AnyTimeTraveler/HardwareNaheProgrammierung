org 100h
cpu 8086



start:
mov ah, 0
int 5
cmp al,0xff
jz yup
mov ah, 0
int 6
jmp start

yup:
  mov ah, 1
  int 5
  mov ah, 4
  mov bl, al
  mov dl, 4
  int 6
  jmp start
