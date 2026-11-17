; notepad, type with the keyboard, point and click with the mouse
; a typewriter + a mouse pointer + click to move the cursor
; characters come from GET_CHAR, mouse bytes from GET_MOUSE_BYTE
; Esc quits back to the shell
.include "sw/os/devices.asm"
.org PROGRAM_START

; registers kept for the whole program, kernel calls don't change them
; R11 = text cursor, pointer to the cell where the next letter goes
; R12 = pointer to the start of the cursor's row
; R13 = pointer to mouse_state
; scratch, R3-R6 screen, R8-R10 mouse, kernel calls may change R1-R7

        LOADLO R13, mouse_state     ; R13 = the mouse variables
        CALL   clear_screen
        LOADHI R11, TEXT_SCREEN_HIGH    ; text cursor at cell 0, top-left
        LOADHI R12, TEXT_SCREEN_HIGH

        ; send the mouse 0xF4, start sending
        ; its answer 0xFA is skipped in mouse_byte
        LOADLO R3, 0x00F4
        STORE  R3, [MOUSE_DATA]
        CALL   show_pointer         ; pointer starts in the middle

; main loop, check the keyboard, then the mouse, forever
main:   CALL   GET_CHAR             ; R1 = next character typed, or -1
        CMPIS  R1, -1
        JZ     check_mouse
        CMPI   R1, 0x001B           ; Esc, quit
        JZ     quit
        MOV    R3, R1               ; screen_char wants it in R3
        CALL   hide_pointer         ; put the cell under the pointer back first
        CALL   screen_char          ; character onto the screen at the cursor
        CALL   show_pointer         ; pointer on top again
check_mouse: CALL GET_MOUSE_BYTE    ; R1 = next mouse byte, or -1
        CMPIS  R1, -1
        JZ     main
        MOV    R5, R1               ; mouse_byte wants it in R5
        CALL   mouse_byte
        JUMP   main

; quit, clean screen, back to the shell
quit:   CALL   SCREEN_CLEAR
        RET

; the mouse, 3 bytes make a packet
; mouse_byte, takes the byte in R5, uses the packet on byte 3
; byte 1, bit 0 = left button, bit 3 = always 1, bit 4 = X negative, bit 5 = Y negative
; byte 2 = X movement, + right. byte 3 = Y movement, + up
; uses R5, R8, R9, R10
mouse_byte: LOAD R8, [R13 + 20]      ; packet_count, bytes of this packet so far
        CMPI   R8, 0x0000
        JNZ    not_first
        CMPI   R5, 0x00FA           ; the mouse's OK to 0xF4, not part of a packet
        JZ     mouse_done
        ANDI   R9, R5, 0x0008       ; a first byte has bit 3 set
        JZ     mouse_done           ; out of step, skip it
        STORE  R5, [R13 + 24]        ; packet_first = byte 1
        LOADLO R8, 0x0001
        STORE  R8, [R13 + 20]        ; packet_count = 1
        RET
not_first: CMPI R8, 0x0001
        JNZ    third_byte
        STORE  R5, [R13 + 28]        ; packet_second = byte 2
        LOADLO R8, 0x0002
        STORE  R8, [R13 + 20]        ; packet_count = 2
        RET
third_byte: LOADLO R8, 0x0000
        STORE  R8, [R13 + 20]        ; packet_count = 0
        LOAD   R8, [R13 + 24]        ; R8 = byte 1, buttons and signs

        ; X = byte 2, sign extended if byte 1 bit 4 is set
        LOAD   R9, [R13 + 28]
        ANDI   R10, R8, 0x0010
        JZ     x_ready
        LOADHI R10, 0xFFFF
        ORI    R10, R10, 0xFF00
        OR     R9, R9, R10          ; 0xFD becomes 0xFFFF_FFFD = -3
x_ready: LOAD  R10, [R13 + 0]        ; mouse_x in pixels, 0-639
        ADD    R10, R10, R9         ; + the movement
        CMPI   R10, 0x0000          ; not below 0
        JGE    x_not_low
        LOADLO R10, 0x0000
x_not_low: CMPI R10, 640            ; not past 639
        JLT    x_ok
        LOADLO R10, 639
x_ok:   STORE  R10, [R13 + 0]

        ; Y = byte 3, same with byte 1 bit 5, then subtracted
        MOV    R9, R5
        ANDI   R10, R8, 0x0020
        JZ     y_ready
        LOADHI R10, 0xFFFF
        ORI    R10, R10, 0xFF00
        OR     R9, R9, R10
y_ready: LOAD  R10, [R13 + 4]        ; mouse_y in pixels, 0-479
        SUB    R10, R10, R9
        CMPI   R10, 0x0000
        JGE    y_not_low
        LOADLO R10, 0x0000
y_not_low: CMPI R10, 480
        JLT    y_ok
        LOADLO R10, 479
y_ok:   STORE  R10, [R13 + 4]

        ; move the highlight
        CALL   hide_pointer
        CALL   show_pointer

        ; click = left button up in the last packet, down in this one
        ANDI   R9, R8, 0x0001       ; left button now
        LOAD   R10, [R13 + 16]       ; last_buttons
        STORE  R9, [R13 + 16]
        CMPI   R9, 0x0000
        JZ     mouse_done           ; not down, no click
        CMPI   R10, 0x0000
        JNZ    mouse_done           ; held, not a new click
        CALL   cursor_to_pointer    ; click, text cursor jumps to the pointer
mouse_done: RET

; pointer_cell_address, out R10 = pointer cell, R9 = start of its row
; column = x / 8, row = y / 16
; row start = 0x2000_0000 + row x 320, cell = row start + column x 4
; uses R8, R9, R10
pointer_cell_address: LOAD R8, [R13 + 4]
        SHIFTI R8, R8, 0x04, 0b1000     ; R8 = row, y >> 4
        SHIFTI R9, R8, 0x08, 0b0000     ; row x 256
        SHIFTI R8, R8, 0x06, 0b0000     ; row x 64
        ADD    R9, R9, R8               ; row x 320
        LOADHI R8, 0x2000
        ADD    R9, R9, R8               ; R9 = the row's first cell
        LOAD   R8, [R13 + 0]
        SHIFTI R8, R8, 0x03, 0b1000     ; column, x >> 3
        SHIFTI R8, R8, 0x02, 0b0000     ; x 4, a cell is one word
        ADD    R10, R9, R8              ; R10 = the cell
        RET

; show_pointer, remembers the cell under the pointer, swaps its two colours
; 0x1F61 becomes 0xF161. uses R9, R10
show_pointer: PUSH R8                ; keep R8, mouse_byte needs byte 1 in it
        CALL   pointer_cell_address
        LOAD   R9, [R10 + 0x0000]   ; the cell as it is
        STORE  R10, [R13 + 8]        ; pointer_cell
        STORE  R9, [R13 + 12]        ; pointer_saved
        PUSH   R5
        ANDI   R8, R9, 0x00FF       ; the letter stays
        ANDI   R5, R9, 0x0F00       ; letter colour
        SHIFTI R5, R5, 0x04, 0b0000 ; up into the background place
        OR     R8, R8, R5
        ANDI   R5, R9, 0xF000       ; background colour
        SHIFTI R5, R5, 0x04, 0b1000 ; down into the letter colour place
        OR     R8, R8, R5
        POP    R5
        STORE  R8, [R10 + 0x0000]   ; the cell with its colours swapped
        POP    R8
        RET

; hide_pointer, puts the cell under the pointer back. uses R9, R10
hide_pointer: LOAD R10, [R13 + 8]    ; pointer_cell, 0 = not shown
        CMPI   R10, 0x0000
        JZ     hide_done
        LOAD   R9, [R13 + 12]        ; pointer_saved
        STORE  R9, [R10 + 0x0000]
        LOADLO R9, 0x0000
        STORE  R9, [R13 + 8]         ; nothing shown
hide_done: RET

; cursor_to_pointer, text cursor jumps to the pointer cell. uses R8, R9, R10
cursor_to_pointer: CALL pointer_cell_address
        MOV    R11, R10             ; next letter goes in the pointer cell
        MOV    R12, R9              ; its row is the pointer row
        RET

; screen_char
; puts the character in R3 on the screen at the cursor, moves the cursor
; Enter 0x0A = next row, Backspace 0x08 = step back and blank, Tab 0x09 = a space
; wraps at the end of a row, scrolls past the bottom row
; cell = background 4 bits, letter colour 4 bits, letter 8 bits, 0x1F00 = white on blue
; uses R3, R4, keeps R3
screen_char: CMPI R3, 0x000A        ; Enter?
        JZ     new_line
        CMPI   R3, 0x0008           ; Backspace?
        JZ     back_space
        MOV    R4, R3
        CMPI   R4, 0x0009           ; Tab? show a space
        JNZ    put_letter
        LOADLO R4, 0x0020
put_letter: ORI R4, R4, 0x1F00      ; add the colours
        STORE  R4, [R11 + 0x0000]   ; into the cell under the cursor
        ADDI   R11, R11, 4          ; cursor one cell right
        ADDI   R4, R12, 320         ; R4 = start of the next row, 80 cells x 4 bytes = 320
        CMP    R11, R4              ; off the end of this row?
        JZ     new_line             ; yes, wrap
        RET

; Backspace, only within this row
back_space: CMP R11, R12            ; at the start of the row?
        JZ     screen_done
        SUBI   R11, R11, 4          ; one cell back
        LOADLO R4, 0x1F20           ; a space on blue
        STORE  R4, [R11 + 0x0000]   ; rub the letter out
screen_done: RET

; next row, 320 bytes further, cursor at its left edge
; past row 29, 0x2000_2580, scroll instead
new_line: ADDI R12, R12, 320
        MOV    R11, R12
        LOADHI R4, 0x2000
        ORI    R4, R4, 0x2580       ; R4 = where row 30 would start
        CMP    R12, R4
        JNZ    screen_done          ; still on the screen
        ; scroll, copy every row up one, cell N + 80 to cell N
        PUSH   R5
        PUSH   R6
        LOADHI R5, 0x2000           ; R5 = cell being filled, from cell 0
        LOADLO R6, 2320             ; 29 rows x 80 cells to move
scroll_copy: LOAD R4, [R5 + 320]    ; the cell one row below
        STORE  R4, [R5 + 0x0000]    ; goes here
        ADDI   R5, R5, 4
        DEC    R6, 0b0100           ; sets Z at 0
        JNZ    scroll_copy
        ; bottom row becomes empty
        LOADLO R6, 80
        LOADLO R4, 0x1F20
scroll_clear: STORE R4, [R5 + 0x0000]
        ADDI   R5, R5, 4
        DEC    R6, 0b0100
        JNZ    scroll_clear
        POP    R6
        POP    R5
        SUBI   R12, R12, 320        ; cursor stays on row 29
        MOV    R11, R12
        RET

; clear_screen, all 2400 cells become a space on blue
; uses R4, R5, R6
clear_screen: LOADHI R5, 0x2000     ; cell 0
        LOADLO R6, 2400             ; 80 x 30 cells
        LOADLO R4, 0x1F20           ; a space, white on blue
clear_cell: STORE R4, [R5 + 0x0000]
        ADDI   R5, R5, 4
        DEC    R6, 0b0100
        JNZ    clear_cell
        RET

; the mouse variables, R13 points here
mouse_state: .word 320              ; +0  mouse_x in pixels, starts in the middle
        .word 240                   ; +4  mouse_y
        .word 0                     ; +8  pointer_cell, 0 = none
        .word 0                     ; +12 pointer_saved, that cell's real value
        .word 0                     ; +16 last_buttons, left button last packet
        .word 0                     ; +20 packet_count, bytes of this packet so far
        .word 0                     ; +24 packet_first, byte 1
        .word 0                     ; +28 packet_second, byte 2
