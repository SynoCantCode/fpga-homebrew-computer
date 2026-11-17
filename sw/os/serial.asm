; serial, the UART routines, talking to the PC over USB
; in R1, out R1, may change R1-R7, keeps R8-R14
; bytes from the PC come out of the UART queue
; bytes to the PC go straight to the UART, no send queue

; send_byte, waits until the UART is free, then sends one byte
; in R1 = the byte, uses R5
send_byte: LOAD R5, [UART_STATUS]
        ANDI   R5, R5, UART_BUSY        ; bit 0, still sending?
        JNZ    send_byte
        STORE  R1, [UART_DATA]
        RET

; print_text, sends a 0 ended text to the PC
; in R1 = pointer to the text
; the pointer is kept in R8
print_text: PUSH R8
        MOV    R8, R1                   ; R8 = pointer into the text
print_next: LOADB R1, [R8]              ; R1 = the letter
        CMPI   R1, 0x0000
        JZ     print_done               ; 0, end of the text
        CALL   send_byte
        INC    R8                       ; next letter
        JUMP   print_next
print_done: POP R8
        RET

; print_line, the same, then CR LF
; in R1 = pointer to the text
print_line: CALL print_text
        LOADLO R1, 0x000D               ; CR
        CALL   send_byte
        LOADLO R1, 0x000A               ; LF
        JUMP   send_byte                ; tail call

; receive_byte, waits for a byte from the PC
; asks GET_SERIAL_BYTE again until it isnt -1
; out R1 = the byte
receive_byte: CALL get_serial_byte
        CMPIS  R1, -1
        JZ     receive_byte             ; nothing yet, again
        RET

; receive_word, 4 bytes, lowest first, into one 32 bit number
; out R1 = the number, built in R8
receive_word: PUSH R8
        CALL   receive_byte
        MOV    R8, R1                   ; bits 7-0
        CALL   receive_byte
        SHIFTI R1, R1, 0x08, 0b0000     ; bits 15-8
        OR     R8, R8, R1
        CALL   receive_byte
        SHIFTI R1, R1, 0x10, 0b0000     ; bits 23-16
        OR     R8, R8, R1
        CALL   receive_byte
        SHIFTI R1, R1, 0x18, 0b0000     ; bits 31-24
        OR     R8, R8, R1
        MOV    R1, R8                   ; R1 = the number
        POP    R8
        RET

; print_byte_hex, sends a byte as 2 hex digits, 0x1C sends "1C"
; in R1 = the byte
; R8 = the byte, R9 = digits left
print_byte_hex: PUSH R8
        PUSH   R9
        SHIFTI R8, R1, 0x18, 0b0000     ; R8 = the byte in bits 31-24
        LOADLO R9, 0x0002               ; 2 digits
hex_digit: SHIFTI R1, R8, 0x1C, 0b1000  ; R1 = top 4 bits, one digit
        CMPI   R1, 0x000A
        JNC    hex_number
        ADDI   R1, R1, 0x0037           ; 10-15 to 'A'-'F'
        JUMP   hex_send
hex_number: ADDI R1, R1, 0x0030         ; 0-9 to '0'-'9'
hex_send: CALL send_byte
        SHIFTI R8, R8, 0x04, 0b0000     ; next digit to the top
        DEC    R9, 0b0100
        JNZ    hex_digit
        POP    R9
        POP    R8
        RET
