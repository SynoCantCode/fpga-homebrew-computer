; wm clicks, windows, taskbar, icons, dragging, resizing, raising
; included by programs/wm.asm

; click, finds what is under the pointer, front first
; R8 = pointer x, R9 = pointer y, R10 = place in the order
; R11 = window number, R12 = its record
click:  PUSH   R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        CALL   unfocus
        LOAD   R1, [mouse_point]
        ANDI   R8, R1, 0xFFFF
        SHIFTI R9, R1, 0x10, 0b1000
        LOAD   R1, [search_open]        ; search list open, it takes the click or closes
        CMPI   R1, 0x0000
        JZ     click_no_search
        CALL   search_click
        CMPI   R1, 0x0000
        JNZ    click_done
click_no_search: CALL front_is_full     ; a full screen window at the front covers the taskbar
        CMPI   R1, 0x0000
        JNZ    click_windows
        CMPI   R9, TASKBAR_Y
        JC     click_taskbar            ; taskbar is in front of the windows
click_windows:
        LOADLO R10, WINDOW_COUNT - 1
click_window: LOADLO R1, order
        SHIFTI R2, R10, 0x02, 0b0000
        ADD    R1, R1, R2
        LOAD   R11, [R1]
        MOV    R1, R11
        CALL   window_record
        MOV    R12, R1
        LOAD   R1, [R12 + W_VISIBLE]
        CMPI   R1, 0x0000
        JZ     click_window_next
        LOAD   R1, [R12 + W_X]          ; inside it?
        CMP    R8, R1
        JNC    click_window_next
        LOAD   R2, [R12 + W_WIDTH]
        ADD    R2, R1, R2
        CMP    R8, R2
        JC     click_window_next
        LOAD   R1, [R12 + W_Y]
        CMP    R9, R1
        JNC    click_window_next
        LOAD   R2, [R12 + W_HEIGHT]
        ADD    R2, R1, R2
        CMP    R9, R2
        JC     click_window_next
        MOV    R1, R12                  ; on its close box, 16 x 16?
        CALL   close_place
        CMP    R8, R1
        JNC    click_min
        ADDI   R1, R1, 16
        CMP    R8, R1
        JC     click_min
        CMP    R9, R2
        JNC    click_min
        ADDI   R2, R2, 16
        CMP    R9, R2
        JC     click_min
        MOV    R1, R12                  ; close it
        CALL   close_window
        JUMP   click_changed
click_min: MOV R1, R12                  ; on its minimise button, 16 x 16? hide it
        CALL   min_place
        CMP    R8, R1
        JNC    click_full
        ADDI   R1, R1, 16
        CMP    R8, R1
        JC     click_full
        CMP    R9, R2
        JNC    click_full
        ADDI   R2, R2, 16
        CMP    R9, R2
        JC     click_full
        STORE  R0, [R12 + W_VISIBLE]
        JUMP   click_changed
click_full: LOAD R1, [R12 + W_NO_FULL]  ; on its full screen button, 16 x 16?
        CMPI   R1, 0x0000
        JNZ    click_raise
        MOV    R1, R12
        CALL   full_place
        CMP    R8, R1
        JNC    click_raise
        ADDI   R1, R1, 16
        CMP    R8, R1
        JC     click_raise
        CMP    R9, R2
        JNC    click_raise
        ADDI   R2, R2, 16
        CMP    R9, R2
        JC     click_raise
        MOV    R1, R11
        CALL   raise
        MOV    R1, R12
        CALL   toggle_full
        JUMP   click_changed
click_raise: MOV R1, R11
        CALL   raise
        LOAD   R1, [R12 + W_X]          ; on its grip, bottom right 12 x 12? resize
        LOAD   R2, [R12 + W_WIDTH]
        ADD    R1, R1, R2
        SUBI   R1, R1, 12
        CMP    R8, R1
        JNC    click_title
        LOAD   R1, [R12 + W_Y]
        LOAD   R2, [R12 + W_HEIGHT]
        ADD    R1, R1, R2
        SUBI   R1, R1, 12
        CMP    R9, R1
        JNC    click_title
        LOADLO R1, 1
        STORE  R1, [resizing]
        JUMP   click_changed
click_title: LOAD R5, [R12 + W_STYLE]   ; on its header? drag
        LOAD   R1, [R5 + S_HEAD_T]
        LOAD   R2, [R12 + W_HEIGHT]
        CALL   from_edge
        LOAD   R2, [R12 + W_Y]
        ADD    R1, R1, R2               ; top of the header on the screen
        CMP    R9, R1
        JNC    click_inside
        LOAD   R2, [R5 + S_HEAD_H]
        ADD    R1, R1, R2
        CMP    R9, R1
        JC     click_inside
        LOAD   R1, [R12 + W_X]
        SUB    R1, R8, R1
        STORE  R1, [drag_dx]
        LOAD   R1, [R12 + W_Y]
        SUB    R1, R9, R1
        STORE  R1, [drag_dy]
        LOADLO R1, 1
        STORE  R1, [dragging]
        JUMP   click_changed
click_inside: LOAD R1, [R12 + W_KIND]   ; inside a page, scroll bar or button?
        CMPI   R1, KIND_PAGE
        JNZ    click_changed
        MOV    R1, R11
        MOV    R2, R8
        MOV    R3, R9
        CALL   scroll_click
        CMPI   R1, 0x0000
        JNZ    click_changed
        STORE  R0, [pressed]
        MOV    R1, R12
        MOV    R2, R8
        MOV    R3, R9
        CALL   press_button
        LOAD   R1, [pressed]            ; nothing pressed and it has an app, the app gets the click
        CMPI   R1, 0x0000
        JNZ    click_changed
        LOAD   R1, [R12 + W_APP]
        CMPI   R1, 0x0000
        JZ     click_changed
        LOAD   R5, [R12 + W_STYLE]      ; from the top left of its content
        LOAD   R3, [R12 + W_X]
        SUB    R3, R8, R3
        LOAD   R4, [R5 + S_CONTENT_L]
        SUB    R3, R3, R4
        LOAD   R4, [R12 + W_Y]
        SUB    R4, R9, R4
        LOAD   R6, [R5 + S_CONTENT_T]
        SUB    R4, R4, R6
        PUSH   R3                       ; a canvas, from its corner
        PUSH   R4
        MOV    R1, R12
        CALL   canvas_of
        POP    R4
        POP    R3
        CMPI   R1, 0x0000
        JZ     click_app
        LOADB  R2, [R1 + 1]
        SHIFTI R2, R2, 0x03, 0b0000
        SUB    R3, R3, R2
        LOADB  R2, [R1 + 2]
        SHIFTI R5, R11, 0x02, 0b0000    ; its row in view, minus the scroll
        LOADLO R6, scroll_rows
        ADD    R5, R5, R6
        LOAD   R5, [R5]
        SUB    R2, R2, R5
        SHIFTI R2, R2, 0x04, 0b0000
        SUB    R4, R4, R2
click_app: MOV R1, R11
        LOADLO R2, APP_CLICK
        CALL   app_call
        JUMP   click_changed
click_window_next: CMPI R10, 0x0000
        JZ     click_icons              ; no window there
        DEC    R10
        JUMP   click_window
click_taskbar: CMPI R8, TASK_LEFT        ; search box, opens its list
        JNC    click_search_box
        CMPI   R8, TRAY_X
        JC     click_tray
        SUBI   R1, R8, TASK_LEFT        ; a window button, which place, not in the gap
        LOAD   R3, [task_step]
        DIVU   R2, R1, R3
        MODU   R1, R1, R3
        SUBI   R3, R3, 4
        CMP    R1, R3
        JC     click_done
        MOV    R1, R2
        CALL   nth_used                 ; place to window
        CMPIS  R1, -1
        JZ     click_done
        MOV    R11, R1
        JUMP   click_toggle
click_toggle: MOV R1, R11               ; front one is hidden, others shown at the front
        CALL   window_record
        MOV    R12, R1
        CALL   front_window
        CMP    R1, R11
        JNZ    click_show
        STORE  R0, [R12 + W_VISIBLE]
        JUMP   click_changed
click_show: LOADLO R1, 1
        STORE  R1, [R12 + W_VISIBLE]
        MOV    R1, R11
        CALL   raise
        JUMP   click_changed
click_icons: CMPI R8, 24                ; an icon, 32 x 32, 80 apart from 24, columns of 5
        JNC    click_done
        CMPI   R9, 24
        JNC    click_done
        SUBI   R1, R8, 24
        DIVUI  R3, R1, 80               ; R3 = column
        MODUI  R1, R1, 80
        CMPI   R1, 32
        JC     click_done
        SUBI   R1, R9, 24
        DIVUI  R2, R1, 80               ; R2 = row
        MODUI  R1, R1, 80
        CMPI   R1, 32
        JC     click_done
        CMPI   R2, 5
        JC     click_done
        MULI   R1, R3, 5
        ADD    R1, R1, R2               ; place = column x 5 + row
        CALL   nth_icon                 ; place to app, open it
        CMPIS  R1, -1
        JZ     click_done
        CALL   launch_app
        JUMP   click_changed
click_changed: LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   click_done               ; skip the taskbar ends below
click_search_box: CALL search_start
        JUMP   click_done
click_tray: LA R1, clock_app_name        ; tray, clock from 30 dots in opens the Clock app
        CMPI   R8, TRAY_X + 30          ; the light opens the Network app
        JC     click_tray_open
        LA     R1, network_app_name
click_tray_open: CALL find_app_number
        CMPIS  R1, -1
        JZ     click_done
        CALL   launch_app
click_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; drag, front window follows the pointer, snapped to 8 x 16 cells
; R5 = new x, R6 = new y, window_record uses R2
drag:   LOAD   R1, [mouse_point]
        ANDI   R5, R1, 0xFFFF
        SHIFTI R6, R1, 0x10, 0b1000
        LOAD   R4, [drag_dx]
        SUB    R5, R5, R4
        LOAD   R4, [drag_dy]
        SUB    R6, R6, R4
        CMPIS  R5, 0
        JGE    drag_x_ok
        LOADLO R5, 0
drag_x_ok: ANDI R5, R5, 0xFFF8          ; a multiple of 8
        CMPI   R5, 600
        JNC    drag_x_kept
        LOADLO R5, 600
drag_x_kept: CMPIS R6, 0
        JGE    drag_y_ok
        LOADLO R6, 0
drag_y_ok: ANDI R6, R6, 0xFFF0          ; a multiple of 16
        CMPI   R6, 432
        JNC    drag_y_kept
        LOADLO R6, 432
drag_y_kept: LOADLO R1, ORDER_FRONT     ; front window
        LOAD   R1, [R1]
        CALL   window_record            ; R1 = its record
        LOAD   R4, [R1 + W_X]
        CMP    R4, R5
        JNZ    drag_moved
        LOAD   R4, [R1 + W_Y]
        CMP    R4, R6
        JZ     drag_same
drag_moved: STORE R5, [R1 + W_X]
        STORE  R6, [R1 + W_Y]
        LOADLO R1, 1
        STORE  R1, [redraw]
drag_same: RET

; resize, front window corner follows the pointer, a cell at a time
; columns = (pointer x - window x - left margin) / 8
; rows = (pointer y - window y - top margin) / 16, at least 12 x 2
; R8 = its record, R9 = its number, R10 = its style
resize: PUSH   R8
        PUSH   R9
        PUSH   R10
        LOADLO R1, ORDER_FRONT          ; front window
        LOAD   R9, [R1]
        MOV    R1, R9
        CALL   window_record
        MOV    R8, R1
        LOAD   R10, [R8 + W_STYLE]
        LOAD   R1, [mouse_point]
        ANDI   R2, R1, 0xFFFF
        SHIFTI R3, R1, 0x10, 0b1000
        LOAD   R4, [R8 + W_X]
        SUB    R2, R2, R4
        LOAD   R5, [R10 + S_CONTENT_L]
        SUB    R2, R2, R5               ; dots across the cells
        CMPIS  R2, 96
        JGE    resize_wide_enough
        LOADLO R2, 96                   ; at least 12 columns
resize_wide_enough: SHIFTI R2, R2, 0x03, 0b1000   ; R2 = columns
        LOADLO R6, PIXELS_ACROSS        ; most that fit, (640 - x - margins) / 8
        SUB    R6, R6, R4
        SUB    R6, R6, R5
        LOAD   R5, [R10 + S_CONTENT_R]
        SUB    R6, R6, R5
        SHIFTI R6, R6, 0x03, 0b1000
        CMP    R2, R6
        JNC    resize_columns_ok
        MOV    R2, R6
resize_columns_ok: LOAD R4, [R8 + W_Y]
        SUB    R3, R3, R4
        LOAD   R5, [R10 + S_CONTENT_T]
        SUB    R3, R3, R5               ; dots down the cells
        CMPIS  R3, 32
        JGE    resize_tall_enough
        LOADLO R3, 32                   ; at least 2 rows
resize_tall_enough: SHIFTI R3, R3, 0x04, 0b1000   ; R3 = rows
        LOADLO R6, PIXELS_DOWN          ; most that fit, (480 - y - margins) / 16
        SUB    R6, R6, R4
        SUB    R6, R6, R5
        LOAD   R5, [R10 + S_CONTENT_B]
        SUB    R6, R6, R5
        SHIFTI R6, R6, 0x04, 0b1000
        CMP    R3, R6
        JNC    resize_rows_ok
        MOV    R3, R6
resize_rows_ok: LOAD R4, [R8 + W_COLUMNS]
        CMP    R4, R2
        JNZ    resize_changed
        LOAD   R4, [R8 + W_ROWS]
        CMP    R4, R3
        JZ     resize_same
resize_changed: STORE R0, [R8 + W_FULL]  ; not full screen
        STORE  R2, [R8 + W_COLUMNS]
        STORE  R3, [R8 + W_ROWS]
        MOV    R1, R8
        CALL   window_size
        MOV    R1, R9
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
resize_same: POP R10
        POP    R9
        POP    R8
        RET

; raise, moves a window to the front of the order, in R1 = its number
raise:  LOADLO R2, 0                    ; R2 = its place in the order
raise_find: LOADLO R3, order
        SHIFTI R4, R2, 0x02, 0b0000
        ADD    R3, R3, R4
        LOAD   R4, [R3]
        CMP    R4, R1
        JZ     raise_shift
        INC    R2
        JUMP   raise_find
raise_shift: CMPI R2, WINDOW_COUNT - 1
        JZ     raise_put
        LOAD   R4, [R3 + 4]
        STORE  R4, [R3]
        ADDI   R3, R3, 4
        INC    R2
        JUMP   raise_shift
raise_put: STORE R1, [R3]
        RET

; front_window, out R1 = front visible window number or -1, uses R1-R5
front_window: LOADLO R2, WINDOW_COUNT - 1
front_next: LOADLO R3, order
        SHIFTI R4, R2, 0x02, 0b0000
        ADD    R3, R3, R4
        LOAD   R1, [R3]
        SHIFTI R5, R1, 0x07, 0b0000
        LOADLO R4, windows
        ADD    R5, R5, R4
        LOAD   R5, [R5 + W_VISIBLE]
        CMPI   R5, 0x0000
        JNZ    front_done
        CMPI   R2, 0x0000
        JZ     front_none
        DEC    R2
        JUMP   front_next
front_none: NOT R1, R0
front_done: RET
