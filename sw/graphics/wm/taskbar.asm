; taskbar, window buttons, the tray with clock and network light, the search box
; included by wm.asm

; taskbar, the bar at the bottom, search box then a button for each window in use
; buttons start at TASK_LEFT, the front one pressed in
; up to 90 dots wide, task_step = width + 4, titles cut to fit
; in R10 = front window number, R8 = window, R9 = its 128 bytes, R11 = button place
taskbar: PUSH  R8
        PUSH   R9
        PUSH   R11
        LOADLO R1, 0
        LOADLO R2, TASKBAR_Y
        LOADLO R3, PIXELS_ACROSS
        LOADLO R4, PIXELS_DOWN - TASKBAR_Y
        LOADLO R5, 1
        CALL   bevel_box
        CALL   tray_draw                ; search box on the left, tray on the right
        CALL   taskbar_layout
        LOADLO R8, 0
        LOADLO R11, 0
taskbar_button: MOV R1, R8
        CALL   window_record
        MOV    R9, R1
        LOAD   R1, [R9 + W_KIND]
        CMPI   R1, KIND_NONE
        JZ     taskbar_next
        LOAD   R1, [task_step]          ; button x = TASK_LEFT + place x task_step
        MUL    R1, R11, R1
        ADDI   R1, R1, TASK_LEFT
        LOADLO R2, TASKBAR_Y + 4
        LOAD   R3, [task_step]
        SUBI   R3, R3, 4
        LOADLO R4, 20
        LOADLO R5, 1                    ; raised, lit up if the pointer is over it
        LOAD   R6, [hover_task]
        CMP    R6, R11
        JNZ    taskbar_front
        LOADLO R5, 2
taskbar_front: CMP R8, R10
        JNZ    taskbar_raised
        LOADLO R5, 0                    ; pressed in, the front window
taskbar_raised: CALL bevel_box
        LOAD   R1, [R9 + W_TITLE]       ; title cut to the letters that fit, (width - 8) / 8
        LOADLO R2, task_text
        CALL   text_copy
        LOAD   R1, [task_step]
        SUBI   R1, R1, 12
        SHIFTI R1, R1, 0x03, 0b1000
        LOADLO R2, task_text
        ADD    R2, R2, R1
        STOREB R0, [R2]                 ; a shorter title ends sooner
        LOAD   R1, [task_step]
        MUL    R1, R11, R1
        ADDI   R1, R1, TASK_LEFT + 6
        LOADLO R2, TASKBAR_Y + 6
        LOADLO R3, task_text
        LOADLO R4, BLACK_DOT
        LOAD   R5, [R9 + W_VISIBLE]
        CMPI   R5, 0x0000
        JNZ    taskbar_text
        LOADLO R4, SHADOW               ; closed window, grey letters
taskbar_text: CALL text
        INC    R11
taskbar_next: INC R8
        CMPI   R8, WINDOW_COUNT
        JNZ    taskbar_button
        POP    R11
        POP    R9
        POP    R8
        RET

; the tray, right end, and the search box, left end
; tray_load, the 16 x 16 pictures from /SYSTEM/DESIGN/SPRITES
; NETOFF, NETCABLE, NETOK and SEARCH .PIC
; one missing = a plain drawing, then a first tray_tick
; R8 = which picture, 0-3, R9 = pointer to its name in tray_names
tray_load: PUSH R8
        PUSH   R9
        LOAD   R1, [sprite_place]       ; each gets its own room from the heap
        PUSH   R1
        STORE  R0, [sprite_place]
        LOADLO R8, 0
        LA     R9, tray_names
tray_load_next: LA R1, nothing_name     ; no app folder, the shared sprites
        MOV    R2, R9
        CALL   load_sprite              ; R1 = its width, 0 = not there, R3 = where
        CMPI   R1, 0x0000
        JZ     tray_load_skip
        SHIFTI R2, R8, 0x02, 0b0000     ; 4 x which, into tray_widths and tray_sprites
        LOADLO R4, tray_widths
        ADD    R4, R4, R2
        STORE  R1, [R4]
        LOADLO R4, tray_sprites
        ADD    R4, R4, R2
        STORE  R3, [R4]
tray_load_skip: MOV R1, R9              ; next name, after this ones 0
        CALL   text_length
        ADD    R9, R9, R2
        INC    R9
        INC    R8
        CMPI   R8, 4
        JNZ    tray_load_next
        POP    R1
        STORE  R1, [sprite_place]
        NOT    R1, R0                   ; no second seen yet, tray_tick looks
        STORE  R1, [tray_second]
        CALL   tray_tick
        POP    R9
        POP    R8
        RET

; tray_tick, every main loop, on a new second reads the time and the network
; time = DS3231 over I2C, registers 1 and 2, network = net_link and NET_IP
; if either changed, the text is made again and the screen drawn
; R8 = time, hours x 256 + minutes, 0xFFFF = no chip, R9 = network, 0 / 1 / 2
tray_tick: LOAD R1, [TIMER]
        DIVUI  R1, R1, 100              ; timer counts hundredths of a second
        LOAD   R2, [tray_second]
        CMP    R1, R2
        JNZ    tray_due
        RET
tray_due: STORE R1, [tray_second]
        PUSH   R8
        PUSH   R9
        LOADLO R1, CLOCK_CHIP           ; 2 bytes from register 1, minutes then hours
        LOADLO R2, 1
        LOADLO R3, 2
        LOADLO R4, tray_chip
        CALLF  I2C_READ                 ; R1 = 0, it answered
        LOADLO R8, 0xFFFF
        CMPI   R1, 0x0000
        JNZ    tray_network
        LOADB  R8, [tray_chip + 1]      ; hours, 24 hour, bits 0-5
        ANDI   R8, R8, 0x003F
        SHIFTI R8, R8, 0x08, 0b0000
        LOADB  R1, [tray_chip]          ; minutes
        ANDI   R1, R1, 0x007F
        OR     R8, R8, R1
tray_network: LOADLO R9, 0              ; 0 = no cable
        LOAD   R5, [NET_CALLS + 4]      ; net_link, 0 = kernel without the network
        CMPI   R5, 0x0000
        JZ     tray_compare
        CALLR  R5                       ; R1 = 1, link is up
        CMPI   R1, 0x0000
        JZ     tray_compare
        LOADLO R9, 1                    ; 1 = cable
        LOAD   R1, [NET_IP]
        CMPI   R1, 0x0000
        JZ     tray_compare
        LOADLO R9, 2                    ; 2 = has an IP, connected
tray_compare: LOAD R1, [tray_time]
        CMP    R1, R8
        JNZ    tray_changed
        LOAD   R1, [tray_net]
        CMP    R1, R9
        JZ     tray_end
tray_changed: STORE R8, [tray_time]
        STORE  R9, [tray_net]
        CALL   tray_format
        LOADLO R1, 1
        STORE  R1, [redraw]
tray_end: POP  R9
        POP    R8
        RET

; tray_format, tray_time into tray_text as "HH:MM", BCD digits, "--:--" = no chip
tray_format: LOAD R1, [tray_time]
        LOADLO R2, 0xFFFF
        CMP    R1, R2
        JZ     tray_no_time
        LOADLO R3, tray_text
        SHIFTI R2, R1, 0x0C, 0b1000     ; hours tens
        ANDI   R2, R2, 0x000F
        ADDI   R2, R2, 0x0030
        STOREB R2, [R3]
        SHIFTI R2, R1, 0x08, 0b1000     ; hours ones
        ANDI   R2, R2, 0x000F
        ADDI   R2, R2, 0x0030
        STOREB R2, [R3 + 1]
        LOADLO R2, 0x003A               ; ':'
        STOREB R2, [R3 + 2]
        SHIFTI R2, R1, 0x04, 0b1000     ; minutes tens
        ANDI   R2, R2, 0x000F
        ADDI   R2, R2, 0x0030
        STOREB R2, [R3 + 3]
        ANDI   R2, R1, 0x000F           ; minutes ones
        ADDI   R2, R2, 0x0030
        STOREB R2, [R3 + 4]
        STOREB R0, [R3 + 5]
        RET
tray_no_time: LA R1, tray_none_text
        LOADLO R2, tray_text
        JUMP   text_copy                ; tail call

; tray_draw, search box, sunken, white inside, magnifier and "Search" in grey
; tray, sunken, network picture or lamp, lime connected, yellow cable, red nothing
; and the clock, "HH:MM"
tray_draw: LOADLO R1, SEARCH_X
        LOADLO R2, TASKBAR_Y + 4
        LOADLO R3, SEARCH_WIDTH
        LOADLO R4, 20
        LOADLO R5, 0
        CALL   bevel_box
        LOADLO R1, SEARCH_X + 2
        LOADLO R2, TASKBAR_Y + 6
        LOADLO R3, SEARCH_WIDTH - 4
        LOADLO R4, 16
        LOADLO R5, WHITE_DOT
        CALL   box
        LOADLO R1, 3                    ; magnifier, if there is one
        LOADLO R2, SEARCH_X + 4
        CALL   tray_sprite
        LOAD   R1, [search_open]
        CMPI   R1, 0x0000
        JZ     tray_hint
        LOADLO R1, SEARCH_X + 24        ; open, typed text in black, a caret, and the list
        LOADLO R2, TASKBAR_Y + 6
        LOADLO R3, search_text
        LOADLO R4, BLACK_DOT
        CALL   text
        LOADLO R1, search_text
        CALL   text_length
        SHIFTI R1, R2, 0x03, 0b0000
        ADDI   R1, R1, SEARCH_X + 24
        LOADLO R2, TASKBAR_Y + 20
        LOADLO R3, 8
        LOADLO R4, 2
        LOADLO R5, BLACK_DOT
        CALL   box
        CALL   search_list
        JUMP   tray_right
tray_hint: LOADLO R1, SEARCH_X + 24     ; closed, "Search" in grey
        LOADLO R2, TASKBAR_Y + 6
        LA     R3, search_hint_text
        LOADLO R4, SHADOW
        CALL   text
tray_right: LOADLO R1, TRAY_X           ; the tray
        LOADLO R2, TASKBAR_Y + 4
        LOADLO R3, PIXELS_ACROSS - 4 - TRAY_X
        LOADLO R4, 20
        LOADLO R5, 0
        CALL   bevel_box
        LOAD   R1, [tray_net]           ; network light, its picture
        LOADLO R2, TRAY_X + 6
        CALL   tray_sprite
        CMPI   R1, 0x0000
        JNZ    tray_clock
        LOADLO R1, TRAY_X + 8           ; or a lamp, black ring, colour inside
        LOADLO R2, TASKBAR_Y + 8
        LOADLO R3, 12
        LOADLO R4, 12
        LOADLO R5, BLACK_DOT
        CALL   box
        LA     R1, tray_lamps
        LOAD   R2, [tray_net]
        ADD    R1, R1, R2
        LOADB  R5, [R1]
        LOADLO R1, TRAY_X + 9
        LOADLO R2, TASKBAR_Y + 9
        LOADLO R3, 10
        LOADLO R4, 10
        CALL   box
tray_clock: LOADLO R1, TRAY_X + 44      ; the clock
        LOADLO R2, TASKBAR_Y + 6
        LOADLO R3, tray_text
        LOADLO R4, BLACK_DOT
        JUMP   text                     ; tail call

; tray_sprite, a tray picture at (x, TASKBAR_Y + 6), a strip shows frame tray_frame
; in R1 = which, 0-3, R2 = x, out R1 = 1 drawn, 0 no picture
tray_sprite: SHIFTI R1, R1, 0x02, 0b0000
        LOADLO R3, tray_widths          ; R4 = frame x in the strip, (tray_frame MOD frames) x 16
        ADD    R3, R3, R1
        LOAD   R4, [R3]
        SHIFTI R4, R4, 0x04, 0b1000
        CMPI   R4, 0x0000
        JZ     tray_sprite_none
        LOAD   R5, [tray_frame]
        MODU   R4, R5, R4
        SHIFTI R4, R4, 0x04, 0b0000
        LOADLO R3, tray_sprites
        ADD    R3, R3, R1
        LOAD   R3, [R3]
        CMPI   R3, 0x0000
        JZ     tray_sprite_none
        LOADHI R1, TASKBAR_Y + 6        ; where, (x, y)
        OR     R1, R1, R2
        LOADHI R2, 16                   ; 16 x 16
        ORI    R2, R2, 16
        ORI    R3, R3, KEY              ; base + the colour to skip
        CALLF  DRAW_SPRITE
        LOADLO R1, 1
        RET
tray_sprite_none: LOADLO R1, 0
        RET

; the search, a click on its box opens a list of installed apps above it
; title or folder name starts with the typed text, any case, up to SEARCH_MAX
; Up / Down choose a row, Enter or a click opens it
; Esc or a click elsewhere closes the list
; search_start, opens the list, nothing typed
search_start: LOADLO R1, 1
        STORE  R1, [search_open]
        STOREB R0, [search_text]
        STORE  R0, [search_choice]
        CALL   search_update
        LOADLO R1, 1
        STORE  R1, [redraw]
        RET

; search_stop, closes the list
search_stop: STORE R0, [search_open]
        LOADLO R1, 1
        STORE  R1, [redraw]
        RET

; search_update, fills search_found and search_count for the typed text
; R8 = app, R9 = its record
search_update: PUSH R8
        PUSH   R9
        STORE  R0, [search_count]
        LOADLO R8, 0
search_next: LOAD R1, [app_count]
        CMP    R8, R1
        JC     search_counted           ; every app looked at
        LOAD   R1, [search_count]
        CMPI   R1, SEARCH_MAX
        JZ     search_counted           ; list is full
        MOV    R1, R8
        CALL   app_record
        MOV    R9, R1
        LOAD   R1, [R9 + W_TITLE]       ; title starts with it
        CALL   search_match
        CMPI   R1, 0x0000
        JNZ    search_add
        LOAD   R1, [R9 + W_NAME]        ; or its folder name
        CALL   search_match
        CMPI   R1, 0x0000
        JZ     search_skip
search_add: LOAD R1, [search_count]     ; found, its number onto search_found
        SHIFTI R2, R1, 0x02, 0b0000
        LOADLO R3, search_found
        ADD    R2, R2, R3
        STORE  R8, [R2]
        INC    R1
        STORE  R1, [search_count]
search_skip: INC R8
        JUMP   search_next
search_counted: LOAD R1, [search_choice]
        LOAD   R2, [search_count]
        CMP    R1, R2
        JNC    search_update_end        ; choice still in the list
        STORE  R0, [search_choice]
search_update_end: POP R9
        POP    R8
        RET

; search_match, does a name start with the typed text, any case
; in R1 = name pointer, 0 = none, out R1 = 1 yes, 0 no, uses R1-R5
search_match: LOADLO R2, search_text    ; text_starts does it
        CALL   text_starts
        MOV    R1, R3
        RET

; search_key, a key while the list is open, in R1 = key
; Esc, Enter, Up / Down, Backspace, or a letter up to SEARCH_LETTERS
; R2 = letters typed, R3 = pointer to their end
search_key: CMPI R1, 0x001B
        JZ     search_stop              ; tail jump
        CMPI   R1, 0x000A
        JZ     search_enter
        CMPI   R1, KEY_UP
        JZ     search_up
        CMPI   R1, KEY_DOWN
        JZ     search_down
        PUSH   R1
        LOADLO R1, search_text
        CALL   text_length
        POP    R1
        LOADLO R3, search_text
        ADD    R3, R3, R2
        CMPI   R1, 0x0008
        JNZ    search_letter
        CMPI   R2, 0x0000               ; Backspace, last letter off
        JZ     search_key_end
        SUBI   R3, R3, 1
        STOREB R0, [R3]
        JUMP   search_changed
search_letter: CMPI R1, 0x0020          ; a letter, 0x20-0x7E, if theres room
        JNC    search_key_end
        CMPI   R1, 0x007F
        JC     search_key_end
        CMPI   R2, SEARCH_LETTERS
        JZ     search_key_end
        STOREB R1, [R3]
        STOREB R0, [R3 + 1]
search_changed: STORE R0, [search_choice] ; new list, first row chosen
        CALL   search_update
search_redraw: LOADLO R1, 1
        STORE  R1, [redraw]
search_key_end: RET
search_up: LOAD R1, [search_choice]
        CMPI   R1, 0x0000
        JZ     search_key_end
        DEC    R1
        STORE  R1, [search_choice]
        JUMP   search_redraw
search_down: LOAD R1, [search_choice]
        INC    R1
        LOAD   R2, [search_count]
        CMP    R1, R2
        JC     search_key_end           ; already the last row
        STORE  R1, [search_choice]
        JUMP   search_redraw
search_enter: LOAD R1, [search_count]
        CMPI   R1, 0x0000
        JZ     search_stop              ; nothing found, just close
        LOAD   R1, [search_choice]
; search_open_row, closes the list and opens the app on a row, in R1 = row
search_open_row: SHIFTI R1, R1, 0x02, 0b0000
        LOADLO R2, search_found
        ADD    R1, R1, R2
        LOAD   R1, [R1]
        PUSH   R1
        CALL   search_stop
        POP    R1
        JUMP   launch_app               ; tail call

; search_top, list height = rows x 18 + 6, at least 1 row, above the taskbar
; out R1 = its y, R2 = its height
search_top: LOAD R2, [search_count]
        CMPI   R2, 0x0000
        JNZ    search_top_rows
        LOADLO R2, 1
search_top_rows: MULI R2, R2, 18
        ADDI   R2, R2, 6
        LOADLO R1, TASKBAR_Y
        SUB    R1, R1, R2
        RET

; search_click, a click while the list is open, in R8 = x, R9 = y
; on a row opens that app, on the search box nothing, elsewhere the list closes
; out R1 = 1 click used, 0 it goes on
search_click: CMPI R9, TASKBAR_Y
        JC     search_click_bar         ; on the taskbar
        CMPI   R8, SEARCH_X + SEARCH_LIST_WIDTH
        JC     search_click_out         ; right of the list
        CALL   search_top
        CMP    R9, R1
        JNC    search_click_out         ; above it
        SUB    R1, R9, R1               ; row = (y - top - 3) / 18
        SUBI   R1, R1, 3
        CMPIS  R1, 0
        JGE    search_click_row
        LOADLO R1, 0
search_click_row: DIVUI R1, R1, 18
        LOAD   R2, [search_count]
        CMP    R1, R2
        JC     search_click_mine        ; below the last row
        CALL   search_open_row
search_click_mine: LOADLO R1, 1
        RET
search_click_bar: CMPI R8, SEARCH_X + SEARCH_WIDTH
        JNC    search_click_mine        ; the search box itself
search_click_out: CALL search_stop
        LOADLO R1, 0
        RET

; search_list, the list above the search box, a raised box, a row for each app found
; chosen row white on dark blue, or "No apps found" in grey
; R8 = row, R9 = top of the list
search_list: PUSH R8
        PUSH   R9
        CALL   search_top
        MOV    R9, R1
        MOV    R4, R2
        LOADLO R1, SEARCH_X
        MOV    R2, R9
        LOADLO R3, SEARCH_LIST_WIDTH
        LOADLO R5, 1
        CALL   bevel_box
        LOAD   R1, [search_count]
        CMPI   R1, 0x0000
        JNZ    search_list_rows
        LOADLO R1, SEARCH_X + 8
        ADDI   R2, R9, 4
        LA     R3, search_none_text
        LOADLO R4, SHADOW
        CALL   text
        JUMP   search_list_end
search_list_rows: LOADLO R8, 0
search_row: LOAD R1, [search_count]
        CMP    R8, R1
        JC     search_list_end
        LOADLO R4, BLACK_DOT
        LOAD   R1, [search_choice]
        CMP    R1, R8
        JNZ    search_row_text
        LOADLO R1, SEARCH_X + 3         ; chosen row, dark blue behind, white letters
        MULI   R2, R8, 18
        ADD    R2, R2, R9
        ADDI   R2, R2, 3
        LOADLO R3, SEARCH_LIST_WIDTH - 6
        LOADLO R4, 18
        LOADLO R5, 0x0038
        CALL   box
        LOADLO R4, WHITE_DOT
search_row_text: PUSH R4
        SHIFTI R1, R8, 0x02, 0b0000     ; the apps title
        LOADLO R2, search_found
        ADD    R1, R1, R2
        LOAD   R1, [R1]
        CALL   app_record
        LOAD   R3, [R1 + W_TITLE]
        LOADLO R1, SEARCH_X + 8
        MULI   R2, R8, 18
        ADD    R2, R2, R9
        ADDI   R2, R2, 4
        POP    R4
        CALL   text
        INC    R8
        JUMP   search_row
search_list_end: POP R9
        POP    R8
        RET

; taskbar_layout, task_step from how many windows are in use
; (TRAY_X - 4 - TASK_LEFT = 368 dots) / windows, at most 94
; uses R1-R5
taskbar_layout: LOADLO R1, 0
        LOADLO R5, 0
layout_count: MOV R4, R1
        CALL   window_record
        LOAD   R2, [R1 + W_KIND]
        MOV    R1, R4
        CMPI   R2, KIND_NONE
        JZ     layout_next
        INC    R5
layout_next: INC R1
        CMPI   R1, WINDOW_COUNT
        JNZ    layout_count
        LOADLO R1, 94
        CMPI   R5, 0x0000
        JZ     layout_done
        LOADLO R2, TRAY_X - 4 - TASK_LEFT
        DIVU   R2, R2, R5
        CMP    R2, R1
        JC     layout_done
        MOV    R1, R2
layout_done: STORE R1, [task_step]
        RET
