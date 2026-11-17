; files app, the cards folders and files in a window
; list shows folders first with a /, then files with sizes
; arrows or a click choose, Enter or a second click opens, Backspace goes up
; Up (event 1)      folder above
; Delete (event 3)  file or empty folder, press twice
; Rename (event 4)  type the new name, Enter to finish
; Folder (event 5)  type a new folders name, Enter to make it
; Open (event 2)    folder, .TXT shown, .PIC as wallpaper, file in /APPS/NAME opens that app
; folders are read with the kernels folder_list, KERNEL_CALLS + 0
; 32 bytes an entry, name, type, kind (0x10 = folder), size
; build: python project/tools/assembler/make_app.py sw/apps/files/app.asm
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
.equ V_WINDOW,  0                       ; window
.equ V_LIST,    4                       ; entries, 24 bytes each, name 13, folder flag at 13, size at 16
.equ V_COUNT,   8                       ; how many
.equ V_CHOSEN,  12                      ; chosen entry
.equ V_TOP,     16                      ; first one shown
.equ V_BLOCK,   20                      ; kernel folder listing on the heap, MAX_ENTRIES x 32 bytes
.equ V_TEXT,    24                      ; text being shown on the heap, 0 = showing the list
.equ V_TEXT_END, 28                     ; its end
.equ V_LINE,    32
.equ V_MESSAGE, 36                      ; pointer to a bottom row message, 0 = none
.equ V_PATH,    40                      ; folder path, up to 95 letters + 0, 40-135
.equ V_FULL,    136                     ; path buffer, 96 bytes, 136-231
.equ V_NUMBER,  232                     ; size as text, 12 bytes, 232-243
.equ V_MODE,    244                     ; 0 list, 1 Delete pressed once, 2 typing a name, 3 typing a folder name
.equ V_TYPED,   248                     ; typed text, up to 12 letters + 0, 248-263
.equ V_SHOW,    264                     ; bottom row while typing, 264-335
.equ V_NEW,     336                     ; path from the typed name, 96 bytes, 336-431
.equ MAX_ENTRIES, 64
.equ ENTRY_BYTES, 24
.equ ROW,       16                      ; list row, 16 dots

; init, reads the root folder, in R1 = window
init:   PUSH   R13
        LA     R13, vars
        STORE  R1, [R13 + V_WINDOW]
        LOADLO R1, 0x0600               ; MAX_ENTRIES x ENTRY_BYTES
        CALLF  ALLOCATE
        STORE  R1, [R13 + V_LIST]
        LOADLO R1, 0x0800               ; MAX_ENTRIES x 32 bytes
        CALLF  ALLOCATE
        STORE  R1, [R13 + V_BLOCK]
        LOADLO R1, 0x002F               ; "/"
        STOREB R1, [R13 + V_PATH]
        ADDI   R1, R13, V_PATH
        STOREB R0, [R1 + 1]
        CALL   read_folder
        POP    R13
        RET

; read_folder, reads the folder at V_PATH into the list, folders first
; kernel folder_list fills V_BLOCK, then two passes with take_line
; R9 = entries left, R10 = count, R11 = pointer to one, R12 = pass, 0 folders, 1 files
read_folder: PUSH R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        STORE  R0, [R13 + V_COUNT]
        STORE  R0, [R13 + V_CHOSEN]
        STORE  R0, [R13 + V_TOP]
        STORE  R0, [R13 + V_MESSAGE]
        LOAD   R5, [KERNEL_CALLS]       ; 0 = kernel has no folder_list
        CMPI   R5, 0x0000
        JZ     folder_not
        ADDI   R1, R13, V_PATH
        LOAD   R2, [R13 + V_BLOCK]
        LOADLO R3, MAX_ENTRIES
        CALLR  R5                       ; R1 = how many, -1 = not a folder
        CMPIS  R1, 0
        JGE    folder_found
folder_not: LA R1, not_folder_text
        STORE  R1, [R13 + V_MESSAGE]
        JUMP   folder_done
folder_found: MOV R10, R1
        LOADLO R12, 0
folder_pass: LOAD R11, [R13 + V_BLOCK]
        MOV    R9, R10
folder_line: CMPI R9, 0x0000
        JZ     folder_pass_done
        LOADB  R2, [R11 + 11]           ; kind, 0x10 = folder
        ANDI   R3, R2, 0x0010
        CMPI   R12, 0x0000              ; folders pass or files pass?
        JNZ    folder_files_pass
        CMPI   R3, 0x0000
        JZ     folder_skip
        JUMP   folder_take
folder_files_pass: CMPI R3, 0x0000
        JNZ    folder_skip
folder_take: CALL take_line
folder_skip: ADDI R11, R11, 32
        DEC    R9
        JUMP   folder_line
folder_pass_done: INC R12
        CMPI   R12, 2
        JNZ    folder_pass
folder_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        RET

; take_line, kernel entry into the list, lowercase name, folder flag, size
; in R11 = the entry, uses R1-R7
take_line: LOAD R1, [R13 + V_COUNT]
        CMPI   R1, MAX_ENTRIES
        JNZ    take_room
        RET
take_room: INC R1
        STORE  R1, [R13 + V_COUNT]
        SUBI   R1, R1, 1
        MULI   R7, R1, ENTRY_BYTES
        LOAD   R1, [R13 + V_LIST]
        ADD    R7, R7, R1               ; R7 = the list entry
        MOV    R6, R7
        LOADLO R5, 0                    ; name, 8 letters, spaces skipped
take_name: ADD R4, R11, R5
        LOADB  R1, [R4]
        CALL   text_lower
        CMPI   R1, 0x0020
        JZ     take_name_next
        STOREB R1, [R6]
        INC    R6
take_name_next: INC R5
        CMPI   R5, 8
        JNZ    take_name
        LOADB  R1, [R11 + 8]            ; then "." and the 3 letter type if any
        CMPI   R1, 0x0020
        JZ     take_name_end
        LOADLO R1, 0x002E
        STOREB R1, [R6]
        INC    R6
take_type: ADD R4, R11, R5
        LOADB  R1, [R4]
        CALL   text_lower
        CMPI   R1, 0x0020
        JZ     take_type_next
        STOREB R1, [R6]
        INC    R6
take_type_next: INC R5
        CMPI   R5, 11
        JNZ    take_type
take_name_end: STOREB R0, [R6]
        LOADB  R1, [R11 + 11]           ; folder?
        ANDI   R1, R1, 0x0010
        SHIFTI R1, R1, 0x04, 0b1000
        STOREB R1, [R7 + 13]
        LOADB  R1, [R11 + 28]           ; size, 4 bytes, lowest first
        LOADB  R2, [R11 + 29]
        SHIFTI R2, R2, 0x08, 0b0000
        OR     R1, R1, R2
        LOADB  R2, [R11 + 30]
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        LOADB  R2, [R11 + 31]
        SHIFTI R2, R2, 0x18, 0b0000
        OR     R1, R1, R2
        STORE  R1, [R7 + 16]
        RET

; entry_of, in R1 = N, out R1 = pointer to entry N, uses R2
entry_of: MULI R1, R1, ENTRY_BYTES
        LOAD   R2, [R13 + V_LIST]
        ADD    R1, R1, R2
        RET

; full_path, V_FULL = V_PATH + "/" + name
; in R1 = pointer to the name, uses R1-R4
full_path: PUSH R1
        ADDI   R1, R13, V_PATH
        ADDI   R2, R13, V_FULL
        CALL   text_copy
        LOADB  R3, [R2 - 1]             ; root already ends in /
        CMPI   R3, 0x002F
        JZ     full_name
        LOADLO R3, 0x002F
        STOREB R3, [R2]
        INC    R2
full_name: POP R1
        JUMP   text_copy

; go_up, cut the last part off V_PATH, uses R1-R7
go_up:  ADDI   R1, R13, V_PATH          ; find the last /
        MOV    R2, R1
up_scan: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     up_cut
        CMPI   R3, 0x002F
        JNZ    up_next
        MOV    R2, R1
up_next: INC   R1
        JUMP   up_scan
up_cut: ADDI   R3, R13, V_PATH
        CMP    R2, R3
        JNZ    up_not_root
        INC    R2                       ; keep the root /
up_not_root: STOREB R0, [R2]
        JUMP   read_folder

; open_chosen, opens the chosen entry, uses R1-R7, keeps R8
open_chosen: PUSH R8
        LOAD   R1, [R13 + V_COUNT]
        CMPI   R1, 0x0000
        JZ     open_done
        LOAD   R1, [R13 + V_CHOSEN]
        CALL   entry_of
        MOV    R8, R1
        LOADB  R2, [R8 + 13]
        CMPI   R2, 0x0000
        JZ     open_file
        MOV    R1, R8                   ; folder, go into it
        CALL   full_path
        ADDI   R1, R13, V_FULL
        ADDI   R2, R13, V_PATH
        CALL   text_copy
        CALL   read_folder
        JUMP   open_done
open_file: MOV R1, R8                   ; file, what kind?
        CALL   full_path
        ADDI   R1, R13, V_PATH          ; in /apps/NAME, open that app
        LA     R2, apps_prefix
        CALL   starts_with
        CMPI   R1, 0x0000
        JNZ    open_app
        MOV    R1, R8
        LA     R2, txt_end
        CALL   ends_with
        CMPI   R1, 0x0000
        JNZ    open_text
        MOV    R1, R8
        LA     R2, pic_end
        CALL   ends_with
        CMPI   R1, 0x0000
        JNZ    open_picture
        MOV    R1, R8
        LA     R2, bin_end
        CALL   ends_with
        LA     R2, unknown_text
        CMPI   R1, 0x0000
        JZ     open_say
        LA     R2, bin_text
open_say: STORE R2, [R13 + V_MESSAGE]
        JUMP   open_done
open_app: ADDI R1, R13, V_PATH          ; app name is after "/apps/", 6 letters
        ADDI   R1, R1, 6
        CALLF  WM_OPEN
        LA     R2, app_opened_text
        CMPI   R1, 0x0000
        JNZ    open_say
        LA     R2, no_app_text
        JUMP   open_say
open_picture: ADDI R1, R13, V_FULL      ; picture, set as wallpaper
        CALLF  WM_WALLPAPER
        LA     R2, wallpaper_text
        CMPI   R1, 0x0000
        JNZ    open_say
        LA     R2, bad_picture_text
        JUMP   open_say
open_text: ADDI R1, R13, V_FULL         ; text, read it and show it
        CALLF  FILE_SIZE
        CMPI   R1, 0x0000
        JNZ    open_done
        CMPI   R2, 0x0000
        JZ     open_done
        PUSH   R2
        ADDI   R1, R2, 1
        CALLF  ALLOCATE
        POP    R2
        CMPI   R1, 0x0000
        JZ     open_done
        STORE  R1, [R13 + V_TEXT]
        ADD    R3, R1, R2
        STORE  R3, [R13 + V_TEXT_END]
        STOREB R0, [R3]
        MOV    R2, R1
        ADDI   R1, R13, V_FULL
        CALLF  FILE_READ
        STORE  R0, [R13 + V_LINE]
open_done: POP R8
        RET

; close_text, back to the list, frees the text, uses R1-R7
close_text: LOAD R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JZ     close_text_done
        CALLF  FREE
        STORE  R0, [R13 + V_TEXT]
close_text_done: RET

; starts_with / ends_with, lowercase compare
; in R1 = text, R2 = other, out R1 = 1 if so, uses R1-R5
starts_with: LOADB R4, [R2]
        CMPI   R4, 0x0000
        JZ     with_yes
        LOADB  R3, [R1]
        PUSH   R1
        MOV    R1, R3
        CALL   text_lower
        MOV    R3, R1
        POP    R1
        CMP    R3, R4
        JNZ    with_no
        INC    R1
        INC    R2
        JUMP   starts_with
ends_with: MOV R5, R1                   ; go back by the others length, then starts_with
ends_text: LOADB R3, [R5]
        CMPI   R3, 0x0000
        JZ     ends_other
        INC    R5
        JUMP   ends_text
ends_other: MOV R4, R2
ends_count: LOADB R3, [R4]
        CMPI   R3, 0x0000
        JZ     ends_back
        INC    R4
        DEC    R5
        JUMP   ends_count
ends_back: CMP R5, R1
        JNC    with_no                  ; shorter than the other
        MOV    R1, R5
        JUMP   starts_with
with_yes: LOADLO R1, 1
        RET
with_no: LOADLO R1, 0
        RET

; rows_shown, list rows that fit, out R1, uses R1-R7
rows_shown: LOAD R1, [R13 + V_WINDOW]
        CALLF  WM_SIZE
        SHIFTI R1, R2, 0x04, 0b1000
        SUBI   R1, R1, 2
        CMPIS  R1, 1
        JGE    rows_ok
        LOADLO R1, 1
rows_ok: RET

; choose, move the chosen entry and scroll to keep it in view
; in R1 = how many, below 0 = up, uses R1-R7
choose: LOAD   R2, [R13 + V_CHOSEN]
        ADD    R2, R2, R1
        LOAD   R3, [R13 + V_COUNT]
        SUBI   R3, R3, 1
        SUB    R4, R3, R2
        CMPIS  R4, 0
        JGE    choose_low
        MOV    R2, R3
choose_low: CMPIS R2, 0
        JGE    choose_set
        LOADLO R2, 0
choose_set: STORE R2, [R13 + V_CHOSEN]
        LOAD   R3, [R13 + V_TOP]        ; above the top, top moves up
        SUB    R4, R2, R3
        CMPIS  R4, 0
        JGE    choose_below
        STORE  R2, [R13 + V_TOP]
        RET
choose_below: PUSH R2                   ; below the last row, top moves down
        CALL   rows_shown
        POP    R2
        LOAD   R3, [R13 + V_TOP]
        ADD    R4, R3, R1
        CMP    R2, R4
        JC     choose_scroll
        RET
choose_scroll: SUB R3, R2, R1
        INC    R3
        STORE  R3, [R13 + V_TOP]
        RET

; key, list, Up / Down choose, Enter opens, Backspace goes up
; text, arrows and Page Up / Down scroll, Backspace back, in R2 = key
key:    PUSH   R13
        LA     R13, vars
        LOAD   R1, [R13 + V_MODE]       ; typing a name? key goes there
        CMPI   R1, 2
        JC     key_typing
        STORE  R0, [R13 + V_MODE]       ; any other key cancels the delete
        STORE  R0, [R13 + V_MESSAGE]
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JNZ    key_text
        CMPI   R2, KEY_UP
        JNZ    key_list_down
        NOT    R1, R0
        CALL   choose
        JUMP   key_drawn
key_list_down: CMPI R2, KEY_DOWN
        JNZ    key_list_enter
        LOADLO R1, 1
        CALL   choose
        JUMP   key_drawn
key_list_enter: CMPI R2, 0x000A
        JNZ    key_list_back
        CALL   open_chosen
        JUMP   key_drawn
key_list_back: CMPI R2, 0x0008
        JNZ    key_done
        CALL   go_up
        JUMP   key_drawn
key_text: CMPI R2, 0x0008               ; text, Backspace goes back to the list
        JNZ    key_text_keys
        CALL   close_text
        JUMP   key_drawn
key_text_keys: NOT R1, R0
        CMPI   R2, KEY_UP
        JZ     key_text_move
        LOADLO R1, 1
        CMPI   R2, KEY_DOWN
        JZ     key_text_move
        SUBI   R1, R0, 8
        CMPI   R2, KEY_PAGE_UP
        JZ     key_text_move
        LOADLO R1, 8
        CMPI   R2, KEY_PAGE_DOWN
        JNZ    key_done
key_text_move: LOAD R2, [R13 + V_LINE]
        ADD    R2, R2, R1
        CMPIS  R2, 0
        JGE    key_text_set
        LOADLO R2, 0
key_text_set: STORE R2, [R13 + V_LINE]
key_drawn: LOAD R1, [R13 + V_WINDOW]
        CALLF  WM_REDRAW
key_done: POP  R13
        RET

; key_typing, letters add (up to 12, no space or /), Backspace removes
; Enter does FILE_MOVE or FOLDER_MAKE and rereads, in R2 = key
key_typing: ADDI R5, R13, V_TYPED       ; R5 = end of typed text, R4 = length
        LOADLO R4, 0
typing_end: LOADB R1, [R5]
        CMPI   R1, 0x0000
        JZ     typing_found
        INC    R5
        INC    R4
        JUMP   typing_end
typing_found: CMPI R2, 0x000A
        JZ     typing_enter
        CMPI   R2, 0x0008
        JNZ    typing_letter
        CMPI   R4, 0x0000
        JZ     key_drawn
        STOREB R0, [R5 - 1]
        JUMP   key_drawn
typing_letter: CMPI R2, 0x0021          ; letter, 0x21-0x7E, not /
        JNC    key_drawn
        CMPI   R2, 0x007F
        JC     key_drawn
        CMPI   R2, 0x002F
        JZ     key_drawn
        CMPI   R4, 12
        JZ     key_drawn
        STOREB R2, [R5]
        STOREB R0, [R5 + 1]
        JUMP   key_drawn
typing_enter: CMPI R4, 0x0000
        JZ     key_drawn
        ADDI   R1, R13, V_TYPED         ; new path = this folder + typed name
        CALL   new_path
        LOAD   R1, [R13 + V_MODE]
        STORE  R0, [R13 + V_MODE]
        CMPI   R1, 3
        JZ     typing_folder
        LOAD   R1, [R13 + V_CHOSEN]     ; Rename, chosen path to the new one
        CALL   entry_of
        CALL   full_path
        ADDI   R1, R13, V_FULL
        ADDI   R2, R13, V_NEW
        CALLF  FILE_MOVE
        LA     R2, renamed_text
        JUMP   typing_done
typing_folder: ADDI R1, R13, V_NEW
        CALLF  FOLDER_MAKE
        LA     R2, folder_made_text
typing_done: PUSH R1
        PUSH   R2
        CALL   read_folder
        POP    R2
        POP    R1
        CMPI   R1, 0x0000
        JZ     typing_said
        LA     R2, failed_text
typing_said: STORE R2, [R13 + V_MESSAGE]
        JUMP   key_drawn

; new_path, V_NEW = V_PATH + "/" + name, in R1 = pointer to name, uses R1-R4
new_path: PUSH R1
        ADDI   R1, R13, V_PATH
        ADDI   R2, R13, V_NEW
        CALL   text_copy
        LOADB  R3, [R2 - 1]
        CMPI   R3, 0x002F
        JZ     new_path_name
        LOADLO R3, 0x002F
        STOREB R3, [R2]
        INC    R2
new_path_name: POP R1
        JUMP   text_copy

; click, picks that entry, opens it if already chosen
; in R2 = x, R3 = y from the canvas corner
click:  PUSH   R13
        LA     R13, vars
        STORE  R0, [R13 + V_MESSAGE]
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JNZ    click_done
        CMPIS  R3, 0
        JGE    click_row
        JUMP   click_done
click_row: SHIFTI R3, R3, 0x04, 0b1000  ; row to entry, row 0 is the path
        SUBI   R3, R3, 1
        CMPIS  R3, 0
        JGE    click_entry
        JUMP   click_done
click_entry: LOAD R1, [R13 + V_TOP]
        ADD    R3, R3, R1
        LOAD   R1, [R13 + V_COUNT]
        CMP    R3, R1
        JC     click_done               ; below the last one
        LOAD   R1, [R13 + V_CHOSEN]
        CMP    R1, R3
        JNZ    click_choose
        CALL   open_chosen              ; already chosen, open it
        JUMP   click_drawn
click_choose: STORE R3, [R13 + V_CHOSEN]
click_drawn: LOAD R1, [R13 + V_WINDOW]
        CALLF  WM_REDRAW
click_done: POP R13
        RET

; button, in R2 = event, 1 Up, 2 Open, 3 Delete, 4 Rename, 5 Folder
button: PUSH   R13
        LA     R13, vars
        STORE  R0, [R13 + V_MESSAGE]
        LOAD   R3, [R13 + V_MODE]       ; R3 = mode before this button
        STORE  R0, [R13 + V_MODE]
        CMPI   R2, 3
        JZ     button_delete
        CMPI   R2, 4
        JZ     button_rename
        CMPI   R2, 5
        JZ     button_folder
        CMPI   R2, 1
        JNZ    button_open
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JZ     button_up
        CALL   close_text
        JUMP   button_drawn
button_up: CALL go_up
        JUMP   button_drawn
button_open: CMPI R2, 2
        JNZ    button_done
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JNZ    button_done
        CALL   open_chosen
        JUMP   button_drawn
button_delete: LOAD R1, [R13 + V_COUNT] ; Delete, first press asks, second deletes
        CMPI   R1, 0x0000
        JZ     button_drawn
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JNZ    button_drawn
        CMPI   R3, 1
        JZ     delete_now
        LOADLO R1, 1
        STORE  R1, [R13 + V_MODE]
        LA     R1, sure_text
        STORE  R1, [R13 + V_MESSAGE]
        JUMP   button_drawn
delete_now: LOAD R1, [R13 + V_CHOSEN]
        CALL   entry_of
        CALL   full_path
        ADDI   R1, R13, V_FULL
        CALLF  FILE_DELETE
        PUSH   R1
        CALL   read_folder
        POP    R1
        LA     R2, deleted_text
        CMPI   R1, 0x0000
        JZ     delete_said
        LA     R2, not_deleted_text
delete_said: STORE R2, [R13 + V_MESSAGE]
        JUMP   button_drawn
button_rename: CMPI R3, 2               ; Rename, type the new name, again cancels
        JZ     button_drawn
        LOAD   R1, [R13 + V_COUNT]
        CMPI   R1, 0x0000
        JZ     button_drawn
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JNZ    button_drawn
        LOAD   R1, [R13 + V_CHOSEN]
        CALL   entry_of
        ADDI   R2, R13, V_TYPED
        CALL   text_copy
        LOADLO R1, 2
        STORE  R1, [R13 + V_MODE]
        JUMP   button_drawn
button_folder: CMPI R3, 3               ; Folder, type a new folder name, again cancels
        JZ     button_drawn
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JNZ    button_drawn
        STOREB R0, [R13 + V_TYPED]
        LOADLO R1, 3
        STORE  R1, [R13 + V_MODE]
button_drawn: LOAD R1, [R13 + V_WINDOW]
        CALLF  WM_REDRAW
button_done: POP R13
        RET

; paint, path row, then the list or the text, then the message row
; R12 = row, R11 = entry or text pointer, R10 = rows, R9 = canvas width
paint:  PUSH   R13
        PUSH   R12
        PUSH   R11
        PUSH   R10
        PUSH   R9
        LA     R13, vars
        LOAD   R1, [R13 + V_WINDOW]
        CALLF  WM_SIZE
        MOV    R9, R1
        SHIFTI R10, R2, 0x04, 0b1000
        LOADLO R1, 0                    ; white canvas
        LOADLO R2, 0
        MOV    R3, R9
        SHIFTI R4, R10, 0x04, 0b0000
        LOADLO R5, 0x0F
        CALLF  WM_BOX
        LOADLO R1, 0                    ; folder path on a navy row
        LOADLO R2, 0
        MOV    R3, R9
        LOADLO R4, ROW
        LOADLO R5, 0x38
        CALLF  WM_BOX
        LOAD   R3, [R13 + V_TEXT]       ; showing a text, its path instead
        ADDI   R3, R13, V_PATH
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JZ     paint_path
        ADDI   R3, R13, V_FULL
paint_path: LOADLO R1, 4
        LOADLO R2, 0
        LOADLO R4, 0x0F
        CALLF  WM_TEXT
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JNZ    paint_text
        LOADLO R12, 0                   ; list, rows 1 to rows - 2
paint_entry: ADDI R1, R12, 2
        CMP    R1, R10
        JC     paint_message
        LOAD   R11, [R13 + V_TOP]
        ADD    R11, R11, R12
        LOAD   R1, [R13 + V_COUNT]
        CMP    R11, R1
        JC     paint_message
        LOAD   R1, [R13 + V_CHOSEN]     ; chosen one highlighted, sky blue
        CMP    R1, R11
        JNZ    paint_entry_text
        LOADLO R1, 0
        ADDI   R2, R12, 1
        SHIFTI R2, R2, 0x04, 0b0000
        MOV    R3, R9
        LOADLO R4, ROW
        LOADLO R5, 0x4C
        CALLF  WM_BOX
paint_entry_text: MOV R1, R11
        CALL   entry_of
        MOV    R11, R1
        LOADLO R1, 8                    ; name, a folder in navy
        ADDI   R2, R12, 1
        SHIFTI R2, R2, 0x04, 0b0000
        MOV    R3, R11
        LOADLO R4, 0x00
        LOADB  R5, [R11 + 13]
        CMPI   R5, 0x0000
        JZ     paint_name
        LOADLO R4, 0x38
paint_name: PUSH R2
        CALLF  WM_TEXT
        POP    R2
        LOADB  R5, [R11 + 13]
        CMPI   R5, 0x0000
        JZ     paint_size
        MOV    R1, R11                  ; folder, "/" right after its name
        LOADLO R4, 0
paint_mark_count: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     paint_mark
        INC    R1
        INC    R4
        JUMP   paint_mark_count
paint_mark: SHIFTI R1, R4, 0x03, 0b0000
        ADDI   R1, R1, 8
        LA     R3, folder_mark
        LOADLO R4, 0x38
        CALLF  WM_TEXT
        JUMP   paint_entry_next
paint_size: PUSH R2                     ; file, size at the right
        LOAD   R1, [R11 + 16]
        ADDI   R2, R13, V_NUMBER
        CALLF  WM_NUMBER
        POP    R2
        SUBI   R1, R9, 96
        ADDI   R3, R13, V_NUMBER
        LOADLO R4, 0xF1
        CALLF  WM_TEXT
paint_entry_next: INC R12
        JUMP   paint_entry
paint_text: LOAD R11, [R13 + V_TEXT]    ; text from line V_LINE, a row each
        LOAD   R12, [R13 + V_LINE]
paint_skip_line: CMPI R12, 0x0000       ; find that line
        JZ     paint_text_rows
        LOAD   R1, [R13 + V_TEXT_END]
        CMP    R11, R1
        JC     paint_message
        LOADB  R1, [R11]
        INC    R11
        CMPI   R1, 0x000A
        JNZ    paint_skip_line
        DEC    R12
        JUMP   paint_skip_line
paint_text_rows: LOADLO R12, 1
paint_text_row: ADDI R1, R12, 1
        CMP    R1, R10
        JC     paint_message
        LOAD   R1, [R13 + V_TEXT_END]
        CMP    R11, R1
        JC     paint_message
        ADDI   R2, R13, V_FULL + 48     ; copy the line into the second half of V_FULL
        SHIFTI R6, R9, 0x03, 0b1000     ; at most the canvas width and 47 letters
        CMPI   R6, 47
        JNC    paint_line_copy
        LOADLO R6, 47
paint_line_copy: LOAD R1, [R13 + V_TEXT_END]
        CMP    R11, R1
        JC     paint_line_end
        LOADB  R1, [R11]
        INC    R11
        CMPI   R1, 0x000A
        JZ     paint_line_end
        CMPI   R1, 0x000D
        JZ     paint_line_copy
        CMPI   R6, 0x0000
        JZ     paint_line_copy          ; past the width, skipped
        STOREB R1, [R2]
        INC    R2
        DEC    R6
        JUMP   paint_line_copy
paint_line_end: STOREB R0, [R2]
        LOADLO R1, 4
        SHIFTI R2, R12, 0x04, 0b0000
        ADDI   R3, R13, V_FULL + 48
        LOADLO R4, 0x00
        CALLF  WM_TEXT
        INC    R12
        JUMP   paint_text_row
paint_message: LOAD R1, [R13 + V_MODE]  ; typing, "new name: ..._" on the last row
        CMPI   R1, 2
        JNC    paint_message_plain
        LA     R1, new_name_text
        LOAD   R2, [R13 + V_MODE]
        CMPI   R2, 2
        JZ     paint_typing
        LA     R1, new_folder_text
paint_typing: ADDI R2, R13, V_SHOW
        CALL   text_copy
        ADDI   R1, R13, V_TYPED
        CALL   text_copy
        LOADLO R1, 0x005F
        STOREB R1, [R2]
        STOREB R0, [R2 + 1]
        ADDI   R3, R13, V_SHOW
        JUMP   paint_message_text
paint_message_plain: LOAD R3, [R13 + V_MESSAGE]   ; message or key help on the last row
        CMPI   R3, 0x0000
        JNZ    paint_message_text
        LA     R3, keys_text
        LOAD   R1, [R13 + V_TEXT]
        CMPI   R1, 0x0000
        JZ     paint_message_text
        LA     R3, text_keys_text
paint_message_text: LOADLO R1, 4
        SUBI   R2, R10, 1
        SHIFTI R2, R2, 0x04, 0b0000
        LOADLO R4, 0x38
        CALLF  WM_TEXT
        POP    R9
        POP    R10
        POP    R11
        POP    R12
        POP    R13
        RET

; tick, nothing, close, back to the list
tick:   RET
close:  PUSH   R13
        LA     R13, vars
        CALL   close_text
        POP    R13
        RET

apps_prefix:      .string "/apps/"
txt_end:          .string ".txt"
pic_end:          .string ".pic"
bin_end:          .string ".bin"
folder_mark:      .string "/"
not_folder_text:  .string "(that folder can't be read)"
bin_text:         .string "a program: run it from the shell (Esc, then: run NAME)"
unknown_text:     .string "Files doesn't know how to open that"
app_opened_text:  .string "its app's window is open"
no_app_text:      .string "that app isn't on the desktop (apps.txt)"
wallpaper_text:   .string "it's the wallpaper now"
bad_picture_text: .string "that picture couldn't be shown"
keys_text:        .string "choose: click, arrows  open: Enter  up: Bksp"
sure_text:        .string "sure? press Delete again to delete it"
deleted_text:     .string "deleted"
not_deleted_text: .string "couldn't delete it (a folder must be empty)"
new_name_text:    .string "new name: "
new_folder_text:  .string "new folder: "
renamed_text:     .string "renamed"
folder_made_text: .string "folder made"
failed_text:      .string "couldn't do that (is the name taken?)"
text_keys_text:   .string "scroll: arrows, PgUp, PgDn  back: Bksp"
vars:   .word 0                         ; 108 words, V_WINDOW to V_NEW
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

.include "sw/apps/lib/text.asm"       ; app library, text_copy, text_lower, number_text, text builder
