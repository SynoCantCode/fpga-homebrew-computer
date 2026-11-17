; app library, text tools
; copy and compare texts, numbers as text, the text builder
; same names as the window manager's
; include it at the end of app.asm
; lines.asm after it for reading a file line by line
; routines only use R1-R7
; text_copy    R1 = from, R2 = to         -> R2 = the 0 written
; text_length  R1 = text                  -> R2 = letters
; text_lower   R1 = letter                -> R1 = it small
; text_same    R1, R2 = two texts         -> R3 = 1 same, else 0
; text_starts  R1 = text, R2 = start      -> R3 = 1 if R1 starts with R2
; number_text  R1 = number, R2 = where    -> decimal digits and a 0, R2 = that 0
; hex_char     R1 = number                -> R1 = bottom 4 bits as a hex digit
; bcd_text     R1 = BCD byte, R2 = where  -> 2 digits, R2 = after them
; tb_start     R1 = room in bytes         -> R1 = 1 ready, 0 no memory
; tb_text      R1 = text
; tb_char      R1 = letter
; tb_number    R1 = number, in decimal
; tb_hex2      R1 = byte, 2 hex digits
; tb_line      adds CR LF
; tb_save      R1 = path                  -> R1 = 0 saved, memory freed

; text_copy, in R1 = pointer to text, R2 = where, out R2 = the 0. uses R1, R3
text_copy: LOADB R3, [R1]
        STOREB R3, [R2]
        CMPI   R3, 0x0000
        JZ     text_copy_done
        INC    R1
        INC    R2
        JUMP   text_copy
text_copy_done: RET

; text_length, in R1 = pointer to text, out R2 = letters. uses R3
text_length: LOADLO R2, 0
text_length_next: ADD R3, R1, R2
        LOADB  R3, [R3]
        CMPI   R3, 0x0000
        JZ     text_length_done
        INC    R2
        JUMP   text_length_next
text_length_done: RET

; text_lower, A-Z to a-z, in and out R1
text_lower: CMPI R1, 0x0041
        JNC    text_lower_done
        CMPI   R1, 0x005B
        JC     text_lower_done
        ADDI   R1, R1, 0x0020
text_lower_done: RET

; text_same, two texts the same, ignoring case
; in R1, R2 = pointers, out R3 = 1 yes, 0 no. uses R1-R5
text_same: LOADB R4, [R1]
        LOADB  R5, [R2]
        PUSH   R1
        MOV    R1, R4
        CALL   text_lower
        MOV    R4, R1
        MOV    R1, R5
        CALL   text_lower
        MOV    R5, R1
        POP    R1
        CMP    R4, R5
        JNZ    text_differ
        CMPI   R4, 0x0000
        JZ     text_alike               ; both ended together
        INC    R1
        INC    R2
        JUMP   text_same
text_alike: LOADLO R3, 1
        RET
text_differ: LOADLO R3, 0
        RET

; text_starts, does a text start with another, ignoring case
; in R1 = pointer to text or 0, R2 = the start, out R3 = 1 yes, 0 no. uses R1-R5
text_starts: CMPI R1, 0x0000
        JZ     text_differ
text_starts_next: LOADB R4, [R2]
        CMPI   R4, 0x0000
        JZ     text_alike               ; all of it matched
        LOADB  R5, [R1]
        PUSH   R1
        MOV    R1, R4
        CALL   text_lower
        MOV    R4, R1
        MOV    R1, R5
        CALL   text_lower
        MOV    R5, R1
        POP    R1
        CMP    R4, R5
        JNZ    text_differ
        INC    R1
        INC    R2
        JUMP   text_starts_next

; number_text, a number in decimal, then a 0
; in R1 = number, R2 = where, 11 bytes, out R2 = the 0. uses R1, R3-R5
number_text: MOV R5, R2
        LOADLO R3, 0
number_text_digit: MODUI R4, R1, 10     ; digits onto the stack, last first
        ADDI   R4, R4, 0x0030
        PUSH   R4
        INC    R3
        DIVUI  R1, R1, 10
        CMPI   R1, 0x0000
        JNZ    number_text_digit
number_text_out: POP R4                 ; then off it, first first
        STOREB R4, [R5]
        INC    R5
        DEC    R3
        CMPI   R3, 0x0000
        JNZ    number_text_out
        STOREB R0, [R5]
        MOV    R2, R5
        RET

; hex_char, bottom 4 bits as a hex digit, in and out R1
hex_char: ANDI R1, R1, 0x000F
        ADDI   R1, R1, 0x0030
        CMPI   R1, 0x003A
        JNC    hex_char_done            ; 0-9
        ADDI   R1, R1, 7                ; A-F, ':' + 7 = 'A'
hex_char_done: RET

; bcd_text, a BCD byte as 2 letters, 0x59 = "59"
; in R1 = byte, R2 = where, out R2 = after them. uses R3
bcd_text: SHIFTI R3, R1, 0x04, 0b1000   ; tens, the top half
        ANDI   R3, R3, 0x000F
        ADDI   R3, R3, 0x0030
        STOREB R3, [R2]
        ANDI   R3, R1, 0x000F           ; ones, the bottom half
        ADDI   R3, R3, 0x0030
        STOREB R3, [R2 + 1]
        ADDI   R2, R2, 2
        RET

; the text builder
; tb_start, a new text, in R1 = bytes of room
; out R1 = 1 ready, 0 no memory
tb_start: PUSH R1
        CALLF  ALLOCATE
        POP    R3
        LA     R2, tb_base
        STORE  R1, [R2]
        STORE  R1, [R2 + 4]             ; tb_at, where the next letter goes
        ADD    R3, R1, R3
        STORE  R3, [R2 + 8]             ; tb_end, nothing is written past it
        CMPI   R1, 0x0000
        JZ     tb_start_done
        LOADLO R1, 1
tb_start_done: RET

; tb_text, add a text without its 0
; in R1 = pointer to it
tb_text: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     tb_done
        PUSH   R1
        MOV    R1, R3
        CALL   tb_char
        POP    R1
        INC    R1
        JUMP   tb_text
tb_done: RET

; tb_char, add one letter if there's room. in R1 = letter. uses R1, R2, R4, R5
tb_char: LA    R4, tb_base
        LOAD   R2, [R4 + 4]
        CMPI   R2, 0x0000
        JZ     tb_done                  ; no text being made
        LOAD   R5, [R4 + 8]
        CMP    R2, R5
        JC     tb_done                  ; no room, left out
        STOREB R1, [R2]
        INC    R2
        STORE  R2, [R4 + 4]
        RET

; tb_number, add a number in decimal
; in R1 = number
tb_number: LA  R2, tb_digits
        CALL   number_text
        LA     R1, tb_digits
        JUMP   tb_text

; tb_hex2, add a byte as 2 hex digits. in R1 = byte
tb_hex2: PUSH  R1
        SHIFTI R1, R1, 0x04, 0b1000
        CALL   hex_char
        CALL   tb_char
        POP    R1
        CALL   hex_char
        JUMP   tb_char

; tb_line, add CR LF, 0x0D 0x0A
tb_line: LOADLO R1, 0x000D
        CALL   tb_char
        LOADLO R1, 0x000A
        JUMP   tb_char

; tb_save, write the text to a file and free its memory
; in R1 = pointer to the path, out R1 = 0 saved, else an error, 1 = no memory
tb_save: LA    R4, tb_base
        LOAD   R2, [R4]
        CMPI   R2, 0x0000
        JZ     tb_save_none
        LOAD   R3, [R4 + 4]
        SUB    R3, R3, R2
        CALLF  FILE_WRITE
        PUSH   R1
        LA     R4, tb_base
        LOAD   R1, [R4]
        CALLF  FREE
        LA     R4, tb_base
        STORE  R0, [R4]
        STORE  R0, [R4 + 4]
        POP    R1
        RET
tb_save_none: LOADLO R1, 1
        RET

tb_base: .word 0                        ; the text being made, 0 = none
        .word  0                        ; tb_at, where the next letter goes
        .word  0                        ; tb_end, the room's end
tb_digits: .word 0                      ; digits for tb_number, 12 bytes
        .word  0
        .word  0
