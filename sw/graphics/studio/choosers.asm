; choosers, the buttons that go round sprite, icon, style, colour, action, name
; included by studio.asm

; load_sprite_list, fills sprite_table from SPRITES.TXT
; then the big sprites from BIGSPRTS.TXT
; up to MAX_SPRITES in all
load_sprite_list: STORE R0, [sprite_count]
        LOADLO R1, 0x0400               ; MAX_SPRITES x 16 bytes
        CALLF  ALLOCATE
        STORE  R1, [sprite_table]
        CMPI   R1, 0x0000
        JZ     sprite_lists_done        ; no room, no sprites
        LA     R1, sprites_list_path
        CALL   load_sprite_file
        LA     R1, big_list_path
        CALL   load_sprite_file
sprite_lists_done: RET

; load_sprite_file, adds a lists lines to sprite_table
; a line = NAME.PIC or NAME.PIC FRAMEWIDTH FRAMES SPEED
; in R1 = pointer to the path
; R8 = line, R9 = file end, R10 = next entry, R11 = line end
load_sprite_file: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        CALL   load_text
        CMPI   R1, 0x0000
        JZ     sprites_listed           ; no list
        MOV    R8, R1
        MOV    R9, R2
        LOAD   R10, [sprite_count]      ; R10 = next entry
        SHIFTI R10, R10, 0x04, 0b0000
        LOAD   R1, [sprite_table]
        ADD    R10, R10, R1
sprite_line: CMP R8, R9
        JC     sprites_listed           ; end of file
        LOAD   R1, [sprite_count]
        CMPI   R1, MAX_SPRITES
        JZ     sprites_listed
        LOADB  R1, [R8]
        CMPI   R1, 0x0000
        JZ     sprite_byte              ; between lines
        CMPI   R1, 0x003B
        JZ     sprite_skip              ; a note line
        CMPI   R1, 0x0020
        JZ     sprite_skip
        MOV    R11, R8                  ; find the lines end first
sprite_end_find: LOADB R1, [R11]
        CMPI   R1, 0x0000
        JZ     sprite_read
        INC    R11
        JUMP   sprite_end_find
sprite_read: MOV R1, R8
        CALL   read_word                ; R2 = name, R1 = just after it
        STORE  R2, [R10]
        STORE  R0, [R10 + 4]
        STORE  R0, [R10 + 8]
        STORE  R0, [R10 + 12]
        LOADB  R4, [R1]
        STOREB R0, [R1]                 ; end the name with a 0
        CMPI   R4, 0x0000
        JZ     sprite_listed            ; just a name, still picture
        INC    R1
        CALL   read_number
        STORE  R2, [R10 + 4]            ; frame width
        CALL   read_number
        STORE  R2, [R10 + 8]            ; frames
        CALL   read_number
        STORE  R2, [R10 + 12]           ; speed, frames a second
sprite_listed: ADDI R10, R10, 16
        LOAD   R1, [sprite_count]
        INC    R1
        STORE  R1, [sprite_count]
        MOV    R8, R11
        JUMP   sprite_line
sprite_skip: LOADB R1, [R8]
        CMPI   R1, 0x0000
        JZ     sprite_line
        INC    R8
        JUMP   sprite_skip
sprite_byte: INC R8
        JUMP   sprite_line
sprites_listed: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; get_sprite, a sprites picture, read from the card only once
; sprite_cache keeps 16, name, base, width, height
; in R1 = pointer to the file name
; out R1 = width or 0, R2 = height, R3 = base
get_sprite: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        LOADLO R9, sprite_cache
        LOADLO R10, 16
cache_next: LOAD R1, [R9]
        CMPI   R1, 0x0000
        JZ     cache_load               ; empty entry, not read yet
        MOV    R2, R8
        CALL   text_same
        CMPI   R3, 1
        JZ     cache_found
        ADDI   R9, R9, 16
        DEC    R10
        CMPI   R10, 0x0000
        JNZ    cache_next
        LOADLO R9, 0                    ; cache full, read but not kept
cache_load: LOADLO R1, app_name
        MOV    R2, R8
        CALL   load_sprite              ; R1 = width or 0, R2 = height, R3 = base
        CMPI   R9, 0x0000
        JZ     cache_end
        STORE  R8, [R9]                 ; kept even if not found, width 0
        STORE  R3, [R9 + 4]
        STORE  R1, [R9 + 8]
        STORE  R2, [R9 + 12]
        JUMP   cache_end
cache_found: LOAD R1, [R9 + 8]
        LOAD   R2, [R9 + 12]
        LOAD   R3, [R9 + 4]
cache_end: POP R10
        POP    R9
        POP    R8
        RET

; copy_element, copies 32 bytes, in R1 = from, R2 = to, uses R3-R5
copy_element: LOADLO R3, 0
copy_element_next: ADD R4, R1, R3
        LOAD   R4, [R4]
        ADD    R5, R2, R3
        STORE  R4, [R5]
        ADDI   R3, R3, 4
        CMPI   R3, ELEMENT_BYTES
        JNZ    copy_element_next
        RET

; next_sprite, the Sprite button
; a picture selected = the next sprite, else add the first one
; put back as it was if it does not fit
; R8 = window, R9 = element, R10 = sprite entry
; R11 = 1 if the element is new
next_sprite: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        LOAD   R1, [sprite_count]
        CMPI   R1, 0x0000
        JNZ    sprite_have
        LA     R1, no_sprites_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   sprite_done
sprite_have: LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOADLO R11, 1
        LOAD   R10, [sprite_table]      ; the first
        LOAD   R9, [selected]
        CMPI   R9, 0x0000
        JZ     sprite_load
        LOADB  R1, [R9]
        CMPI   R1, E_IMAGE
        JZ     sprite_swap
        CMPI   R1, E_ANIM
        JNZ    sprite_load
sprite_swap: LOADLO R11, 0              ; picture selected, take the sprite after it
        LOAD   R7, [sprite_table]
        LOAD   R6, [sprite_count]
sprite_find: LOAD R1, [R7]
        LOAD   R2, [R9 + 16]
        CALL   text_same
        ADDI   R7, R7, 16
        DEC    R6
        CMPI   R3, 1
        JZ     sprite_found             ; R7 = the entry after it
        CMPI   R6, 0x0000
        JNZ    sprite_find
sprite_found: CMPI R6, 0x0000
        JNZ    sprite_take
        LOAD   R7, [sprite_table]       ; after the last or not in the list, the first
sprite_take: MOV R10, R7
sprite_load: LOAD R1, [R10]
        CALL   get_sprite               ; R1 = width, R2 = height, R3 = base
        CMPI   R1, 0x0000
        JNZ    sprite_loaded
        LA     R1, not_read_text        ; couldn't read NAME
        LOAD   R2, [R10]
        CALL   say_two
        JUMP   sprite_done
sprite_loaded: PUSH R1
        PUSH   R2
        PUSH   R3
        CMPI   R11, 0x0000
        JZ     sprite_keep
        MOV    R1, R8                   ; new element
        CALL   new_element
        CMPI   R1, 0x0000
        JNZ    sprite_new
        POP    R3
        POP    R2
        POP    R1
        LA     R1, full_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   sprite_done
sprite_new: MOV R9, R1
        CALL   free_row                 ; before it has a kind
        STOREB R1, [R9 + 2]
sprite_keep: MOV R1, R9                 ; keep a copy to put back
        LOADLO R2, old_element
        CALL   copy_element
        POP    R3
        POP    R2
        POP    R1
        STORE  R3, [R9 + 4]             ; the picture
        LOAD   R4, [R10]
        STORE  R4, [R9 + 16]            ; file name
        LOAD   R4, [R10 + 4]            ; frame width = animation
        CMPI   R4, 0x0000
        JNZ    sprite_anim
        LOADLO R4, E_IMAGE              ; still picture, width and height
        STOREB R4, [R9]
        STOREB R0, [R9 + 3]
        STORE  R1, [R9 + 8]
        STORE  R2, [R9 + 12]
        JUMP   sprite_placed
sprite_anim: LOADLO R5, E_ANIM          ; animation, frame width, frames low half + height high
        STOREB R5, [R9]
        STORE  R4, [R9 + 8]
        LOAD   R5, [R10 + 8]
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R5, R5, R2
        STORE  R5, [R9 + 12]
        LOAD   R5, [R10 + 12]
        STOREB R5, [R9 + 3]             ; speed
        LOADLO R5, 1
        STORE  R5, [R8 + W_ANIMATES]
sprite_placed: MOV R1, R9               ; make room, check everything fits
        MOV    R2, R8
        CALL   element_cells
        ADD    R1, R2, R4
        CALL   make_room
        CMPI   R1, 0x0000
        JZ     sprite_no_room
        CALL   all_fit
        CMPI   R1, 0x0000
        JZ     sprite_no_room
        STORE  R9, [selected]
        STORE  R0, [title_selected]
        LOADLO R1, 0
        CALL   draw_window
        LA     R1, sprite_said          ; sprite: NAME
        LOAD   R2, [R10]
        CALL   say_two
        JUMP   sprite_done
sprite_no_room: LOADLO R1, old_element  ; does not fit, put it back
        MOV    R2, R9
        CALL   copy_element
        CMPI   R11, 0x0000
        JZ     sprite_refused
        LOAD   R1, [R8 + W_ELEMENT_COUNT]   ; a new one, take it off again
        DEC    R1
        STORE  R1, [R8 + W_ELEMENT_COUNT]
sprite_refused: LA R1, no_room_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
sprite_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; next_icon, the apps desktop icon, next sprite in SPRITES.TXT
; goes back to the first after the last, saved as icon NAME
; R8 = window
next_icon: PUSH R8
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [sprite_count]
        CMPI   R1, 0x0000
        JNZ    icon_have
        LA     R1, no_sprites_text
        STORE  R1, [status]
        JUMP   icon_end
icon_have: LOAD R1, [R8 + W_ICON_NAME]
        CMPI   R1, 0x0000
        JZ     icon_first
        LOAD   R7, [sprite_table]
        LOAD   R6, [sprite_count]
icon_next: LOAD R1, [R7]
        LOAD   R2, [R8 + W_ICON_NAME]
        CALL   text_same
        ADDI   R7, R7, 16
        DEC    R6
        CMPI   R3, 1
        JZ     icon_found               ; R7 = the entry after it
        CMPI   R6, 0x0000
        JNZ    icon_next
icon_first: LOAD R1, [sprite_table]     ; not in the list, the first
        LOAD   R1, [R1]
        JUMP   icon_set
icon_found: CMPI R6, 0x0000
        JZ     icon_first               ; the last one, back to the first
        LOAD   R1, [R7]
icon_set: STORE R1, [R8 + W_ICON_NAME]
        CMPI   R1, 0x0000
        JNZ    icon_named
        LA     R1, icon_none_text
        STORE  R1, [status]
        JUMP   icon_end
icon_named: MOV R2, R1
        LA     R1, icon_said
        CALL   say_two
icon_end: LOADLO R1, 1
        STORE  R1, [redraw]
        POP    R8
        RET

; next_style, next style from STYLES.TXT, default after the last
; window resized for the new margins, R8 = window
next_style: PUSH R8
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [style_pick]
        LOAD   R2, [style_list]
        LOAD   R3, [style_list_end]
        CALL   next_name                ; R1 = next style name, 0 = default
        STORE  R1, [style_pick]
        LOADLO R2, styles
        CMPI   R1, 0x0000
        JZ     style_chosen
        CALL   find_style               ; R1 = the style
        MOV    R2, R1
style_chosen: STORE R2, [R8 + W_STYLE]
        MOV    R1, R8
        CALL   window_size
        CALL   keep_on_screen
        LOADLO R1, 0
        CALL   draw_window
        LA     R1, style_said
        LOAD   R2, [style_pick]
        CMPI   R2, 0x0000
        JNZ    style_say
        LA     R2, default_said
style_say: CALL say_two
        POP    R8
        RET

; next_colour, next colour from colour_list for the selected element
; R8 = element
next_colour: PUSH R8
        LOAD   R1, [title_selected]     ; title selected, its icon labels colour
        CMPI   R1, 0x0000
        JNZ    colour_label
        LOAD   R8, [selected]
        CMPI   R8, 0x0000
        JZ     colour_pick
        LOADB  R1, [R8]
        CMPI   R1, E_TEXT_LINE
        JZ     colour_go
        CMPI   R1, E_WRAP
        JZ     colour_go
        CMPI   R1, E_BOX
        JZ     colour_go
        CMPI   R1, E_INPUT
        JZ     colour_go
colour_pick: LA R1, pick_text_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   colour_end
colour_label: LOADLO R8, label_colours - 3  ; so R8 + 3 is the label colour byte
colour_go: LOADB R2, [R8 + 3]           ; find its colour in the list
        LA     R3, colour_list
        LOADLO R4, 0
colour_find: ADD R5, R3, R4
        LOADB  R5, [R5]
        INC    R4
        CMP    R5, R2
        JZ     colour_found             ; R4 = the one after it
        CMPI   R4, COLOURS
        JNZ    colour_find
        LOADLO R4, 0                    ; not in the list, the first
colour_found: CMPI R4, COLOURS
        JNZ    colour_take
        LOADLO R4, 0                    ; after the last, the first
colour_take: ADD R5, R3, R4
        LOADB  R5, [R5]
        STOREB R5, [R8 + 3]
        LOADLO R1, 0
        CALL   draw_window
        LA     R1, colour_said
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
colour_end: POP R8
        RET

; next_action, nothing, close, open each app in APPS.TXT, events, nothing
; R8 = button
next_action: PUSH R8
        LOAD   R8, [selected]
        CMPI   R8, 0x0000
        JZ     action_pick
        LOADB  R1, [R8]
        CMPI   R1, E_BUTTON
        JZ     action_go
action_pick: LA R1, pick_button_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   action_end
action_go: LOAD R1, [R8 + 8]
        CMPI   R1, ACTION_CLOSE
        JZ     action_from_close
        CMPI   R1, ACTION_OPEN
        JZ     action_from_open
        CMPI   R1, ACTION_EVENT
        JZ     action_from_event
        LOADLO R1, ACTION_CLOSE         ; nothing to close
        STORE  R1, [R8 + 8]
        JUMP   action_said
action_from_close: LOADLO R1, 0         ; close to open the first app
        JUMP   action_app
action_from_open: LOAD R1, [R8 + 12]    ; open the next app
action_app: LOAD R2, [app_list]
        LOAD   R3, [app_list_end]
        CALL   next_name
        STORE  R1, [R8 + 12]
        LOADLO R2, ACTION_OPEN
        CMPI   R1, 0x0000
        JNZ    action_set
        LOADLO R1, 1                    ; after the last app, event 1
        STORE  R1, [R8 + 12]
        LOADLO R2, ACTION_EVENT
        JUMP   action_set
action_from_event: LOAD R1, [R8 + 12]   ; event N + 1, after event 3 nothing
        INC    R1
        STORE  R1, [R8 + 12]
        LOADLO R2, ACTION_EVENT
        CMPI   R1, 4
        JNZ    action_set
        STORE  R0, [R8 + 12]
        LOADLO R2, 0
action_set: STORE R2, [R8 + 8]
action_said: MOV R1, R8
        CALL   say_action
action_end: POP R8
        RET

; say_action, status line says what a button does
say_action: LOAD R2, [R1 + 8]
        CMPI   R2, ACTION_CLOSE
        JZ     say_close
        CMPI   R2, ACTION_OPEN
        JZ     say_open
        CMPI   R2, ACTION_EVENT
        JNZ    say_nothing
        LOAD   R2, [R1 + 12]            ; event N
        LA     R1, does_event_text
        ADDI   R2, R2, 0x0030
        LOADLO R3, number_buffer
        STOREB R2, [R3]
        STOREB R0, [R3 + 1]
        MOV    R2, R3
        JUMP   say_two
say_nothing:
        LA     R1, does_nothing_text
        JUMP   say_one
say_close: LA R1, does_close_text
say_one: STORE R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        RET
say_open: LOAD R2, [R1 + 12]
        LA     R1, does_open_text

; say_two, status line from two texts
; in R1, R2 = pointers to them, uses R1-R3
say_two: PUSH R2
        LOADLO R2, status_text
        CALL   text_copy                ; R2 = the 0 after it
        POP    R1
        CALL   text_copy
        LOADLO R1, status_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        RET

; next_name, the name after one in a list, a name a line
; in R1 = pointer to a name or 0, R2 = list or 0, R3 = its end
; out R1 = next name, the first if not found, 0 after the last
; R8 = name, R9 = line, R10 = end
; R11 = 1 once the name is passed, R12 = first name
next_name: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        MOV    R8, R1
        MOV    R9, R2
        MOV    R10, R3
        LOADLO R11, 0
        LOADLO R12, 0
        CMPI   R9, 0x0000
        JZ     name_none                ; no list
        CMPI   R8, 0x0000
        JNZ    name_line
        LOADLO R11, 1                   ; none yet, the first is the answer
name_line: CMP R9, R10
        JC     name_last                ; end of list
        LOADB  R1, [R9]
        CMPI   R1, 0x0000
        JZ     name_byte                ; between lines
        CMPI   R1, 0x003B
        JZ     name_skip_line           ; a note line
        CMPI   R1, 0x0020
        JZ     name_skip_line
        MOV    R1, R9
        CALL   cut_word                 ; name ends at its first space
        CMPI   R12, 0x0000
        JNZ    name_have_first
        MOV    R12, R9
name_have_first: CMPI R11, 1
        JZ     name_this
        MOV    R1, R9
        MOV    R2, R8
        CALL   text_same
        CMPI   R3, 1
        JNZ    name_skip_line
        LOADLO R11, 1                   ; found, the answer is the next one
name_skip_line: LOADB R1, [R9]
        CMPI   R1, 0x0000
        JZ     name_line
        INC    R9
        JUMP   name_skip_line
name_byte: INC R9
        JUMP   name_line
name_this: MOV R1, R9
        JUMP   name_end
name_last: CMPI R11, 1
        JZ     name_none                ; it's the last one
        MOV    R1, R12                  ; not in the list, the first
        JUMP   name_end
name_none: LOADLO R1, 0
name_end: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; element_fits, does an elements text fit where it is
; in R1 = pointer to it, out R1 = 1 fits, 0 not
; uses R1-R7, R8 = element, R9 = window
element_fits: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADLO R1, 0
        CALL   window_record
        MOV    R9, R1
        LOADB  R1, [R8]
        CMPI   R1, E_TEXT_LINE
        JZ     fits_line
        CMPI   R1, E_BUTTON
        JZ     fits_line
        CMPI   R1, E_BOX
        JZ     fits_box
        CMPI   R1, E_INPUT
        JZ     fits_box
        CMPI   R1, E_WRAP
        JZ     fits_wrap
        JUMP   fits_yes
fits_line: LOAD R1, [R8 + 4]            ; one row, column + length, + 2 for a button
        CALL   text_length
        LOADB  R1, [R8 + 1]
        ADD    R2, R2, R1
        LOADB  R1, [R8]
        CMPI   R1, E_BUTTON
        JNZ    fits_line_end
        ADDI   R2, R2, 2
fits_line_end: LOAD R1, [R9 + W_COLUMNS]
        CMP    R1, R2
        JC     fits_yes
        JUMP   fits_no
fits_box: LOAD R1, [R8 + 4]             ; wrapped to its width, rows <= its height
        LOAD   R2, [R8 + 8]
        CALL   text_rows
        LOAD   R2, [R8 + 12]
        CMP    R2, R1
        JC     fits_yes
        JUMP   fits_no
fits_wrap: LOAD R1, [R8 + 4]            ; wrapped to the window, rows <= page rows below it
        LOAD   R2, [R9 + W_COLUMNS]
        CALL   text_rows
        LOADLO R2, PAGE_MAX
        LOADB  R3, [R8 + 2]
        SUB    R2, R2, R3
        CMP    R2, R1
        JC     fits_yes
fits_no: LOADLO R1, 0
        JUMP   fits_end
fits_yes: LOADLO R1, 1
fits_end: POP R9
        POP    R8
        RET

; saving
