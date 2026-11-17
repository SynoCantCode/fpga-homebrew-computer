; reading the words of a line, spaces, words, hex and decimal numbers
; included by shell.asm

; skip_spaces, in R1 = pointer into a text, out R1 = pointer to the first non space
skip_spaces: LOADB R5, [R1]
        CMPI   R5, 0x0020
        JNZ    skip_done
        INC    R1
        JUMP   skip_spaces
skip_done: RET

; after_word, in R1 = pointer to a word, out R1 = pointer to the next word
after_word: LOADB R5, [R1]
        CMPI   R5, 0x0000
        JZ     skip_spaces              ; end of the line
        CMPI   R5, 0x0020
        JZ     skip_spaces              ; word ended, skip the spaces
        INC    R1
        JUMP   after_word

; word_is, is the word at R1 exactly this name?
; in R1 = pointer to the word, R2 = pointer to the name
; out R1 = 1 if they match, else 0
word_is: LOADB R5, [R1]                 ; R5 = character of the word
        LOADB  R6, [R2]                 ; R6 = character of the name
        CMPI   R6, 0x0000
        JZ     word_name_end            ; whole name matched
        CMP    R5, R6
        JNZ    word_no
        INC    R1
        INC    R2
        JUMP   word_is
word_name_end: CMPI R5, 0x0000          ; the word must end here too
        JZ     word_yes
        CMPI   R5, 0x0020
        JZ     word_yes
word_no: LOADLO R1, 0x0000
        RET
word_yes: LOADLO R1, 0x0001
        RET

; parse_hex, reads a hex number, 0-9 a-f A-F, at most 8 digits count
; in R1 = pointer to it, out R1 = the number
; R2 = pointer to the next word, or 0 if not a hex number
parse_hex: LOADLO R6, 0x0000            ; R6 = number so far
        LOADLO R7, 0x0000               ; R7 = digits so far
hex_next: LOADB R5, [R1]                ; R5 = next character
        CMPI   R5, 0x0061
        JNC    hex_not_lower            ; below 'a'
        SUBI   R5, R5, 0x0020           ; 'a'-'f' to 'A'-'F'
hex_not_lower: CMPI R5, 0x0030
        JNC    hex_end                  ; below '0', not a digit
        CMPI   R5, 0x003A
        JNC    hex_decimal_digit        ; '0'-'9'
        CMPI   R5, 0x0041
        JNC    hex_end                  ; between '9' and 'A'
        CMPI   R5, 0x0047
        JC     hex_end                  ; 'G' or above
        SUBI   R5, R5, 0x0037           ; 'A'-'F' to 10-15
        JUMP   hex_add
hex_decimal_digit: SUBI R5, R5, 0x0030  ; '0'-'9' to 0-9
hex_add: SHIFTI R6, R6, 0x04, 0b0000    ; number up one hex digit
        OR     R6, R6, R5               ; new digit at the bottom
        INC    R7
        INC    R1
        JUMP   hex_next
hex_end: CMPI R7, 0x0000
        JZ     hex_none                 ; no digits
        CMPI   R5, 0x0000
        JZ     hex_skip                 ; line ended after it, fine
        CMPI   R5, 0x0020
        JNZ    hex_none                 ; not a space after it, not a number
hex_skip: LOADB R5, [R1]                ; past the spaces after it
        CMPI   R5, 0x0020
        JNZ    hex_done
        INC    R1
        JUMP   hex_skip
hex_done: MOV R2, R1
        MOV    R1, R6
        RET
hex_none: LOADLO R2, 0x0000
        RET

; parse_decimal, reads a decimal number, digits 0-9 only
; in R1 = pointer to it, out R1 = the number
; R2 = pointer to the next word, or 0 if not a decimal number
parse_decimal: LOADLO R6, 0x0000        ; R6 = number so far
        LOADLO R7, 0x0000               ; R7 = digits so far
decimal_next: LOADB R5, [R1]            ; R5 = next character
        CMPI   R5, 0x0030
        JNC    decimal_end              ; below '0', not a digit
        CMPI   R5, 0x003A
        JC     decimal_end              ; above '9', not a digit
        SUBI   R5, R5, 0x0030           ; '0'-'9' to 0-9
        MULI   R6, R6, 10               ; number x 10
        ADD    R6, R6, R5               ; new digit at the bottom
        INC    R7
        INC    R1
        JUMP   decimal_next
decimal_end: CMPI R7, 0x0000
        JZ     decimal_none             ; no digits
        CMPI   R5, 0x0000
        JZ     decimal_skip             ; line ended after it, fine
        CMPI   R5, 0x0020
        JNZ    decimal_none             ; not a space after it, not a number
decimal_skip: LOADB R5, [R1]            ; past the spaces after it
        CMPI   R5, 0x0020
        JNZ    decimal_done
        INC    R1
        JUMP   decimal_skip
decimal_done: MOV R2, R1
        MOV    R1, R6
        RET
decimal_none: LOADLO R2, 0x0000
        RET

; show_word, prints "AAAAAAAA: WWWWWWWW", an address and its word
; in R1 = the address, a multiple of 4, R8 keeps it
show_word: PUSH R8
        MOV    R8, R1
        CALLF  screen_hex_word          ; the address
        LA     R1, colon
        CALLF  screen_text
        LOAD   R1, [R8]                 ; R1 = the word at that address
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        POP    R8
        RET

; the commands, each gets R1 = pointer to the text after its name
