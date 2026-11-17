; folders, mkdir, touch, rm and the current folder path
; included by shell.asm

; path_update, changes FS_PATH after a cd PATH
; leading / = from the root, . = stay, .. = drop the last part, name = add it in capitals
; in R1 = pointer to the typed path, R8 = pointer into it, R9 = end of FS_PATH
path_update: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADB  R5, [R8]
        CMPI   R5, 0x002F
        JNZ    path_find_end
        STOREB R0, [FS_PATH]            ; leading /, start from the root
        INC    R8
path_find_end: LOADLO R9, FS_PATH
path_end_next: LOADB R5, [R9]
        CMPI   R5, 0x0000
        JZ     path_part
        INC    R9
        JUMP   path_end_next
path_part: LOADB R5, [R8]
        CMPI   R5, 0x0000
        JZ     path_done
        CMPI   R5, 0x0020
        JZ     path_done
        CMPI   R5, 0x002E
        JNZ    path_name
        LOADB  R6, [R8 + 1]             ; starts with a dot, . or ..
        CMPI   R6, 0x002E
        JZ     path_up
        INC    R8                       ; . = stay
        JUMP   path_next
path_up: ADDI R8, R8, 2                 ; .. = drop the last part
path_cut: LOADLO R6, FS_PATH
        CMP    R9, R6
        JZ     path_cut_done            ; nothing left, the root
        DEC    R9
        LOADB  R5, [R9]
        CMPI   R5, 0x002F
        JNZ    path_cut
path_cut_done: STOREB R0, [R9]
        JUMP   path_next
path_name: LOADLO R6, FS_PATH + 0x7E
        CMP    R9, R6
        JC     path_skip                ; FS_PATH full, skip this part
        LOADLO R5, 0x002F
        STOREB R5, [R9]                 ; add the /
        INC    R9
path_char: LOADB R5, [R8]               ; then the name in capitals
        CMPI   R5, 0x0000
        JZ     path_name_done
        CMPI   R5, 0x0020
        JZ     path_name_done
        CMPI   R5, 0x002F
        JZ     path_name_done
        CMPI   R5, 0x0061
        JNC    path_store
        CMPI   R5, 0x007B
        JC     path_store
        SUBI   R5, R5, 0x020
path_store: LOADLO R6, FS_PATH + 0x7F
        CMP    R9, R6
        JC     path_char_next           ; no room, leave it out
        STOREB R5, [R9]
        INC    R9
path_char_next: INC R8
        JUMP   path_char
path_name_done: STOREB R0, [R9]
        JUMP   path_next
path_skip: LOADB R5, [R8]               ; skip a part that doesnt fit
        CMPI   R5, 0x0000
        JZ     path_done
        CMPI   R5, 0x0020
        JZ     path_done
        CMPI   R5, 0x002F
        JZ     path_next
        INC    R8
        JUMP   path_skip
path_next: LOADB R5, [R8]
        CMPI   R5, 0x002F
        JNZ    path_done
        INC    R8                       ; past the /, next part
        JUMP   path_part
path_done: POP R9
        POP    R8
        RET

; mkdir NAME, makes an empty folder, NAME can be a path
command_mkdir: CALL folder_make
        CMPI   R1, 0x0000
        JNZ    show_fs_error            ; tail call
        RET

; touch NAME, makes an empty file if there isnt one, NAME can be a path
; R8 = pointer to the typed name
command_touch: PUSH R8
        MOV    R8, R1
        CALLF  fs_find
        CMPI   R1, 13
        JNZ    touch_there              ; 0 or 14 = already there, else an error
        MOV    R1, R8
        LOADLO R2, 0
        LOADLO R3, 0
        CALL   file_write               ; new file, 0 bytes
touch_there: POP R8
        CMPI   R1, 0x0000
        JZ     touch_done
        CMPI   R1, 14
        JZ     touch_done
        JUMP   show_fs_error
touch_done: RET

; rm NAME, deletes a file or an empty folder, NAME can be a path
command_rm: CALL file_delete
        CMPI   R1, 0x0000
        JNZ    show_fs_error
        RET
