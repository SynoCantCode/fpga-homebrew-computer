; decorator, pictures on the desktop under the windows, saved
; the list has the big sprites first, then the sprites
; the chosen one is shown on the right with WM_PICTURE
; key, Up and Down choose, Enter places
; click on the list chooses
; button, event 1 Place is WM_DECORATE
; event 2 Remove all is WM_UNDECORATE
; on the desktop the right button drags a decoration
; build and send with send_app.py decor
.include "sw/apps/app_defs.asm"
.org APP_BASE
        JUMP   init
        JUMP   tick
        JUMP   key
        JUMP   click
        JUMP   paint
        JUMP   button
        JUMP   close
        .word  0                        ; no ticks

.equ MAX_NAMES, 48                      ; most pictures in the list
.equ ROWS_SHOWN, 10                     ; list rows in view, page rows 1-10
.equ LIST_WIDTH, 24                     ; list width in cells
.equ PREVIEW_X, 208                     ; preview x in dots, cell 26
.equ CHOSEN_COLOUR, 0x18                ; chosen row, navy, name white
.equ BIG_COLOUR, 0x38                   ; big sprite name, dark blue, others black

; variables, vars + V_...
vars:   .word 0                         ; V_COUNT, how many names
        .word 0                         ; V_BIG, how many are big sprites, the first ones
        .word 0                         ; V_CHOSEN, the chosen one
        .word 0                         ; V_TOP, the first one in view
        .word 0                         ; V_LOADED, 1 once the lists are read
.equ V_COUNT, 0
.equ V_BIG, 4
.equ V_CHOSEN, 8
.equ V_TOP, 12
.equ V_LOADED, 16
names:  .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   ; 48 pointers to the names, 192 bytes
        .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; init, nothing, the lists are read on the first paint
init:   RET

; read_lists, once, big sprite names then sprite names. R13 = vars
read_lists: LOAD R1, [R13 + V_LOADED]
        CMPI   R1, 0x0000
        JNZ    read_lists_done
        LOADLO R1, 1
        STORE  R1, [R13 + V_LOADED]
        LA     R1, big_list_path
        CALL   read_names               ; added to names
        LOAD   R1, [R13 + V_COUNT]
        STORE  R1, [R13 + V_BIG]
        LA     R1, sprite_list_path
        CALL   read_names
read_lists_done: RET

; read_names, add a list file's first word of each line to names
; in R1 = pointer to its path. R8 = line, R9 = text end. uses R1-R7
read_names: PUSH R8
        PUSH   R9
        CALL   file_text                ; R1 = text or 0, R2 = its end
        CMPI   R1, 0x0000
        JZ     names_done
        MOV    R9, R2
        CALL   line_first
        MOV    R8, R1
names_line: CMPI R8, 0x0000
        JZ     names_done
        LOAD   R1, [R13 + V_COUNT]
        CMPI   R1, MAX_NAMES
        JZ     names_done               ; full
        MOV    R1, R8                   ; find the next line first, first_word writes a 0 into this one
        MOV    R2, R9
        CALL   line_next
        PUSH   R1
        MOV    R1, R8
        CALL   first_word               ; R2 = the name
        LOAD   R1, [R13 + V_COUNT]
        SHIFTI R3, R1, 0x02, 0b0000
        LA     R4, names
        ADD    R3, R3, R4
        STORE  R2, [R3]
        INC    R1
        STORE  R1, [R13 + V_COUNT]
        POP    R8
        JUMP   names_line
names_done: POP R9
        POP    R8
        RET

; chosen_name, out R1 = pointer to the chosen name or 0. uses R1-R3
chosen_name: LOAD R1, [R13 + V_COUNT]
        LOAD   R2, [R13 + V_CHOSEN]
        CMP    R2, R1
        JC     chosen_none
        SHIFTI R2, R2, 0x02, 0b0000
        LA     R3, names
        ADD    R2, R2, R3
        LOAD   R1, [R2]
        RET
chosen_none: LOADLO R1, 0
        RET

; paint, the list and the chosen picture on the right. in R1 = window
; R8 = row in view 0-9, R9 = name number, R12 = window, R13 = vars
paint:  PUSH   R13
        PUSH   R12
        PUSH   R9
        PUSH   R8
        MOV    R12, R1
        LA     R13, vars
        CALL   read_lists
        LOADLO R8, 0
paint_row: CMPI R8, ROWS_SHOWN
        JZ     paint_preview
        LOAD   R9, [R13 + V_TOP]
        ADD    R9, R9, R8
        LOAD   R1, [R13 + V_COUNT]
        CMP    R9, R1
        JC     paint_preview            ; no more names
        LOAD   R1, [R13 + V_CHOSEN]     ; chosen one gets a navy bar
        CMP    R1, R9
        JNZ    paint_name
        LOADLO R1, 0
        ADDI   R2, R8, 1
        SHIFTI R2, R2, 0x04, 0b0000
        LOADLO R3, 192                  ; LIST_WIDTH x 8
        LOADLO R4, 16
        LOADLO R5, CHOSEN_COLOUR
        CALLF  WM_BOX
paint_name: SHIFTI R1, R9, 0x02, 0b0000 ; its name
        LA     R2, names
        ADD    R1, R1, R2
        LOAD   R3, [R1]
        LOADLO R4, 0x00                 ; sprite, black
        LOAD   R1, [R13 + V_BIG]
        CMP    R9, R1
        JC     paint_colour
        LOADLO R4, BIG_COLOUR           ; big sprite, dark blue
paint_colour: LOAD R1, [R13 + V_CHOSEN]
        CMP    R1, R9
        JNZ    paint_text
        LOADLO R4, 0x0F                 ; chosen, white
paint_text: LOADLO R1, 8
        ADDI   R2, R8, 1
        SHIFTI R2, R2, 0x04, 0b0000
        CALLF  WM_TEXT
        INC    R8
        JUMP   paint_row
paint_preview: CALL chosen_name         ; chosen picture, right of the list
        CMPI   R1, 0x0000
        JZ     paint_done
        MOV    R3, R1
        LOADLO R1, PREVIEW_X
        LOADLO R2, 16
        CALLF  WM_PICTURE
paint_done: POP R8
        POP    R9
        POP    R12
        POP    R13
        RET

; key, Up and Down choose, Enter places. in R1 = window, R2 = key
key:    PUSH   R13
        PUSH   R12
        MOV    R12, R1
        LA     R13, vars
        CMPI   R2, 0x000A
        JZ     key_place
        LOAD   R1, [R13 + V_CHOSEN]
        CMPI   R2, KEY_UP
        JZ     key_up
        CMPI   R2, KEY_DOWN
        JNZ    key_done
        INC    R1                       ; Down, the next, not past the last
        LOAD   R2, [R13 + V_COUNT]
        CMP    R1, R2
        JC     key_done
        JUMP   key_choose
key_up: CMPI   R1, 0x0000               ; Up, the one before, not before the first
        JZ     key_done
        DEC    R1
key_choose: CALL choose
        JUMP   key_done
key_place: MOV R1, R12
        CALL   place
key_done: POP  R12
        POP    R13
        RET

; choose, set the chosen one, scroll it into view, redraw
; in R1 = its number, R12 = window, R13 = vars
choose: STORE  R1, [R13 + V_CHOSEN]
        LOAD   R2, [R13 + V_TOP]
        CMP    R1, R2
        JC     choose_below             ; at or below the top
        STORE  R1, [R13 + V_TOP]        ; above, make it the top
        JUMP   choose_drawn
choose_below: ADDI R2, R2, ROWS_SHOWN
        CMP    R1, R2
        JNC    choose_drawn             ; in view
        SUBI   R1, R1, ROWS_SHOWN - 1   ; past the bottom, make it the bottom row
        STORE  R1, [R13 + V_TOP]
choose_drawn: MOV R1, R12
        CALLF  WM_REDRAW
        RET

; click, on the list chooses that one. in R1 = window, R2 = x, R3 = y
click:  PUSH   R13
        PUSH   R12
        MOV    R12, R1
        LA     R13, vars
        CMPI   R2, 192                  ; LIST_WIDTH x 8, right of the list does nothing
        JC     click_done
        SHIFTI R3, R3, 0x04, 0b1000     ; page row
        CMPI   R3, 0x0000
        JZ     click_done               ; the heading
        CMPI   R3, ROWS_SHOWN + 1
        JC     click_done               ; below the list
        DEC    R3
        LOAD   R1, [R13 + V_TOP]
        ADD    R1, R1, R3
        LOAD   R2, [R13 + V_COUNT]
        CMP    R1, R2
        JC     click_done               ; empty row
        CALL   choose
click_done: POP R12
        POP    R13
        RET

; button, event 1 Place, event 2 Remove all. in R1 = window, R2 = event
button: PUSH   R13
        LA     R13, vars
        CMPI   R2, 1
        JZ     button_place
        CMPI   R2, 2
        JNZ    button_done
        PUSH   R1
        CALLF  WM_UNDECORATE
        POP    R1
        LA     R3, removed_text
        CALL   say
        JUMP   button_done
button_place: CALL place
button_done: POP R13
        RET

; place, chosen picture onto the desktop, #note says how it went
; in R1 = window, R13 = vars
place:  PUSH   R1
        CALL   chosen_name
        LA     R3, none_text
        CMPI   R1, 0x0000
        JZ     place_say
        CALLF  WM_DECORATE              ; R1 = 1 placed, 0 not
        LA     R3, placed_text
        CMPI   R1, 0x0000
        JNZ    place_say
        LA     R3, full_text
place_say: POP R1
; say, #note shows a text. in R1 = window, R3 = pointer to a text that stays
say:    LA     R2, note_name
        CALLF  WM_SET_TEXT
        RET

tick:
close:  RET

big_list_path:    .string "/system/design/bigsprts/bigsprts.txt"
sprite_list_path: .string "/system/design/sprites/sprites.txt"
note_name:        .string "note"
placed_text:      .string "Placed: right-drag it to move it"
full_text:        .string "Couldn't place it (16 at most)"
none_text:        .string "Choose a picture first"
removed_text:     .string "All decorations removed"

.include "sw/apps/lib/text.asm"       ; text_copy, number_text
.include "sw/apps/lib/lines.asm"      ; file_text, line_first, line_next, first_word
