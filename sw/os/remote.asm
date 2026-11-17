; remote control, the PC works the computer through the UART
; keys, mouse and a copy of the screen
; messages start with a letter no upload starts with
; an uploads first byte is a multiple of 4, or 'Q' / 'S'
; 'K' + 1 byte   = a key, ASCII or KEY_UP 0x80 and on
; 'M' + 3 bytes  = a mouse packet, buttons, x move, y move
; a wheel mouse gets a 0 as 4th byte
; 'W' + 1 byte   = wheel notches, + toward you, - away, dropped on a plain mouse
; 'V'            = view, sends 0x02, then the 2400 cells as
; 2 bytes each, character then colours, then the cursors cell
; number, 2 bytes, lowest first
; remote_check is called by GET_CHAR and GET_MOUSE_BYTE when their queue is empty
; handles one message at most
; only when all its bytes have arrived
; a key goes into REMOTE_KEY, GET_CHAR picks it up
; a mouse packet goes into the mouse queue
; uses R1-R7
remote_check: LOAD R5, [UART_QUEUE + QUEUE_TAIL]
        LOAD   R6, [UART_QUEUE + QUEUE_HEAD]
        SUB    R7, R6, R5
        ANDI   R7, R7, QUEUE_MASK       ; R7 = bytes waiting, head - tail
        CMPI   R7, 0x0000
        JZ     remote_done              ; nothing from the PC
        LOADB  R2, [R5 + UART_QUEUE + QUEUE_SLOTS] ; R2 = first byte waiting, not taken out
        CMPI   R2, 0x004B
        JZ     remote_key               ; 'K'
        CMPI   R2, 0x004D
        JZ     remote_mouse             ; 'M'
        CMPI   R2, 0x0056
        JZ     remote_view              ; 'V'
        CMPI   R2, 0x0057               ; keeps the instruction count the same
        JUMP   remote_more              ; 'W', an upload, or junk
remote_done: RET                        ; an upload, left for the shell

remote_key: CMPI R7, 2
        JNC    remote_done              ; the key isnt here yet
        LOAD   R1, [REMOTE_KEY]
        CMPI   R1, 0x0000
        JNZ    remote_done              ; the last key is still waiting
        CALL   get_serial_byte          ; 'K'
        CALL   get_serial_byte          ; R1 = the key
        STORE  R1, [REMOTE_KEY]
        RET

remote_mouse: CMPI R7, 4
        JNC    remote_done              ; packet not all here yet
        CALL   get_serial_byte          ; 'M'
        LOADLO R2, 3                    ; R2 = packet bytes left
remote_mouse_next: CALL get_serial_byte ; R1 = next packet byte
        CALL   mouse_put
        DEC    R2, 0b0100
        JNZ    remote_mouse_next
        LOAD   R3, [MOUSE_PACKET_SIZE]
        CMPI   R3, 4
        JNZ    remote_done              ; plain mouse, done
        LOADLO R1, 0                    ; wheel mouse, 4th byte = 0
        JUMP   mouse_put

remote_wheel: CMPI R7, 2
        JNC    remote_done              ; notches not here yet
        CALL   get_serial_byte          ; 'W'
        CALL   get_serial_byte          ; R1 = notches
        LOAD   R3, [MOUSE_PACKET_SIZE]
        CMPI   R3, 4
        JNZ    remote_done              ; plain mouse, dropped
        MOV    R2, R1                   ; packet = no buttons, no move, the wheel
        LOADLO R1, 0x0008
        CALL   mouse_put
        LOADLO R1, 0
        CALL   mouse_put
        LOADLO R1, 0
        CALL   mouse_put
        MOV    R1, R2
        JUMP   mouse_put

; mouse_put, a byte into the mouse queue, in R1 = byte, uses R3-R5
mouse_put: DI                           ; so the mouse interrupt cant put one in too
        LOAD   R3, [MOUSE_QUEUE + QUEUE_HEAD] ; R3 = slot it goes in
        ADDI   R4, R3, 1
        ANDI   R4, R4, QUEUE_MASK       ; R4 = next head, wrapped
        LOAD   R5, [MOUSE_QUEUE + QUEUE_TAIL]
        CMP    R4, R5
        JZ     mouse_put_full           ; full, dropped
        STOREB R1, [R3 + MOUSE_QUEUE + QUEUE_SLOTS]
        STORE  R4, [MOUSE_QUEUE + QUEUE_HEAD]
mouse_put_full: EI
        RET

remote_view: CALL get_serial_byte       ; 'V'
        LOADLO R1, 0x0002               ; 0x02, screen starts here
        CALL   send_byte
        LOADHI R2, TEXT_SCREEN_HIGH     ; R2 = cell 0, 0x2000_0000
        LOADLO R3, SCREEN_CELLS         ; R3 = cells left
remote_view_next: LOAD R4, [R2]         ; R4 = cell, bits 7-0 character, bits 15-8 colours
        ANDI   R1, R4, 0x00FF
        CALL   send_byte                ; character
        SHIFTI R1, R4, 0x08, 0b1000
        ANDI   R1, R1, 0x00FF
        CALL   send_byte                ; colours
        ADDI   R2, R2, 4
        DEC    R3, 0b0100
        JNZ    remote_view_next
        LOAD   R1, [SCREEN_CURSOR]      ; cursor, pointer to its cell
        LOADHI R2, TEXT_SCREEN_HIGH
        SUB    R1, R1, R2
        SHIFTI R4, R1, 0x02, 0b1000     ; to a cell number, 4 bytes per cell
        ANDI   R1, R4, 0x00FF
        CALL   send_byte
        SHIFTI R1, R4, 0x08, 0b1000
        JUMP   send_byte                ; tail call
