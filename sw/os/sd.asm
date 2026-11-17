; SD, the SD card driver
; the card is a row of 512 byte blocks
; read and written with byte swaps through the SPI controller
; a command is always 6 bytes
; [0x40 + command number][4 bytes argument, highest first][CRC + a final 1 bit]
; the response is 1 byte, 0x00 = OK, 0x01 = OK but idle, else an error
; the card sends 0xFF when it has nothing to say
; sd_init, 80 clock ticks with nobody selected, then selected and slow
; CMD0 go idle, into SPI mode, answers 0x01
; CMD8 3.3 V, answers 0x01 and echoes 0x1AA
; CMD55 + CMD41 start up, repeated until it answers 0x00
; CMD58 card kind, bit 30 = 1 high capacity, block numbers
; 0 = old small card, byte numbers, then the SPI clock goes fast
; in R1-R4, out R1, may change R1-R7, keeps R8-R14
; error numbers, 0 = fine
; 1 = no answer to CMD0     2 = CMD8 refused     3 = never finished waking up
; 4 = CMD58 refused     5 = read refused     6 = no data from a read     7 = write refused
; 8 = written data rejected     9 = sd_init not done yet

; spi_swap, sends one byte and gives back the one that came in
; in R1 = byte to send, out R1 = byte received, uses R5
spi_swap: STORE R1, [SPI_DATA]          ; start the swap
spi_swap_wait: LOAD R5, [SPI_STATUS]
        ANDI   R5, R5, SPI_BUSY
        JNZ    spi_swap_wait            ; wait until its done
        LOAD   R1, [SPI_DATA]           ; the byte that came back
        RET

; sd_command, sends one command and gets its response
; in R1 = command number, R2 = argument, R3 = CRC, only checked for CMD0/CMD8
; out R1 = response, or 0xFF if no answer
; R8 = argument, R9 = CRC, R10 = tries left
sd_command: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R2
        MOV    R9, R3
        ORI    R10, R1, 0x0040          ; first byte, 01 + command number
        LOADLO R1, 0x00FF
        CALL   spi_swap                 ; one spare byte first
        MOV    R1, R10
        CALL   spi_swap                 ; command byte
        SHIFTI R1, R8, 0x18, 0b1000
        CALL   spi_swap                 ; argument, highest byte first
        SHIFTI R1, R8, 0x10, 0b1000
        CALL   spi_swap
        SHIFTI R1, R8, 0x08, 0b1000
        CALL   spi_swap
        MOV    R1, R8
        CALL   spi_swap
        MOV    R1, R9
        CALL   spi_swap                 ; CRC
        LOADLO R10, 10                  ; 10 tries for the response
sd_command_wait: LOADLO R1, 0x00FF
        CALL   spi_swap
        ANDI   R5, R1, 0x0080           ; a response has its top bit 0
        JZ     sd_command_done
        DEC    R10, 0b0100
        JNZ    sd_command_wait
        LOADLO R1, 0x00FF               ; no answer
sd_command_done: POP R10
        POP    R9
        POP    R8
        RET

; sd_finish, deselects the card and sends one more byte
sd_finish: STORE R0, [SPI_SELECT]
        LOADLO R1, 0x00FF
        JUMP   spi_swap

; sd_init, wakes the card up, out R1 = 0 or an error number
; SD_STATE = 1 old small card, byte numbers, 2 high capacity, block numbers
; R8 = tries left
sd_init: PUSH R8
        STORE  R0, [SD_STATE]           ; not ready yet
        LOADLO R1, SPI_SLOW
        STORE  R1, [SPI_SPEED]          ; slow, under 400 kHz
        STORE  R0, [SPI_SELECT]         ; nobody selected
        LOADLO R8, 10
sd_init_clocks: LOADLO R1, 0x00FF
        CALL   spi_swap                 ; 10 bytes = 80 clock ticks
        DEC    R8, 0b0100
        JNZ    sd_init_clocks
        LOADLO R1, SELECT_SD_CARD
        STORE  R1, [SPI_SELECT]

        LOADLO R8, 10                   ; CMD0, go idle
sd_init_cmd0: LOADLO R1, 0
        LOADLO R2, 0
        LOADLO R3, 0x0095               ; CMD0 CRC
        CALL   sd_command
        CMPI   R1, 0x0001
        JZ     sd_init_cmd8
        DEC    R8, 0b0100
        JNZ    sd_init_cmd0
        LOADLO R1, 1                    ; error 1, no answer
        JUMP   sd_init_end

sd_init_cmd8: LOADLO R1, 8              ; CMD8, 3.3 V, check pattern 0xAA
        LOADLO R2, 0x01AA
        LOADLO R3, 0x0087               ; CMD8 CRC
        CALL   sd_command
        CMPI   R1, 0x0001
        JNZ    sd_init_cmd8_refused
        LOADLO R8, 4                    ; skip the 4 more bytes of its answer
sd_init_cmd8_more: LOADLO R1, 0x00FF
        CALL   spi_swap
        DEC    R8, 0b0100
        JNZ    sd_init_cmd8_more

        LOADLO R8, 0xFFFF               ; CMD55 + CMD41 until it answers 0x00
sd_init_acmd41: LOADLO R1, 55           ; CMD55, next is an app command
        LOADLO R2, 0
        LOADLO R3, 0x0001
        CALL   sd_command
        LOADLO R1, 41                   ; CMD41, start up, argument bit 30 = high capacity ok
        LOADHI R2, 0x4000
        LOADLO R3, 0x0001
        CALL   sd_command
        CMPI   R1, 0x0000
        JZ     sd_init_cmd58            ; 0x00, awake
        DEC    R8, 0b0100
        JNZ    sd_init_acmd41
        LOADLO R1, 3                    ; error 3, never woke up
        JUMP   sd_init_end

sd_init_cmd58: LOADLO R1, 58            ; CMD58, read the OCR
        LOADLO R2, 0
        LOADLO R3, 0x0001
        CALL   sd_command
        CMPI   R1, 0x0000
        JNZ    sd_init_cmd58_refused
        LOADLO R1, 0x00FF
        CALL   spi_swap                 ; OCR first byte, bit 6 = high capacity
        ANDI   R8, R1, 0x0040
        LOADLO R1, 0x00FF
        CALL   spi_swap                 ; other 3 bytes, not needed
        LOADLO R1, 0x00FF
        CALL   spi_swap
        LOADLO R1, 0x00FF
        CALL   spi_swap
        LOADLO R1, 1                    ; SD_STATE 1, old small card
        CMPI   R8, 0x0000
        JZ     sd_init_kind
        LOADLO R1, 2                    ; SD_STATE 2, high capacity
sd_init_kind: STORE R1, [SD_STATE]
        LOADLO R1, SPI_FAST
        STORE  R1, [SPI_SPEED]          ; SPI clock fast
        LOADLO R1, 0                    ; ok
        JUMP   sd_init_end

sd_init_cmd8_refused: LOADLO R1, 2      ; error 2, old SD 1.x card
        JUMP   sd_init_end
sd_init_cmd58_refused: LOADLO R1, 4     ; error 4
sd_init_end: MOV R8, R1
        CALL   sd_finish
        MOV    R1, R8                   ; R1 = the answer
        POP    R8
        RET

; sd_address, block number for high capacity, block x 512 for an old card
; in R1 = block number, out R1 = address to send
sd_address: LOAD R5, [SD_STATE]
        CMPI   R5, 0x0002
        JZ     sd_address_done
        SHIFTI R1, R1, 0x09, 0b0000     ; x 512
sd_address_done: RET

; sd_read_block, reads one 512 byte block into memory
; in R1 = block number, R2 = where the bytes go, out R1 = 0 or an error number
; R8 = pointer, R9 = bytes / tries left
sd_read_block: PUSH R8
        PUSH   R9
        MOV    R8, R2
        LOAD   R5, [SD_STATE]
        CMPI   R5, 0x0000
        JZ     sd_read_not_ready
        CALL   sd_address
        MOV    R2, R1
        LOADLO R1, SELECT_SD_CARD
        STORE  R1, [SPI_SELECT]
        LOADLO R1, 17                   ; CMD17, read one block
        LOADLO R3, 0x0001
        CALL   sd_command
        CMPI   R1, 0x0000
        JNZ    sd_read_refused
        LOADLO R9, 0xFFFF               ; wait for the start byte, 0xFE
sd_read_wait: LOADLO R1, 0x00FF
        CALL   spi_swap
        CMPI   R1, 0x00FE
        JZ     sd_read_data
        DEC    R9, 0b0100
        JNZ    sd_read_wait
        LOADLO R1, 6                    ; error 6, no data
        JUMP   sd_read_end
sd_read_data: LOADLO R9, 512
sd_read_next: LOADLO R1, 0x00FF
        CALL   spi_swap                 ; one byte of the block
        STOREB R1, [R8]                 ; into memory
        INC    R8
        DEC    R9, 0b0100
        JNZ    sd_read_next
        LOADLO R1, 0x00FF
        CALL   spi_swap                 ; 2 CRC bytes, not used
        LOADLO R1, 0x00FF
        CALL   spi_swap
        LOADLO R1, 0                    ; ok
        JUMP   sd_read_end
sd_read_refused: LOADLO R1, 5           ; error 5
        JUMP   sd_read_end
sd_read_not_ready: LOADLO R1, 9         ; error 9, sd_init first
sd_read_end: MOV R9, R1
        CALL   sd_finish
        MOV    R1, R9
        POP    R9
        POP    R8
        RET

; sd_write_block, writes 512 bytes from memory into one block
; in R1 = block number, R2 = pointer to the bytes, out R1 = 0 or an error number
; R8 = pointer, R9 = bytes / tries left
sd_write_block: PUSH R8
        PUSH   R9
        MOV    R8, R2
        LOAD   R5, [SD_STATE]
        CMPI   R5, 0x0000
        JZ     sd_write_not_ready
        CALL   sd_address
        MOV    R2, R1
        LOADLO R1, SELECT_SD_CARD
        STORE  R1, [SPI_SELECT]
        LOADLO R1, 24                   ; CMD24, write one block
        LOADLO R3, 0x0001
        CALL   sd_command
        CMPI   R1, 0x0000
        JNZ    sd_write_refused
        LOADLO R1, 0x00FF
        CALL   spi_swap                 ; one spare byte
        LOADLO R1, 0x00FE
        CALL   spi_swap                 ; start byte
        LOADLO R9, 512
sd_write_next: LOADB R1, [R8]           ; one byte from memory
        CALL   spi_swap                 ; to the card
        INC    R8
        DEC    R9, 0b0100
        JNZ    sd_write_next
        LOADLO R1, 0x00FF
        CALL   spi_swap                 ; 2 CRC bytes, not checked in SPI mode
        LOADLO R1, 0x00FF
        CALL   spi_swap
        LOADLO R1, 0x00FF
        CALL   spi_swap                 ; xxx0_0101 = accepted
        ANDI   R1, R1, 0x001F
        CMPI   R1, 0x0005
        JNZ    sd_write_rejected
        LOADLO R9, 0xFFFF               ; busy saving, sends 0x00 until done
sd_write_busy: LOADLO R1, 0x00FF
        CALL   spi_swap
        CMPI   R1, 0x00FF
        JZ     sd_write_done
        DEC    R9, 0b0100
        JNZ    sd_write_busy
sd_write_done: LOADLO R1, 0             ; ok
        JUMP   sd_write_end
sd_write_refused: LOADLO R1, 7          ; error 7
        JUMP   sd_write_end
sd_write_rejected: LOADLO R1, 8         ; error 8
        JUMP   sd_write_end
sd_write_not_ready: LOADLO R1, 9        ; error 9
sd_write_end: MOV R9, R1
        CALL   sd_finish
        MOV    R1, R9
        POP    R9
        POP    R8
        RET
