; mem, the note, time, pins, desktop
; included by shell.asm

; mem, the memory map
; mem_table row = first address, last address, pointer to description
; 0 description ends the table, R8 walks it
command_mem: PUSH R8
        LA     R8, mem_table
mem_next: LOAD R5, [R8 + 8]
        CMPI   R5, 0x0000
        JZ     mem_done
        LOAD   R1, [R8]
        CALLF  screen_hex_word          ; first address
        LOADLO R1, 0x002D
        CALLF  screen_char              ; -
        LOAD   R1, [R8 + 4]
        CALLF  screen_hex_word          ; last address
        LA     R1, two_spaces
        CALLF  screen_text
        LOAD   R1, [R8 + 8]
        CALLF  screen_line              ; description
        ADDI   R8, R8, 12               ; next row
        JUMP   mem_next
mem_done: POP R8
        RET

; note_take, first line of the note into LINE_BUFFER, rest moved up
; R1 = read pointer, R2 = write pointer, R3 = byte
note_take: LOADLO R1, NEXT_COMMANDS
        LOADLO R2, LINE_BUFFER
take_next: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     take_last                ; end of the note, last line
        INC    R1
        CMPI   R3, 0x000A
        JZ     take_rest                ; end of the line
        STOREB R3, [R2]
        INC    R2
        JUMP   take_next
take_last: STOREB R0, [R2]
        STOREB R0, [NEXT_COMMANDS]      ; note is empty
        RET
take_rest: STOREB R0, [R2]
        LOADLO R2, NEXT_COMMANDS        ; move the other lines to the front
take_move: LOADB R3, [R1]
        STOREB R3, [R2]
        INC    R1
        INC    R2
        CMPI   R3, 0x0000
        JNZ    take_move
        RET

; time, date and time from the DS3231 at I2C 0x68, YYYY-MM-DD HH:MM:SS
; registers 0-6 = seconds, minutes, hours, weekday, date, month, year
; each is BCD, shown as 2 hex digits
; masks, seconds and minutes 0x7F, hours 0x3F, date 0x3F, month 0x1F
; time YYMMDDHHMMSS sets it, then shows it
command_time: LOADB R5, [R1]
        CMPI   R5, 0x0000
        JNZ    time_set
        LOADLO R1, CLOCK_CHIP           ; 7 registers into TIME_BYTES
        LOADLO R2, 0
        LOADLO R3, 7
        LOADLO R4, TIME_BYTES
        CALLF  I2C_READ
        CMPI   R1, 0x0000
        JNZ    time_missing
        LA     R1, century_text         ; "20"
        CALLF  screen_text
        LOADB  R1, [TIME_BYTES + 6]     ; year
        CALL   time_two
        LOADLO R1, 0x002D               ; '-'
        CALLF  screen_char
        LOADB  R1, [TIME_BYTES + 5]     ; month
        ANDI   R1, R1, 0x001F
        CALL   time_two
        LOADLO R1, 0x002D
        CALLF  screen_char
        LOADB  R1, [TIME_BYTES + 4]     ; date
        ANDI   R1, R1, 0x003F
        CALL   time_two
        LOADLO R1, 0x0020
        CALLF  screen_char
        LOADB  R1, [TIME_BYTES + 2]     ; hours
        ANDI   R1, R1, 0x003F
        CALL   time_two
        LOADLO R1, 0x003A               ; ':'
        CALLF  screen_char
        LOADB  R1, [TIME_BYTES + 1]     ; minutes
        ANDI   R1, R1, 0x007F
        CALL   time_two
        LOADLO R1, 0x003A
        CALLF  screen_char
        LOADB  R1, [TIME_BYTES]         ; seconds
        ANDI   R1, R1, 0x007F
        CALL   time_two
        LOADLO R1, 0x000A
        JUMPF  screen_char
time_missing: LA R1, no_clock_text
        JUMPF  screen_line
; time_two, shows a BCD byte as 2 digits, in R1 = the byte
time_two: PUSH R1
        SHIFTI R1, R1, 0x04, 0b1000     ; tens, top 4 bits
        ANDI   R1, R1, 0x000F
        ADDI   R1, R1, 0x0030
        CALLF  screen_char
        POP    R1
        ANDI   R1, R1, 0x000F           ; ones, bottom 4 bits
        ADDI   R1, R1, 0x0030
        JUMPF  screen_char
; time_set, 12 digits, YY MM DD HH MM SS into registers 6, 5, 4, 2, 1, 0
; weekday register 3 = 1, written over I2C, then shown
; R8 = pointer into the digits, R7 = 1 if a pair wasnt 2 digits
time_set: PUSH R8
        MOV    R8, R1
        LOADLO R7, 0
        CALL   time_pair
        STOREB R1, [TIME_BYTES + 6]
        CALL   time_pair
        STOREB R1, [TIME_BYTES + 5]
        CALL   time_pair
        STOREB R1, [TIME_BYTES + 4]
        CALL   time_pair
        STOREB R1, [TIME_BYTES + 2]
        CALL   time_pair
        STOREB R1, [TIME_BYTES + 1]
        CALL   time_pair
        STOREB R1, [TIME_BYTES]
        LOADLO R1, 1
        STOREB R1, [TIME_BYTES + 3]
        POP    R8
        CMPI   R7, 0x0000
        JNZ    time_usage
        LOADLO R1, CLOCK_CHIP
        LOADLO R2, 0
        LOADLO R3, 7
        LOADLO R4, TIME_BYTES
        CALLF  I2C_WRITE
        CMPI   R1, 0x0000
        JNZ    time_missing
        LA     R1, blank                ; set, show it
        JUMP   command_time
time_usage: LA R1, time_usage_text
        JUMPF  screen_line
; time_pair, 2 digits to a BCD byte, in R8 = pointer, moved on 2
; out R1 = the byte, R7 = 1 if not 2 digits
time_pair: LOADB R1, [R8]
        SUBI   R1, R1, 0x0030           ; '0'-'9' to 0-9, anything else is 10 or more
        CMPI   R1, 10
        JC     time_pair_bad
        LOADB  R2, [R8 + 1]
        SUBI   R2, R2, 0x0030
        CMPI   R2, 10
        JC     time_pair_bad
        SHIFTI R1, R1, 0x04, 0b0000     ; tens into the top 4 bits
        OR     R1, R1, R2
        ADDI   R8, R8, 2
        RET
time_pair_bad: LOADLO R7, 1
        LOADLO R1, 0
        RET

; pins, the 16 pins of the MCP23017 at I2C 0x20, A0-A7 and B0-B7
; a pin is an input with pull-up or an output
; pins            shows them, "A 0b0000_0001  B 0b0000_0000", bit 0 = pin 0
; pins out HHHH   which pins are outputs, low byte = A, high byte = B, 1 = output
; pins set HHHH   output levels, same order, 1 = high
; registers, IODIR 0x00/0x01 (1 = input), GPPU 0x0C/0x0D (1 = pull-up)
; GPIO 0x12/0x13, OLAT 0x14/0x15, R8 = pointer into the line
command_pins: PUSH R8
        MOV    R8, R1
        LOADB  R5, [R8]
        CMPI   R5, 0x0000
        JZ     pins_show
        LA     R2, pins_out_name
        CALL   word_is
        CMPI   R1, 0x0000
        JNZ    pins_out
        MOV    R1, R8
        LA     R2, pins_set_name
        CALL   word_is
        CMPI   R1, 0x0000
        JNZ    pins_set
        LA     R1, pins_usage_text
        POP    R8
        JUMPF  screen_line
; pins out HHHH, IODIR and GPPU = NOT the bits
pins_out: MOV R1, R8
        CALL   after_word
        CALL   parse_hex                ; R1 = the 16 bits, R2 = 0 if not hex
        CMPI   R2, 0x0000
        JZ     pins_bad
        NOT    R1, R1
        STOREB R1, [TIME_BYTES]         ; IODIRA, IODIRB
        SHIFTI R2, R1, 0x08, 0b1000
        STOREB R2, [TIME_BYTES + 1]
        LOADLO R1, PINS_CHIP
        LOADLO R2, 0x00
        LOADLO R3, 2
        LOADLO R4, TIME_BYTES
        CALLF  I2C_WRITE
        CMPI   R1, 0x0000
        JNZ    pins_missing
        LOADLO R1, PINS_CHIP            ; same bits, pull-ups on the inputs
        LOADLO R2, 0x0C
        LOADLO R3, 2
        LOADLO R4, TIME_BYTES
        CALLF  I2C_WRITE
        JUMP   pins_show
; pins set HHHH, OLATA, OLATB = the bits
pins_set: MOV R1, R8
        CALL   after_word
        CALL   parse_hex
        CMPI   R2, 0x0000
        JZ     pins_bad
        STOREB R1, [TIME_BYTES]
        SHIFTI R2, R1, 0x08, 0b1000
        STOREB R2, [TIME_BYTES + 1]
        LOADLO R1, PINS_CHIP
        LOADLO R2, 0x14
        LOADLO R3, 2
        LOADLO R4, TIME_BYTES
        CALLF  I2C_WRITE
        CMPI   R1, 0x0000
        JNZ    pins_missing
; pins_show, reads GPIOA, GPIOB, shows 8 bits each
pins_show: LOADLO R1, PINS_CHIP
        LOADLO R2, 0x12
        LOADLO R3, 2
        LOADLO R4, TIME_BYTES
        CALLF  I2C_READ
        CMPI   R1, 0x0000
        JNZ    pins_missing
        LA     R1, pins_a_text          ; "A 0b"
        CALLF  screen_text
        LOADB  R1, [TIME_BYTES]
        CALL   pins_bits
        LA     R1, pins_b_text          ; "  B 0b"
        CALLF  screen_text
        LOADB  R1, [TIME_BYTES + 1]
        CALL   pins_bits
        LOADLO R1, 0x000A
        POP    R8
        JUMPF  screen_char
pins_bad: LA R1, pins_usage_text
        POP    R8
        JUMPF  screen_line
pins_missing: LA R1, no_pins_text
        POP    R8
        JUMPF  screen_line
; pins_bits, a byte as 8 binary digits, highest first, _ after 4
; in R1 = the byte, R8 = the byte, R7 = count
pins_bits: PUSH R8
        MOV    R8, R1
        LOADLO R7, 8
pins_bit: SHIFTI R1, R8, 0x07, 0b1000
        ANDI   R1, R1, 0x0001
        ADDI   R1, R1, 0x0030
        PUSH   R7
        CALLF  screen_char
        POP    R7
        SHIFTI R8, R8, 0x01, 0b0000
        DEC    R7
        CMPI   R7, 4
        JNZ    pins_no_gap
        LOADLO R1, 0x005F               ; '_'
        PUSH   R7
        CALLF  screen_char
        POP    R7
pins_no_gap: CMPI R7, 0x0000
        JNZ    pins_bit
        POP    R8
        RET

; desktop, starts the window manager /wm.bin
command_desktop: LA R1, wm_path
        JUMP   run_file

; tables and texts
