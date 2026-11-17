; screen, the text screen driver
; the cursor is kept in RAM
; SCREEN_CURSOR     pointer to the cell for the next character
; SCREEN_ROW_START  pointer to the first cell of the cursors row
; SCREEN_COLOUR     background in bits 15-12, letter in 11-8, 0x1F00 = white on blue
; 80 x 30 cells, cell N at TEXT_SCREEN + N x 4, a row is ROW_BYTES (320)
; in R1, may change R1-R7, keeps R8-R14

; screen_char, one character at the cursor, moves the cursor
; in R1 = the character
; Enter 0x0A = start of the next row, CR 0x0D = nothing
; Backspace 0x08 = step back and blank the cell, Tab 0x09 = a space
; wraps at the end of a row, scrolls past the bottom row
screen_char: LOAD R5, [SCREEN_CURSOR]   ; R5 = cell for this character
        LOAD   R6, [SCREEN_ROW_START]   ; R6 = start of its row
        CMPI   R1, 0x000A
        JZ     screen_new_line
        CMPI   R1, 0x000D
        JZ     screen_done
        CMPI   R1, 0x0008
        JZ     screen_back_space
        CMPI   R1, 0x0009
        JNZ    screen_put
        LOADLO R1, 0x0020               ; Tab is a space
screen_put: LOAD R7, [SCREEN_COLOUR]
        OR     R7, R7, R1               ; R7 = colours + character
        STORE  R7, [R5]                 ; into the cell
        ADDI   R5, R5, CELL_BYTES       ; cursor one cell right
        ADDI   R7, R6, ROW_BYTES        ; R7 = start of the next row
        CMP    R5, R7
        JZ     screen_new_line          ; end of the row, wrap
        STORE  R5, [SCREEN_CURSOR]
screen_done: RET

; Backspace, one cell back and blank it, not past the left edge
screen_back_space: CMP R5, R6
        JZ     screen_done
        SUBI   R5, R5, CELL_BYTES
        LOAD   R7, [SCREEN_COLOUR]
        ORI    R7, R7, 0x0020           ; a space in the current colours
        STORE  R7, [R5]
        STORE  R5, [SCREEN_CURSOR]
        RET

; next row, cursor at its left edge
; past the bottom row, scroll up one row and blank the bottom
screen_new_line: ADDI R6, R6, ROW_BYTES
        LOADHI R7, TEXT_SCREEN_HIGH
        ORI    R7, R7, TEXT_SCREEN_END - TEXT_SCREEN ; R7 = 0x2000_2580, where row 30 would start
        CMP    R6, R7
        JNZ    screen_row_ok            ; still on the screen
        LOADHI R5, TEXT_SCREEN_HIGH     ; R5 = cell being filled, from cell 0
        LOADLO R7, SCREEN_CELLS - SCREEN_COLUMNS ; 29 rows x 80 cells to move up
screen_scroll_copy: LOAD R2, [R5 + ROW_BYTES] ; R2 = the cell one row below
        STORE  R2, [R5]                 ; comes up here
        ADDI   R5, R5, CELL_BYTES
        DEC    R7, 0b0100               ; sets Z at 0
        JNZ    screen_scroll_copy
        LOADLO R7, SCREEN_COLUMNS       ; then blank the bottom row
        LOAD   R2, [SCREEN_COLOUR]
        ORI    R2, R2, 0x0020
screen_scroll_clear: STORE R2, [R5]
        ADDI   R5, R5, CELL_BYTES
        DEC    R7, 0b0100
        JNZ    screen_scroll_clear
        SUBI   R6, R6, ROW_BYTES        ; cursor stays on row 29
screen_row_ok: STORE R6, [SCREEN_ROW_START]
        STORE  R6, [SCREEN_CURSOR]
        RET

; screen_text, puts a 0 ended text on the screen
; in R1 = pointer to the text, kept in R8
screen_text: PUSH R8
        MOV    R8, R1                   ; R8 = pointer into the text
screen_text_next: LOADB R1, [R8]        ; R1 = one letter
        CMPI   R1, 0x0000
        JZ     screen_text_done         ; 0, end of the text
        CALL   screen_char
        INC    R8
        JUMP   screen_text_next
screen_text_done: POP R8
        RET

; screen_line, the same, then a new line
; in R1 = pointer to the text
screen_line: CALL screen_text
        LOADLO R1, 0x000A
        JUMP   screen_char              ; tail call

; screen_clear, every cell a space, cursor to the top left
screen_clear: LOADHI R5, TEXT_SCREEN_HIGH ; R5 = cell 0
        STORE  R5, [SCREEN_CURSOR]
        STORE  R5, [SCREEN_ROW_START]
        LOADLO R6, SCREEN_CELLS         ; 2400 cells
        LOAD   R7, [SCREEN_COLOUR]
        ORI    R7, R7, 0x0020           ; R7 = a space in the current colours
screen_clear_next: STORE R7, [R5]
        ADDI   R5, R5, CELL_BYTES
        DEC    R6, 0b0100
        JNZ    screen_clear_next
        RET

; screen_hex_word, a 32 bit number as 8 hex digits
; in R1 = the number
; R8 = the number, R9 = digits left
screen_hex_word: PUSH R8
        PUSH   R9
        MOV    R8, R1                   ; R8 = the number
        LOADLO R9, 0x0008               ; 8 digits
screen_hex_digit: SHIFTI R1, R8, 0x1C, 0b1000 ; R1 = top 4 bits, one digit
        CMPI   R1, 0x000A
        JNC    screen_hex_number
        ADDI   R1, R1, 0x0037           ; 10-15 to 'A'-'F'
        JUMP   screen_hex_put
screen_hex_number: ADDI R1, R1, 0x0030  ; 0-9 to '0'-'9'
screen_hex_put: CALL screen_char
        SHIFTI R8, R8, 0x04, 0b0000     ; next digit to the top
        DEC    R9, 0b0100
        JNZ    screen_hex_digit
        POP    R9
        POP    R8
        RET
