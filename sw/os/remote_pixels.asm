; remote_pixels.asm, remote control part 2, the wheel and the junk rule
; included last in the ROM so no other routines address moves
; remote_check reaches it through remote_more

; remote_more, 'W' is the wheel, else an upload at the shell prompt
; (UPLOADS_WELCOME), anywhere else its junk and thrown away
; in R2 = first byte waiting, R7 = bytes waiting
remote_more: CMPI R2, 0x0057
        JZ     remote_wheel             ; 'W'
        LOAD   R3, [UPLOADS_WELCOME]    ; at the shell prompt its an upload, leave it
        CMPI   R3, 0x0000
        JNZ    remote_more_done
        CALL   get_serial_byte          ; junk, thrown away
remote_more_done: RET
