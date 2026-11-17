; scrolling, pages taller than their windows, the scroll bar
; included by winlib.asm

; scroll_setup, page height into page_rows_tab, scroll kept in range, into scroll_now
; in R8 = the windows 128 bytes, uses R1-R7
scroll_setup: MOV R1, R8
        CALL   page_height              ; R1 = page rows
        LOADLO R2, windows
        SUB    R3, R8, R2
        SHIFTI R3, R3, 0x07, 0b1000
        SHIFTI R3, R3, 0x02, 0b0000     ; R3 = window number x 4
        LOADLO R4, page_rows_tab
        ADD    R4, R4, R3
        STORE  R1, [R4]
        LOAD   R5, [R8 + W_ROWS]
        SUB    R1, R1, R5               ; R1 = the most it can scroll
        LOADLO R4, scroll_rows
        ADD    R4, R4, R3
        LOAD   R2, [R4]
        SUB    R6, R1, R2
        CMPIS  R6, 0
        JGE    scroll_low
        MOV    R2, R1
scroll_low: CMPIS R2, 0
        JGE    scroll_set
        LOADLO R2, 0
scroll_set: STORE R2, [R4]
        STORE  R2, [scroll_now]
        RET

; page_height, rows a windows page needs, its lowest elements bottom
; at least the windows rows, at most PAGE_MAX
; in R1 = the windows 128 bytes, out R1 = rows, uses R1-R7
page_height: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        LOAD   R11, [R8 + W_ROWS]
        LOAD   R9, [R8 + W_ELEMENTS]
        LOAD   R10, [R8 + W_ELEMENT_COUNT]
        CMPI   R9, 0x0000
        JZ     height_done
height_next: CMPI R10, 0x0000
        JZ     height_done
        LOADB  R1, [R9]
        CMPI   R1, 0x0000
        JZ     height_skip
        CMPI   R1, E_WRAP
        JZ     height_wrap
        CMPI   R1, E_BOX
        JZ     height_box
        CMPI   R1, E_INPUT
        JZ     height_box
        CMPI   R1, E_CANVAS
        JZ     height_box
        CMPI   R1, E_SHELL
        JZ     height_skip              ; a shell command takes no room
        CMPI   R1, E_IMAGE
        JZ     height_image
        CMPI   R1, E_ANIM
        JZ     height_anim
        LOADLO R2, 1                    ; text or button, one row
        JUMP   height_bottom
height_wrap: LOAD R1, [R9 + 4]
        LOAD   R2, [R8 + W_COLUMNS]
        CALL   text_rows
        MOV    R2, R1
        JUMP   height_bottom
height_box: LOAD R2, [R9 + 12]
        JUMP   height_bottom
height_anim: LOAD R2, [R9 + 12]
        SHIFTI R2, R2, 0x10, 0b1000
        JUMP   height_dots
height_image: LOAD R2, [R9 + 12]
height_dots: ADDI R2, R2, 15            ; dots to rows, rounded up
        SHIFTI R2, R2, 0x04, 0b1000
height_bottom: LOADB R1, [R9 + 2]
        ADD    R1, R1, R2
        CMP    R1, R11
        JNC    height_skip
        MOV    R11, R1
height_skip: ADDI R9, R9, ELEMENT_BYTES
        DEC    R10
        JUMP   height_next
height_done: CMPI R11, PAGE_MAX + 1
        JNC    height_max
        LOADLO R11, PAGE_MAX
height_max: MOV R1, R11
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; vis_height, input or canvas height in rows, cut at the windows last row
; in R8 = the 128 bytes, R9 = element, R12 = its row, out R4 = rows, uses R5
vis_height: LOAD R4, [R9 + 12]
        LOAD   R5, [R8 + W_ROWS]
        SUB    R5, R5, R12
        CMP    R5, R4
        JC     vis_done
        MOV    R4, R5
vis_done: RET

; image_row, in R2 = page row, R8 = the 128 bytes, R9 = element
; out R2 = row in the window, -1 if not wholly in view, uses R3, R6, R7
image_row: LOAD R3, [scroll_now]
        SUB    R2, R2, R3
        CMPIS  R2, 0
        JGE    image_row_top
        NOT    R2, R0
        RET
image_row_top: LOAD R6, [R9 + 12]       ; rows = height in dots, rounded up, an animation uses the high half
        LOADB  R7, [R9]
        CMPI   R7, E_ANIM
        JNZ    image_row_dots
        SHIFTI R6, R6, 0x10, 0b1000
image_row_dots: ADDI R6, R6, 15
        SHIFTI R6, R6, 0x04, 0b1000
        ADD    R6, R6, R2
        LOAD   R7, [R8 + W_ROWS]
        CMP    R7, R6
        JC     image_row_in
        NOT    R2, R0
image_row_in: RET

; scroll_bar, over the windows last column when the page is taller
; ^ at the top, v at the bottom, a box between showing the part in view
; in R8 = the windows 128 bytes, DRAW_PAGE = its picture
; R9 = bar x, R10 = bar y, R11 = window rows, R12 = page rows, R13 = scroll
scroll_bar: PUSH R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        LOADLO R2, windows
        SUB    R3, R8, R2
        SHIFTI R3, R3, 0x07, 0b1000
        SHIFTI R3, R3, 0x02, 0b0000
        LOADLO R4, page_rows_tab
        ADD    R4, R4, R3
        LOAD   R12, [R4]
        LOAD   R11, [R8 + W_ROWS]
        CMP    R11, R12
        JC     bar_done                 ; page fits, no bar
        LOAD   R13, [scroll_now]
        LOAD   R4, [R8 + W_STYLE]
        LOAD   R9, [R8 + W_COLUMNS]
        SUBI   R9, R9, 1
        SHIFTI R9, R9, 0x03, 0b0000
        LOAD   R1, [R4 + S_CONTENT_L]
        ADD    R9, R9, R1
        LOAD   R10, [R4 + S_CONTENT_T]
        MOV    R1, R9                   ; track
        MOV    R2, R10
        LOADLO R3, 8
        SHIFTI R4, R11, 0x04, 0b0000
        LOADLO R5, SILVER
        CALL   box
        MOV    R1, R9                   ; ^ at the top
        MOV    R2, R10
        LOADLO R3, 8
        LOADLO R4, 16
        LOADLO R5, 1
        CALL   bevel_box
        MOV    R1, R9
        MOV    R2, R10
        LA     R3, bar_up_text
        LOADLO R4, BLACK_DOT
        CALL   text
        SUBI   R2, R11, 1               ; v at the bottom
        SHIFTI R2, R2, 0x04, 0b0000
        ADD    R2, R2, R10
        PUSH   R2
        MOV    R1, R9
        LOADLO R3, 8
        LOADLO R4, 16
        LOADLO R5, 1
        CALL   bevel_box
        POP    R2
        MOV    R1, R9
        LA     R3, bar_down_text
        LOADLO R4, BLACK_DOT
        CALL   text
        CMPI   R11, 3                   ; the box, track = (rows - 2) x 16 dots
        JNC    bar_done                 ; height = track x rows / page, place = track x scroll / page
        SUBI   R6, R11, 2
        SHIFTI R6, R6, 0x04, 0b0000     ; R6 = track dots
        MUL    R2, R6, R13
        DIVU   R2, R2, R12
        ADD    R2, R2, R10
        ADDI   R2, R2, 16               ; y
        MUL    R4, R6, R11
        DIVU   R4, R4, R12              ; height
        CMPI   R4, 6
        JNC    bar_box
        LOADLO R4, 6
bar_box: MOV R1, R9
        LOADLO R3, 8
        LOADLO R5, 1
        CALL   bevel_box
bar_done: POP R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        RET

; scroll_by, scrolls a window some rows, redraws it and the screen
; in R1 = window number, R2 = rows, below 0 = up
scroll_by: PUSH R1
        SHIFTI R3, R1, 0x02, 0b0000
        LOADLO R4, scroll_rows
        ADD    R4, R4, R3
        LOAD   R5, [R4]
        ADD    R5, R5, R2
        CMPIS  R5, 0
        JGE    scroll_by_set
        LOADLO R5, 0
scroll_by_set: STORE R5, [R4]
        POP    R1
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
        RET

; scroll_click, a click on a windows scroll bar?
; ^ = row up, v = row down, elsewhere = a windowful up or down
; in R1 = window number, R2 = x, R3 = y on the screen, out R1 = 1 on the bar, 0 not
scroll_click: PUSH R8
        PUSH   R9
        MOV    R9, R1
        PUSH   R2
        CALL   window_record
        MOV    R8, R1
        POP    R2
        SHIFTI R4, R9, 0x02, 0b0000
        LOADLO R5, page_rows_tab
        ADD    R4, R4, R5
        LOAD   R6, [R4]                 ; R6 = page rows
        LOAD   R5, [R8 + W_ROWS]        ; R5 = window rows
        CMP    R5, R6
        JC     click_bar_no             ; no bar
        LOAD   R4, [R8 + W_STYLE]
        LOAD   R7, [R8 + W_X]           ; column, the windows last?
        SUB    R2, R2, R7
        LOAD   R7, [R4 + S_CONTENT_L]
        SUB    R2, R2, R7
        CMPIS  R2, 0
        JGE    click_bar_x
        JUMP   click_bar_no
click_bar_x: SHIFTI R2, R2, 0x03, 0b1000
        LOAD   R7, [R8 + W_COLUMNS]
        SUBI   R7, R7, 1
        CMP    R2, R7
        JNZ    click_bar_no
        LOAD   R7, [R8 + W_Y]           ; row
        SUB    R3, R3, R7
        LOAD   R7, [R4 + S_CONTENT_T]
        SUB    R3, R3, R7
        CMPIS  R3, 0
        JGE    click_bar_y
        JUMP   click_bar_no
click_bar_y: SHIFTI R3, R3, 0x04, 0b1000
        CMP    R3, R5
        JC     click_bar_no             ; below the cells
        NOT    R2, R0                   ; ^, one up
        CMPI   R3, 0x0000
        JZ     click_bar_scroll
        LOADLO R2, 1                    ; v, one down
        SUBI   R7, R5, 1
        CMP    R3, R7
        JZ     click_bar_scroll
        SUBI   R2, R5, 1                ; between, a windowful, up in the top half
        SHIFTI R7, R5, 0x01, 0b1000
        CMP    R3, R7
        JC     click_bar_scroll
        SUB    R2, R0, R2
click_bar_scroll: MOV R1, R9
        CALL   scroll_by
        LOADLO R1, 1
        JUMP   click_bar_end
click_bar_no: LOADLO R1, 0
click_bar_end: POP R9
        POP    R8
        RET
