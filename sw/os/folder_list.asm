; folder_list.asm, reading a folder for any program
; entries copied into the programs memory, 32 bytes each, as the card keeps them
; programs reach it through KERNEL_CALLS + 0
; LOAD R5, [KERNEL_CALLS]  then  CALLR R5
;
; a folder line, 32 bytes, FAT32: bytes 0-7 name, 8-10 type, padded with spaces
; 11 kind (0x10 folder, 0x20 file), 20-21 and 26-27 first cluster, 28-31 size
; left out: deleted lines (0xE5), . and .., long name pieces (0x0F), card name (0x08)
; first byte 0 = end of the folder

; folder_list, a folders entries into memory
; in R1 = pointer to path, R2 = where they go, R3 = room for how many
; out R1 = how many copied, or -1 if not a folder
; R8 cluster, R9 block, R10 blocks left, R11 next place, R12 count, R13 room left
folder_list: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        MOV    R11, R2
        MOV    R13, R3
        LOADLO R12, 0
        CALLF  file_size                ; 14 = a folder, first cluster in FS_FILE_CLUSTER
        CMPI   R1, 14
        JZ     n_list_folder
        NOT    R12, R0                  ; not a folder, -1
        JUMP   n_list_end
n_list_folder: LOAD R8, [FS_FILE_CLUSTER]
        CMPI   R8, 0x0000
        JNZ    n_list_cluster
        LOAD   R8, [FS_ROOT_CLUSTER]    ; cluster 0 means the root
n_list_cluster: MOV R1, R8
        CALLF  cluster_block
        MOV    R9, R1
        LOAD   R10, [FS_SECTORS_PER_CLUSTER]
n_list_block: MOV R1, R9
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    n_list_end
        LOADLO R6, DISK_BUFFER
n_list_line: LOADB R1, [R6]
        CMPI   R1, 0x0000
        JZ     n_list_end               ; end of the folder
        CMPI   R1, 0x00E5
        JZ     n_list_next              ; deleted
        CMPI   R1, 0x002E
        JZ     n_list_next              ; . and ..
        LOADB  R2, [R6 + 11]
        CMPI   R2, 0x000F
        JZ     n_list_next              ; piece of a long name
        ANDI   R2, R2, 0x0008
        JNZ    n_list_next              ; the cards own name
        CMPI   R13, 0x0000
        JZ     n_list_end               ; no room for more
        LOADLO R7, 0                    ; copy the line, 32 bytes
n_list_copy: ADD R1, R6, R7
        LOADB  R1, [R1]
        ADD    R2, R11, R7
        STOREB R1, [R2]
        INC    R7
        CMPI   R7, 32
        JNZ    n_list_copy
        ADDI   R11, R11, 32
        INC    R12
        DEC    R13
n_list_next: ADDI R6, R6, 32
        CMPI   R6, DISK_BUFFER + 512
        JNZ    n_list_line
        INC    R9                       ; next block of the cluster
        DEC    R10
        CMPI   R10, 0x0000
        JNZ    n_list_block
        MOV    R1, R8                   ; or the next cluster from the FAT
        CALLF  fat_next
        MOV    R8, R1
        CMPI   R8, 0x0000
        JNZ    n_list_cluster
n_list_end: MOV R1, R12
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET
