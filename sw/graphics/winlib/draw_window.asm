; draw_window, a windows own picture, its cells, wrapping
; included by winlib.asm

; draw_window, draws a windows own picture from its style
; frame, panel, whats inside, grip
; DRAW_PAGE points at the windows picture, then put back
; header is drawn by compose in title_bar
; a page draws its elements, then its pictures
; in R1 = window number
; R8 = its 128 bytes, R9 = width, R10 = height, R11 = inside / count, R13 = style
draw_window: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        CALL   window_record
        MOV    R8, R1
        CALL   window_room              ; picture big enough for its size?
        CMPI   R1, 0x0000               ; no room in the heap, not drawn
        JZ     draw_window_end
        CALL   scroll_setup             ; page height, scroll kept in range
        LOAD   R9, [R8 + W_WIDTH]
        LOAD   R10, [R8 + W_HEIGHT]
        LOAD   R13, [R8 + W_STYLE]
        LOAD   R1, [DRAW_PAGE]
        STORE  R1, [saved_page]
        LOAD   R1, [R8 + W_PICTURE]
        STORE  R1, [DRAW_PAGE]          ; draw into the windows own picture
        LOAD   R1, [R13 + S_PICTURE]
        CMPI   R1, 0x0000
        JZ     draw_parts
        MOV    R1, R8                   ; drawn style, my picture fitted to the size, 9-slice
        CALL   nine_slice
        JUMP   draw_inside
draw_parts: LOADLO R1, 0                ; frame
        LOADLO R2, 0
        MOV    R3, R9
        MOV    R4, R10
        LOAD   R5, [R13 + S_FRAME_FILL]
        CALL   box
        LOADLO R1, 0                    ; light top and left edges
        LOADLO R2, 0
        MOV    R3, R9
        LOADLO R4, 1
        LOAD   R5, [R13 + S_FRAME_LIGHT]
        CALL   box
        LOADLO R1, 0
        LOADLO R2, 0
        LOADLO R3, 1
        MOV    R4, R10
        LOAD   R5, [R13 + S_FRAME_LIGHT]
        CALL   box
        LOADLO R1, 0                    ; dark bottom and right edges
        SUBI   R2, R10, 1
        MOV    R3, R9
        LOADLO R4, 1
        LOAD   R5, [R13 + S_FRAME_DARK]
        CALL   box
        SUBI   R1, R9, 1
        LOADLO R2, 0
        LOADLO R3, 1
        MOV    R4, R10
        LOAD   R5, [R13 + S_FRAME_DARK]
        CALL   box
        LOAD   R1, [R13 + S_PANEL_L]    ; line just above the panel
        LOAD   R2, [R13 + S_PANEL_T]
        SUBI   R2, R2, 1
        SUB    R3, R9, R1
        LOAD   R4, [R13 + S_PANEL_R]
        SUB    R3, R3, R4
        LOADLO R4, 1
        LOAD   R5, [R13 + S_PANEL_EDGE]
        CALL   box
        LOAD   R1, [R13 + S_PANEL_L]    ; panel, width - left - right, height - top - bottom
        LOAD   R2, [R13 + S_PANEL_T]
        SUB    R3, R9, R1
        LOAD   R4, [R13 + S_PANEL_R]
        SUB    R3, R3, R4
        SUB    R4, R10, R2
        LOAD   R5, [R13 + S_PANEL_B]
        SUB    R4, R4, R5
        LOAD   R5, [R13 + S_PANEL_COLOUR]
        CALL   box
draw_inside: LOAD R11, [R8 + W_KIND]
        MOV    R1, R8                   ; cells all spaces first
        CALL   clear_cells
        MOV    R1, R8                   ; page elements, button frames and letters into the cells
        CALL   page_into_cells
        MOV    R1, R8
        CALL   draw_cells
        MOV    R1, R8                   ; then its pictures, on top
        CALL   page_images
        CALL   scroll_bar               ; scroll bar if the page is taller than the window
        LOAD   R7, [R8 + W_APP]         ; a real app paints last
        CMPI   R7, 0x0000
        JZ     inside_grip
        LOAD   R1, [R13 + S_CONTENT_T]  ; paint only inside the content
        STORE  R1, [paint_top]          ; between paint_top and paint_bottom
        LOAD   R2, [R8 + W_HEIGHT]
        LOAD   R3, [R13 + S_CONTENT_B]
        SUB    R2, R2, R3
        STORE  R2, [paint_bottom]
        LOAD   R2, [scroll_now]         ; corner = content corner, moved up by the scroll
        SHIFTI R2, R2, 0x04, 0b0000     ; row N is y = N x 16
        SUB    R1, R1, R2
        STORE  R1, [paint_y]
        LOAD   R1, [R13 + S_CONTENT_L]
        STORE  R1, [paint_x]
        MOV    R1, R8                   ; a canvas, from its corner instead
        CALL   canvas_of
        CMPI   R1, 0x0000
        JZ     inside_paint
        LOADB  R2, [R1 + 1]
        SHIFTI R2, R2, 0x03, 0b0000
        LOAD   R3, [paint_x]
        ADD    R3, R3, R2
        STORE  R3, [paint_x]
        LOADB  R2, [R1 + 2]
        LOAD   R3, [scroll_now]
        SUB    R2, R2, R3
        CMPIS  R2, 0
        JGE    inside_canvas_in
        JUMP   inside_grip              ; canvas scrolled away above, no paint
inside_canvas_in: LOADB R2, [R1 + 2]    ; + the canvas row
        SHIFTI R2, R2, 0x04, 0b0000
        LOAD   R3, [paint_y]
        ADD    R3, R3, R2
        STORE  R3, [paint_y]
inside_paint: LOADLO R2, windows
        SUB    R1, R8, R2
        SHIFTI R1, R1, 0x07, 0b1000     ; R1 = window number
        LOAD   R7, [R8 + W_APP]
        ADDI   R7, R7, APP_PAINT
        CALLR  R7
        JUMP   inside_grip
inside_grip: LOAD R1, [R13 + S_PICTURE]  ; a drawn style draws its own grip
        CMPI   R1, 0x0000
        JNZ    inside_done
        LOADLO R11, 0                   ; grip, 3 diagonal lines in the bottom right corner
grip_line: SUBI R1, R9, 13              ; from (width - 13 + R11, height - 4)
        ADD    R1, R1, R11
        SUBI   R2, R10, 4
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        SUBI   R2, R9, 4                ; to (width - 4, height - 13 + R11)
        SUBI   R3, R10, 13
        ADD    R3, R3, R11
        SHIFTI R3, R3, 0x10, 0b0000
        OR     R2, R2, R3
        LOAD   R3, [R13 + S_FRAME_DARK]
        CALLF  DRAW_LINE
        ADDI   R11, R11, 4
        CMPI   R11, 12
        JNZ    grip_line
inside_done: LOAD R1, [saved_page]
        STORE  R1, [DRAW_PAGE]          ; back to the screens page
draw_window_end: POP R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; window_size, size in dots, columns x 8 and rows x 16 + the style margins
; in R1 = pointer to its 128 bytes, uses R2, R3
window_size: LOAD R2, [R1 + W_COLUMNS]
        SHIFTI R2, R2, 0x03, 0b0000
        LOAD   R3, [R1 + W_STYLE]
        LOAD   R3, [R3 + S_CONTENT_L]
        ADD    R2, R2, R3
        LOAD   R3, [R1 + W_STYLE]
        LOAD   R3, [R3 + S_CONTENT_R]
        ADD    R2, R2, R3
        STORE  R2, [R1 + W_WIDTH]
        LOAD   R2, [R1 + W_ROWS]
        SHIFTI R2, R2, 0x04, 0b0000
        LOAD   R3, [R1 + W_STYLE]
        LOAD   R3, [R3 + S_CONTENT_T]
        ADD    R2, R2, R3
        LOAD   R3, [R1 + W_STYLE]
        LOAD   R3, [R3 + S_CONTENT_B]
        ADD    R2, R2, R3
        STORE  R2, [R1 + W_HEIGHT]
        RET

; clear_cells, every cell a space, colour 0
; in R1 = pointer to its 128 bytes, uses R1-R4
clear_cells: LOAD R2, [R1 + W_COLUMNS]
        LOAD   R3, [R1 + W_ROWS]
        MUL    R2, R2, R3
        LOAD   R3, [R1 + W_CELLS]
        LOADLO R4, 0x0020
clear_cell: CMPI R2, 0x0000
        JZ     clear_cells_done
        STOREB R4, [R3]
        STOREB R0, [R3 + 1]
        ADDI   R3, R3, 2
        DEC    R2
        JUMP   clear_cell
clear_cells_done: RET

; put_text, text into the cells from a column and row, no wrapping
; in R1 = pointer to the 128 bytes, R2 = column, R3 = row, R4 = pointer to text, R5 = colour
; uses R1-R7, R6 = columns, R7 = cell
put_text: LOAD R6, [R1 + W_COLUMNS]
        MUL    R7, R3, R6               ; cell = cells + (row x columns + column) x 2
        ADD    R7, R7, R2
        SHIFTI R7, R7, 0x01, 0b0000
        LOAD   R3, [R1 + W_CELLS]
        ADD    R7, R7, R3
put_next: CMP R2, R6
        JC     put_done                 ; end of the row
        LOADB  R3, [R4]
        CMPI   R3, 0x0000
        JZ     put_done                 ; end of the text
        STOREB R3, [R7]
        STOREB R5, [R7 + 1]
        ADDI   R7, R7, 2
        INC    R4
        INC    R2
        JUMP   put_next
put_done: RET

; wrap_box, paragraph wrapped inside a box of cells
; a word that doesnt fit goes to the next row, a word longer than a row is cut
; wrap element = whole width from its row down, box element = its own box
; in R1 = pointer to the 128 bytes, R2 = pointer to the element
; R8 = columns, R9 = last row + 1, R10 = cells, R11 = column in the box, R12 = row
; R13 = next letter, R14 = colour, R7 = box width, box_left = left column
; R4 = word length, R5 = word end, R6 = cell
wrap_box: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        PUSH   R14
        LOAD   R8, [R1 + W_COLUMNS]
        LOAD   R9, [R1 + W_ROWS]
        LOAD   R10, [scroll_now]        ; rows are page rows, window shows from scroll_now
        ADD    R9, R9, R10
        LOAD   R10, [R1 + W_CELLS]
        LOAD   R13, [R2 + 4]
        LOADB  R14, [R2 + 3]
        LOADB  R12, [R2 + 2]
        STORE  R0, [box_left]           ; paragraph, whole width
        MOV    R7, R8
        LOADB  R3, [R2]
        CMPI   R3, E_WRAP
        JZ     wrap_ready               ; box or input, its own rectangle
        LOADB  R3, [R2 + 1]             ; box left, width, height
        CMP    R3, R8
        JC     wrap_done                ; starts right of the window, nothing
        STORE  R3, [box_left]
        LOAD   R7, [R2 + 8]
        ADD    R4, R3, R7
        CMP    R8, R4
        JC     wrap_width_ok
        SUB    R7, R8, R3               ; cut at the right edge
wrap_width_ok: LOAD R4, [R2 + 12]
        ADD    R4, R4, R12
        CMP    R9, R4
        JNC    wrap_ready               ; window ends first
        MOV    R9, R4                   ; box ends first
wrap_ready: LOADLO R11, 0
        CMPI   R7, 0x0000
        JZ     wrap_done
        CMP    R12, R9
        JC     wrap_done                ; starts below the last row, nothing
wrap_next: LOADB R1, [R13]
        CMPI   R1, 0x0000
        JZ     wrap_done                ; end of the text
        CMPI   R1, 0x000A
        JZ     wrap_enter               ; Enter, new row
        CMPI   R1, 0x005C
        JNZ    wrap_not_enter
        LOADB  R6, [R13 + 1]            ; "\n" as two letters, new row too
        CMPI   R6, 0x006E
        JNZ    wrap_not_enter
        INC    R13
wrap_enter: INC R13
        LOADLO R11, 0
        INC    R12
        CMP    R12, R9
        JC     wrap_done
        JUMP   wrap_next
wrap_not_enter:
        CMPI   R1, 0x0020
        JNZ    wrap_word
        INC    R13                      ; space, one empty cell
        CMPI   R11, 0x0000
        JZ     wrap_next
        INC    R11
        CMP    R11, R7
        JNC    wrap_next                ; still on the row
        LOADLO R11, 0                   ; past the end, next row
        INC    R12
        CMP    R12, R9
        JC     wrap_done                ; no rows left
        JUMP   wrap_next
wrap_word: MOV R5, R13                  ; a word, find its end
wrap_measure: LOADB R1, [R5]
        CMPI   R1, 0x0000
        JZ     wrap_measured
        CMPI   R1, 0x000A
        JZ     wrap_measured
        CMPI   R1, 0x005C
        JNZ    wrap_measure_on
        LOADB  R6, [R5 + 1]
        CMPI   R6, 0x006E
        JZ     wrap_measured            ; "\n" ends the word
        LOADB  R1, [R5]
wrap_measure_on:
        CMPI   R1, 0x0020
        JZ     wrap_measured
        INC    R5
        JUMP   wrap_measure
wrap_measured: SUB R4, R5, R13          ; R4 = length
        CMPI   R11, 0x0000
        JZ     wrap_letters             ; row start, it goes here
        ADD    R6, R11, R4
        CMP    R7, R6
        JC     wrap_letters             ; fits on this row
        LOADLO R11, 0                   ; doesnt fit, next row
        INC    R12
        CMP    R12, R9
        JC     wrap_done
wrap_letters: CMP R13, R5
        JC     wrap_next                ; whole word written
        CMP    R11, R7
        JNC    wrap_put
        LOADLO R11, 0                   ; word longer than a row, cut
        INC    R12
        CMP    R12, R9
        JC     wrap_done
wrap_put: LOAD R6, [scroll_now]          ; row scrolled away above, not written
        SUB    R6, R12, R6
        CMPIS  R6, 0
        JGE    wrap_visible
        INC    R11
        INC    R13
        JUMP   wrap_letters
wrap_visible: MUL R6, R6, R8            ; cell = cells + (row in window x columns + box_left + column) x 2
        ADD    R6, R6, R11
        LOAD   R1, [box_left]
        ADD    R6, R6, R1
        SHIFTI R6, R6, 0x01, 0b0000
        ADD    R6, R6, R10
        LOADB  R1, [R13]
        STOREB R1, [R6]                 ; letter
        STOREB R14, [R6 + 1]            ; colour
        INC    R11
        INC    R13
        JUMP   wrap_letters
wrap_done: POP R14
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; text_rows, rows a text takes wrapped to a width, same as wrap_box
; in R1 = pointer to text, R2 = width in cells, out R1 = rows, 0 if empty
; uses R1-R7, R3 = column, R4 = row, R5 = word end, R6 = letter, R7 = 1 once theres a letter
text_rows: LOADLO R3, 0
        LOADLO R4, 0
        LOADLO R7, 0
rows_next: LOADB R6, [R1]
        CMPI   R6, 0x0000
        JZ     rows_done
        LOADLO R7, 1
        CMPI   R6, 0x000A
        JZ     rows_enter
        CMPI   R6, 0x005C
        JNZ    rows_not_enter
        LOADB  R5, [R1 + 1]
        CMPI   R5, 0x006E
        JNZ    rows_not_enter
        INC    R1                       ; "\n", two letters
rows_enter: INC R1
        LOADLO R3, 0
        INC    R4
        JUMP   rows_next
rows_not_enter: CMPI R6, 0x0020
        JNZ    rows_word
        INC    R1                       ; space
        CMPI   R3, 0x0000
        JZ     rows_next
        INC    R3
        CMP    R3, R2
        JNC    rows_next
        LOADLO R3, 0
        INC    R4
        JUMP   rows_next
rows_word: MOV R5, R1                   ; a word, find its end
rows_measure: LOADB R6, [R5]
        CMPI   R6, 0x0000
        JZ     rows_measured
        CMPI   R6, 0x000A
        JZ     rows_measured
        CMPI   R6, 0x0020
        JZ     rows_measured
        CMPI   R6, 0x005C
        JNZ    rows_measure_on
        LOADB  R6, [R5 + 1]
        CMPI   R6, 0x006E
        JZ     rows_measured
rows_measure_on: INC R5
        JUMP   rows_measure
rows_measured: SUB R6, R5, R1           ; length
        CMPI   R3, 0x0000
        JZ     rows_letters
        ADD    R6, R3, R6
        CMP    R2, R6
        JC     rows_letters             ; fits on this row
        LOADLO R3, 0
        INC    R4
rows_letters: CMP R1, R5
        JC     rows_next
        CMP    R3, R2
        JNC    rows_put
        LOADLO R3, 0                    ; longer than a row, cut
        INC    R4
rows_put: INC R3
        INC    R1
        JUMP   rows_letters
rows_done: ADD R1, R4, R7              ; last row + 1, 0 if nothing
        RET

; draw_cells, cells drawn as letters into the picture, spaces skipped
; cell c, r at (left margin + c x 8, top margin + r x 16)
; in R1 = pointer to the 128 bytes, DRAW_PAGE already set
; R8 = window, R9 = cell, R10 = column, R11 = row, R12 = left margin, R13 = top margin
draw_cells: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        MOV    R8, R1
        LOAD   R1, [R8 + W_STYLE]
        LOAD   R12, [R1 + S_CONTENT_L]
        LOAD   R13, [R1 + S_CONTENT_T]
        LOAD   R9, [R8 + W_CELLS]
        LOADLO R11, 0
draw_cells_row: LOAD R1, [R8 + W_ROWS]
        CMP    R11, R1
        JC     draw_cells_done
        LOADLO R10, 0
draw_cells_cell: LOAD R1, [R8 + W_COLUMNS]
        CMP    R10, R1
        JC     draw_cells_next_row
        LOADB  R1, [R9]
        CMPI   R1, 0x0020
        JZ     draw_cells_skip
        STOREB R1, [one_letter]         ; letter as a 1 letter text
        STOREB R0, [one_letter + 1]
        SHIFTI R1, R10, 0x03, 0b0000
        ADD    R1, R1, R12
        SHIFTI R2, R11, 0x04, 0b0000
        ADD    R2, R2, R13
        LOADLO R3, one_letter
        LOADB  R4, [R9 + 1]             ; colour
        CALL   text
draw_cells_skip: ADDI R9, R9, 2
        INC    R10
        JUMP   draw_cells_cell
draw_cells_next_row: INC R11
        JUMP   draw_cells_row
draw_cells_done: POP R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET
