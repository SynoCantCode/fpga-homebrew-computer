; mouse, clicks on the toolbar and the window, dragging, resizing
; included by studio.asm

; studio_click, a click on the toolbar, corner, header or an element
; R8 = x, R9 = y, R10 = window, R11 = column, R12 = row
studio_click: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        LOAD   R1, [mouse_point]
        ANDI   R8, R1, 0xFFFF
        SHIFTI R9, R1, 0x10, 0b1000
        LOADLO R1, 1
        STORE  R1, [redraw]
        CMPI   R9, TOOLBAR_H
        JC     click_work
        MOV    R1, R8                   ; the toolbar
        CALL   toolbar_at
        CMPIS  R1, -1
        JZ     click_end
        CALL   tool
        JUMP   click_end
click_work: STORE R0, [title_selected]
        LOADLO R1, 0
        CALL   window_record
        MOV    R10, R1
        LOAD   R1, [R10 + W_X]          ; the corner, bottom right 12 x 12 dots?
        LOAD   R2, [R10 + W_WIDTH]
        ADD    R1, R1, R2
        CMP    R8, R1
        JC     click_nothing
        SUBI   R2, R1, 12
        CMP    R8, R2
        JNC    click_element
        LOAD   R1, [R10 + W_Y]
        LOAD   R2, [R10 + W_HEIGHT]
        ADD    R1, R1, R2
        CMP    R9, R1
        JC     click_nothing
        SUBI   R2, R1, 12
        CMP    R9, R2
        JNC    click_element
        LOADLO R1, 2
        STORE  R1, [holding]
        JUMP   click_end
click_element: LOADLO R1, 0             ; its scroll bar?
        MOV    R2, R8
        MOV    R3, R9
        CALL   scroll_click
        CMPI   R1, 0x0000
        JNZ    click_end
        LOAD   R1, [R10 + W_STYLE]      ; the header, above its cells?
        LOAD   R1, [R1 + S_CONTENT_T]
        LOAD   R2, [R10 + W_Y]
        ADD    R1, R1, R2
        CMP    R9, R1
        JC     click_cells              ; below it
        CMP    R9, R2
        JNC    click_nothing            ; above the window
        LOAD   R1, [R10 + W_X]
        CMP    R8, R1
        JNC    click_nothing            ; left of it
        STORE  R0, [selected]           ; title selected, holding the window
        LOADLO R1, 1
        STORE  R1, [title_selected]
        LOADLO R1, 4
        STORE  R1, [holding]
        LOAD   R1, [R10 + W_X]
        SUB    R1, R8, R1
        STORE  R1, [drag_dx]
        LOAD   R1, [R10 + W_Y]
        SUB    R1, R9, R1
        STORE  R1, [drag_dy]
        LA     R1, title_text
        STORE  R1, [status]
        JUMP   click_end
click_cells: MOV R1, R8                 ; the cell under the pointer
        MOV    R2, R9
        CALL   cell_at                  ; R1 = column, R2 = row, -1 = outside
        CMPIS  R1, -1
        JZ     click_nothing
        MOV    R11, R1
        MOV    R12, R2
        LOAD   R1, [selected]           ; the size handle, its bottom right cell?
        CMPI   R1, 0x0000
        JZ     click_pick
        LOADB  R2, [R1]
        CMPI   R2, E_BOX
        JZ     click_handle
        CMPI   R2, E_CANVAS
        JZ     click_handle
        CMPI   R2, E_INPUT
        JNZ    click_pick
click_handle: LOADB R2, [R1 + 1]
        LOAD   R3, [R1 + 8]
        ADD    R2, R2, R3
        SUBI   R2, R2, 1
        CMP    R11, R2
        JNZ    click_pick
        LOADB  R2, [R1 + 2]
        LOAD   R3, [R1 + 12]
        ADD    R2, R2, R3
        SUBI   R2, R2, 1
        CMP    R12, R2
        JNZ    click_pick
        LOADLO R1, 3
        STORE  R1, [holding]
        LA     R1, sizing_text
        STORE  R1, [status]
        JUMP   click_end
click_pick:
        MOV    R1, R11
        MOV    R2, R12
        CALL   element_at               ; R1 = the element there or 0
        CMPI   R1, 0x0000
        JZ     click_nothing
        STORE  R1, [selected]
        PUSH   R1
        MOV    R2, R10
        CALL   element_cells
        SUB    R3, R11, R1
        STORE  R3, [grab_column]        ; where in it it was grabbed
        SUB    R3, R12, R2
        STORE  R3, [grab_row]
        POP    R1
        LOADLO R1, 1
        STORE  R1, [holding]
        LA     R1, selected_text
        STORE  R1, [status]
        LOAD   R1, [selected]           ; a button, say what it does
        LOADB  R2, [R1]
        CMPI   R2, E_BUTTON
        JNZ    click_end
        CALL   say_action
        JUMP   click_end
click_nothing: STORE R0, [selected]
click_end: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; cell_at, the windows cell under a point
; in R1 = x, R2 = y, out R1 = column or -1, R2 = row, uses R3-R5
cell_at: PUSH  R1
        PUSH   R2
        LOADLO R1, 0
        CALL   window_record            ; uses R2, so y is on the stack
        MOV    R5, R1
        POP    R2
        POP    R1
        LOAD   R3, [R5 + W_X]
        SUB    R1, R1, R3
        LOAD   R3, [R5 + W_STYLE]
        LOAD   R4, [R3 + S_CONTENT_L]
        SUB    R1, R1, R4
        LOAD   R4, [R5 + W_Y]
        SUB    R2, R2, R4
        LOAD   R4, [R3 + S_CONTENT_T]
        SUB    R2, R2, R4
        CMPIS  R1, 0
        JGE    cell_x
        JUMP   cell_outside
cell_x: CMPIS  R2, 0
        JGE    cell_y
        JUMP   cell_outside
cell_y: SHIFTI R1, R1, 0x03, 0b1000
        SHIFTI R2, R2, 0x04, 0b1000
        LOAD   R3, [R5 + W_COLUMNS]
        CMP    R1, R3
        JC     cell_outside
        LOAD   R3, [R5 + W_ROWS]
        CMP    R2, R3
        JC     cell_outside
        LOAD   R3, [scroll_rows]        ; + the scroll, the pages row
        ADD    R2, R2, R3
        RET
cell_outside: NOT R1, R0
        RET

; element_at, the top element covering a cell, the last one wins
; in R1 = column, R2 = row, out R1 = pointer or 0
; R8 = column, R9 = row, R10 = window, R11 = element, R12 = count, R13 = answer
element_at: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        MOV    R8, R1
        MOV    R9, R2
        LOADLO R1, 0
        CALL   window_record
        MOV    R10, R1
        LOAD   R11, [R10 + W_ELEMENTS]
        LOAD   R12, [R10 + W_ELEMENT_COUNT]
        LOADLO R13, 0
element_at_next: CMPI R12, 0x0000
        JZ     element_at_done
        LOADB  R1, [R11]
        CMPI   R1, 0x0000
        JZ     element_at_skip          ; empty, a picture that didn't load
        CMPI   R1, E_SHELL
        JZ     element_at_skip          ; shell command, not on the page
        MOV    R1, R11
        MOV    R2, R10
        CALL   element_cells
        CMP    R8, R1
        JNC    element_at_skip
        ADD    R3, R1, R3
        CMP    R8, R3
        JC     element_at_skip
        CMP    R9, R2
        JNC    element_at_skip
        ADD    R4, R2, R4
        CMP    R9, R4
        JC     element_at_skip
        MOV    R13, R11                 ; this one, a later one may cover it
element_at_skip: ADDI R11, R11, ELEMENT_BYTES
        DEC    R12
        JUMP   element_at_next
element_at_done: MOV R1, R13
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; studio_drag, button held, moves the element, the corner or the window
; nothing happens if something would stick out
; R8 = window, R9 = element
studio_drag: LOAD R1, [holding]
        CMPI   R1, 1
        JZ     drag_element
        CMPI   R1, 2
        JZ     drag_corner
        CMPI   R1, 3
        JZ     drag_size
        CMPI   R1, 4
        JZ     drag_window
        RET
drag_window: PUSH R8                    ; the window follows the pointer
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [mouse_point]
        ANDI   R2, R1, 0xFFFF
        SHIFTI R3, R1, 0x10, 0b1000
        LOAD   R4, [drag_dx]
        SUB    R2, R2, R4
        LOAD   R4, [drag_dy]
        SUB    R3, R3, R4
        LOAD   R4, [R8 + W_X]           ; the old place
        LOAD   R5, [R8 + W_Y]
        PUSH   R4
        PUSH   R5
        STORE  R2, [R8 + W_X]
        STORE  R3, [R8 + W_Y]
        CALL   keep_on_screen
        POP    R5
        POP    R4
        LOAD   R1, [R8 + W_X]
        CMP    R1, R4
        JNZ    window_moved
        LOAD   R1, [R8 + W_Y]
        CMP    R1, R5
        JZ     drag_window_done
window_moved: LOADLO R1, 1
        STORE  R1, [redraw]
drag_window_done: POP R8
        RET
drag_size: PUSH R9                      ; size, from its top left cell to the pointers cell
        LOAD   R9, [selected]
        LOAD   R1, [mouse_point]
        ANDI   R2, R1, 0xFFFF
        SHIFTI R3, R1, 0x10, 0b1000
        MOV    R1, R2
        MOV    R2, R3
        CALL   cell_at
        CMPIS  R1, -1
        JZ     size_done
        LOADB  R3, [R9 + 1]
        SUB    R1, R1, R3
        ADDI   R1, R1, 1                ; width
        CMPIS  R1, 1
        JGE    size_wide
        LOADLO R1, 1
size_wide: LOADB R3, [R9 + 2]
        SUB    R2, R2, R3
        ADDI   R2, R2, 1                ; height
        CMPIS  R2, 1
        JGE    size_tall
        LOADLO R2, 1
size_tall: LOAD R3, [R9 + 8]
        CMP    R3, R1
        JNZ    size_changed
        LOAD   R3, [R9 + 12]
        CMP    R3, R2
        JZ     size_done
size_changed: LOAD R3, [R9 + 8]         ; keep the old size
        LOAD   R4, [R9 + 12]
        STORE  R1, [R9 + 8]
        STORE  R2, [R9 + 12]
        PUSH   R3
        PUSH   R4
        CALL   all_fit                  ; still fits?
        POP    R4
        POP    R3
        CMPI   R1, 0x0000
        JNZ    size_fits
        STORE  R3, [R9 + 8]             ; no, the size stays
        STORE  R4, [R9 + 12]
        LA     R1, fits_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   size_done
size_fits: LOADLO R1, 0
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
size_done: POP R9
        RET
drag_element: PUSH R8
        PUSH   R9
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R9, [selected]
        LOAD   R1, [mouse_point]
        ANDI   R2, R1, 0xFFFF
        SHIFTI R3, R1, 0x10, 0b1000
        MOV    R1, R2
        MOV    R2, R3
        CALL   cell_at
        CMPIS  R1, -1
        JZ     drag_element_done        ; off the cells, it stays
        LOAD   R3, [grab_column]
        SUB    R1, R1, R3
        CMPIS  R1, 0
        JGE    drag_column_ok
        LOADLO R1, 0
drag_column_ok: LOAD R3, [grab_row]
        SUB    R2, R2, R3
        CMPIS  R2, 0
        JGE    drag_row_ok
        LOADLO R2, 0
drag_row_ok: LOADB R3, [R9]
        CMPI   R3, E_WRAP
        JNZ    drag_any_column
        LOADLO R1, 0                    ; a paragraph is the whole width
drag_any_column: LOADB R3, [R9 + 1]
        LOADB  R4, [R9 + 2]
        CMP    R3, R1
        JNZ    drag_moved
        CMP    R4, R2
        JZ     drag_element_done
drag_moved: STOREB R1, [R9 + 1]
        STOREB R2, [R9 + 2]
        PUSH   R3
        PUSH   R4
        CALL   all_fit                  ; would it stick out?
        POP    R4
        POP    R3
        CMPI   R1, 0x0000
        JNZ    drag_fits
        STOREB R3, [R9 + 1]             ; yes, it stays
        STOREB R4, [R9 + 2]
        JUMP   drag_element_done
drag_fits: LOADLO R1, 0
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
drag_element_done: POP R9
        POP    R8
        RET
drag_corner: PUSH R8                    ; the corner, columns and rows from the pointer
        PUSH   R9
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R9, [R8 + W_STYLE]
        LOAD   R1, [mouse_point]
        ANDI   R2, R1, 0xFFFF
        SHIFTI R3, R1, 0x10, 0b1000
        LOAD   R4, [R8 + W_X]
        SUB    R2, R2, R4
        LOAD   R4, [R9 + S_CONTENT_L]
        SUB    R2, R2, R4
        SHIFTI R2, R2, 0x03, 0b1000     ; columns
        CMPIS  R2, 12
        JGE    corner_wide
        LOADLO R2, 12
corner_wide: CMPI R2, 79
        JNC    corner_narrow
        LOADLO R2, 78
corner_narrow: LOAD R4, [R8 + W_Y]
        SUB    R3, R3, R4
        LOAD   R4, [R9 + S_CONTENT_T]
        SUB    R3, R3, R4
        SHIFTI R3, R3, 0x04, 0b1000     ; rows
        CMPIS  R3, 2
        JGE    corner_tall
        LOADLO R3, 2
corner_tall: CMPI R3, 25
        JNC    corner_short
        LOADLO R3, 24                   ; fits between the toolbar and the status line
corner_short: LOAD R4, [R8 + W_COLUMNS]
        CMP    R4, R2
        JNZ    corner_changed
        LOAD   R4, [R8 + W_ROWS]
        CMP    R4, R3
        JZ     corner_done
corner_changed: LOAD R4, [R8 + W_COLUMNS] ; keep the old size
        LOAD   R5, [R8 + W_ROWS]
        STORE  R2, [R8 + W_COLUMNS]
        STORE  R3, [R8 + W_ROWS]
        PUSH   R4
        PUSH   R5
        CALL   all_fit                  ; everything still fits?
        POP    R5
        POP    R4
        CMPI   R1, 0x0000
        JNZ    corner_fits
        STORE  R4, [R8 + W_COLUMNS]     ; no, the size stays
        STORE  R5, [R8 + W_ROWS]
        LA     R1, too_small_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   corner_done
corner_fits: MOV R1, R8
        CALL   window_size
        CALL   keep_on_screen
        LOADLO R1, 0
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
corner_done: POP R9
        POP    R8
        RET

; editing
