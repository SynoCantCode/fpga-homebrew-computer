; small text tools, copy, length, reading words and numbers
; included by winlib.asm

; text_copy, in R1 = pointer to a text, R2 = where it goes
; out R2 = pointer to the 0 written after it, uses R1, R3
text_copy: LOADB R3, [R1]
        STOREB R3, [R2]
        CMPI   R3, 0x0000
        JZ     text_copy_done
        INC    R1
        INC    R2
        JUMP   text_copy
text_copy_done: RET

; text_length, in R1 = pointer to a text, out R2 = letters, uses R3
text_length: LOADLO R2, 0
text_length_next: ADD R3, R1, R2
        LOADB  R3, [R3]
        CMPI   R3, 0x0000
        JZ     text_length_done
        INC    R2
        JUMP   text_length_next
text_length_done: RET

; cut_word, 0 at its first space, in R1 = pointer, uses R1, R2
cut_word: LOADB R2, [R1]
        CMPI   R2, 0x0000
        JZ     cut_done
        CMPI   R2, 0x0020
        JZ     cut_here
        INC    R1
        JUMP   cut_word
cut_here: STOREB R0, [R1]
cut_done: RET

; skip_spaces, in/out R1 = pointer, moved past spaces, uses R2
skip_spaces: LOADB R2, [R1]
        CMPI   R2, 0x0020
        JNZ    skip_done
        INC    R1
        JUMP   skip_spaces
skip_done: RET

; read_word, next word, in R1 = pointer
; out R1 = just after it, R2 = start, R3 = length, 0 no word, uses R4
read_word: CALL skip_spaces
        MOV    R2, R1
read_word_next: LOADB R4, [R1]
        CMPI   R4, 0x0000
        JZ     read_word_end
        CMPI   R4, 0x0020
        JZ     read_word_end
        INC    R1
        JUMP   read_word_next
read_word_end: SUB R3, R1, R2
        RET

; read_number, next decimal number, in R1 = pointer
; out R1 = just after it, R2 = value, 0 if none, uses R3
read_number: CALL skip_spaces
        LOADLO R2, 0
read_number_next: LOADB R3, [R1]
        SUBI   R3, R3, 0x30
        CMPI   R3, 10
        JC     read_number_done         ; not a digit
        MULI   R2, R2, 10
        ADD    R2, R2, R3
        INC    R1
        JUMP   read_number_next
read_number_done: RET

; read_hex, next hex number, in R1 = pointer
; out R1 = just after it, R2 = value, uses R3
read_hex: CALL skip_spaces
        LOADLO R2, 0
read_hex_next: LOADB R3, [R1]
        CMPI   R3, 0x0061
        JNC    read_hex_big
        SUBI   R3, R3, 0x20             ; small letter made big
read_hex_big: SUBI R3, R3, 0x30
        CMPI   R3, 10
        JNC    read_hex_digit           ; 0-9
        SUBI   R3, R3, 7                ; A-F become 10-15
        CMPI   R3, 10
        JNC    read_hex_done
        CMPI   R3, 16
        JC     read_hex_done
read_hex_digit: SHIFTI R2, R2, 0x04, 0b0000
        OR     R2, R2, R3
        INC    R1
        JUMP   read_hex_next
read_hex_done: RET

; reading a text file line by line, load_text ended each line with a 0
; the pattern, for APPS.TXT, ICONS.TXT
; R8 = line_first(text, its end)
; loop: R8 = 0? done
; R1 = line_next(R8, end) first, and keep it
; cutting the line up writes 0s into it
; work on the line, first_word, read_number, read_word
; R8 = the next line kept above, again
; line_first, first real line from a place, blank lines and ; notes skipped
; in R1 = place in the text, R2 = text end, out R1 = line start or 0
; uses R3
line_first: CMP R1, R2
        JC     line_none                ; end of the text
        LOADB  R3, [R1]
        CMPI   R3, 0x0021
        JNC    line_blank               ; a 0 or a space
        CMPI   R3, 0x003B
        JZ     line_note                ; a note, whole line skipped
        RET
line_blank: INC R1
        JUMP   line_first
line_note: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     line_blank
        INC    R1
        JUMP   line_note
line_none: LOADLO R1, 0
        RET

; line_next, next real line after this one
; in R1 = line start, R2 = text end, out like line_first, uses R3
line_next: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     line_blank               ; end of this line, then like line_first
        INC    R1
        JUMP   line_next

; first_word, cuts off a lines first word with a 0, in R1 = line
; out R2 = word, R1 = rest of the line, uses R3, R4
first_word: CALL read_word              ; R2 = start, R1 = just after it
        LOADB  R4, [R1]
        STOREB R0, [R1]
        CMPI   R4, 0x0000
        JZ     first_word_done
        INC    R1
first_word_done: RET

; word_is, is a word this keyword, case ignored
; in R2 = pointer to word, R3 = length, R4 = pointer to keyword in small letters
; out R5 = 1 yes, 0 no, keeps R2, R3, uses R1, R6, R7
word_is: LOADLO R5, 0
        LOADLO R6, 0
word_is_next: CMP R6, R3
        JC     word_is_end
        ADD    R7, R2, R6
        LOADB  R7, [R7]
        CMPI   R7, 0x0041
        JNC    word_is_small
        CMPI   R7, 0x005B
        JC     word_is_small
        ADDI   R7, R7, 0x20
word_is_small: ADD R1, R4, R6
        LOADB  R1, [R1]
        CMP    R1, R7
        JNZ    word_is_done
        INC    R6
        JUMP   word_is_next
word_is_end: ADD R1, R4, R6
        LOADB  R1, [R1]
        CMPI   R1, 0x0000
        JNZ    word_is_done             ; keyword is longer
        LOADLO R5, 1
word_is_done: RET


; field_box, an inputs box, white with a grey line round it
; in R1 = x, R2 = y, R3 = width, R4 = height, R8-R11 = those
field_box: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        MOV    R9, R2
        MOV    R10, R3
        MOV    R11, R4
        LOADLO R5, SHADOW
        CALL   box                      ; grey all over
        ADDI   R1, R8, 1
        ADDI   R2, R9, 1
        SUBI   R3, R10, 2
        SUBI   R4, R11, 2
        LOADLO R5, WHITE_DOT
        CALL   box                      ; white inside
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET
