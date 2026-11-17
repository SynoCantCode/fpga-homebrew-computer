; mv, cp, rename
; included by shell.asm

; two_names, splits "OLD NEW", in R1 = pointer to the typed words
; out R1 = pointer to OLD, R2 = pointer to NEW or 0, uses R5, R6
two_names: MOV R6, R1
        LOADB  R5, [R6]
        CMPI   R5, 0x0000
        JZ     two_names_none
        CALL   after_word               ; R1 = pointer to the second word
        LOADB  R5, [R1]
        CMPI   R5, 0x0000
        JZ     two_names_none
        MOV    R2, R1
        MOV    R1, R6
        RET
two_names_none: LOADLO R2, 0
        RET

; mv OLD NEW, moves or renames a file or folder
command_mv: CALL two_names
        CMPI   R2, 0x0000
        JZ     two_names_usage
        CALL   file_move
        CMPI   R1, 0x0000
        JNZ    show_fs_error
        RET
two_names_usage: LA R1, two_names_text
        JUMPF  screen_line

; rename OLD NAME, new name in the same folder, NAME has no /
; builds the new path in FS_MOVE_PATH, folder part of OLD + NAME
; refuses a name that is taken, then the kernel moves it
; R8 = pointer to OLD
command_rename: CALL two_names          ; R1 = OLD, R2 = NAME or 0
        CMPI   R2, 0x0000
        JZ     rename_usage
        MOV    R6, R2                   ; NAME must not have a /
rename_check: LOADB R5, [R6]
        CMPI   R5, 0x0000
        JZ     rename_build
        CMPI   R5, 0x0020
        JZ     rename_build
        CMPI   R5, 0x002F
        JZ     rename_usage
        INC    R6
        JUMP   rename_check
rename_build: MOV R6, R1                ; R6 = just after the last / of OLD
        MOV    R3, R1
rename_scan: LOADB R5, [R3]
        CMPI   R5, 0x0000
        JZ     rename_copy_folder
        CMPI   R5, 0x0020
        JZ     rename_copy_folder
        INC    R3
        CMPI   R5, 0x002F
        JNZ    rename_scan
        MOV    R6, R3
        JUMP   rename_scan
rename_copy_folder: LOADLO R4, FS_MOVE_PATH ; FS_MOVE_PATH = OLD up to there
        MOV    R3, R1
rename_folder_next: CMP R3, R6
        JZ     rename_copy_name
        LOADB  R5, [R3]
        STOREB R5, [R4]
        INC    R3
        INC    R4
        JUMP   rename_folder_next
rename_copy_name: LOADB R5, [R2]        ; then NAME
        CMPI   R5, 0x0000
        JZ     rename_go
        CMPI   R5, 0x0020
        JZ     rename_go
        STOREB R5, [R4]
        INC    R2
        INC    R4
        JUMP   rename_copy_name
rename_go: STOREB R0, [R4]
        PUSH   R8
        MOV    R8, R1
        LOADLO R1, FS_MOVE_PATH
        CALLF  fs_find                  ; the new name must not exist
        CMPI   R1, 13
        JZ     rename_do
        CMPI   R1, 0x0000
        JZ     rename_taken
        CMPI   R1, 14
        JNZ    rename_done
rename_taken: LOADLO R1, 23
        JUMP   rename_done
rename_do: MOV R1, R8
        LOADLO R2, FS_MOVE_PATH
        CALL   file_move
rename_done: POP R8
        CMPI   R1, 0x0000
        JNZ    show_fs_error
        RET
rename_usage: LA R1, rename_usage_text
        JUMPF  screen_line

; cp OLD NEW, copies a file
command_cp: CALL two_names
        CMPI   R2, 0x0000
        JZ     two_names_usage
        CALL   file_copy
        CMPI   R1, 0x0000
        JNZ    show_fs_error
        RET
