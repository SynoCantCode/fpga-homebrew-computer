; elements, adding one, making room, deleting
; included by studio.asm

; tool, a toolbar button, in R1 = its number
tool:   CMPI   R1, 0
        JZ     add_text
        CMPI   R1, 1
        JZ     add_box
        CMPI   R1, 2
        JZ     add_input
        CMPI   R1, 3
        JZ     add_button
        CMPI   R1, 4
        JZ     next_sprite
        CMPI   R1, 5
        JZ     add_canvas
        CMPI   R1, 6
        JZ     next_style
        CMPI   R1, 7
        JZ     next_colour
        CMPI   R1, 8
        JZ     next_action
        CMPI   R1, 9
        JZ     save_page
        CMPI   R1, 10
        JZ     add_to_desktop
        CMPI   R1, 11
        JZ     next_icon
        RET

; add_text, add_box, add_input, add_button, a new element under the others
add_text: PUSH R8
        LOADLO R8, E_TEXT_LINE
        LA     R2, sample_text
        JUMP   add_element
add_box: PUSH  R8
        LOADLO R8, E_BOX
        LA     R2, sample_box
        JUMP   add_element
add_canvas: PUSH R8
        LOADLO R8, E_CANVAS
        LA     R2, empty_text
        JUMP   add_element
add_input: PUSH R8
        LOADLO R8, E_INPUT
        LA     R2, empty_text
        JUMP   add_element
add_button: PUSH R8
        LOADLO R8, E_BUTTON
        LA     R2, sample_button
; add_element, in R8 = kind, R2 = its first text
; R9 = window, R10 = element, R11 = text copy
add_element: PUSH R9
        PUSH   R10
        PUSH   R11
        PUSH   R2
        LOADLO R1, 0
        CALL   window_record
        MOV    R9, R1
        CALL   new_element
        MOV    R10, R1
        POP    R2
        CMPI   R10, 0x0000
        JZ     add_full
        PUSH   R2
        LOADLO R1, 0x0104               ; own copy of the text, with room to type
        CALLF  ALLOCATE
        MOV    R11, R1
        POP    R1
        MOV    R2, R11
        CALL   text_copy
        CALL   free_row                 ; first row under the others
        STOREB R1, [R10 + 2]            ; its row
        STOREB R8, [R10]                ; its kind
        STORE  R11, [R10 + 4]           ; its text
        LOADLO R1, 1
        STOREB R1, [R10 + OWN_TEXT]
        STOREB R0, [R10 + 1]
        LOAD   R1, [R9 + W_COLUMNS]     ; box up to 16 x 3, input up to 16 x 2
        CMPI   R1, 17
        JNC    add_width
        LOADLO R1, 16
add_width: STORE R1, [R10 + 8]
        LOADLO R1, 3
        CMPI   R8, E_INPUT
        JNZ    add_height
        LOADLO R1, 2
add_height: STORE R1, [R10 + 12]
        CMPI   R8, E_BUTTON
        JNZ    add_drawn
        LOADLO R1, ACTION_CLOSE         ; a button closes its window
        STORE  R1, [R10 + 8]
        STORE  R0, [R10 + 12]
add_drawn: MOV R1, R10                  ; room for it below the others?
        MOV    R2, R9
        CALL   element_cells
        ADD    R1, R2, R4
        CALL   make_room
        CMPI   R1, 0x0000
        JNZ    add_room
        LOAD   R1, [R9 + W_ELEMENT_COUNT]   ; no room, take it off again
        DEC    R1
        STORE  R1, [R9 + W_ELEMENT_COUNT]
        LA     R1, no_room_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   add_end
add_room: STORE R10, [selected]
        STORE  R0, [title_selected]
        LOADLO R1, 0
        CALL   draw_window
        LA     R1, added_text
        STORE  R1, [status]
        JUMP   add_end
add_full: LA   R1, full_text
        STORE  R1, [status]
add_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; free_row, the first row under every element
; out R1 = the row, uses R1-R7
free_row: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R9, [R8 + W_ELEMENTS]
        LOAD   R10, [R8 + W_ELEMENT_COUNT]
        LOADLO R11, 0
free_next: CMPI R10, 0x0000
        JZ     free_found
        LOADB  R1, [R9]
        CMPI   R1, 0x0000
        JZ     free_skip
        CMPI   R1, E_WRAP               ; a paragraph counts its first row only
        JNZ    free_size
        LOADB  R1, [R9 + 2]
        ADDI   R1, R1, 1
        JUMP   free_bottom
free_size: MOV R1, R9
        MOV    R2, R8
        CALL   element_cells
        ADD    R1, R2, R4
free_bottom: CMP R1, R11
        JNC    free_skip
        MOV    R11, R1
free_skip: ADDI R9, R9, ELEMENT_BYTES
        DEC    R10
        JUMP   free_next
free_found: MOV R1, R11
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; make_room, grows window 0 down, up to MAX_ROWS
; in R1 = rows needed, out R1 = 1 ok, 0 too tall, uses R1-R5
make_room: PUSH R8
        MOV    R3, R1
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [R8 + W_ROWS]
        CMP    R1, R3
        JC     room_yes                 ; has them already
        CMPI   R3, MAX_ROWS + 1
        JC     room_page                ; too tall for the window, the page grows
        STORE  R3, [R8 + W_ROWS]
        MOV    R1, R8
        CALL   window_size
        CALL   keep_on_screen
room_yes: LOADLO R1, 1
        JUMP   room_end
room_page: CMPI R3, PAGE_MAX + 1
        JC     room_no                  ; past the pages last row
        LOAD   R1, [R8 + W_ROWS]        ; scroll so its bottom shows
        SUB    R1, R3, R1
        STORE  R1, [scroll_rows]
        JUMP   room_yes
room_no: LOADLO R1, 0
room_end: POP R8
        RET

; delete_selected, takes the selected element out of the page
delete_selected: LOAD R1, [selected]
        CMPI   R1, 0x0000
        JNZ    delete_go
        RET
delete_go: PUSH R8
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R2, [selected]           ; from the selected one
        LOAD   R3, [R8 + W_ELEMENTS]
        LOAD   R4, [R8 + W_ELEMENT_COUNT]
        SHIFTI R4, R4, 0x05, 0b0000
        ADD    R4, R3, R4               ; to the end of the elements
delete_move: ADDI R5, R2, ELEMENT_BYTES
        CMP    R5, R4
        JC     delete_moved
        LOAD   R6, [R5]
        STORE  R6, [R2]
        ADDI   R2, R2, 4
        JUMP   delete_move
delete_moved: LOAD R1, [R8 + W_ELEMENT_COUNT]
        DEC    R1
        STORE  R1, [R8 + W_ELEMENT_COUNT]
        STORE  R0, [selected]
        LOADLO R1, 0
        CALL   draw_window
        LA     R1, deleted_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        POP    R8
        RET
