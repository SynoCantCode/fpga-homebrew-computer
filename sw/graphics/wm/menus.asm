; menus, right click menus and the shells note
; included by wm.asm

; right_click, a menu at the pointer, for an icon, a window header or the desktop
; R8 = x, R9 = y, R10 = window or place in the order
right_click: PUSH R8
        PUSH   R9
        PUSH   R10
        STORE  R0, [menu_count]
        LOAD   R1, [mouse_point]
        ANDI   R8, R1, 0xFFFF
        SHIFTI R9, R1, 0x10, 0b1000
        CMPI   R9, TASKBAR_Y            ; not on the taskbar
        JC     right_done
        LOADLO R10, WINDOW_COUNT - 1    ; a window there? front first
right_window: LOADLO R1, order
        SHIFTI R2, R10, 0x02, 0b0000
        ADD    R1, R1, R2
        LOAD   R1, [R1]
        PUSH   R1
        CALL   window_record
        POP    R2
        LOAD   R3, [R1 + W_VISIBLE]
        CMPI   R3, 0x0000
        JZ     right_next
        LOAD   R3, [R1 + W_X]
        CMP    R8, R3
        JNC    right_next
        LOAD   R4, [R1 + W_WIDTH]
        ADD    R3, R3, R4
        CMP    R8, R3
        JC     right_next
        LOAD   R3, [R1 + W_Y]
        CMP    R9, R3
        JNC    right_next
        LOAD   R4, [R1 + W_STYLE]       ; on its header, above its cells?
        LOAD   R4, [R4 + S_CONTENT_T]
        ADD    R3, R3, R4
        CMP    R9, R3
        JC     right_done               ; inside it, nothing
        MOV    R10, R2                  ; Minimise, Full screen, Close
        LA     R1, menu_min_text
        LOADLO R2, MENU_MIN
        MOV    R3, R10
        CALL   menu_add
        LA     R1, menu_full_text
        LOADLO R2, MENU_FULL
        MOV    R3, R10
        CALL   menu_add
        LA     R1, menu_close_text
        LOADLO R2, MENU_CLOSE
        MOV    R3, R10
        CALL   menu_add
        JUMP   right_show
right_next: CMPI R10, 0x0000
        JZ     right_desktop
        DEC    R10
        JUMP   right_window
right_desktop: LOAD R1, [hover_place]   ; a desktop icon, Open, Remove, Edit page, Edit code, Build
        CMPIS  R1, -1
        JZ     right_empty
        CALL   nth_icon
        MOV    R10, R1
        CALL   app_record               ; a file on the desktop has its own menu
        LOAD   R1, [R1 + A_KIND]
        CMPI   R1, 0x0000
        JZ     right_app_menu
        CALL   item_menu
        JUMP   right_show
right_app_menu: LA R1, menu_open_text
        LOADLO R2, MENU_OPEN
        MOV    R3, R10
        CALL   menu_add
        MOV    R1, R10                  ; Remove icon, not for Settings
        CALL   is_settings
        CMPI   R1, 0x0000
        JNZ    right_no_remove
        LA     R1, menu_remove_text
        LOADLO R2, MENU_REMOVE
        MOV    R3, R10
        CALL   menu_add
right_no_remove:
        MOV    R1, R10                  ; a full screen app has no Edit page
        CALL   app_record
        LOAD   R1, [R1 + A_FULL]
        CMPI   R1, 0x0000
        JNZ    right_show
        LA     R1, menu_edit_text
        LOADLO R2, MENU_EDIT
        MOV    R3, R10
        CALL   menu_add
        LA     R1, menu_code_text
        LOADLO R2, MENU_CODE
        MOV    R3, R10
        CALL   menu_add
        LA     R1, menu_build_text
        LOADLO R2, MENU_BUILD
        MOV    R3, R10
        CALL   menu_add
        JUMP   right_show
right_empty: LA R1, menu_settings_text  ; empty desktop, Settings, Files
        LOADLO R2, MENU_APP
        LA     R3, settings_name
        CALL   menu_add
        LA     R1, menu_files_text
        LOADLO R2, MENU_APP
        LA     R3, files_name
        CALL   menu_add
right_show: LOADLO R1, PIXELS_ACROSS - MENU_WIDTH   ; at the pointer, kept on the screen
        CMP    R8, R1
        JNC    right_x
        MOV    R8, R1
right_x: STORE R8, [menu_x]
        LOAD   R1, [menu_count]
        MULI   R1, R1, MENU_ROW
        ADDI   R1, R1, 4
        LOADLO R2, TASKBAR_Y
        SUB    R2, R2, R1
        CMP    R9, R2
        JNC    right_y
        MOV    R9, R2
right_y: STORE R9, [menu_y]
        LOADLO R1, 1
        STORE  R1, [menu_open]
        STORE  R1, [redraw]
right_done: POP R10
        POP    R9
        POP    R8
        RET

; menu_add, adds an item to the menu
; in R1 = text pointer, R2 = action, R3 = window or app name, uses R4, R5
menu_add: LOAD R4, [menu_count]
        CMPI   R4, MENU_MAX
        JZ     menu_add_done
        MULI   R5, R4, 12
        ADDIW  R5, R5, menu_items
        STORE  R1, [R5]
        STORE  R2, [R5 + 4]
        STORE  R3, [R5 + 8]
        INC    R4
        STORE  R4, [menu_count]
menu_add_done: RET

; menu_at, item under the pointer, out R1 = item or -1, uses R1-R4
menu_at: LOAD R1, [mouse_point]
        ANDI   R2, R1, 0xFFFF
        SHIFTI R3, R1, 0x10, 0b1000
        LOAD   R4, [menu_x]
        SUB    R2, R2, R4
        CMPIS  R2, 0
        JGE    menu_at_x
        JUMP   menu_at_none
menu_at_x: CMPI R2, MENU_WIDTH
        JC     menu_at_none
        LOAD   R4, [menu_y]
        SUB    R3, R3, R4
        SUBI   R3, R3, 2
        CMPIS  R3, 0
        JGE    menu_at_y
        JUMP   menu_at_none
menu_at_y: DIVUI R1, R3, MENU_ROW
        LOAD   R4, [menu_count]
        CMP    R1, R4
        JC     menu_at_none
        RET
menu_at_none: NOT R1, R0
        RET

; menu_click, a click while a menu shows, runs the item, menu closes
menu_click: PUSH R8
        STORE  R0, [menu_open]
        LOADLO R1, 1
        STORE  R1, [redraw]
        CALL   menu_at
        CMPIS  R1, -1
        JZ     menu_click_done
        MULI   R8, R1, 12
        ADDIW  R8, R8, menu_items
        LOAD   R1, [R8 + 4]
        CMPI   R1, MENU_APP
        JZ     menu_app
        LOAD   R2, [R8 + 8]             ; the others take a window
        CMPI   R1, MENU_OPEN
        JZ     menu_show
        CMPI   R1, MENU_MIN
        JZ     menu_min
        CMPI   R1, MENU_FULL
        JZ     menu_full
        CMPI   R1, MENU_EDIT
        JZ     menu_edit
        CMPI   R1, MENU_REMOVE
        JZ     menu_remove
        CMPI   R1, MENU_CODE
        JZ     menu_code
        CMPI   R1, MENU_BUILD
        JZ     menu_build
        CMPI   R1, MENU_UNDECORATE
        JZ     menu_undecorate
        MOV    R1, R2                   ; Close
        CALL   window_record
        CALL   close_window
        JUMP   menu_click_done
menu_show: MOV R1, R2                   ; Open, the icons app
        CALL   launch_app
        JUMP   menu_click_done
menu_undecorate: MOV R1, R2             ; Remove decoration
        CALL   decor_remove
        JUMP   menu_click_done
menu_remove: MOV R1, R2                 ; Remove from desktop
        CALL   remove_icon
        JUMP   menu_click_done
menu_min: MOV R1, R2
        CALL   window_record
        STORE  R0, [R1 + W_VISIBLE]
        JUMP   menu_click_done
menu_full: MOV R1, R2
        PUSH   R2
        CALL   raise
        POP    R1
        CALL   window_record
        CALL   toggle_full
        JUMP   menu_click_done
menu_app: LOAD R1, [R8 + 8]
        CALL   api_open
        JUMP   menu_click_done
menu_edit: LA  R3, run_studio_text      ; Edit page, "run /studio.bin NAME"
        LA     R4, nothing_text
        JUMP   menu_note
menu_code: LA  R3, run_edit_text        ; Edit code, "run /edit.bin /apps/NAME/app.asm"
        LA     R4, app_asm_text
        JUMP   menu_note
menu_build: LA R3, run_build_text       ; Build, "run /build.bin NAME"
        LA     R4, nothing_text
menu_note: CALL note_for                ; then "run /wm.bin", and WM ends
menu_click_done: POP R8
        RET

; note_for, shell note for one app, a command with its name, then "run /wm.bin"
; sets quit_now, in R2 = app, R3 = text before the name, R4 = text after
; R8 = app name, R9 = text after it
note_for: PUSH R8
        PUSH   R9
        MOV    R9, R4
        PUSH   R3
        MOV    R1, R2
        CALL   app_record
        LOAD   R8, [R1 + W_NAME]
        POP    R1
        LOADLO R2, NEXT_COMMANDS
        CALL   note_add
        MOV    R1, R8
        CALL   note_add
        MOV    R1, R9
        CALL   note_line
        LA     R1, run_wm_text
        CALL   note_line
        STOREB R0, [R2]
        LOADLO R1, 1
        STORE  R1, [quit_now]
        POP    R9
        POP    R8
        RET

; the shells note, NEXT_COMMANDS, kernel RAM 0x4800-0x48FF
; commands, one a line, the shell runs them after WM ends
; like "run /studio.bin clock" then "run /wm.bin"
; note_add, text onto the note, note_line adds a line end 0x0A too
; in R1 = text pointer, R2 = where on the note, out R2 = after it
; what doesnt fit is left out, uses R1, R3, R5
note_add: LOADLO R5, NEXT_COMMANDS + NEXT_COMMANDS_SIZE - 2
note_add_next: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     note_add_done
        CMP    R2, R5
        JC     note_add_done            ; full
        STOREB R3, [R2]
        INC    R1
        INC    R2
        JUMP   note_add_next
note_add_done: RET
note_line: CALL note_add
        LOADLO R3, 0x000A
        STOREB R3, [R2]
        INC    R2
        RET

; is_full_app, does its page have shell lines
; in R1 = window, out R1 = 1 yes, 0 no, uses R2-R4
is_full_app: CALL window_record
        LOAD   R2, [R1 + W_ELEMENTS]
        LOAD   R3, [R1 + W_ELEMENT_COUNT]
fullapp_next: CMPI R3, 0x0000
        JZ     fullapp_no
        LOADB  R4, [R2]
        CMPI   R4, E_SHELL
        JZ     fullapp_yes
        ADDI   R2, R2, ELEMENT_BYTES
        DEC    R3
        JUMP   fullapp_next
fullapp_no: LOADLO R1, 0
        RET
fullapp_yes: LOADLO R1, 1
        RET

; shell_check, a visible page with shell lines? lines go on the note, window closes
; out R1 = 1 WM ends, else 0, R8 = the windows 128 bytes
; R9 = element pointer, R10 = window number, R4 = elements left, R2 = where on the note
shell_check: PUSH R8
        PUSH   R9
        PUSH   R10
        LOADLO R10, 0
check_window: MOV R1, R10
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [R8 + W_KIND]
        CMPI   R1, KIND_PAGE
        JNZ    check_next
        LOAD   R1, [R8 + W_VISIBLE]
        CMPI   R1, 0x0000
        JZ     check_next
        LOAD   R9, [R8 + W_ELEMENTS]
        LOAD   R4, [R8 + W_ELEMENT_COUNT]
        LOADLO R2, NEXT_COMMANDS
check_element: CMPI R4, 0x0000
        JZ     check_end
        LOADB  R1, [R9]
        CMPI   R1, E_SHELL
        JNZ    check_skip
        LOAD   R1, [R9 + 4]
        CALL   note_line
check_skip: ADDI R9, R9, ELEMENT_BYTES
        DEC    R4
        JUMP   check_element
check_end: LOADLO R3, NEXT_COMMANDS
        CMP    R2, R3
        JZ     check_next               ; no shell lines, an ordinary window
        STOREB R0, [R2]
        STORE  R0, [R8 + W_VISIBLE]
        LOADLO R1, 1
        JUMP   check_done
check_next: INC R10
        CMPI   R10, WINDOW_COUNT
        JNZ    check_window
        LOADLO R1, 0
check_done: POP R10
        POP    R9
        POP    R8
        RET

; draw_menu, a raised box, an item a row, the one under the pointer navy
; R8 = item, R9 = its y, R10 = item under the pointer
draw_menu: LOAD R1, [menu_open]
        CMPI   R1, 0x0000
        JNZ    draw_menu_go
        RET
draw_menu_go: PUSH R8
        PUSH   R9
        PUSH   R10
        CALL   menu_at
        MOV    R10, R1
        LOAD   R1, [menu_x]
        LOAD   R2, [menu_y]
        LOADLO R3, MENU_WIDTH
        LOAD   R4, [menu_count]
        MULI   R4, R4, MENU_ROW
        ADDI   R4, R4, 4
        LOADLO R5, 1
        CALL   bevel_box
        LOADLO R8, 0
draw_menu_item: LOAD R1, [menu_count]
        CMP    R8, R1
        JC     draw_menu_done
        MULI   R9, R8, MENU_ROW
        LOAD   R1, [menu_y]
        ADD    R9, R9, R1
        ADDI   R9, R9, 2
        LOADLO R4, BLACK_DOT
        CMP    R8, R10
        JNZ    draw_menu_text
        LOAD   R1, [menu_x]             ; under the pointer, navy
        ADDI   R1, R1, 2
        MOV    R2, R9
        LOADLO R3, MENU_WIDTH - 4
        LOADLO R4, MENU_ROW
        LOADLO R5, NAVY + 8
        CALL   box
        LOADLO R4, WHITE_DOT
draw_menu_text: LOAD R1, [menu_x]
        ADDI   R1, R1, 8
        ADDI   R2, R9, 1
        MULI   R3, R8, 12
        ADDIW  R3, R3, menu_items
        LOAD   R3, [R3]
        CALL   text
        INC    R8
        JUMP   draw_menu_item
draw_menu_done: POP R10
        POP    R9
        POP    R8
        RET
