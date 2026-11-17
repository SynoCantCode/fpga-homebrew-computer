; text builder, a text file made a piece at a time, then saved
; and small letter and number tools
; included by winlib.asm
;
; making a file, like ICONS.TXT, "pong 9" a line
;         LOADLO R1, 1024          ; room for it
; CALL   tb_start          ; R1 = 0 no memory
; LA     R1, name          ; for each line
;         CALL   tb_text           ;   a text
;         LOADLO R1, 0x0020
;         CALL   tb_char           ;   a letter
;         LOADLO R1, 9
;         CALL   tb_number         ;   a number, in decimal
; CALL   tb_line           ;   line end, CR LF
;         LA     R1, path
; CALL   tb_save           ; written to the card, R1 = 0 saved
; one text at a time, in tb_base, tb_at, tb_end
; every tb_ routine keeps R8-R14, uses R1-R7
; a text longer than the room is cut short

; tb_start, new text, in R1 = bytes it may need, out R1 = 1 ready, 0 no memory
tb_start: PUSH R1
        CALLF  ALLOCATE
        POP    R2
        STORE  R1, [tb_base]
        STORE  R1, [tb_at]
        ADD    R2, R1, R2               ; end of the room
        STORE  R2, [tb_end]
        CMPI   R1, 0x0000
        JZ     tb_start_done
        LOADLO R1, 1
tb_start_done: RET

; tb_text, adds a text without its 0, a letter at a time
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

; tb_char, adds one letter if theres room, in R1 = letter, uses R1-R3
tb_char: LOAD  R2, [tb_at]
        CMPI   R2, 0x0000
        JZ     tb_done                  ; no text being made
        LOAD   R3, [tb_end]
        CMP    R2, R3
        JC     tb_done                  ; end of the room, left out
        STOREB R1, [R2]
        INC    R2
        STORE  R2, [tb_at]
        RET

; tb_number, adds a number in decimal, digits made in tb_digits
; in R1 = number
tb_number: LOADLO R2, tb_digits
        CALL   number_text
        LOADLO R1, tb_digits
        JUMP   tb_text

; tb_hex2, adds a byte as 2 hex digits, in R1 = byte
tb_hex2: PUSH  R1
        SHIFTI R1, R1, 0x04, 0b1000
        CALL   hex_char
        CALL   tb_char
        POP    R1
        CALL   hex_char
        JUMP   tb_char

; tb_line, adds a line end, CR LF (0x0D 0x0A)
tb_line: LOADLO R1, 0x000D
        CALL   tb_char
        LOADLO R1, 0x000A
        JUMP   tb_char

; tb_save, writes the text to the card as a file, frees its memory
; in R1 = pointer to path, out R1 = 0 saved, else an error, 1 = no memory
tb_save: LOAD  R2, [tb_base]
        CMPI   R2, 0x0000
        JZ     tb_save_none
        LOAD   R3, [tb_at]
        SUB    R3, R3, R2
        CALLF  FILE_WRITE
        PUSH   R1
        LOAD   R1, [tb_base]
        CALLF  FREE
        STORE  R0, [tb_base]
        STORE  R0, [tb_at]
        POP    R1
        RET
tb_save_none: LOADLO R1, 1
        RET

; letters and numbers

; text_lower, A-Z to a-z, in/out R1
text_lower: CMPI R1, 0x0041
        JNC    lower_done
        CMPI   R1, 0x005B
        JC     lower_done
        ADDI   R1, R1, 0x0020
lower_done: RET

; text_starts, does a text start with another, case ignored
; in R1 = pointer to text or 0, R2 = pointer to the start, out R3 = 1 yes, 0 no
; uses R1-R5
text_starts: CMPI R1, 0x0000
        JZ     starts_no
starts_next: LOADB R4, [R2]
        CMPI   R4, 0x0000
        JZ     starts_yes               ; all of it matched
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
        JNZ    starts_no
        INC    R1
        INC    R2
        JUMP   starts_next
starts_yes: LOADLO R3, 1
        RET
starts_no: LOADLO R3, 0
        RET

; hex_char, bottom 4 bits as a hex digit, in/out R1
hex_char: ANDI R1, R1, 0x000F
        ADDI   R1, R1, 0x0030
        CMPI   R1, 0x003A
        JNC    hex_char_done            ; 0-9
        ADDI   R1, R1, 7                ; A-F, ':' + 7 = 'A'
hex_char_done: RET

; make_point, x and y as one point, y in the top 16 bits
; in R1 = x, R2 = y, out R1 = point, uses R2
make_point: SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        RET
