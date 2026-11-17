; find the biggest number in a list, and PRINT it (runs on the board: send.sh uploads it)
; answer: "biggest number: 0x0000002F"
.org 0x5000

        LOADHI R2, 0xFFFF
        ORI    R2, R2, 0x8000       ; R2 = 0xFFFF_8000, the I/O area (send_byte needs it)
        LOADLO R1, list             ; R1 points at the numbers
        LOADLO R5, 5                ; R5 = how many numbers
        LOADLO R6, 0                ; R6 = the biggest so far
loop:   LOAD   R7, [R1 + 0x0000]    ; R7 = the number R1 points at
        CMP    R7, R6               ; new number - biggest so far, sets the flags
        JN     next                 ; negative: the new one is smaller, skip the copy
        MOV    R6, R7               ; not negative: it's the biggest so far
next:   ADDI   R1, R1, 4            ; point at the next number (each .word is 4 bytes)
        DEC    R5, 0b0100           ; one fewer left, sets Z
        JNZ    loop

        LOADLO R1, answer_text      ; print "biggest number: "
        CALL   print_text
        MOV    R3, R6               ; then the number itself
        CALL   print_hex
        LOADLO R3, 0x000D           ; CR
        CALL   send_byte
        LOADLO R3, 0x000A           ; LF
        CALL   send_byte
        RET                         ; back to the loader

; print_hex: prints R3 as "0x" and 8 hex digits
; uses R3, R9 (digits left), R10 (the number, shifted along)
print_hex: MOV R10, R3
        LOADLO R3, 0x0030           ; '0'
        CALL   send_byte
        LOADLO R3, 0x0078           ; 'x'
        CALL   send_byte
        LOADLO R9, 0x0008           ; 8 digits
digit:  SHIFTI R3, R10, 0x1C, 0b1000    ; R3 = R10 shifted RIGHT by 28: the top 4 bits = one digit (0-15)
        CMPI   R3, 0x000A           ; below 10?
        JNC    is_number            ; yes: it's 0-9
        ADDI   R3, R3, 0x0037       ; 10-15: + 0x37 gives 'A'-'F' (0x41-0x46)
        JUMP   send_digit
is_number: ADDI R3, R3, 0x0030      ; 0-9: + 0x30 gives '0'-'9' (0x30-0x39)
send_digit: CALL send_byte
        SHIFTI R10, R10, 0x04, 0b0000   ; LEFT by 4: the next digit moves to the top
        DEC    R9, 0b0100           ; one digit fewer, sets Z
        JNZ    digit
        RET

; print_text: sends the text R1 points at, up to its 0 byte (no new line)
; uses R1, R3
print_text: LOADB R3, [R1 + 0x0000]
        CMPI   R3, 0x0000
        JZ     text_done
        CALL   send_byte
        INC    R1
        JUMP   print_text
text_done: RET

; send_byte: waits until the UART is free, then sends R3
; uses R4
send_byte: LOAD R4, [R2 + 0x0008]   ; UART status
        ANDI   R4, R4, 0x0001       ; bit 0: busy
        JNZ    send_byte
        STORE  R3, [R2 + 0x0004]    ; send it
        RET

answer_text: .string "biggest number: "
list:   .word 12
        .word 47
        .word 5
        .word 31
        .word 47
