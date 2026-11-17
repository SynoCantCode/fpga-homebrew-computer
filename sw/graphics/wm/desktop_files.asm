; wm desktop files, whatever is in /DESKTOP shows as an icon
; included by programs/wm.asm
; each file or folder gets a record in apps, A_KIND says what it is
; ITEM_TEXT     .TXT .ASM .MD    floppy icon, opens in edit.bin
; ITEM_PROGRAM  .BIN             terminal icon, the shell runs it
; ITEM_FOLDER   a folder         folder icon, opens Files
; ITEM_FILE     anything else    floppy icon, opens Files
; the kernel lists the folder, 32 bytes an entry

; desktop_files, makes a desktop item of everything in /DESKTOP
; folder_list is KERNEL_CALLS + 0, entries are 32 bytes each
; R10 = how many, R11 = pointer to the entry, R12 = the list
desktop_files: PUSH R10
        PUSH   R11
        PUSH   R12
        LOAD   R5, [KERNEL_CALLS]       ; 0 = no folder_list, no desktop files
        CMPI   R5, 0x0000
        JZ     desk_files_end
        LOADLO R1, 0x0400               ; room for APPS_MAX x 32 bytes
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     desk_files_end
        MOV    R12, R1
        LA     R1, desktop_path
        MOV    R2, R12
        LOADLO R3, APPS_MAX
        LOAD   R5, [KERNEL_CALLS]
        CALLR  R5                       ; R1 = how many, -1 = no /DESKTOP
        MOV    R10, R1
        MOV    R11, R12
desk_files_next: CMPIS R10, 0
        JZ     desk_files_free
        JGE    desk_files_one
        JUMP   desk_files_free
desk_files_one: CALL desk_item
        ADDI   R11, R11, 32
        DEC    R10
        JUMP   desk_files_next
desk_files_free: MOV R1, R12
        CALLF  FREE
desk_files_end: POP R12
        POP    R11
        POP    R10
        RET

; desk_item, makes one folder entry a desktop item
; name in small letters like "notes.txt", 16 bytes from the heap
; in R11 = the entry. R8 = its record, R9 = its number, R10 = the name
desk_item: LOAD R1, [app_count]
        CMPI   R1, APPS_MAX
        JNZ    desk_item_room
        RET                             ; table is full
desk_item_room: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R12
        MOV    R9, R1
        CALL   app_record
        MOV    R8, R1
        LOADLO R1, 16
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     desk_item_end
        MOV    R10, R1
        MOV    R2, R10                  ; name, up to 8 letters, spaces left out
        LOADLO R5, 0
desk_name: ADD R4, R11, R5
        LOADB  R1, [R4]
        CALL   text_lower
        CMPI   R1, 0x0020
        JZ     desk_name_next
        STOREB R1, [R2]
        INC    R2
desk_name_next: INC R5
        CMPI   R5, 8
        JNZ    desk_name
        LOADB  R1, [R11 + 8]            ; then "." and its type, if any
        CMPI   R1, 0x0020
        JZ     desk_name_end
        LOADLO R1, 0x002E
        STOREB R1, [R2]
        INC    R2
desk_type: ADD R4, R11, R5
        LOADB  R1, [R4]
        CALL   text_lower
        CMPI   R1, 0x0020
        JZ     desk_type_next
        STOREB R1, [R2]
        INC    R2
desk_type_next: INC R5
        CMPI   R5, 11
        JNZ    desk_type
desk_name_end: STOREB R0, [R2]
        STORE  R10, [R8 + W_NAME]       ; its record, on the desktop, white label
        STORE  R10, [R8 + W_TITLE]      ; not opened at the start
        LOADLO R1, 1
        STORE  R1, [R8 + W_ICON]
        STORE  R1, [R8 + A_HIDDEN]
        LOADLO R1, WHITE_DOT
        STORE  R1, [R8 + A_LABEL]
        CALL   desk_kind                ; R1 = its kind, R2 = its icon file name
        STORE  R1, [R8 + A_KIND]
        STORE  R2, [R8 + W_ICON_NAME]
        MOV    R12, R9                  ; its icon, R8 = record, R12 = number
        CALL   load_icon
        INC    R9
        STORE  R9, [app_count]
desk_item_end: POP R12
        POP    R10
        POP    R9
        POP    R8
        RET

; desk_kind, in R11 = the entry, out R1 = ITEM_FOLDER, ITEM_PROGRAM, ITEM_TEXT or ITEM_FILE
; R2 = pointer to its icon sprite name, uses R3, R4
desk_kind: LOADB R1, [R11 + 11]
        ANDI   R1, R1, 0x0010
        JZ     desk_kind_file
        LOADLO R1, ITEM_FOLDER
        LA     R2, folder_icon_name
        RET
desk_kind_file: LOADB R3, [R11 + 8]     ; its type, 3 letters as one number, "BIN" = 0x42494E
        SHIFTI R3, R3, 0x10, 0b0000
        LOADB  R4, [R11 + 9]
        SHIFTI R4, R4, 0x08, 0b0000
        OR     R3, R3, R4
        LOADB  R4, [R11 + 10]
        OR     R3, R3, R4
        LOADLO R1, ITEM_PROGRAM
        LA     R2, program_icon_name
        LOADHI R4, 0x0042               ; "BIN"
        ORI    R4, R4, 0x494E
        CMP    R3, R4
        JZ     desk_kind_done
        LOADLO R1, ITEM_TEXT
        LA     R2, text_icon_name
        LOADHI R4, 0x0054               ; "TXT"
        ORI    R4, R4, 0x5854
        CMP    R3, R4
        JZ     desk_kind_done
        LOADHI R4, 0x0041               ; "ASM"
        ORI    R4, R4, 0x534D
        CMP    R3, R4
        JZ     desk_kind_done
        LOADHI R4, 0x004D               ; "MD "
        ORI    R4, R4, 0x4420
        CMP    R3, R4
        JZ     desk_kind_done
        LOADLO R1, ITEM_FILE            ; anything else
desk_kind_done: RET

; open_item, opens a desktop file
; text in the editor, program run, WM ends and "run /wm.bin" brings it back
; folder or anything else opens Files. in R1 = its number
open_item: PUSH R1                      ; keep its number, note_for wants it in R2
        CALL   app_record
        LOAD   R1, [R1 + A_KIND]
        POP    R2
        CMPI   R1, ITEM_TEXT
        JZ     open_text
        CMPI   R1, ITEM_PROGRAM
        JZ     open_program
open_in_files: LA R1, files_name        ; folder or anything else, Files
        CALL   find_app_number
        CMPIS  R1, -1
        JZ     open_item_done
        JUMP   launch_app
open_text: LA  R3, run_edit_desk_text   ; "run /edit.bin /desktop/NAME"
        LA     R4, nothing_text
        JUMP   note_for
open_program: LA R3, run_desk_text      ; "run /desktop/NAME"
        LA     R4, nothing_text
        JUMP   note_for
open_item_done: RET

; item_menu, right-click menu of a desktop file
; Open or Run, Remove icon, Show in Files for a text or program
; in R10 = its number, uses R1-R7
item_menu: MOV R1, R10
        CALL   app_record
        LOAD   R4, [R1 + A_KIND]
        LA     R1, menu_open_text
        CMPI   R4, ITEM_PROGRAM
        JNZ    item_menu_open
        LA     R1, menu_run_text
item_menu_open: PUSH R4
        LOADLO R2, MENU_OPEN
        MOV    R3, R10
        CALL   menu_add
        LA     R1, menu_remove_text
        LOADLO R2, MENU_REMOVE
        MOV    R3, R10
        CALL   menu_add
        POP    R4
        CMPI   R4, ITEM_FOLDER
        JZ     item_menu_done
        CMPI   R4, ITEM_FILE
        JZ     item_menu_done
        LA     R1, menu_show_files_text
        LOADLO R2, MENU_APP
        LA     R3, files_name
        CALL   menu_add
item_menu_done: RET
