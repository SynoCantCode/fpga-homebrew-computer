; icon_places, where each desktop icon sits, right button drag moves them
; included by wm.asm
; grid of 8 columns x 5 rows, 80 x 80 dots each, from (24, 24)
; place = column x 5 + row, 0-39, kept in A_PLACE
; saved in /SYSTEM/DESIGN/ICONS.TXT, one line each, "NAME PLACE"
; a file also has its icon, label colour and "off"
; like "notes.txt 5 floppy.pic 0F off"
; an icon taken off leaves a gap
; an icon put back goes after the last place used
; right button held and moved over 4 dots = drag
; dropped on a taken place = the two swap
; not moved = its menu
.equ PLACES, 40                             ; 8 columns x 5 rows

; load_layout, every records place from ICONS.TXT
; ones not named get the first free places, then ICONS.TXT is saved
; R8 = pointer in the text, R9 = its end, R10 = record or count
load_layout: PUSH R8
        PUSH   R9
        PUSH   R10
        LOADLO R10, 0                   ; every place = -1 first
layout_clear: LOAD R1, [app_count]
        CMP    R10, R1
        JC     layout_read
        MOV    R1, R10
        CALL   app_record
        NOT    R2, R0
        STORE  R2, [R1 + A_PLACE]
        INC    R10
        JUMP   layout_clear
layout_read: LA R1, layout_path
        CALL   load_text                ; line ends become 0s, the text is kept
        CMPI   R1, 0x0000               ; icon names point into it
        JZ     layout_new
        MOV    R9, R2                   ; R9 = end of the text
        CALL   line_first               ; R8 = a line
        MOV    R8, R1
layout_line: CMPI R8, 0x0000
        JZ     layout_new
        MOV    R1, R8                   ; find the next line first, cutting writes 0s
        MOV    R2, R9
        CALL   line_next
        PUSH   R1
        MOV    R1, R8                   ; its name
        CALL   first_word               ; R2 = name, R1 = the rest
        MOV    R10, R2
        CALL   read_number              ; R2 = its place, R1 = after it
        MOV    R8, R1
        CMPI   R2, PLACES
        JC     layout_line_done         ; 0-39 only
        PUSH   R2
        MOV    R1, R10
        CALL   find_app_number          ; R1 = app or file with this name, or -1
        POP    R2
        CMPIS  R1, -1
        JZ     layout_line_done
        PUSH   R2                       ; app_record uses R2
        CALL   app_record
        POP    R2
        STORE  R2, [R1 + A_PLACE]
        LOAD   R3, [R1 + A_KIND]        ; a file, icon and label colour may follow
        CMPI   R3, 0x0000
        JZ     layout_line_done
        PUSH   R1
        MOV    R1, R8
        CALL   first_word               ; R2 = icon name, R1 = the rest
        MOV    R8, R1
        POP    R1
        LOADB  R3, [R2]
        CMPI   R3, 0x0000
        JZ     layout_line_done         ; no icon named
        PUSH   R1
        PUSH   R8
        PUSH   R12
        MOV    R8, R1                   ; load_icon wants R8 = record, R12 = its number
        STORE  R2, [R8 + W_ICON_NAME]   ; number = (record - apps) / 128
        LOAD   R12, [apps]
        SUB    R12, R8, R12
        SHIFTI R12, R12, 0x07, 0b1000
        CALL   load_icon
        POP    R12
        POP    R8
        POP    R1
        LOADB  R3, [R8]                 ; label colour, if any
        CMPI   R3, 0x0000
        JZ     layout_line_done
        PUSH   R1
        MOV    R1, R8
        CALL   read_hex                 ; R2 = colour, R1 = after it
        MOV    R8, R1
        POP    R1
        STORE  R2, [R1 + A_LABEL]
        PUSH   R1                       ; then "off" = icon not on the desktop
        MOV    R1, R8
        CALL   read_word
        LA     R4, word_off
        CALL   word_is                  ; R5 = 1 if it is
        POP    R1
        CMPI   R5, 1
        JNZ    layout_line_done
        STORE  R0, [R1 + W_ICON]
layout_line_done: POP R8                ; next line
        JUMP   layout_line
layout_new: LOADLO R10, 0               ; ones with no place get the first free ones
        LOADLO R8, 0                    ; R8 = 1 if one got a place, save ICONS.TXT
layout_place: LOAD R1, [app_count]
        CMP    R10, R1
        JC     layout_placed
        MOV    R1, R10
        CALL   app_record
        LOAD   R2, [R1 + A_PLACE]
        CMPIS  R2, -1
        JNZ    layout_place_next
        PUSH   R1
        LOADLO R1, 0
        CALL   free_place               ; R1 = first free place, -1 = desktop full
        POP    R2
        STORE  R1, [R2 + A_PLACE]
        LOADLO R8, 1
layout_place_next: INC R10
        JUMP   layout_place
layout_placed: CMPI R8, 0x0000
        JZ     layout_end
        CALL   save_layout
layout_end: POP R10
        POP    R9
        POP    R8
        RET

; free_place, first place with no icon
; in R1 = where to start, out R1 = place or -1, uses R1-R6
free_place: CMPI R1, PLACES
        JNC    free_place_try
        NOT    R1, R0
        RET
free_place_try: MOV R6, R1
        CALL   nth_icon                 ; an icon there?
        CMPIS  R1, -1
        JZ     free_place_found
        ADDI   R1, R6, 1
        JUMP   free_place
free_place_found: MOV R1, R6
        RET

; end_place, first free place after the last one used, else first free anywhere
; out R1 = place or -1, uses R1-R6
end_place: LOADLO R6, PLACES - 1        ; look down from 39 for the last place used
end_place_look: MOV R1, R6
        PUSH   R6
        CALL   nth_icon
        POP    R6
        CMPIS  R1, -1
        JNZ    end_place_after
        CMPI   R6, 0x0000
        JZ     end_place_first          ; no icons at all
        DEC    R6
        JUMP   end_place_look
end_place_after: ADDI R1, R6, 1
        CALL   free_place
        CMPIS  R1, -1
        JNZ    end_place_done
end_place_first: LOADLO R1, 0
        JUMP   free_place
end_place_done: RET

; save_layout, writes ICONS.TXT from the records
; "NAME PLACE", a file also gets icon and label colour
; R9 = record, R10 = its number
save_layout: PUSH R9
        PUSH   R10
        LOADLO R1, 1024
        CALL   tb_start
        LOADLO R10, 0
save_layout_next: LOAD R1, [app_count]
        CMP    R10, R1
        JC     save_layout_write
        MOV    R1, R10
        CALL   app_record
        MOV    R9, R1
        LOAD   R1, [R9 + A_PLACE]
        CMPIS  R1, -1
        JZ     save_layout_skip         ; no place
        LOAD   R1, [R9 + W_NAME]        ; name, space, place
        CALL   tb_text
        LOADLO R1, 0x0020
        CALL   tb_char
        LOAD   R1, [R9 + A_PLACE]
        CALL   tb_number
        LOAD   R1, [R9 + A_KIND]        ; a file, icon and label colour too
        CMPI   R1, 0x0000
        JZ     save_layout_line
        LOAD   R1, [R9 + W_ICON_NAME]
        CMPI   R1, 0x0000
        JZ     save_layout_line
        LOADLO R1, 0x0020
        CALL   tb_char
        LOAD   R1, [R9 + W_ICON_NAME]
        CALL   tb_text
        LOADLO R1, 0x0020
        CALL   tb_char
        LOAD   R1, [R9 + A_LABEL]
        CALL   tb_hex2
        LOAD   R1, [R9 + W_ICON]        ; icon off the desktop, add " off"
        CMPI   R1, 0x0000
        JNZ    save_layout_line
        LA     R1, apps_off_text
        CALL   tb_text
save_layout_line: CALL tb_line
save_layout_skip: INC R10
        JUMP   save_layout_next
save_layout_write: LA R1, layout_path
        CALL   tb_save
        POP    R10
        POP    R9
        RET

; right_button, the right mouse button, every main loop
; pressed on an icon, icon_drag = its record + 1
; moved over 4 dots = drag, let go = icon_drop, not moved = its menu
; in R3 = button, 1 = down, R4 = button before, uses R1-R7
right_button: CMPI R3, 0x0000
        JZ     right_up
        CMPI   R4, 0x0000
        JNZ    right_held
        LOAD   R1, [menu_open]          ; just pressed, a menu showing = new menu
        CMPI   R1, 0x0000
        JNZ    right_menu_now
        LOAD   R1, [hover_place]        ; on an icon?
        CMPIS  R1, -1
        JZ     right_decor
        CALL   nth_icon
        CMPIS  R1, -1
        JZ     right_decor
        INC    R1
        STORE  R1, [icon_drag]
        STORE  R0, [icon_moved]
        LOAD   R1, [mouse_point]
        STORE  R1, [icon_drag_from]
        STORE  R1, [icon_drag_last]
        RET
right_decor: CALL decor_drag_start      ; on a decoration? it may be dragged
        CMPI   R1, 0x0000
        JNZ    right_button_done
right_menu_now: JUMP right_click
right_held: LOAD R1, [decor_drag]       ; a held decoration follows the pointer
        CMPI   R1, 0x0000
        JNZ    decor_drag_move
        LOAD   R1, [icon_drag]
        CMPI   R1, 0x0000
        JZ     right_button_done
        LOAD   R1, [mouse_point]        ; pointer moved?
        LOAD   R2, [icon_drag_last]
        CMP    R1, R2
        JZ     right_button_done
        STORE  R1, [icon_drag_last]
        LOAD   R2, [icon_moved]
        CMPI   R2, 0x0000
        JNZ    right_moving
        LOAD   R2, [icon_drag_from]          ; over 4 dots from the press, x or y?
        ANDI   R3, R1, 0xFFFF
        ANDI   R4, R2, 0xFFFF
        SUB    R3, R3, R4
        CALL   right_far
        CMPI   R3, 0x0000
        JNZ    right_start
        SHIFTI R3, R1, 0x10, 0b1000
        SHIFTI R4, R2, 0x10, 0b1000
        SUB    R3, R3, R4
        CALL   right_far
        CMPI   R3, 0x0000
        JZ     right_button_done
right_start: LOADLO R1, 1
        STORE  R1, [icon_moved]
right_moving: LOADLO R1, 1
        STORE  R1, [redraw]
right_button_done: RET
right_up: CMPI R4, 0x0000               ; let go
        JZ     right_button_done
        LOAD   R1, [decor_drag]         ; a decoration, saved where it is or its menu
        CMPI   R1, 0x0000
        JNZ    decor_drag_stop
        LOAD   R1, [icon_drag]
        CMPI   R1, 0x0000
        JZ     right_button_done
        STORE  R0, [icon_drag]
        LOAD   R2, [icon_moved]
        STORE  R0, [icon_moved]
        CMPI   R2, 0x0000
        JZ     right_menu_now           ; not moved, its menu
        DEC    R1
        JUMP   icon_drop

; right_far, is a distance over 4 dots
; in R3 = distance, can be negative, out R3 = 1 far, 0 near
right_far: CMPIS R3, 0
        JGE    right_far_plus
        SUB    R3, R0, R3
right_far_plus: CMPI R3, 5
        JNC    right_far_near           ; under 5
        LOADLO R3, 1
        RET
right_far_near: LOADLO R3, 0
        RET

; icon_drop, dragged icon goes to the place under the pointer
; an icon already there gets the old place, ICONS.TXT saved
; in R1 = dragged record number, R8 = it, R9 = the place
icon_drop: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOAD   R1, [mouse_point]
        ANDI   R2, R1, 0xFFFF
        SHIFTI R3, R1, 0x10, 0b1000
        DIVUI  R2, R2, 80               ; column, 0-7
        CMPI   R2, 8
        JNC    icon_drop_column
        LOADLO R2, 7
icon_drop_column: DIVUI R3, R3, 80           ; row, 0-4
        CMPI   R3, 5
        JNC    icon_drop_row
        LOADLO R3, 4
icon_drop_row: MULI R9, R2, 5
        ADD    R9, R9, R3
        MOV    R1, R9                   ; another icon there already?
        CALL   nth_icon
        CMPIS  R1, -1
        JZ     icon_drop_put
        CMP    R1, R8
        JZ     icon_drop_put
        PUSH   R1                       ; the other one gets the old place
        MOV    R1, R8
        CALL   app_record
        LOAD   R2, [R1 + A_PLACE]
        POP    R1
        PUSH   R2
        CALL   app_record
        POP    R2
        STORE  R2, [R1 + A_PLACE]
icon_drop_put: MOV R1, R8
        CALL   app_record
        STORE  R9, [R1 + A_PLACE]
        NOT    R1, R0
        STORE  R1, [hover_place]
        LOADLO R1, 1
        STORE  R1, [redraw]
        CALL   save_layout
        POP    R9
        POP    R8
        RET

; drag_icon_draw, the dragged icon centred on the pointer
; name under it in white, uses R1-R7
drag_icon_draw: LOAD R1, [icon_moved]
        CMPI   R1, 0x0000
        JZ     icon_drag_drawn
        LOAD   R1, [mouse_point]
        ANDI   R6, R1, 0xFFFF
        SHIFTI R7, R1, 0x10, 0b1000
        SUBI   R6, R6, 16               ; top left = pointer - 16, not below 0
        CMPIS  R6, 0
        JGE    icon_drag_x_ok
        LOADLO R6, 0
icon_drag_x_ok: SUBI R7, R7, 16
        CMPIS  R7, 0
        JGE    icon_drag_y_ok
        LOADLO R7, 0
icon_drag_y_ok: PUSH R6
        PUSH   R7
        SHIFTI R1, R7, 0x10, 0b0000
        OR     R1, R1, R6
        LOADHI R2, 32
        ORI    R2, R2, 32
        LOAD   R3, [icons]
        ORI    R3, R3, KEY
        LOAD   R4, [icon_drag]          ; source x = 32 x the record
        DEC    R4
        SHIFTI R4, R4, 0x05, 0b0000
        CALLF  DRAW_SPRITE
        LOAD   R1, [icon_drag]          ; its name, centred under it
        DEC    R1
        CALL   app_record
        LOAD   R3, [R1 + W_TITLE]
        MOV    R1, R3
        PUSH   R3
        CALL   text_length
        POP    R3
        POP    R7
        POP    R6
        SHIFTI R2, R2, 0x02, 0b0000
        ADDI   R1, R6, 16
        SUB    R1, R1, R2
        CMPIS  R1, 0
        JGE    icon_drag_label_x
        LOADLO R1, 0
icon_drag_label_x: ADDI R2, R7, 36
        LOADLO R4, WHITE_DOT
        JUMP   text                     ; tail call
icon_drag_drawn: RET
