; mouse_start.asm, wakes the mouse and turns its wheel on
; programs call it through KERNEL_CALLS + 4
; a PS/2 mouse starts with 3 byte packets and no wheel
; the wheel comes on after sample rates 200, 100, 80
; then 0xF2 answers 3 instead of 0 and packets get a 4th byte
; MOUSE_PACKET_SIZE = 4 for a wheel mouse
; commands go out through MOUSE_DATA, the mouse answers 0xFA
; no mouse = every wait gives up, stays a plain mouse

; mouse_start, out R1 = 4 wheel mouse, 3 plain or none, uses R1-R7
mouse_start: PUSH R8
        STORE  R0, [MOUSE_PACKET_SIZE]  ; plain mouse for now
        LOADLO R1, 0x00F5               ; stop sending
        CALL   mouse_command
        CMPI   R1, 0x0000
        JZ     mouse_start_on           ; no answer, just start
        LOADLO R1, 0x00F3               ; sample rate 200
        CALL   mouse_command
        LOADLO R1, 0x00C8
        CALL   mouse_command
        LOADLO R1, 0x00F3               ; 100
        CALL   mouse_command
        LOADLO R1, 0x0064
        CALL   mouse_command
        LOADLO R1, 0x00F3               ; 80
        CALL   mouse_command
        LOADLO R1, 0x0050
        CALL   mouse_command
        LOADLO R1, 0x00F2               ; ask its ID
        CALL   mouse_command
        CALL   mouse_answer             ; R1 = ID, 0 plain, 3 wheel, 4 wheel + 5 buttons, -1 none
        CMPI   R1, 3
        JZ     mouse_start_wheel
        CMPI   R1, 4
        JNZ    mouse_start_on
mouse_start_wheel: LOADLO R1, 4
        STORE  R1, [MOUSE_PACKET_SIZE]  ; 4 byte packets
mouse_start_on: LOADLO R1, 0x00F4       ; start sending
        CALL   mouse_send
        STORE  R0, [MOUSE_PACKET_COUNT] ; no half packet, no notches waiting
        STORE  R0, [MOUSE_WHEEL]
        LOADLO R1, 3
        LOAD   R2, [MOUSE_PACKET_SIZE]
        CMPI   R2, 4
        JNZ    mouse_start_done
        LOADLO R1, 4
mouse_start_done: POP R8
        RET

; mouse_command, sends a command byte and waits for 0xFA
; in R1 = the byte, out R1 = 1 OK, 0 no answer, uses R1-R8
mouse_command: CALL mouse_send
mouse_command_wait: CALL mouse_answer
        CMPIS  R1, -1
        JZ     mouse_command_no
        CMPI   R1, 0x00FA
        JNZ    mouse_command_wait       ; not the OK, skip
        LOADLO R1, 1
        RET
mouse_command_no: LOADLO R1, 0
        RET

; mouse_send, a byte out to the mouse, waits until its gone
; in R1 = the byte, uses R1, R2
mouse_send: STORE R1, [MOUSE_DATA]
mouse_send_wait: LOAD R2, [MOUSE_STATUS]
        TESTI  R2, 0x0001               ; bit 0 = still sending
        JNZ    mouse_send_wait
        RET

; mouse_answer, next byte from the mouse, waits about 50 ms, out R1 = byte or -1, uses R1-R8
mouse_answer: LOADLO R8, 20000          ; tries
mouse_answer_next: CALLF get_mouse_byte
        CMPIS  R1, -1
        JNZ    mouse_answer_done
        DEC    R8, 0b0100
        JNZ    mouse_answer_next
mouse_answer_done: RET
