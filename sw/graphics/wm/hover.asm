; wm hover, lit buttons, popping icons, full screen, animation
; included by programs/wm.asm

; hover_controls, which button the pointer is over
; hover_task = taskbar place, hover_title = window x 4 + 1 close, 2 full, 3 minimise
; hover_button, hover_button_win = a page button, redraws on a change
; R8 = x, R9 = y, R10 = window under the pointer or -1, R11 = new value
hover_controls: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        LOAD   R1, [mouse_point]
        ANDI   R8, R1, 0xFFFF
        SHIFTI R9, R1, 0x10, 0b1000
        NOT    R11, R0                  ; taskbar button, -1 = none
        CMPI   R9, TASKBAR_Y
        JNC    hover_task_set
        CALL   front_is_full
        CMPI   R1, 0x0000
        JNZ    hover_task_set
        CMPI   R8, TASK_LEFT
        JNC    hover_task_set
        CMPI   R8, TRAY_X
        JC     hover_task_set
        SUBI   R1, R8, TASK_LEFT
        LOAD   R3, [task_step]
        DIVU   R2, R1, R3
        MODU   R1, R1, R3
        SUBI   R3, R3, 4
        CMP    R1, R3
        JC     hover_task_set
        PUSH   R2
        MOV    R1, R2
        CALL   nth_used
        POP    R2
        CMPIS  R1, -1
        JZ     hover_task_set
        MOV    R11, R2
hover_task_set: LOAD R1, [hover_task]
        CMP    R1, R11
        JZ     hover_window
        STORE  R11, [hover_task]
        LOADLO R1, 1
        STORE  R1, [redraw]
hover_window: CALL window_under         ; window under the pointer
        MOV    R10, R1
        NOT    R11, R0                  ; its title buttons, -1 = none
        CMPIS  R10, -1
        JZ     hover_title_set
        MOV    R1, R10
        CALL   window_record
        PUSH   R1
        CALL   close_place
        CALL   hover_in_16
        POP    R6
        LOADLO R7, 1
        CMPI   R1, 0x0000
        JNZ    hover_title_found
        PUSH   R6
        LOAD   R1, [R6 + W_NO_FULL]
        CMPI   R1, 0x0000
        JNZ    hover_title_min
        MOV    R1, R6
        CALL   full_place
        CALL   hover_in_16
        LOADLO R7, 2
        CMPI   R1, 0x0000
        JNZ    hover_title_pop
hover_title_min: POP R6
        PUSH   R6
        MOV    R1, R6
        CALL   min_place
        CALL   hover_in_16
        LOADLO R7, 3
        CMPI   R1, 0x0000
        JNZ    hover_title_pop
        POP    R6
        JUMP   hover_title_set
hover_title_pop: POP R6
hover_title_found: SHIFTI R11, R10, 0x02, 0b0000
        OR     R11, R11, R7
hover_title_set: LOAD R1, [hover_title]
        CMP    R1, R11
        JZ     hover_page
        STORE  R11, [hover_title]
        LOADLO R1, 1
        STORE  R1, [redraw]
hover_page: LOADLO R11, 0               ; a page button, 0 = none
        CMPIS  R10, -1
        JZ     hover_page_set
        MOV    R1, R10
        CALL   button_under
        MOV    R11, R1
hover_page_set: LOAD R1, [hover_button]
        CMP    R1, R11
        JZ     hover_controls_done
        STORE  R11, [hover_button]      ; changed, redraw the old and the new window
        CMPI   R1, 0x0000
        JZ     hover_page_new
        LOAD   R1, [hover_button_win]
        CALL   draw_window
hover_page_new: STORE R10, [hover_button_win]
        CMPI   R11, 0x0000
        JZ     hover_page_drawn
        MOV    R1, R10
        CALL   draw_window
hover_page_drawn: LOADLO R1, 1
        STORE  R1, [redraw]
hover_controls_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; hover_in_16, pointer (R8, R9) in the 16 x 16 box at (R1, R2)? out R1 = 1, uses R1, R2
hover_in_16: CMP R8, R1
        JNC    in_16_no
        ADDI   R1, R1, 16
        CMP    R8, R1
        JC     in_16_no
        CMP    R9, R2
        JNC    in_16_no
        ADDI   R2, R2, 16
        CMP    R9, R2
        JC     in_16_no
        LOADLO R1, 1
        RET
in_16_no: LOADLO R1, 0
        RET

; window_under, front window under the pointer (R8, R9), out R1 = number or -1, uses R1-R7
window_under: LOADLO R6, WINDOW_COUNT - 1
under_next: LOADLO R1, order
        SHIFTI R2, R6, 0x02, 0b0000
        ADD    R1, R1, R2
        LOAD   R7, [R1]                 ; R7 = the window
        MOV    R1, R7
        CALL   window_record
        LOAD   R2, [R1 + W_VISIBLE]
        CMPI   R2, 0x0000
        JZ     under_skip
        LOAD   R2, [R1 + W_X]
        CMP    R8, R2
        JNC    under_skip
        LOAD   R3, [R1 + W_WIDTH]
        ADD    R2, R2, R3
        CMP    R8, R2
        JC     under_skip
        LOAD   R2, [R1 + W_Y]
        CMP    R9, R2
        JNC    under_skip
        LOAD   R3, [R1 + W_HEIGHT]
        ADD    R2, R2, R3
        CMP    R9, R2
        JC     under_skip
        MOV    R1, R7
        RET
under_skip: CMPI R6, 0x0000
        JZ     under_none
        DEC    R6
        JUMP   under_next
under_none: NOT R1, R0
        RET

; button_under, page button under the pointer (R8, R9)
; in R1 = window, out R1 = pointer to the button element or 0, uses R1-R7
button_under: PUSH R12
        MOV    R12, R1
        CALL   window_record
        MOV    R6, R1                   ; R6 = its record
        LOAD   R2, [R6 + W_KIND]
        CMPI   R2, KIND_PAGE
        JNZ    under_button_none
        LOAD   R5, [R6 + W_STYLE]
        LOAD   R2, [R6 + W_X]           ; the cell, column
        SUB    R2, R8, R2
        LOAD   R3, [R5 + S_CONTENT_L]
        SUB    R2, R2, R3
        CMPIS  R2, 0
        JGE    under_button_x
        JUMP   under_button_none
under_button_x: SHIFTI R2, R2, 0x03, 0b1000
        LOAD   R3, [R6 + W_Y]           ; and row, + the scroll
        SUB    R3, R9, R3
        LOAD   R4, [R5 + S_CONTENT_T]
        SUB    R3, R3, R4
        CMPIS  R3, 0
        JGE    under_button_y
        JUMP   under_button_none
under_button_y: SHIFTI R3, R3, 0x04, 0b1000
        SHIFTI R4, R12, 0x02, 0b0000
        LOADLO R5, scroll_rows
        ADD    R4, R4, R5
        LOAD   R4, [R4]
        ADD    R3, R3, R4
        LOAD   R4, [R6 + W_ELEMENTS]    ; buttons on that row, column inside label + 2?
        LOAD   R12, [R6 + W_ELEMENT_COUNT]
under_button_next: CMPI R12, 0x0000
        JZ     under_button_none
        LOADB  R5, [R4]
        CMPI   R5, E_BUTTON
        JNZ    under_button_skip
        LOADB  R5, [R4 + 2]
        CMP    R5, R3
        JNZ    under_button_skip
        LOADB  R5, [R4 + 1]
        CMP    R2, R5
        JNC    under_button_skip
        PUSH   R2
        PUSH   R3
        PUSH   R4
        PUSH   R5
        LOAD   R1, [R4 + 4]
        CALL   text_length                   ; R2 = label length, uses R3
        MOV    R6, R2
        POP    R5
        POP    R4
        POP    R3
        POP    R2
        ADD    R5, R5, R6
        ADDI   R5, R5, 2
        CMP    R2, R5
        JC     under_button_skip
        MOV    R1, R4
        POP    R12
        RET
under_button_skip: ADDI R4, R4, ELEMENT_BYTES
        DEC    R12
        JUMP   under_button_next
under_button_none: LOADLO R1, 0
        POP    R12
        RET

; hover_check, which desktop icon the pointer is over, or -1
; icon and label are 32 x 48, columns of 5, 80 apart, uses R1-R7
hover_check: LOAD R1, [mouse_point]
        ANDI   R2, R1, 0xFFFF           ; x
        SHIFTI R3, R1, 0x10, 0b1000     ; y
        NOT    R1, R0                   ; -1 = none
        CMPI   R2, 24
        JNC    hover_set
        CMPI   R3, 24
        JNC    hover_set
        CMPI   R3, TASKBAR_Y
        JC     hover_set
        SUBI   R4, R2, 24
        DIVUI  R5, R4, 80               ; R5 = column
        MODUI  R4, R4, 80
        CMPI   R4, 32
        JC     hover_set
        SUBI   R6, R3, 24
        DIVUI  R7, R6, 80               ; R7 = row
        MODUI  R6, R6, 80
        CMPI   R6, 48
        JC     hover_set
        CMPI   R7, 5
        JC     hover_set
        MULI   R6, R5, 5
        ADD    R6, R6, R7               ; R6 = place
        MOV    R1, R6
        CALL   nth_icon                 ; an icon there?
        CMPIS  R1, -1
        JZ     hover_set
        MOV    R1, R6
hover_set: LOAD R2, [menu_open]          ; menu showing, redraw for its highlight
        CMPI   R2, 0x0000
        JZ     hover_compare
        LOADLO R2, 1
        STORE  R2, [redraw]
hover_compare: LOAD R2, [hover_place]
        CMP    R1, R2
        JZ     hover_done
        STORE  R1, [hover_place]
        LOADLO R1, 1
        STORE  R1, [redraw]
hover_done: RET

; toggle_full, window to full screen or back, old place and size kept
; in R1 = its record
; R8 = record, R9 = its style
toggle_full: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOAD   R9, [R8 + W_STYLE]
        LOAD   R1, [R8 + W_FULL]
        CMPI   R1, 0x0000
        JZ     full_on
        LOAD   R1, [R8 + W_SAVED_X]     ; back to where it was
        STORE  R1, [R8 + W_X]
        LOAD   R1, [R8 + W_SAVED_Y]
        STORE  R1, [R8 + W_Y]
        LOAD   R1, [R8 + W_SAVED_COLUMNS]
        STORE  R1, [R8 + W_COLUMNS]
        LOAD   R1, [R8 + W_SAVED_ROWS]
        STORE  R1, [R8 + W_ROWS]
        STORE  R0, [R8 + W_FULL]
        JUMP   full_drawn
full_on: LOAD  R1, [R8 + W_X]           ; save how it is
        STORE  R1, [R8 + W_SAVED_X]
        LOAD   R1, [R8 + W_Y]
        STORE  R1, [R8 + W_SAVED_Y]
        LOAD   R1, [R8 + W_COLUMNS]
        STORE  R1, [R8 + W_SAVED_COLUMNS]
        LOAD   R1, [R8 + W_ROWS]
        STORE  R1, [R8 + W_SAVED_ROWS]
        STORE  R0, [R8 + W_X]           ; then the whole screen
        STORE  R0, [R8 + W_Y]
        LOADLO R1, PIXELS_ACROSS        ; columns = (640 - margins) / 8
        LOAD   R2, [R9 + S_CONTENT_L]
        SUB    R1, R1, R2
        LOAD   R2, [R9 + S_CONTENT_R]
        SUB    R1, R1, R2
        SHIFTI R1, R1, 0x03, 0b1000
        CMPI   R1, 79
        JNC    full_columns
        LOADLO R1, 78                   ; at most 78
full_columns: STORE R1, [R8 + W_COLUMNS]
        LOADLO R1, PIXELS_DOWN          ; rows = (480 - margins) / 16
        LOAD   R2, [R9 + S_CONTENT_T]
        SUB    R1, R1, R2
        LOAD   R2, [R9 + S_CONTENT_B]
        SUB    R1, R1, R2
        SHIFTI R1, R1, 0x04, 0b1000
        CMPI   R1, 31
        JNC    full_rows
        LOADLO R1, 30                   ; at most 30
full_rows: STORE R1, [R8 + W_ROWS]
        LOADLO R1, 1
        STORE  R1, [R8 + W_FULL]
full_drawn: MOV R1, R8                  ; new size, draw again
        CALL   window_size
        LOAD   R1, [R8 + W_FULL]
        CMPI   R1, 0x0000
        JZ     full_size_done
        LOADLO R1, PIXELS_ACROSS        ; full screen is exactly 640 x 480
        STORE  R1, [R8 + W_WIDTH]
        LOADLO R1, PIXELS_DOWN
        STORE  R1, [R8 + W_HEIGHT]
full_size_done: LOADLO R2, windows
        SUB    R1, R8, R2
        SHIFTI R1, R1, 0x07, 0b1000
        CALL   draw_window
        POP    R9
        POP    R8
        RET

; anim_tick, animation step, 10 a second
; next frame of each strip icon, redraws open windows that animate
; R8 = the window, R9 = its record
anim_tick: PUSH R8
        PUSH   R9
        LOAD   R1, [tray_frame]         ; tray light, next frame
        INC    R1
        STORE  R1, [tray_frame]
        LOAD   R1, [tray_net]
        SHIFTI R1, R1, 0x02, 0b0000
        LOADLO R2, tray_widths
        ADD    R1, R1, R2
        LOAD   R1, [R1]
        CMPI   R1, 17
        JNC    anim_apps
        LOADLO R1, 1
        STORE  R1, [redraw]
anim_apps: CALL decor_anim               ; decoration strips, next frames
        LOADLO R8, 0                    ; animated app icons, next frame into the icons picture
anim_next: LOAD R1, [app_count]
        CMP    R8, R1
        JC     anim_windows
        MOV    R1, R8
        CALL   app_record
        MOV    R9, R1
        LOAD   R1, [R9 + W_ICON_FRAMES]
        CMPI   R1, 2
        JNC    anim_icon_next           ; not animated
        LOAD   R2, [R9 + W_ICON_FRAME]  ; next frame
        INC    R2
        CMP    R2, R1
        JNC    anim_frame
        LOADLO R2, 0
anim_frame: STORE R2, [R9 + W_ICON_FRAME]
        LOAD   R1, [DRAW_PAGE]
        STORE  R1, [saved_page]
        LOAD   R1, [icons]
        STORE  R1, [DRAW_PAGE]          ; into the icons picture at (32 x app, 0)
        SHIFTI R4, R2, 0x05, 0b0000     ; from (32 x frame, 0) in the strip
        SHIFTI R1, R8, 0x05, 0b0000
        LOADHI R2, 32
        ORI    R2, R2, 32
        LOAD   R3, [R9 + W_ICON_STRIP]
        CALLF  DRAW_COPY
        LOAD   R1, [saved_page]
        STORE  R1, [DRAW_PAGE]
        LOADLO R1, 1
        STORE  R1, [redraw]
anim_icon_next: INC R8
        JUMP   anim_next
anim_windows: LOADLO R8, 0              ; open windows with an animate, draw again
anim_window: MOV R1, R8
        CALL   window_record
        MOV    R9, R1
        LOAD   R1, [R9 + W_KIND]
        CMPI   R1, KIND_NONE
        JZ     anim_skip
anim_page: LOAD R1, [R9 + W_ANIMATES]
        CMPI   R1, 0x0000
        JZ     anim_skip
        LOAD   R1, [R9 + W_VISIBLE]
        CMPI   R1, 0x0000
        JZ     anim_skip
        MOV    R1, R8
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
anim_skip: INC R8
        CMPI   R8, WINDOW_COUNT
        JNZ    anim_window
        POP    R9
        POP    R8
        RET

; front_is_full, out R1 = 1 if the front open window is full screen, else 0
; uses R1-R5
front_is_full: CALL front_window
        CMPIS  R1, -1
        JZ     front_not_full
        CALL   window_record
        LOAD   R1, [R1 + W_FULL]
        RET
front_not_full: LOADLO R1, 0
        RET
