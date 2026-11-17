; line, reading a whole typed line
; kept in LINE_BUFFER, one byte per character, 0 at the end
; LINE_LENGTH = characters so far
; every character goes into the buffer and onto the screen
; up to LINE_BUFFER_SIZE - 1 characters, more are ignored

; line_key, adds one typed character to the line
; in R1 = the character
; out R1 = 1 if it was Enter, else 0
; Enter 0x0A finishes the line, Backspace 0x08 takes one off
; other characters below 0x20 are ignored
line_key: LOAD R5, [LINE_LENGTH]        ; R5 = characters so far
        CMPI   R1, 0x000A
        JZ     line_enter
        CMPI   R1, 0x0008
        JZ     line_back_space
        CMPI   R1, 0x0020
        JNC    line_ignore              ; below 0x20, a control character
        CMPI   R5, LINE_BUFFER_SIZE - 1
        JZ     line_ignore              ; full
        LOADLO R6, LINE_BUFFER
        ADD    R6, R6, R5               ; R6 = next free byte
        STOREB R1, [R6]                 ; into the buffer
        INC    R5
        STORE  R5, [LINE_LENGTH]
        CALL   screen_char              ; and onto the screen
        LOADLO R1, 0x0000               ; not finished
        RET

line_back_space: CMPI R5, 0x0000
        JZ     line_ignore              ; nothing to take back
        DEC    R5                       ; one character fewer
        STORE  R5, [LINE_LENGTH]
        CALL   screen_char              ; R1 = Backspace, the screen rubs it out
        LOADLO R1, 0x0000
        RET

line_enter: LOADLO R6, LINE_BUFFER
        ADD    R6, R6, R5
        STOREB R0, [R6]                 ; 0 after the last character
        STORE  R0, [LINE_LENGTH]        ; ready for the next line
        CALL   screen_char              ; R1 = Enter, new line on the screen
        LOADLO R1, 0x0001               ; finished
        RET

line_ignore: LOADLO R1, 0x0000
        RET

; read_line, waits for a whole typed line
; out R1 = pointer to the line, LINE_BUFFER
; the shell calls line_key itself, it watches the UART too
read_line: CALL get_char                ; R1 = a character or -1
        CMPIS  R1, -1
        JZ     read_line                ; nothing typed
        CALL   line_key
        CMPI   R1, 0x0000
        JZ     read_line                ; not Enter yet
        LOADLO R1, LINE_BUFFER          ; R1 = pointer to the line
        RET
