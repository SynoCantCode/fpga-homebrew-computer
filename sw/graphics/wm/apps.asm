; wm apps, APPS.TXT, app records, opening, closing, saving
; included by programs/wm.asm

; load_apps, reads /APPS/APPS.TXT, one app a line
; a line = folder name, then "off" if not on the desktop
; each app gets a record in apps, icon drawn at (32 x number, 0)
; no page = left out, apps not hidden are opened
; R8 = pointer into the list, R9 = its end, R10 = next app number
; R11 = its record, R12 = its number for load_icon
load_apps: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        LOADLO R1, 4224                 ; APPS_MAX x 128 + 1 spare record
        CALLF  ALLOCATE
        STORE  R1, [apps]
        STORE  R0, [app_count]
        CMPI   R1, 0x0000
        JZ     apps_done
        MOV    R2, R1
        LOADLO R3, 4224
apps_clear: STORE R0, [R2]
        ADDI   R2, R2, 4
        SUBI   R3, R3, 4
        CMPI   R3, 0x0000
        JNZ    apps_clear
        LA     R1, apps_list_path
        CALL   load_text
        CMPI   R1, 0x0000
        JZ     apps_open                ; no list, no apps
        STORE  R1, [apps_text]
        MOV    R9, R2                   ; R9 = end of the text
        LOADLO R10, 0
        CALL   line_first               ; R8 = a line
        MOV    R8, R1
apps_next: CMPI R8, 0x0000
        JZ     apps_open                ; end of the list
        CMPI   R10, APPS_MAX
        JZ     apps_open                ; full
        MOV    R1, R8                   ; find the next line first, cutting writes 0s into this one
        MOV    R2, R9
        CALL   line_next
        PUSH   R1
        MOV    R1, R10                  ; its record
        CALL   app_record
        MOV    R11, R1
        MOV    R1, R8                   ; its name, first word of the line
        CALL   first_word               ; R2 = name, R1 = rest of the line
        STORE  R2, [R11 + W_NAME]
        STORE  R2, [R11 + W_TITLE]      ; title, unless the page gives one
        LOADLO R2, 1
        STORE  R2, [R11 + W_ICON]       ; on the desktop unless "off" follows
        LOADLO R2, WHITE_DOT
        STORE  R2, [R11 + A_LABEL]
        CALL   read_word                ; next word, "off"?
        LA     R4, word_off
        CALL   word_is
        CMPI   R5, 1
        JNZ    apps_scan
        MOV    R1, R10                  ; Settings always stays on the desktop
        CALL   is_settings
        CMPI   R1, 0x0000
        JNZ    apps_scan
        STORE  R0, [R11 + W_ICON]
apps_scan: MOV R1, R11                  ; read its page
        CALL   scan_page
        CMPI   R1, 0x0000
        JZ     apps_line_done           ; no page, left out
        MOV    R8, R11                  ; its icon, R8 = record, R12 = number
        MOV    R12, R10
        LOAD   R2, [R11 + W_ICON_NAME]
        CALL   load_icon
        INC    R10
        STORE  R10, [app_count]
apps_line_done: POP R8                  ; next line
        JUMP   apps_next
apps_open: CALL desktop_files          ; then the files in /DESKTOP
        CALL   load_layout              ; icon places from ICONS.TXT
        LOADLO R10, 0                   ; open the apps not hidden and not full screen
apps_open_next: LOAD R1, [app_count]
        CMP    R10, R1
        JC     apps_done
        MOV    R1, R10
        CALL   app_record
        LOAD   R2, [R1 + A_HIDDEN]
        LOAD   R3, [R1 + A_FULL]
        OR     R2, R2, R3
        JNZ    apps_open_skip
        MOV    R1, R10
        CALL   launch_app
apps_open_skip: INC R10
        JUMP   apps_open_next
apps_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; app_record
; in R1 = app or desktop file number, out R1 = pointer to its record
; keeps every other register
; a number out of range gives the spare record
app_record: PUSH R2
        CMPI   R1, APPS_MAX
        JNC    app_record_in            ; 0 to APPS_MAX - 1, unsigned
        LOADLO R1, APPS_MAX             ; out of range, the spare
app_record_in: SHIFTI R1, R1, 0x07, 0b0000
        LOAD   R2, [apps]
        ADD    R1, R1, R2
        POP    R2
        RET

; scan_page, reads title, icon, label, hidden, shell from an app page
; the page stays in the heap, title and icon name point into it
; in R1 = app record with W_NAME set, out R1 = 1, or 0 if no page
; R8 = record, R9 = line, R10 = page end, R11 = line end
scan_page: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        LOAD   R1, [R8 + W_NAME]
        LA     R2, page_name
        CALL   make_path                ; "/apps/NAME/page.txt"
        CALL   load_text
        CMPI   R1, 0x0000
        JZ     scan_end
        MOV    R9, R1
        MOV    R10, R2
scan_line: CMP R9, R10
        JC     scan_done
        LOADB  R1, [R9]
        CMPI   R1, 0x0000
        JNZ    scan_found
        INC    R9
        JUMP   scan_line
scan_found: MOV R11, R9                 ; end of the line, a 0
scan_find_end: LOADB R1, [R11]
        CMPI   R1, 0x0000
        JZ     scan_ended
        INC    R11
        JUMP   scan_find_end
scan_ended: MOV R1, R9                  ; its first word
        CALL   read_word
        PUSH   R1
        LA     R4, word_title
        CALL   word_is
        POP    R1
        CMPI   R5, 1
        JNZ    scan_not_title
        CALL   skip_spaces              ; title TEXT, rest of the line
        STORE  R1, [R8 + W_TITLE]
        JUMP   scan_next
scan_not_title: PUSH R1
        LA     R4, word_icon
        CALL   word_is
        POP    R1
        CMPI   R5, 1
        JNZ    scan_not_icon
        CALL   read_word                ; icon NAME.PIC, end the word with a 0
        STOREB R0, [R1]
        STORE  R2, [R8 + W_ICON_NAME]
        JUMP   scan_next
scan_not_icon: PUSH R1
        LA     R4, word_label
        CALL   word_is
        POP    R1
        CMPI   R5, 1
        JNZ    scan_not_label
        CALL   read_hex                 ; label NN
        STORE  R2, [R8 + A_LABEL]
        JUMP   scan_next
scan_not_label: PUSH R1
        LA     R4, word_hidden
        CALL   word_is
        POP    R1
        CMPI   R5, 1
        JNZ    scan_not_hidden
        LOADLO R1, 1
        STORE  R1, [R8 + A_HIDDEN]
        JUMP   scan_next
scan_not_hidden: LA R4, word_shell
        CALL   word_is
        CMPI   R5, 1
        JNZ    scan_next
        LOADLO R1, 1
        STORE  R1, [R8 + A_FULL]
scan_next: MOV R9, R11
        JUMP   scan_line
scan_done: LOADLO R1, 1
scan_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; launch_app, opens an app
; shows its window at the front, or makes one
; window slot N for app N if free, else the first free slot
; in R1 = app number, out R1 = its window, or -1
; R8 = window record, R9 = window, R10 = app, R11 = app record
launch_app: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R10, R1
        CALL   app_record
        MOV    R11, R1
        LOAD   R1, [R11 + A_KIND]       ; a file on the desktop, open_item opens it
        CMPI   R1, 0x0000
        JZ     launch_an_app
        MOV    R1, R10
        CALL   open_item
        NOT    R1, R0
        JUMP   launch_end
launch_an_app: LOAD R1, [R11 + A_WINDOW]
        CMPI   R1, 0x0000
        JZ     launch_slot
        SUBI   R9, R1, 1                ; open already, show at the front
        JUMP   launch_show
launch_slot: MOV R9, R10                ; slot = its own number if free
        CMPI   R9, WINDOW_COUNT
        JNC    launch_check
        JUMP   launch_search
launch_check: MOV R1, R9
        CALL   window_record
        LOAD   R1, [R1 + W_KIND]
        CMPI   R1, KIND_NONE
        JZ     launch_make
launch_search: LOADLO R9, 0             ; else the first free one
launch_search_next: MOV R1, R9
        CALL   window_record
        LOAD   R1, [R1 + W_KIND]
        CMPI   R1, KIND_NONE
        JZ     launch_make
        INC    R9
        CMPI   R9, WINDOW_COUNT
        JNZ    launch_search_next
        NOT    R1, R0                   ; no free slot
        JUMP   launch_end
launch_make: MOV R1, R9                 ; clear the slot, default style
        CALL   window_record
        MOV    R8, R1
        MOV    R2, R8
        LOADLO R3, 128
launch_clear: STORE R0, [R2]
        ADDI   R2, R2, 4
        SUBI   R3, R3, 4
        CMPI   R3, 0x0000
        JNZ    launch_clear
        LOADLO R1, styles
        STORE  R1, [R8 + W_STYLE]
        LOAD   R1, [R11 + W_NAME]
        STORE  R1, [R8 + W_NAME]
        LOAD   R1, [icons]              ; read its page, icon not loaded again
        PUSH   R1
        STORE  R0, [icons]
        MOV    R1, R9
        CALL   load_page
        POP    R2
        STORE  R2, [icons]
        CMPI   R1, 0x0000
        JNZ    launch_paged
        LOADLO R1, KIND_NONE
        STORE  R1, [R8 + W_KIND]
        NOT    R1, R0
        JUMP   launch_end
launch_paged: ADDI R1, R10, 1           ; window knows its app
        STORE  R1, [R8 + W_ICON]
        ADDI   R1, R9, 1                ; app knows its window
        STORE  R1, [R11 + A_WINDOW]
        MOV    R1, R9                   ; its program
        CALL   load_app
        MOV    R1, R8                   ; its size and cells
        CALL   window_size
        LOADLO R1, 0x12C0
        CALLF  ALLOCATE
        STORE  R1, [R8 + W_CELLS]
        CMPI   R1, 0x0000
        JNZ    launch_draw
        MOV    R1, R9                   ; no room, undo
        CALL   release_window
        NOT    R1, R0
        JUMP   launch_end
launch_draw: MOV R1, R9
        CALL   draw_window
launch_show: MOV R1, R9
        CALL   window_record
        LOADLO R2, 1
        STORE  R2, [R1 + W_VISIBLE]
        MOV    R1, R9
        CALL   raise
        LOADLO R1, 1
        STORE  R1, [redraw]
        MOV    R1, R9
launch_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; release_window, empties a window slot
; frees its picture, cells and program code, not the page text
; in R1 = window. R8 = its record, R9 = window, R10 = place in the tables
release_window: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R9, R1
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [R8 + W_KIND]
        CMPI   R1, KIND_NONE
        JZ     release_done
        SHIFTI R10, R9, 0x02, 0b0000
        LOAD   R1, [R8 + W_ICON]        ; its app has no window
        CMPI   R1, 0x0000
        JZ     release_memory
        SUBI   R1, R1, 1
        CALL   app_record
        STORE  R0, [R1 + A_WINDOW]
release_memory: LOADLO R1, picture_raw  ; its picture
        ADD    R1, R1, R10
        LOAD   R1, [R1]
        CMPI   R1, 0x0000
        JZ     release_cells
        CALLF  FREE
release_cells: LOADLO R1, picture_raw
        ADD    R1, R1, R10
        STORE  R0, [R1]
        LOADLO R1, picture_rows
        ADD    R1, R1, R10
        STORE  R0, [R1]
        LOAD   R1, [R8 + W_CELLS]       ; its cells
        CMPI   R1, 0x0000
        JZ     release_code
        CALLF  FREE
release_code: LOADLO R1, app_raw        ; its program code
        ADD    R1, R1, R10
        LOAD   R1, [R1]
        CMPI   R1, 0x0000
        JZ     release_record
        CALLF  FREE
release_record: LOADLO R1, app_raw
        ADD    R1, R1, R10
        STORE  R0, [R1]
        LOADLO R1, KIND_NONE            ; slot empty
        STORE  R1, [R8 + W_KIND]
        STORE  R0, [R8 + W_VISIBLE]
        STORE  R0, [R8 + W_APP]
        STORE  R0, [R8 + W_PICTURE]
        STORE  R0, [R8 + W_CELLS]
        STORE  R0, [R8 + W_ICON]
        LOAD   R1, [focus_window]       ; clear the focus and highlights pointing at it
        CMP    R1, R9
        JNZ    release_hover
        NOT    R1, R0
        STORE  R1, [focus_window]
release_hover: NOT R1, R0
        STORE  R1, [hover_task]
        STORE  R1, [hover_title]
        STORE  R0, [hover_button]
        LOADLO R1, 1
        STORE  R1, [redraw]
release_done: POP R10
        POP    R9
        POP    R8
        RET

; find_app_number, finds an app by name, case ignored
; in R1 = pointer to name, out R1 = number or -1. R8 = name, R9 = app
find_app_number: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADLO R9, 0
find_number_next: LOAD R1, [app_count]
        CMP    R9, R1
        JC     find_number_none
        MOV    R1, R9
        CALL   app_record
        LOAD   R2, [R1 + W_NAME]
        MOV    R1, R8
        CALL   text_same
        CMPI   R3, 1
        JZ     find_number_found
        INC    R9
        JUMP   find_number_next
find_number_found: MOV R1, R9
        JUMP   find_number_end
find_number_none: NOT R1, R0
find_number_end: POP R9
        POP    R8
        RET

; remove_icon, takes an app off the desktop and saves APPS.TXT
; in R1 = app number
remove_icon: CALL app_record
        STORE  R0, [R1 + W_ICON]
        NOT    R1, R0
        STORE  R1, [hover_place]
        LOADLO R1, 1
        STORE  R1, [redraw]
        CALL   save_layout              ; a file "off" is kept there
        JUMP   save_apps

; put_icon, puts an app icon back on the desktop and saves APPS.TXT
; in R1 = app number
put_icon: CALL app_record                ; goes in the first free place after the last one used
        PUSH   R1
        CALL   end_place
        POP    R2
        STORE  R1, [R2 + A_PLACE]
        LOADLO R1, 1
        STORE  R1, [R2 + W_ICON]
        STORE  R1, [redraw]
        CALL   save_layout
        JUMP   save_apps

; is_settings, is this app Settings, the one that stays on the desktop
; in R1 = app number, out R1 = 1 yes, 0 no, uses R1-R5
is_settings: CALL app_record
        LOAD   R2, [R1 + W_NAME]
        LA     R1, settings_name
        CALL   text_same                ; R3 = 1 if the same
        LOADLO R1, 1
        CMPI   R3, 1
        JZ     is_settings_done
        LOADLO R1, 0
is_settings_done: RET

; save_apps, writes APPS.TXT from the records
; each app name, then " off" if not on the desktop. R10 = record number
save_apps: PUSH R10
        LOADLO R1, 2048
        CALL   tb_start
        LA     R1, apps_note_text
        CALL   tb_text
        LOADLO R10, 0
save_apps_next: LOAD R1, [app_count]
        CMP    R10, R1
        JC     save_apps_write
        MOV    R1, R10
        CALL   app_record
        LOAD   R2, [R1 + A_KIND]
        CMPI   R2, 0x0000
        JNZ    save_apps_skip
        PUSH   R1
        LOAD   R1, [R1 + W_NAME]
        CALL   tb_text
        POP    R1
        LOAD   R1, [R1 + W_ICON]
        CMPI   R1, 0x0000
        JNZ    save_apps_line
        LA     R1, apps_off_text        ; " off"
        CALL   tb_text
save_apps_line: CALL tb_line
save_apps_skip: INC R10
        JUMP   save_apps_next
save_apps_write: LA R1, apps_list_path
        CALL   tb_save
        POP    R10
        RET
