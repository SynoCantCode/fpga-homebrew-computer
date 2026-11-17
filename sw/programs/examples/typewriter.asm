; typewriter, type on the PS/2 keyboard, the letters appear on the screen
; the kernel's GET_CHAR does the keyboard
; SCREEN_CHAR and SCREEN_CLEAR do the screen
; forever, a character in, onto the screen, and to the PC
; arrows and such, codes 0x80 and up, are skipped
.include "sw/os/devices.asm"
.org PROGRAM_START

        CALL   SCREEN_CLEAR         ; blank screen, cursor at the top-left
main:   CALL   GET_CHAR             ; R1 = next character typed, or -1
        CMPIS  R1, -1
        JZ     main                 ; nothing typed, ask again
        CMPI   R1, 0x0080
        JC     main                 ; 0x80 and up, arrows, Home, Delete, skip
        MOV    R8, R1               ; R8 = the character, kept over the calls
        CALL   SCREEN_CHAR          ; onto the screen
        MOV    R1, R8
        CALL   SEND_BYTE            ; and to the PC
        JUMP   main
