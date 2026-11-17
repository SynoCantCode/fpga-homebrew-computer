; input, page buttons, typing into inputs, closing a window, keys to the front app
; included by wm.asm

; press_button, a click inside a page, finds the cell and the button or input there
; in R1 = the windows 128 bytes, R2 = pointer x, R3 = pointer y
; R8 = window, R9 = cell column, R10 = cell row, R11 = element pointer, R12 = count
press_button: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        MOV    R8, R1
        LOAD   R5, [R8 + W_STYLE]
        LOAD   R4, [R8 + W_X]
        SUB    R2, R2, R4
        LOAD   R4, [R5 + S_CONTENT_L]
        SUB    R2, R2, R4
        CMPIS  R2, 0
        JGE    press_across
        JUMP   press_done               ; left of the cells
press_across: SHIFTI R9, R2, 0x03, 0b1000
        LOAD   R4, [R8 + W_Y]
        SUB    R3, R3, R4
        LOAD   R4, [R5 + S_CONTENT_T]
        SUB    R3, R3, R4
        CMPIS  R3, 0
        JGE    press_down
        JUMP   press_done               ; above the cells
press_down: SHIFTI R10, R3, 0x04, 0b1000
        LOADLO R4, windows              ; add the scroll to get the pages row
        SUB    R4, R8, R4
        SHIFTI R4, R4, 0x07, 0b1000
        SHIFTI R4, R4, 0x02, 0b0000
        LOADLO R5, scroll_rows
        ADD    R4, R4, R5
        LOAD   R4, [R4]
        ADD    R10, R10, R4
        LOAD   R11, [R8 + W_ELEMENTS]
        LOAD   R12, [R8 + W_ELEMENT_COUNT]
press_next: CMPI R12, 0x0000
        JZ     press_done
        LOADB  R1, [R11]
        CMPI   R1, E_INPUT
        JNZ    press_not_input
        LOADB  R1, [R11 + 2]            ; an input, is the cell inside its box?
        CMP    R10, R1
        JNC    press_skip
        LOAD   R2, [R11 + 12]
        ADD    R1, R1, R2
        CMP    R10, R1
        JC     press_skip
        LOADB  R1, [R11 + 1]
        CMP    R9, R1
        JNC    press_skip
        LOAD   R2, [R11 + 8]
        ADD    R1, R1, R2
        CMP    R9, R1
        JC     press_skip
        LOADLO R2, 1
        STORE  R2, [pressed]
        LOADLO R2, windows              ; yes, typing goes to this window and input
        SUB    R1, R8, R2
        SHIFTI R1, R1, 0x07, 0b1000
        STORE  R1, [focus_window]
        STORE  R11, [focus_element]
        CALL   draw_window              ; draw again, shows the cursor
        JUMP   press_done
press_not_input: CMPI R1, E_BUTTON
        JNZ    press_skip
        LOADB  R1, [R11 + 2]
        CMP    R1, R10
        JNZ    press_skip               ; another row
        LOADB  R5, [R11 + 1]
        CMP    R9, R5
        JNC    press_skip               ; left of it
        LOAD   R1, [R11 + 4]
        CALL   text_length
        ADD    R5, R5, R2
        ADDI   R5, R5, 2
        CMP    R9, R5
        JC     press_skip               ; right of it
        LOADLO R1, 1
        STORE  R1, [pressed]
        LOAD   R1, [R11 + 8]            ; this button, its action
        CMPI   R1, ACTION_CLOSE
        JNZ    press_open
        MOV    R1, R8
        CALL   close_window
        JUMP   press_done
press_open: CMPI R1, ACTION_OPEN
        JNZ    press_event
        LOAD   R1, [R11 + 12]
        CALL   find_app_number
        CMPIS  R1, -1
        JZ     press_done               ; no such app
        CALL   launch_app
        JUMP   press_done
press_event: CMPI R1, ACTION_EVENT       ; event N goes to the apps button handler
        JNZ    press_done
        LOADLO R2, windows
        SUB    R1, R8, R2
        SHIFTI R1, R1, 0x07, 0b1000
        LOADLO R2, APP_BUTTON
        LOAD   R3, [R11 + 12]
        CALL   app_call
        JUMP   press_done
press_skip: ADDI R11, R11, ELEMENT_BYTES
        DEC    R12
        JUMP   press_next
press_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; nth_used, the Nth window in use
; in R1 = place on the taskbar, out R1 = window or -1, uses R1-R4
nth_used: LOADLO R2, 0
nth_used_next: CMPI R2, WINDOW_COUNT
        JZ     nth_none
        SHIFTI R3, R2, 0x07, 0b0000
        LOADLO R4, windows
        ADD    R3, R3, R4
        LOAD   R4, [R3 + W_KIND]
        CMPI   R4, KIND_NONE
        JZ     nth_used_skip
        CMPI   R1, 0x0000
        JZ     nth_found
        DEC    R1
nth_used_skip: INC R2
        JUMP   nth_used_next

; nth_icon, the icon in a place of the desktop grid
; in R1 = place, out R1 = app or file number, or -1, uses R1-R4
nth_icon: LOADLO R2, 0
nth_icon_next: LOAD R3, [app_count]
        CMP    R2, R3
        JC     nth_none
        SHIFTI R3, R2, 0x07, 0b0000
        LOAD   R4, [apps]
        ADD    R3, R3, R4
        LOAD   R4, [R3 + W_ICON]
        CMPI   R4, 0x0000
        JZ     nth_icon_skip            ; not on the desktop
        LOAD   R4, [R3 + A_PLACE]
        CMP    R4, R1
        JZ     nth_found
nth_icon_skip: INC R2
        JUMP   nth_icon_next
nth_found: MOV R1, R2
        RET
nth_none: NOT R1, R0
        RET

; type_key, a typed key into the input with the focus, in R1 = key
; 0x20-0x7E added up to INPUT_MAX, 0x0A = new row, 0x08 = backspace
; the window is drawn again
type_key: LOAD R2, [focus_window]
        CMPIS  R2, -1
        JZ     type_done                ; no input has the focus
        LOAD   R3, [focus_element]
        LOAD   R4, [R3 + 4]             ; R4 = its buffer
        MOV    R6, R1
        MOV    R1, R4
        CALL   text_length                   ; R2 = letters in it
        ADD    R5, R4, R2               ; R5 = pointer to its end
        CMPI   R6, 0x0008
        JNZ    type_not_back
        CMPI   R2, 0x0000
        JZ     type_done                ; nothing to take off
        SUBI   R5, R5, 1
        STOREB R0, [R5]
        JUMP   type_redraw
type_not_back: CMPI R6, 0x000A
        JZ     type_enter
        CMPI   R6, 0x0020
        JNC    type_done                ; not a letter
        CMPI   R6, 0x007F
        JC     type_done
        JUMP   type_add
type_enter: LOAD R7, [focus_element]    ; Enter, new line if the box has several rows
        LOAD   R7, [R7 + 12]            ; one row input, the apps key handler gets it
        CMPI   R7, 1                    ; 1 row?
        JNZ    type_add
        LOAD   R1, [focus_window]
        CMPI   R1, APP_SLOTS
        JC     type_done
        LOADLO R2, APP_KEY
        LOADLO R3, 0x000A
        JUMP   app_call
type_add: CMPI R2, INPUT_MAX
        JC     type_done                ; full
        STOREB R6, [R5]
        STOREB R0, [R5 + 1]
        PUSH   R5                       ; does it still fit in its box, wrapped?
        LOAD   R3, [focus_element]
        LOAD   R1, [R3 + 4]
        LOAD   R2, [R3 + 8]
        CALL   text_rows
        POP    R5
        LOAD   R3, [focus_element]
        LOAD   R2, [R3 + 12]
        CMP    R2, R1
        JC     type_redraw              ; yes
        STOREB R0, [R5]                 ; no, take the letter off again
        JUMP   type_done
type_redraw: LOAD R1, [focus_window]
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
type_done: RET

; unfocus, no input has the focus, window drawn again without the cursor
unfocus: LOAD  R1, [focus_window]
        CMPIS  R1, -1
        JZ     unfocus_done
        NOT    R2, R0
        STORE  R2, [focus_window]
        STORE  R0, [focus_element]
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
unfocus_done: RET

; close_window, hides a window and empties its inputs
; in R1 = its 128 bytes
; R8 = window, R9 = element pointer, R10 = elements left
close_window: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        STORE  R0, [R8 + W_VISIBLE]
        LOAD   R1, [R8 + W_APP]         ; a real app is told its closing
        CMPI   R1, 0x0000
        JZ     close_window_page
        LOADLO R2, windows
        SUB    R1, R8, R2
        SHIFTI R1, R1, 0x07, 0b1000
        LOADLO R2, APP_CLOSE
        CALL   app_call
close_window_page: LOAD R1, [R8 + W_KIND]
        CMPI   R1, KIND_PAGE
        JNZ    close_window_done
        LOAD   R9, [R8 + W_ELEMENTS]
        LOAD   R10, [R8 + W_ELEMENT_COUNT]
close_window_next: CMPI R10, 0x0000
        JZ     close_window_drawn
        LOADB  R1, [R9]
        CMPI   R1, E_INPUT
        JNZ    close_window_skip
        LOAD   R1, [R9 + 4]
        STOREB R0, [R1]                 ; emptied
close_window_skip: ADDI R9, R9, ELEMENT_BYTES
        DEC    R10
        JUMP   close_window_next
close_window_drawn: LOADLO R2, windows   ; slot emptied, its memory given back
        SUB    R1, R8, R2
        SHIFTI R1, R1, 0x07, 0b1000
        CALL   release_window
close_window_done: POP R10
        POP    R9
        POP    R8
        RET


; real apps, programs inside windows

; route_key, a key to the input with the focus, else to the front windows app
; in R1 = key
route_key: CMPI R1, KEY_PAGE_UP        ; Page Up / Page Down scroll the front window
        JZ     route_page
        CMPI   R1, KEY_PAGE_DOWN
        JZ     route_page
        CMPI   R1, KEY_UP               ; Up / Down scroll a row if the page is longer
        JZ     route_arrow
        CMPI   R1, KEY_DOWN
        JZ     route_arrow
route_key_on: LOAD R2, [focus_window]
        CMPIS  R2, -1
        JNZ    type_key
        PUSH   R1
        CALL   front_window             ; R1 = front window, -1 = none
        POP    R3
        CMPIS  R1, -1
        JZ     route_done
        CMPI   R1, APP_SLOTS
        JC     route_done               ; no such window
        LOADLO R2, APP_KEY
        JUMP   app_call
route_done: RET
; route_arrow, Up / Down scroll the front window a row if its page is longer
; a page that fits, the key goes to the input or the app
route_arrow: PUSH R1
        CALL   front_window
        POP    R3
        CMPIS  R1, -1
        JZ     route_arrow_on
        PUSH   R1
        PUSH   R3
        CALL   window_record
        LOAD   R4, [R1 + W_ROWS]        ; its rows
        POP    R3
        POP    R1
        SHIFTI R5, R1, 0x02, 0b0000     ; its pages rows, from page_rows_tab
        LOADLO R6, page_rows_tab
        ADD    R5, R5, R6
        LOAD   R5, [R5]
        CMP    R4, R5
        JC     route_arrow_on           ; page fits, nothing to scroll
        LOADLO R2, 1
        CMPI   R3, KEY_DOWN
        JZ     scroll_by
        NOT    R2, R0                   ; Up = -1
        JUMP   scroll_by
route_arrow_on: MOV R1, R3
        JUMP   route_key_on
; wheel_check, mouse wheel, MOUSE_WHEEL = notches turned
; window under the pointer scrolls WHEEL_ROWS rows a notch, + down, - up
; a page that fits, its app gets Down / Up keys instead
; called by the main loop, uses R1-R7
wheel_check: LOAD R1, [MOUSE_WHEEL]
        CMPI   R1, 0x0000
        JZ     wheel_done
        STORE  R0, [MOUSE_WHEEL]        ; taken, back to 0
        PUSH   R8
        PUSH   R9
        PUSH   R10
        MULI   R10, R1, WHEEL_ROWS      ; R10 = rows to move
        LOAD   R1, [mouse_point]
        ANDI   R8, R1, 0xFFFF           ; window_under wants x in R8, y in R9
        SHIFTI R9, R1, 0x10, 0b1000
        CALL   window_under             ; R1 = window under the pointer, or -1
        CMPIS  R1, -1
        JZ     wheel_end
        PUSH   R1
        CALL   window_record
        LOAD   R4, [R1 + W_ROWS]        ; its rows
        POP    R1
        SHIFTI R5, R1, 0x02, 0b0000     ; its pages rows, from page_rows_tab
        LOADLO R6, page_rows_tab
        ADD    R5, R5, R6
        LOAD   R5, [R5]
        CMP    R4, R5
        JC     wheel_keys               ; page fits, app gets arrow keys
        MOV    R2, R10
        CALL   scroll_by
        JUMP   wheel_end
wheel_keys: MOV R8, R1                  ; R8 = window, R9 = key, R10 = how many
        LOADLO R9, KEY_DOWN
        CMPIS  R10, 0
        JGE    wheel_key_next
        LOADLO R9, KEY_UP
        SUB    R10, R0, R10
wheel_key_next: MOV R1, R8
        LOADLO R2, APP_KEY
        MOV    R3, R9
        CALL   app_call                 ; no app in it, nothing happens
        DEC    R10, 0b0100
        JNZ    wheel_key_next
wheel_end: POP R10
        POP    R9
        POP    R8
wheel_done: RET

route_page: PUSH R1
        CALL   front_window
        POP    R3
        CMPIS  R1, -1
        JZ     route_done
        PUSH   R1
        PUSH   R3
        CALL   window_record
        LOAD   R2, [R1 + W_ROWS]
        SUBI   R2, R2, 1
        POP    R3
        POP    R1
        CMPI   R3, KEY_PAGE_DOWN
        JZ     scroll_by
        SUB    R2, R0, R2
        JUMP   scroll_by
