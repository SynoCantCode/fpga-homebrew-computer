; I2C, bit-banged on the two shared wires
; DS3231 clock at 0x68, MCP23017 pins at 0x20
; I2C_READ  (0x009C)  in R1 = chip address, R2 = first register, R3 = byte count, R4 = where to
; out R1 = 0, or 1 if no answer
; I2C_WRITE (0x00A0)  in R1 = chip address, R2 = first register, R3 = byte count, R4 = the bytes
; out R1 = 0, or 1 if no answer
;
; I2C_PINS bit 0 = SCL, bit 1 = SDA, 1 = let go (high), 0 = pull low
; start  SDA goes low while SCL is high
; byte   8 bits, highest first, SDA set while SCL is low
; ack    9th clock, SDA low = ACK, high = NACK
; stop   SDA goes high while SCL is high
; read = start, address + 0, register, start, address + 1, bytes
; every byte gets an ACK but the last
; each step waits I2C_WAIT loops, about 5 microseconds, 100 kHz
; i2c_clock_up waits for a chip that holds SCL low
; uses R1-R7, I2C_READ and I2C_WRITE keep R8-R11
.equ I2C_WAIT, 40                       ; loops per step
.equ SCL_LET_GO, 0b01
.equ SDA_LET_GO, 0b10

; i2c_wait, pause of I2C_WAIT loops, uses R5
i2c_wait: LOADLO R5, I2C_WAIT
i2c_wait_loop: DEC R5
        CMPI   R5, 0x0000
        JNZ    i2c_wait_loop
        RET

; i2c_clock_up, let SCL go and wait till its high, 1000 looks at most
; in R2 = SDA bit, SDA_LET_GO or 0, uses R3, R5
i2c_clock_up: ORI R3, R2, SCL_LET_GO
        STORE  R3, [I2C_PINS]
        LOADLO R5, 1000
clock_up_look: LOAD R3, [I2C_PINS]
        ANDI   R3, R3, SCL_LET_GO
        JNZ    clock_up_done
        DEC    R5
        CMPI   R5, 0x0000
        JNZ    clock_up_look
clock_up_done: JUMP i2c_wait

; i2c_start, both let go, SDA low, then SCL low
i2c_start: LOADLO R1, SCL_LET_GO + SDA_LET_GO
        STORE  R1, [I2C_PINS]
        CALL   i2c_wait
        LOADLO R1, SCL_LET_GO           ; SDA low while SCL is high
        STORE  R1, [I2C_PINS]
        CALL   i2c_wait
        STORE  R0, [I2C_PINS]           ; both low
        JUMP   i2c_wait

; i2c_stop, both low, SCL let go, then SDA let go
i2c_stop: STORE R0, [I2C_PINS]
        CALL   i2c_wait
        LOADLO R1, SCL_LET_GO
        STORE  R1, [I2C_PINS]
        CALL   i2c_wait
        LOADLO R1, SCL_LET_GO + SDA_LET_GO
        STORE  R1, [I2C_PINS]
        JUMP   i2c_wait

; i2c_send, one byte out, highest bit first
; in R1 = byte, out R1 = 0 ACK, 1 NACK, R6 = byte, R7 = bits left, R2 = SDA bit
i2c_send: MOV R6, R1
        LOADLO R7, 8
send_bit: SHIFTI R2, R6, 0x07, 0b1000   ; bit 7 goes out
        ANDI   R2, R2, 0x0001
        SHIFTI R2, R2, 0x01, 0b0000     ; move to SDAs place, bit 1
        STORE  R2, [I2C_PINS]           ; set SDA, SCL low
        CALL   i2c_wait
        CALL   i2c_clock_up             ; SCL high, chip reads it
        STORE  R2, [I2C_PINS]           ; SCL low
        SHIFTI R6, R6, 0x01, 0b0000     ; next bit into bit 7
        DEC    R7
        CMPI   R7, 0x0000
        JNZ    send_bit
        LOADLO R2, SDA_LET_GO           ; 9th clock, let SDA go
        STORE  R2, [I2C_PINS]
        CALL   i2c_wait
        CALL   i2c_clock_up
        LOAD   R1, [I2C_PINS]
        SHIFTI R1, R1, 0x01, 0b1000     ; R1 = SDA, 0 ACK, 1 NACK
        ANDI   R1, R1, 0x0001
        STORE  R2, [I2C_PINS]           ; SCL low
        RET

; i2c_receive, one byte in, highest bit first
; in R1 = 1 ACK, 0 NACK, out R1 = byte, R6 = ACK or not, R7 = bits left, R4 = byte so far
i2c_receive: MOV R6, R1
        LOADLO R7, 8
        LOADLO R4, 0
receive_bit: LOADLO R2, SDA_LET_GO      ; let SDA go, chip sets it
        STORE  R2, [I2C_PINS]
        CALL   i2c_wait
        CALL   i2c_clock_up             ; SCL high, read the bit
        LOAD   R1, [I2C_PINS]
        SHIFTI R1, R1, 0x01, 0b1000
        ANDI   R1, R1, 0x0001
        SHIFTI R4, R4, 0x01, 0b0000     ; new bit in at the bottom
        OR     R4, R4, R1
        STORE  R2, [I2C_PINS]           ; SCL low
        DEC    R7
        CMPI   R7, 0x0000
        JNZ    receive_bit
        LOADLO R2, SDA_LET_GO           ; 9th clock, NACK = SDA high
        CMPI   R6, 0x0000
        JZ     receive_answer
        LOADLO R2, 0                    ; ACK = SDA low
receive_answer: STORE R2, [I2C_PINS]
        CALL   i2c_wait
        CALL   i2c_clock_up
        STORE  R2, [I2C_PINS]           ; SCL low
        LOADLO R2, SDA_LET_GO           ; let SDA go
        STORE  R2, [I2C_PINS]
        MOV    R1, R4
        RET

; i2c_read, see I2C_READ above
; R8 = chip address, R9 = register, R10 = bytes left, R11 = where the next goes
i2c_read: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        MOV    R9, R2
        MOV    R10, R3
        MOV    R11, R4
        CALL   i2c_start
        SHIFTI R1, R8, 0x01, 0b0000     ; address + 0, write
        CALL   i2c_send
        CMPI   R1, 0x0000
        JNZ    i2c_failed
        MOV    R1, R9
        CALL   i2c_send
        CMPI   R1, 0x0000
        JNZ    i2c_failed
        CALL   i2c_start                ; start again, now reading
        SHIFTI R1, R8, 0x01, 0b0000
        ORI    R1, R1, 0x0001           ; address + 1, read
        CALL   i2c_send
        CMPI   R1, 0x0000
        JNZ    i2c_failed
read_byte: LOADLO R1, 1                 ; ACK every byte but the last
        CMPI   R10, 1
        JNZ    read_this
        LOADLO R1, 0
read_this: CALL i2c_receive
        STOREB R1, [R11]
        INC    R11
        DEC    R10
        CMPI   R10, 0x0000
        JNZ    read_byte
        JUMP   i2c_done

; i2c_write, see I2C_WRITE above, same registers as i2c_read
i2c_write: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        MOV    R9, R2
        MOV    R10, R3
        MOV    R11, R4
        CALL   i2c_start
        SHIFTI R1, R8, 0x01, 0b0000     ; address + 0, write
        CALL   i2c_send
        CMPI   R1, 0x0000
        JNZ    i2c_failed
        MOV    R1, R9                   ; first register
        CALL   i2c_send
        CMPI   R1, 0x0000
        JNZ    i2c_failed
write_byte: CMPI R10, 0x0000            ; then the bytes
        JZ     i2c_done
        LOADB  R1, [R11]
        CALL   i2c_send
        CMPI   R1, 0x0000
        JNZ    i2c_failed
        INC    R11
        DEC    R10
        JUMP   write_byte

i2c_done: CALL i2c_stop
        LOADLO R1, 0
        JUMP   i2c_end
i2c_failed: CALL i2c_stop
        LOADLO R1, 1
i2c_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET
