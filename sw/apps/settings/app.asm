; settings app, starts hidden, the gear icon opens it
; page buttons send events
; Next (1) / None (2)   next wallpaper in WALLPAPR.TXT, or none
; App (3)               which app or /DESKTOP file the ones below change
; Icon (4)              next sprite in SPRITES.TXT, default the gear
; Colour (5)            next of 8 label colours
; Delete (7)            deletes a file from /DESKTOP, press twice
; #note says how it went, #kind says what the item is
; Desktop (6, #desk)    icon on or off the desktop, not for Settings itself
; an apps icon and label colour are saved in its PAGE.TXT, icon FILE.PIC, label NN
; files on the desktop keep theirs in ICONS.TXT
; build: python project/tools/assembler/make_app.py sw/apps/settings/app.asm
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

; variables in vars, through R13
.equ V_WINDOW,    0                     ; window number
.equ V_WALLS,     4                     ; wallpapers in the list
.equ V_WALL_NOW,  8                     ; the one showing, -1 = none
.equ V_SPRITES,   12                    ; sprites in the list
.equ V_APP,       16                    ; chosen app number
.equ V_OUT,       20                    ; saving, pointer to the page being written
.equ V_OUT_END,   24                    ; where the next letter goes
.equ V_WALL_NAMES, 28                   ; pointers to wallpaper names, 64, 28-283
.equ V_SPRITE_NAMES, 284                ; pointers to sprite names, 64, 284-539
.equ V_PATH,      540                   ; path buffer, 64 bytes, 540-603
.equ V_LABEL,     604                   ; saving, label colour being written
.equ V_SURE,      608                   ; 1 = Delete pressed once
.equ MAX_NAMES,   64

; init, read both lists, pick the first app, in R1 = window
init:   PUSH   R13
        LA     R13, vars
        STORE  R1, [R13 + V_WINDOW]
        STORE  R0, [R13 + V_WALL_NOW]
        LA     R1, wall_list_path
        ADDI   R2, R13, V_WALL_NAMES
        CALL   read_list
        STORE  R1, [R13 + V_WALLS]
        LA     R1, sprite_list_path
        ADDI   R2, R13, V_SPRITE_NAMES
        CALL   read_list
        STORE  R1, [R13 + V_SPRITES]
        NOT    R1, R0                   ; -1, next_app steps to the first app
        STORE  R1, [R13 + V_APP]
        CALL   next_app
        POP    R13
        RET

; read_list, reads a list file into the heap, one name a line
; in R1 = pointer to path, R2 = pointer table (MAX_NAMES), out R1 = count
; R8 = table, R9 = count, R10 = text end, R11 = line
read_list: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R2
        LOADLO R9, 0
        CALL   file_text                ; R1 = text or 0, R2 = its end
        CMPI   R1, 0x0000
        JZ     list_done
        MOV    R10, R2
        CALL   line_first
        MOV    R11, R1
list_line: CMPI R11, 0x0000
        JZ     list_done                ; no more lines
        CMPI   R9, MAX_NAMES
        JZ     list_done                ; table full
        MOV    R1, R11                  ; find the next line first, first_word writes a 0 here
        MOV    R2, R10
        CALL   line_next
        PUSH   R1
        MOV    R1, R11
        CALL   first_word               ; R2 = name
        SHIFTI R3, R9, 0x02, 0b0000     ; store it in the table
        ADD    R3, R3, R8
        STORE  R2, [R3]
        INC    R9
        POP    R11
        JUMP   list_line
list_done: MOV R1, R9
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; next_app, V_APP = next installed app, 0 to 31, wraps
; uses R1-R7
next_app: PUSH R12
        LOADLO R12, 0                   ; at most 32 tries
next_app_try: LOAD R1, [R13 + V_APP]
        INC    R1
        CMPI   R1, 32
        JNZ    next_app_in
        LOADLO R1, 0
next_app_in: STORE R1, [R13 + V_APP]
        CALLF  WM_APP_INFO              ; R1 = name, 0 = no app there
        CMPI   R1, 0x0000
        JNZ    next_app_done
        INC    R12
        CMPI   R12, 32
        JNZ    next_app_try
next_app_done: POP R12
        JUMP   desk_label               ; update the Desktop button text

; desk_label, shows the chosen item, sets #kind, clears #note and V_SURE
; #desk = Remove from desktop, Add to desktop or Always on desktop
; Always is for Settings itself
; uses R1-R7
desk_label: STORE R0, [R13 + V_SURE]
        LOAD   R1, [R13 + V_APP]
        CALLF  WM_APP_INFO              ; R1 = name or 0, R5 = 1 on the desktop, R6 = kind
        CMPI   R1, 0x0000
        JZ     desk_label_done
        PUSH   R1
        PUSH   R5
        PUSH   R6
        LA     R3, kind_texts           ; #kind, entry R6 of kind_texts, 16 bytes each
        SHIFTI R6, R6, 0x04, 0b0000
        ADD    R3, R3, R6
        LOAD   R1, [R13 + V_WINDOW]
        LA     R2, kind_name
        CALLF  WM_SET_TEXT
        LOAD   R1, [R13 + V_WINDOW]     ; #note, empty
        LA     R2, note_name
        LA     R3, nothing_text
        CALLF  WM_SET_TEXT
        POP    R6
        POP    R5
        POP    R1
        LA     R3, desk_remove_text
        CMPI   R5, 0x0000
        JNZ    desk_label_settings
        LA     R3, desk_add_text
desk_label_settings: PUSH R3           ; is it Settings itself?
        LA     R2, settings_word
        CALL   text_same
        MOV    R4, R3
        POP    R3
        CMPI   R4, 1
        JNZ    desk_set
        LA     R3, desk_always_text
desk_set: LOAD R1, [R13 + V_WINDOW]
        LA     R2, desk_name
        CALLF  WM_SET_TEXT
desk_label_done: RET

; button, in R2 = event, 1 Next, 2 None, 3 App, 4 Icon, 5 Colour, 6 Desktop, 7 Delete
button: PUSH   R13
        LA     R13, vars
        CMPI   R2, 1
        JZ     button_next
        CMPI   R2, 2
        JZ     button_none
        CMPI   R2, 3
        JZ     button_app
        CMPI   R2, 4
        JZ     button_icon
        CMPI   R2, 5
        JZ     button_colour
        CMPI   R2, 6
        JZ     button_desk
        CMPI   R2, 7
        JZ     button_delete
        JUMP   button_done
button_delete: LOAD R1, [R13 + V_APP]   ; Delete, a file on the desktop, press twice
        CALLF  WM_APP_INFO              ; R1 = name, R6 = kind
        CMPI   R1, 0x0000
        JZ     button_done
        LA     R3, del_app_text         ; apps are not deleted here
        CMPI   R6, 0x0000
        JZ     del_said
        LOAD   R2, [R13 + V_SURE]
        CMPI   R2, 0x0000
        JNZ    del_now
        LOADLO R2, 1                    ; first press, ask
        STORE  R2, [R13 + V_SURE]
        LA     R3, del_sure_text
        JUMP   del_said
del_now: STORE R0, [R13 + V_SURE]       ; second press, delete /desktop/NAME
        PUSH   R1
        LA     R1, desk_folder_text
        ADDI   R2, R13, V_PATH
        CALL   text_copy
        POP    R1
        CALL   text_copy
        ADDI   R1, R13, V_PATH
        CALLF  FILE_DELETE
        LA     R3, del_failed_text
        CMPI   R1, 0x0000
        JNZ    del_said
        LOAD   R1, [R13 + V_APP]        ; deleted, icon off the desktop
        LOADLO R2, 0
        CALLF  WM_SET_DESKTOP
        LA     R3, del_done_text
del_said: LOAD R1, [R13 + V_WINDOW]
        LA     R2, note_name
        CALLF  WM_SET_TEXT
        JUMP   button_drawn
button_desk: LOAD R1, [R13 + V_APP]     ; Desktop, toggle on / off
        CALLF  WM_APP_INFO              ; R5 = 1 on the desktop, R6 = kind
        CMPI   R1, 0x0000
        JZ     button_done
        LOADLO R2, 1
        CMPI   R5, 0x0000
        JZ     button_desk_set
        LOADLO R2, 0
button_desk_set: LOAD R1, [R13 + V_APP]
        CALLF  WM_SET_DESKTOP
        CALL   desk_label
        JUMP   button_drawn
button_none: NOT R1, R0                 ; no wallpaper
        STORE  R1, [R13 + V_WALL_NOW]
        LOADLO R1, 0
        CALLF  WM_WALLPAPER
        JUMP   button_drawn
button_next: LOAD R2, [R13 + V_WALLS]   ; next wallpaper, wraps to the first
        CMPI   R2, 0x0000
        JZ     button_done
        LOAD   R1, [R13 + V_WALL_NOW]
        INC    R1
        CMP    R1, R2
        JNC    button_wall
        LOADLO R1, 0
button_wall: STORE R1, [R13 + V_WALL_NOW]
        LA     R1, wallpaper_folder     ; path = folder + name
        ADDI   R2, R13, V_PATH
        CALL   text_copy
        PUSH   R2
        CALL   wall_name
        POP    R2
        CALL   text_copy
        ADDI   R1, R13, V_PATH
        CALLF  WM_WALLPAPER
        JUMP   button_drawn
button_app: CALL next_app
        JUMP   button_drawn
button_icon: LOAD R1, [R13 + V_APP]     ; Icon, the sprite after the current one
        CALLF  WM_APP_INFO              ; R3 = icon name, 0 = default
        CMPI   R1, 0x0000
        JZ     button_done
        LOAD   R5, [R13 + V_SPRITES]
        CMPI   R5, 0x0000
        JZ     button_done              ; no sprite list
        LOADLO R4, 0                    ; R4 = index of its icon in the list
        CMPI   R3, 0x0000
        JZ     icon_take                ; none yet, take the first
icon_find: SHIFTI R6, R4, 0x02, 0b0000
        ADD    R6, R6, R13
        LOAD   R1, [R6 + V_SPRITE_NAMES]
        MOV    R2, R3
        PUSH   R3
        PUSH   R4
        PUSH   R5
        CALL   text_same               ; R3 = 1 if the same
        MOV    R1, R3
        POP    R5
        POP    R4
        POP    R3
        CMPI   R1, 1
        JZ     icon_found
        INC    R4
        CMP    R4, R5
        JNC    icon_find
        LOADLO R4, 0                    ; not in the list, take the first
        JUMP   icon_take
icon_found: INC R4                      ; the one after, wraps
        CMP    R4, R5
        JNC    icon_take
        LOADLO R4, 0
icon_take: SHIFTI R6, R4, 0x02, 0b0000
        ADD    R6, R6, R13
        LOAD   R2, [R6 + V_SPRITE_NAMES]
icon_set: LOAD R1, [R13 + V_APP]
        CALLF  WM_SET_ICON
        CALL   save_if_app
        JUMP   button_drawn
button_colour: LOAD R1, [R13 + V_APP]   ; Colour, next in colour_list
        CALLF  WM_APP_INFO              ; R4 = label colour
        CMPI   R1, 0x0000
        JZ     button_done
        LA     R3, colour_list
        LOADLO R5, 0
colour_find: ADD R6, R3, R5
        LOADB  R6, [R6]
        INC    R5
        CMP    R6, R4
        JZ     colour_found
        CMPI   R5, 8
        JNZ    colour_find
        LOADLO R5, 0
colour_found: CMPI R5, 8
        JNZ    colour_take
        LOADLO R5, 0
colour_take: ADD R6, R3, R5
        LOADB  R2, [R6]
        LOAD   R1, [R13 + V_APP]
        CALLF  WM_SET_LABEL
        CALL   save_if_app
button_drawn: LOAD R1, [R13 + V_WINDOW]
        CALLF  WM_REDRAW
button_done: POP R13
        RET

; save_if_app, save_page only for an app, WM keeps files in ICONS.TXT
save_if_app: LOAD R1, [R13 + V_APP]
        CALLF  WM_APP_INFO              ; R6 = kind
        CMPI   R6, 0x0000
        JZ     save_page
        RET

; save_page, rewrites the apps PAGE.TXT with its icon and label
; old icon and label lines dropped, new ones added at the end
; R8 = page, R9 = its end, R10 = line pointer
; R11 = app name, R12 = icon name
save_page: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        LOAD   R1, [R13 + V_APP]
        CALLF  WM_APP_INFO              ; R1 = name, R3 = icon name, R4 = label colour
        CMPI   R1, 0x0000
        JZ     save_end
        MOV    R11, R1
        MOV    R12, R3
        STORE  R4, [R13 + V_LABEL]
        LA     R1, apps_folder          ; path = /apps/NAME/page.txt
        ADDI   R2, R13, V_PATH
        CALL   text_copy
        MOV    R1, R11
        CALL   text_copy
        LA     R1, page_file
        CALL   text_copy
        ADDI   R1, R13, V_PATH
        CALLF  FILE_SIZE                ; R2 = size
        CMPI   R1, 0x0000
        JNZ    save_end
        MOV    R9, R2
        ADD    R1, R9, R9               ; room for the page and the new page
        ADDI   R1, R1, 96
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     save_end
        MOV    R8, R1
        ADDI   R1, R13, V_PATH
        MOV    R2, R8
        CALLF  FILE_READ
        CMPI   R1, 0x0000
        JNZ    save_free
        ADD    R9, R8, R9               ; R9 = page end
        ADDI   R1, R9, 96               ; start the text builder for the new page
        SUB    R1, R1, R8
        CALL   tb_start
        MOV    R10, R8
save_line: CMP R10, R9
        JC     save_lines_done
        MOV    R1, R10                  ; skip old icon / label lines
        LA     R2, word_icon
        CALL   text_starts
        CMPI   R3, 1
        JZ     save_skip
        MOV    R1, R10
        LA     R2, word_label
        CALL   text_starts
        CMPI   R3, 1
        JZ     save_skip
save_copy: LOADB R1, [R10]              ; copy any other line up to LF
        PUSH   R1
        CALL   tb_char
        POP    R1
        INC    R10
        CMPI   R1, 0x000A
        JZ     save_line
        CMP    R10, R9
        JC     save_lines_done
        JUMP   save_copy
save_skip: LOADB R1, [R10]
        INC    R10
        CMPI   R1, 0x000A
        JZ     save_line
        CMP    R10, R9
        JC     save_lines_done
        JUMP   save_skip
save_lines_done: CMP R9, R8             ; end the last line if needed
        JZ     save_new
        LOADB  R1, [R9 - 1]
        CMPI   R1, 0x000A
        JZ     save_new
        CALL   tb_line
save_new: CMPI R12, 0x0000              ; icon FILE.PIC
        JZ     save_label_line
        LA     R1, word_icon
        CALL   tb_text
        MOV    R1, R12
        CALL   tb_text
        CALL   tb_line
save_label_line: LA R1, word_label      ; label NN
        CALL   tb_text
        LOAD   R1, [R13 + V_LABEL]
        CALL   tb_hex2
        CALL   tb_line
        ADDI   R1, R13, V_PATH          ; write it back
        CALL   tb_save
save_free: MOV R1, R8
        CALLF  FREE
save_end: POP  R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; wall_name, out R1 = pointer to the current wallpaper name or "none", uses R1, R2
wall_name: LOAD R1, [R13 + V_WALL_NOW]
        CMPIS  R1, 0
        JGE    wall_some
        LA     R1, none_text
        RET
wall_some: LOAD R2, [R13 + V_WALLS]
        CMP    R1, R2
        JC     wall_none
        SHIFTI R2, R1, 0x02, 0b0000
        ADD    R2, R2, R13
        LOAD   R1, [R2 + V_WALL_NAMES]
        RET
wall_none: LA  R1, no_list_text
        RET


; paint, each value after its name, wallpaper, app, icon, label
; label drawn in its colour on teal
paint:  PUSH   R13
        PUSH   R12
        LA     R13, vars
        CALL   wall_name
        MOV    R3, R1
        LOADLO R1, 88
        LOADLO R2, 0
        LOADLO R4, 0x38
        CALLF  WM_TEXT
        LOAD   R1, [R13 + V_APP]
        CALLF  WM_APP_INFO              ; R1 = name or 0, R2 = title, R3 = icon, R4 = label colour
        CMPI   R1, 0x0000
        JZ     paint_done
        PUSH   R4
        PUSH   R3
        MOV    R12, R2                  ; R12 = title
        MOV    R3, R2                   ; app title
        LOADLO R1, 88
        LOADLO R2, 32
        LOADLO R4, 0x38
        CALLF  WM_TEXT
        LOAD   R1, [R13 + V_APP]        ; its icon
        LOADLO R2, 88
        LOADLO R3, 56
        CALLF  WM_ICON
        POP    R3                       ; icon file name without .pic, default "gear"
        CMPI   R3, 0x0000
        JNZ    paint_icon_name
        LA     R3, own_icon_text
        JUMP   paint_icon
paint_icon_name: ADDI R2, R13, V_PATH   ; copy up to the dot
paint_icon_copy: LOADB R1, [R3]
        CMPI   R1, 0x002E
        JZ     paint_icon_cut
        STOREB R1, [R2]
        CMPI   R1, 0x0000
        JZ     paint_icon_cut
        INC    R3
        INC    R2
        JUMP   paint_icon_copy
paint_icon_cut: STOREB R0, [R2]
        ADDI   R3, R13, V_PATH
paint_icon: LOADLO R1, 128
        LOADLO R2, 64
        LOADLO R4, 0x38
        CALLF  WM_TEXT
        LOADLO R1, 88                   ; label, on teal in its colour
        LOADLO R2, 96
        LOADLO R3, 96
        LOADLO R4, 16
        LOADLO R5, 0x28
        CALLF  WM_BOX
        POP    R4
        LOADLO R1, 92
        LOADLO R2, 96
        MOV    R3, R12
        CALLF  WM_TEXT
paint_done: POP R12
        POP    R13
        RET

; tick, key, click, close: nothing to do
tick:   RET
key:    RET
click:  RET
close:  RET

wall_list_path:   .string "/system/design/wallpapr/wallpapr.txt"
desk_name:        .string "desk"
kind_name:        .string "kind"
note_name:        .string "note"
nothing_text:     .string ""
desk_folder_text: .string "/desktop/"
del_app_text:     .string "Apps can't be deleted here"
del_sure_text:    .string "Sure? Press Delete again"
del_done_text:    .string "Deleted"
del_failed_text:  .string "Couldn't: a folder must be empty"
kind_texts:       .string "an app         "   ; 16 bytes each, in the order of WM kinds
                  .string "a text file    "
                  .string "a program      "
                  .string "a folder       "
                  .string "a file         "
desk_add_text:    .string "Add to desktop"
desk_remove_text: .string "Remove from desktop"
desk_always_text: .string "Always on desktop"
settings_word:    .string "settings"
sprite_list_path: .string "/system/design/sprites/sprites.txt"
wallpaper_folder: .string "/system/design/wallpapr/"
apps_folder:      .string "/apps/"
page_file:        .string "/page.txt"
word_icon:        .string "icon "
word_label:       .string "label "
a_space:          .string " "
nothing:          .string ""
none_text:        .string "none"
no_list_text:     .string "(no WALLPAPR.TXT)"
own_icon_text:    .string "gear"
; label colours, white, black, yellow, sky blue, navy, silver, pink, green
colour_list:      .byte 0x0F, 0x00, 0x88, 0x48, 0x38, 0xF0, 0xB8, 0x68
vars:   .word 0                         ; 152 words, V_WINDOW to V_LABEL
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0                         ; V_SURE

.include "sw/apps/lib/text.asm"       ; app library, text_copy, text_same, text builder
.include "sw/apps/lib/lines.asm"      ; line reader, file_text, line_first, line_next, first_word
