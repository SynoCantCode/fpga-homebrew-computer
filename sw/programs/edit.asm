; edit, a small text editor, run edit.bin story.txt
; opens the file or starts a new one
; saves it under the same name on quit
; typing puts a letter in at the cursor, Enter starts a new line
; Backspace, Del take out the letter before, at the cursor
; arrows move the cursor, Home, End go to the line's start, end
; Page Up, Down move 27 lines
; a click puts the cursor under the pointer
; the wheel moves 3 lines a notch
; Esc quits, asks to save if anything changed
; the whole file sits in RAM from BUFFER, 0x101C_0000, one byte per letter
; 0x0A ends a line, 0x0D bytes are taken out on open
; length = bytes of text, cursor = the byte the cursor is on
; top = the byte the screen's first row starts with
; changed = 1 once anything was typed or deleted
; typing moves the bytes after the cursor one up, deleting one down
; the whole screen is drawn again from top after every key or click
; rows 0-27 the text, row 28 the name, row 29 the keys
; starts with R2 = pointer to what was typed after its name
.include "sw/os/devices.asm"
.equ BUFFER_HIGH, 0x101C            ; the text lives at 0x101C_0000 in the SDRAM
.equ BUFFER_MAX_HIGH, 0x0004        ; most it can be, 0x0004_0000 = 256 KB
.equ TEXT_ROWS, 28                  ; screen rows 0-27 show the text
.equ NORMAL, 0x1F00                 ; background 1 blue-violet, letters F white
.equ CURSOR, 0xF100                 ; cursor cell, the two colours swapped
.equ BAR, 0x7000                    ; rows 28-29, background 7 silver, letters 0 black
.equ POINTER_ICON, 0x0080           ; mouse pointer, 0x80 = arrow, 0x81 = star, 0x82 = plus
.equ POINTER_COLOUR, 0x0E00         ; colour E yellow, on the cell's own background
; variables, in block RAM at PROGRAM_DATA
.equ length,        PROGRAM_DATA + 0   ; bytes of text
.equ cursor,        PROGRAM_DATA + 4   ; the byte the cursor is on
.equ top,           PROGRAM_DATA + 8   ; the byte the first row starts with
.equ changed,       PROGRAM_DATA + 12  ; 1 once anything changed
.equ cursor_cell,   PROGRAM_DATA + 16  ; pointer to the cursor's cell, 0 = not on the screen
.equ mouse_x,       PROGRAM_DATA + 20  ; mouse pointer in pixels, starts at 320, 240
.equ mouse_y,       PROGRAM_DATA + 24
.equ pointer_cell,  PROGRAM_DATA + 28  ; pointer to the cell the pointer is drawn on, 0 = not drawn
.equ pointer_saved, PROGRAM_DATA + 32  ; what that cell held
.equ last_buttons,  PROGRAM_DATA + 36  ; left button last time round
.equ file_name,     PROGRAM_DATA + 52  ; 0x40 bytes, the name, then a 0
.equ VARIABLES_END, PROGRAM_DATA + 116
.org PROGRAM_SDRAM

; start, clear the variables, get the file name, open the file
        LOADLO R5, PROGRAM_DATA
clear_variables: STORE R0, [R5]
        ADDI   R5, R5, 4
        CMPI   R5, VARIABLES_END
        JNZ    clear_variables
        LOADLO R5, 1                ; the button counts as held at the start
        STORE  R5, [last_buttons]
        LOADLO R5, file_name        ; copy the typed name into file_name, up to a space
        LOADLO R6, 0x003F           ; at most 0x3F letters
copy_name: LOADB R7, [R2]
        CMPI   R7, 0x0000
        JZ     name_done
        CMPI   R7, 0x0020
        JZ     name_done
        STOREB R7, [R5]
        INC    R2
        INC    R5
        DEC    R6, 0b0100
        JNZ    copy_name
name_done: STOREB R0, [R5]
        LOADB  R7, [file_name]
        CMPI   R7, 0x0000
        JNZ    open
        LA     R1, usage_text       ; no name given
        CALLF  SCREEN_LINE
        RET
open:   LOADLO R1, file_name
        CALLF  FILE_SIZE            ; R1 = 0 or an error, R2 = its size
        CMPI   R1, 0x0000
        JZ     have_size
        CMPI   R1, 13
        JNZ    open_failed          ; 13 = not there, a new empty file
        STORE  R0, [length]
        JUMP   opened
have_size: LOADHI R5, BUFFER_MAX_HIGH
        CMP    R5, R2
        JNC    too_big              ; too big to fit
        LOADLO R1, file_name
        LOADHI R2, BUFFER_HIGH
        CALLF  FILE_READ            ; the whole file into BUFFER, R2 = its size
        CMPI   R1, 0x0000
        JNZ    open_failed
        STORE  R2, [length]
        CALL   strip_cr             ; 0x0D 0x0A line ends become 0x0A
opened: STORE  R0, [cursor]
        STORE  R0, [top]
        STORE  R0, [changed]
        LOAD   R5, [KERNEL_CALLS + 4] ; start the mouse with the kernel's mouse_start
        CMPI   R5, 0x0000
        JZ     opened_plain
        CALLR  R5
        JUMP   opened_mouse
opened_plain: LOADLO R3, 0x00F4     ; no mouse_start, just "start sending"
        STORE  R3, [MOUSE_DATA]
opened_mouse: LOADLO R5, 320         ; the pointer starts in the middle
        STORE  R5, [MOUSE_X]
        STORE  R5, [mouse_x]
        LOADLO R5, 240
        STORE  R5, [MOUSE_Y]
        STORE  R5, [mouse_y]
        JUMP   main_draw
open_failed: MOV R8, R1             ; R8 = the error number
        LA     R1, open_error_text
        CALLF  SCREEN_TEXT
        MOV    R1, R8
        CALLF  SCREEN_HEX_WORD
        LOADLO R1, 0x000A
        CALLF  SCREEN_CHAR
        RET
too_big: LA     R1, too_big_text
        CALLF  SCREEN_LINE
        RET

; main loop, a key or a mouse byte, then draw
main_draw: CALL draw
        STORE  R0, [pointer_cell]   ; draw wrote every cell, put the pointer back
        CALL   show_pointer
main_key: CALLF GET_CHAR             ; R1 = next character, or -1
        CMPIS  R1, -1
        JZ     main_mouse
        CMPI   R1, 0x001B
        JZ     escape
        CMPI   R1, 0x0008
        JZ     key_backspace
        CMPI   R1, KEY_DELETE
        JZ     key_delete
        CMPI   R1, KEY_LEFT
        JZ     key_left
        CMPI   R1, KEY_RIGHT
        JZ     key_right
        CMPI   R1, KEY_UP
        JZ     key_up
        CMPI   R1, KEY_DOWN
        JZ     key_down
        CMPI   R1, KEY_HOME
        JZ     key_home
        CMPI   R1, KEY_END
        JZ     key_end
        CMPI   R1, KEY_PAGE_UP
        JZ     key_page_up
        CMPI   R1, KEY_PAGE_DOWN
        JZ     key_page_down
        CMPI   R1, 0x000A
        JZ     key_insert           ; Enter, a new line
        CMPI   R1, 0x0020
        JNC    main_key             ; other control characters ignored
        CMPI   R1, 0x007F
        JC     main_key             ; 0x7F and above, not a letter
key_insert: CALL insert
        JUMP   main_draw
key_backspace: LOAD R5, [cursor]
        CMPI   R5, 0x0000
        JZ     main_key             ; nothing before the cursor
        DEC    R5
        STORE  R5, [cursor]
        CALL   delete_here
        JUMP   main_draw
key_delete: CALL delete_here
        JUMP   main_draw
key_left: LOAD R5, [cursor]
        CMPI   R5, 0x0000
        JZ     main_key
        DEC    R5
        STORE  R5, [cursor]
        JUMP   main_draw
key_right: LOAD R5, [cursor]
        LOAD   R6, [length]
        CMP    R5, R6
        JC     main_key             ; already at the end
        INC    R5
        STORE  R5, [cursor]
        JUMP   main_draw
key_up: CALL   move_up
        JUMP   main_draw
key_down: CALL move_down
        JUMP   main_draw
key_home: LOAD R1, [cursor]
        CALL   line_start
        STORE  R1, [cursor]
        JUMP   main_draw
key_end: LOAD  R1, [cursor]
        CALL   line_end
        STORE  R1, [cursor]
        JUMP   main_draw
key_page_up: LOADLO R8, TEXT_ROWS - 1
page_up_next: CALL move_up
        DEC    R8, 0b0100
        JNZ    page_up_next
        JUMP   main_draw
key_page_down: LOADLO R8, TEXT_ROWS - 1
page_down_next: CALL move_down
        DEC    R8, 0b0100
        JNZ    page_down_next
        JUMP   main_draw
main_mouse: CALLF MOUSE_STATE        ; reads the waiting packets, R1 = pointer position
        CALL   mouse_moved          ; R2 = buttons
        LOAD   R8, [MOUSE_WHEEL]    ; wheel turned? notches, + toward you
        CMPI   R8, 0x0000
        JZ     main_key
        STORE  R0, [MOUSE_WHEEL]    ; taken
        MULI   R8, R8, 3            ; 3 lines a notch
        CMPIS  R8, 0
        JLT    wheel_up
wheel_down_next: CALL move_down
        DEC    R8, 0b0100
        JNZ    wheel_down_next
        JUMP   main_draw
wheel_up: SUB  R8, R0, R8
wheel_up_next: CALL move_up
        DEC    R8, 0b0100
        JNZ    wheel_up_next
        JUMP   main_draw

; quitting
escape: LOAD   R5, [changed]
        CMPI   R5, 0x0000
        JZ     quit                 ; nothing changed, nothing to save
        LA     R1, ask_text
        CALL   bottom_message       ; "Save the changes?"
ask_key: CALLF  GET_CHAR
        CMPIS  R1, -1
        JZ     ask_key
        CMPI   R1, 0x0079           ; y
        JZ     save_quit
        CMPI   R1, 0x0059           ; Y
        JZ     save_quit
        CMPI   R1, 0x006E           ; n
        JZ     quit
        CMPI   R1, 0x004E           ; N
        JZ     quit
        JUMP   main_draw            ; another key, keep editing
save_quit: LOADLO R1, file_name
        LOADHI R2, BUFFER_HIGH
        LOAD   R3, [length]
        CALLF  FILE_WRITE           ; save under the same name
        CMPI   R1, 0x0000
        JZ     quit
        MOV    R8, R1               ; didn't work, say so, wait for a key, keep editing
        LA     R1, save_error_text
        CALL   bottom_message       ; R2 = the cell after the text
        MOV    R1, R8
        CALL   put_hex
save_wait: CALLF GET_CHAR
        CMPIS  R1, -1
        JZ     save_wait
        JUMP   main_draw
quit:   CALLF  SCREEN_CLEAR         ; clean screen for the shell
        RET

; changing the text
; insert, puts the byte in R1 in at the cursor
; bytes from the cursor on move one up, from the end down. uses R2-R7
insert: LOAD   R6, [length]
        LOADHI R5, BUFFER_MAX_HIGH
        CMP    R6, R5
        JC     insert_full          ; buffer full, the letter is dropped
        LOADHI R5, BUFFER_HIGH
        LOAD   R7, [cursor]
        ADD    R2, R5, R6           ; R2 = pointer just past the last byte
        ADD    R3, R5, R7           ; R3 = pointer to the cursor's byte
insert_move: CMP R2, R3
        JZ     insert_put
        SUBI   R2, R2, 1
        LOADB  R4, [R2]
        STOREB R4, [R2 + 1]         ; one place up
        JUMP   insert_move
insert_put: STOREB R1, [R3]
        INC    R6
        STORE  R6, [length]
        INC    R7
        STORE  R7, [cursor]
        LOADLO R5, 1
        STORE  R5, [changed]
insert_full: RET

; delete_here, takes out the byte at the cursor. uses R2-R7
delete_here: LOAD R6, [length]
        LOAD   R7, [cursor]
        CMP    R7, R6
        JC     delete_none          ; cursor at the very end, nothing there
        LOADHI R5, BUFFER_HIGH
        ADD    R2, R5, R7           ; R2 = pointer to the cursor's byte
        ADD    R3, R5, R6
        SUBI   R3, R3, 1            ; R3 = pointer to the last byte
delete_move: CMP R2, R3
        JZ     delete_done
        LOADB  R4, [R2 + 1]
        STOREB R4, [R2]             ; one place down
        INC    R2
        JUMP   delete_move
delete_done: DEC R6
        STORE  R6, [length]
        LOADLO R5, 1
        STORE  R5, [changed]
delete_none: RET

; strip_cr, takes every 0x0D out of the text
; R5 = byte being read, R6 = where it goes, R7 = past the end. uses R4-R7
strip_cr: LOADHI R5, BUFFER_HIGH
        MOV    R6, R5
        LOAD   R7, [length]
        ADD    R7, R7, R5
strip_next: CMP R5, R7
        JZ     strip_done
        LOADB  R4, [R5]
        INC    R5
        CMPI   R4, 0x000D
        JZ     strip_next           ; 0x0D, skip it
        STOREB R4, [R6]
        INC    R6
        JUMP   strip_next
strip_done: LOADHI R5, BUFFER_HIGH
        SUB    R6, R6, R5
        STORE  R6, [length]
        RET

; lines
; line_start, in R1 = a byte number, out R1 = first byte of its line
; uses R5, R6
line_start: LOADHI R5, BUFFER_HIGH
line_start_back: CMPI R1, 0x0000
        JZ     line_start_done
        ADD    R6, R5, R1
        SUBI   R6, R6, 1
        LOADB  R6, [R6]             ; the byte before it
        CMPI   R6, 0x000A
        JZ     line_start_done
        DEC    R1
        JUMP   line_start_back
line_start_done: RET

; line_end, in R1 = a byte number, out R1 = the 0x0A ending its line, or length
; uses R5, R6, R7
line_end: LOAD R6, [length]
        LOADHI R5, BUFFER_HIGH
line_end_next: CMP R1, R6
        JC     line_end_done        ; end of the text
        ADD    R7, R5, R1
        LOADB  R7, [R7]
        CMPI   R7, 0x000A
        JZ     line_end_done
        INC    R1
        JUMP   line_end_next
line_end_done: RET

; move_up, cursor to the line above, same column if it fits, else its end
; R9 = this line's start, R10 = column. uses R1, R5-R7
move_up: LOAD  R1, [cursor]
        CALL   line_start
        MOV    R9, R1
        LOAD   R10, [cursor]
        SUB    R10, R10, R9         ; R10 = column
        CMPI   R9, 0x0000
        JZ     move_up_done         ; already on the first line
        SUBI   R1, R9, 1            ; the 0x0A ending the line above
        CALL   line_start           ; R1 = the line above's start
        ADD    R1, R1, R10          ; same column there
        SUBI   R5, R9, 1            ; R5 = the line above's end
        CMP    R5, R1
        JC     move_up_set          ; long enough
        MOV    R1, R5               ; shorter, go to its end
move_up_set: STORE R1, [cursor]
move_up_done: RET

; move_down, cursor to the line below, same column if it fits. uses R1, R5-R10
move_down: LOAD R1, [cursor]
        CALL   line_start
        LOAD   R10, [cursor]
        SUB    R10, R10, R1         ; R10 = column
        LOAD   R1, [cursor]
        CALL   line_end
        LOAD   R6, [length]
        CMP    R1, R6
        JC     move_down_done       ; already on the last line
        ADDI   R9, R1, 1            ; R9 = the line below's start
        MOV    R1, R9
        CALL   line_end             ; R1 = the line below's end
        ADD    R5, R9, R10          ; same column there
        CMP    R1, R5
        JNC    move_down_set        ; shorter, stay at its end
        MOV    R1, R5
move_down_set: STORE R1, [cursor]
move_down_done: RET

; the screen
; draw, the whole screen from top, rows 0-27 the text
; then the cursor's cell, then rows 28-29
; R8 = byte being drawn, R9 = pointer to the cell, R10 = row, R11 = column
; R12 = BUFFER, R13 = length, R14 = cursor
draw:   CALL   keep_cursor_visible
        LOADHI R9, TEXT_SCREEN_HIGH ; R9 = cell 0, 0x2000_0000
        LOAD   R8, [top]
        LOADLO R10, 0
        LOADLO R11, 0
        LOADHI R12, BUFFER_HIGH
        LOAD   R13, [length]
        LOAD   R14, [cursor]
        STORE  R0, [cursor_cell]    ; not found yet
draw_next: CMPI R10, TEXT_ROWS
        JZ     draw_cursor          ; every text row is drawn
        CMP    R8, R14
        JNZ    draw_not_cursor
        STORE  R9, [cursor_cell]    ; the cursor is on this cell
draw_not_cursor: CMP R8, R13
        JC     draw_blank_rest      ; text ended, the rest is empty
        ADD    R5, R12, R8
        LOADB  R5, [R5]             ; next letter
        INC    R8
        CMPI   R5, 0x000A
        JZ     draw_line_end
        ORI    R5, R5, NORMAL
        STORE  R5, [R9]
        ADDI   R9, R9, 4
        INC    R11
        CMPI   R11, 80
        JNZ    draw_next
        INC    R10                  ; 80 letters, go on in the next row
        LOADLO R11, 0
        JUMP   draw_next
draw_line_end: CALL blank_row_end   ; rest of this row is empty
        INC    R10
        LOADLO R11, 0
        JUMP   draw_next
draw_blank_rest: CMPI R10, TEXT_ROWS
        JZ     draw_cursor
        CALL   blank_row_end
        INC    R10
        LOADLO R11, 0
        JUMP   draw_blank_rest
draw_cursor: LOAD R5, [cursor_cell]
        CMPI   R5, 0x0000
        JZ     draw_bar
        LOAD   R6, [R5]
        ANDI   R6, R6, 0x00FF       ; its letter
        ORI    R6, R6, CURSOR       ; in the cursor's colours
        STORE  R6, [R5]
draw_bar: LOADHI R2, TEXT_SCREEN_HIGH   ; rows 28 and 29, silver, then the name and the keys
        ORI    R2, R2, 0x2300       ; cell 28 x 80 = 2240, x 4 = 0x2300
        LOADLO R5, BAR + 0x20
        LOADLO R6, 160              ; 2 rows of 80 cells
draw_bar_blank: STORE R5, [R2]
        ADDI   R2, R2, 4
        DEC    R6, 0b0100
        JNZ    draw_bar_blank
        LOADHI R2, TEXT_SCREEN_HIGH
        ORI    R2, R2, 0x2300
        LA     R1, bar_title
        CALL   put_text             ; " EDIT  "
        LOADLO R1, file_name
        CALL   put_text             ; the file name
        LOAD   R5, [changed]
        CMPI   R5, 0x0000
        JZ     draw_keys
        LA     R1, changed_text
        CALL   put_text             ; "   (changed)"
draw_keys: LOADHI R2, TEXT_SCREEN_HIGH
        ORI    R2, R2, 0x2440       ; cell 29 x 80 = 2320, x 4 = 0x2440
        LA     R1, keys_text
        JUMP   put_text             ; tail call

; blank_row_end, fills the rest of the row with empty cells
; in R9 = pointer to the cell, R11 = column, out R9 = next row's first cell. uses R5
blank_row_end: LOADLO R5, NORMAL + 0x20
blank_next: CMPI R11, 80
        JZ     blank_done
        STORE  R5, [R9]
        ADDI   R9, R9, 4
        INC    R11
        JUMP   blank_next
blank_done: RET

; keep_cursor_visible, moves top so the cursor's row is on the screen
; cursor above top, top = its line's start. 28 rows or more below, top moves down
; R8 = byte being counted, R9 = rows, R10 = column, R11 = cursor, R12 = BUFFER
keep_cursor_visible: LOAD R1, [cursor]
        LOAD   R5, [top]
        CMP    R1, R5
        JC     visible_count        ; cursor at or after top
        CALL   line_start
        STORE  R1, [top]
visible_count: LOAD R8, [top]
        LOADLO R9, 0
        LOADLO R10, 0
        LOAD   R11, [cursor]
        LOADHI R12, BUFFER_HIGH
visible_next: CMP R8, R11
        JZ     visible_check
        ADD    R5, R12, R8
        LOADB  R5, [R5]
        INC    R8
        CMPI   R5, 0x000A
        JZ     visible_row
        INC    R10
        CMPI   R10, 80
        JNZ    visible_next
visible_row: INC R9
        LOADLO R10, 0
        JUMP   visible_next
visible_check: CMPI R9, TEXT_ROWS
        JNC    visible_done         ; fewer than 28 rows below top, on the screen
        LOAD   R1, [top]
        CALL   line_end
        ADDI   R1, R1, 1            ; top = the next line's start
        STORE  R1, [top]
        JUMP   visible_count
visible_done: RET

; put_text, writes a text into cells in the bar's colours
; in R1 = pointer to the text, R2 = pointer to the first cell, out R2 = cell after. uses R5
put_text: LOADB R5, [R1]
        CMPI   R5, 0x0000
        JZ     put_text_done
        ORI    R5, R5, BAR
        STORE  R5, [R2]
        INC    R1
        ADDI   R2, R2, 4
        JUMP   put_text
put_text_done: RET

; put_hex, writes R1 as 8 hex digits into cells from R2. uses R1, R2, R5, R6
put_hex: LOADLO R6, 8
put_hex_next: SHIFTI R5, R1, 0x1C, 0b1000  ; top 4 bits
        SHIFTI R1, R1, 0x04, 0b0000        ; next 4 move up
        CMPI   R5, 0x000A
        JC     put_hex_letter
        ADDI   R5, R5, 0x30         ; 0-9
        JUMP   put_hex_store
put_hex_letter: ADDI R5, R5, 0x37   ; A-F, 0x41 - 0x0A
put_hex_store: ORI R5, R5, BAR
        STORE  R5, [R2]
        ADDI   R2, R2, 4
        DEC    R6, 0b0100
        JNZ    put_hex_next
        RET

; bottom_message, clears row 29 and writes the text at R1. out R2 = cell after. uses R1-R6
bottom_message: LOADHI R2, TEXT_SCREEN_HIGH
        ORI    R2, R2, 0x2440
        LOADLO R5, BAR + 0x20
        LOADLO R6, 80
bottom_blank: STORE R5, [R2]
        ADDI   R2, R2, 4
        DEC    R6, 0b0100
        JNZ    bottom_blank
        LOADHI R2, TEXT_SCREEN_HIGH
        ORI    R2, R2, 0x2440
        JUMP   put_text

; the mouse
; mouse_moved, moves the pointer, clicks if the left button just went down
; in R1 = x in bits 15-0, y in bits 31-16, pixels, R2 = buttons
; uses R1, R2, R5, R8-R13
mouse_moved: ANDI R5, R1, 0xFFFF
        SHIFTI R1, R1, 0x10, 0b1000
        LOAD   R8, [mouse_x]
        CMP    R5, R8
        JNZ    mouse_move
        LOAD   R8, [mouse_y]
        CMP    R1, R8
        JZ     mouse_buttons        ; didn't move
mouse_move: STORE R5, [mouse_x]
        STORE  R1, [mouse_y]
        PUSH   R2
        CALL   hide_pointer         ; pointer to its new place
        CALL   show_pointer
        POP    R2
mouse_buttons: ANDI R9, R2, 0x0001  ; click = left button up last time, down this time
        LOAD   R10, [last_buttons]
        STORE  R9, [last_buttons]
        CMPI   R9, 0x0000
        JZ     mouse_done
        CMPI   R10, 0x0000
        JNZ    mouse_done           ; held, not a new click
        CALL   click
mouse_done: RET

; pointer_cell_address, out R10 = pointer to the cell under the pointer
; column = x / 8, row = y / 16, cell = 0x2000_0000 + row x 320 + column x 4. uses R9, R10
pointer_cell_address: LOAD R10, [mouse_y]
        SHIFTI R10, R10, 0x04, 0b1000   ; row
        SHIFTI R9, R10, 0x08, 0b0000    ; row x 256
        SHIFTI R10, R10, 0x06, 0b0000   ; row x 64
        ADD    R10, R10, R9             ; row x 320
        LOAD   R9, [mouse_x]
        SHIFTI R9, R9, 0x03, 0b1000     ; column
        SHIFTI R9, R9, 0x02, 0b0000     ; x 4
        ADD    R10, R10, R9
        LOADHI R9, TEXT_SCREEN_HIGH
        ADD    R10, R10, R9
        RET

; show_pointer, remembers the cell under the pointer, draws the icon there
; uses R9, R10
show_pointer: CALL pointer_cell_address
        LOAD   R9, [R10]
        STORE  R10, [pointer_cell]  ; where the pointer is drawn
        STORE  R9, [pointer_saved]  ; what was there
        ANDI   R9, R9, 0xF000       ; the cell's background
        ORI    R9, R9, POINTER_COLOUR + POINTER_ICON
        STORE  R9, [R10]
        RET

; hide_pointer, puts the cell under the pointer back. uses R9, R10
hide_pointer: LOAD R10, [pointer_cell]
        CMPI   R10, 0x0000
        JZ     hide_done            ; not shown
        LOAD   R9, [pointer_saved]
        STORE  R9, [R10]
        STORE  R0, [pointer_cell]
hide_done: RET

; click, cursor to the letter under the pointer
; walks the text from top like draw, counting rows and columns
; R8 = byte, R9 = row, R10 = column, R11 = pointer row, R12 = pointer column, R13 = length
click:  LOAD   R11, [mouse_y]
        SHIFTI R11, R11, 0x04, 0b1000   ; pointer's row
        CMPI   R11, TEXT_ROWS
        JNC    click_text               ; rows 28-29 are the bar, no text
        RET
click_text: LOAD R12, [mouse_x]
        SHIFTI R12, R12, 0x03, 0b1000   ; its column
        LOAD   R8, [top]
        LOADLO R9, 0
        LOADLO R10, 0
        LOAD   R13, [length]
click_next: CMP R8, R13
        JC     click_found              ; end of the text
        CMP    R9, R11
        JNZ    click_walk               ; not the pointer's row yet
        CMP    R10, R12
        JZ     click_found              ; the pointer's column
        LOADHI R5, BUFFER_HIGH
        ADD    R5, R5, R8
        LOADB  R5, [R5]
        CMPI   R5, 0x000A
        JZ     click_found              ; line ends before the pointer's column
click_walk: LOADHI R5, BUFFER_HIGH
        ADD    R5, R5, R8
        LOADB  R5, [R5]
        INC    R8
        CMPI   R5, 0x000A
        JZ     click_row
        INC    R10
        CMPI   R10, 80
        JNZ    click_next
click_row: INC R9
        LOADLO R10, 0
        CMP    R9, R11
        JNC    click_next               ; still above the pointer's row
        CMP    R9, R11
        JZ     click_next
        DEC    R8                       ; went past it, end of the row before
click_found: STORE R8, [cursor]
        CALL   draw
        STORE  R0, [pointer_cell]
        JUMP   show_pointer             ; tail call

; texts
usage_text:      .string "use: run edit.bin NAME  (opens NAME, or starts it if it isn't there yet)"
open_error_text: .string "could not open the file, error "
too_big_text:    .string "that file is too big for the editor (256 KB at most)"
bar_title:       .string " EDIT  "
changed_text:    .string "   (changed)"
keys_text:       .string " Esc: save and quit   arrows Home End PgUp PgDn: move   click: put the cursor"
ask_text:        .string " Save the changes? y = save and quit, n = quit without saving, other = go back"
save_error_text: .string " could not save, error "
