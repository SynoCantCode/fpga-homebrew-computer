; FS, the file system, reads FAT32 files from the SD card
; the card is laid out in 4 regions
; block 0: the partition table, FAT32 part starts at block N (4 bytes at 0x1C6)
; block N: the boot record, the FAT32 settings
; then:    the FAT, one 4 byte number per cluster, the next cluster or the end
; then:    the data area, files and folder lists in clusters
; a folder is a list of 32 byte entries, name (8 + 3 letters), kind, first cluster, size
; name byte 0x00 = end of the list, 0xE5 = deleted
; fs_mount reads the partition table and boot record once
; results in FS_PARTITION_START, FS_FAT_START, FS_DATA_START, FS_ROOT_CLUSTER, FS_STATE
; the kernel reads into its own DISK_BUFFER (0x4400 - 0x45FF)
; inputs R1-R4, answer in R1, may wreck R1-R7, keeps R8-R14
; error numbers, 0 = all right, 1-9 = the SD driver (sd.asm)
; 10 = block 0 is no partition table or boot record, 11 = not FAT32
; 12 = bad file name, 13 = no such file, 14 = a folder, not a file
; 15 = FAT chain ended before the file did, 16 = write refused
; 17 = not a program (.BIN only), 18 = program too big
; 19 = card full, 20 = folder full, 21 = a file where a folder was expected
; 22 = a folder in the path is missing, 23 = name taken, 24 = can not be moved there
; 25 = not enough memory to copy, 26 = folder not empty
; 27 = can not be deleted (root, "." or "..", current folder)
; names can be paths, "games/snake.txt", or "/games/snake.txt" from the root
; ".." = folder above, "." = this one

; read_u16 / read_u32, read a 2 or 4 byte number, lowest byte first
; one byte at a time, the address need not be a multiple of 4
; in R1 = pointer to the lowest byte, out R1 = the number, uses R5, R6
read_u16: LOADB R5, [R1]                ; low byte
        LOADB  R6, [R1 + 1]             ; high byte
        SHIFTI R6, R6, 0x08, 0b0000     ; up 8 bits
        OR     R1, R5, R6
        RET
read_u32: LOADB R5, [R1 + 3]            ; from the highest byte down, shift up 8, add the next
        LOADB  R6, [R1 + 2]
        SHIFTI R5, R5, 0x08, 0b0000
        OR     R5, R5, R6
        LOADB  R6, [R1 + 1]
        SHIFTI R5, R5, 0x08, 0b0000
        OR     R5, R5, R6
        LOADB  R6, [R1]
        SHIFTI R5, R5, 0x08, 0b0000
        OR     R1, R5, R6
        RET

; is_fat32_boot_record, "FAT32" at byte 0x52 of DISK_BUFFER
; out R1 = 1 if it is, 0 if not, uses R5
is_fat32_boot_record: LOADLO R1, 0x0000
        LOADB  R5, [DISK_BUFFER + 0x52]
        CMPI   R5, 0x0046               ; 'F'
        JNZ    boot_record_done
        LOADB  R5, [DISK_BUFFER + 0x53]
        CMPI   R5, 0x0041               ; 'A'
        JNZ    boot_record_done
        LOADB  R5, [DISK_BUFFER + 0x54]
        CMPI   R5, 0x0054               ; 'T'
        JNZ    boot_record_done
        LOADB  R5, [DISK_BUFFER + 0x55]
        CMPI   R5, 0x0033               ; '3'
        JNZ    boot_record_done
        LOADB  R5, [DISK_BUFFER + 0x56]
        CMPI   R5, 0x0032               ; '2'
        JNZ    boot_record_done
        LOADLO R1, 0x0001
boot_record_done: RET

; fs_mount, finds the FAT32 part of the card, wakes the SD card first if needed
; out R1 = 0 or an error number, R8 = partition first block, R9 = FAT first block
fs_mount: PUSH R8
        PUSH   R9
        STORE  R0, [FS_STATE]           ; not mounted until this succeeds
        LOAD   R5, [SD_STATE]
        CMPI   R5, 0x0000
        JNZ    mount_read               ; SD card already awake
        CALL   sd_init
        CMPI   R1, 0x0000
        JNZ    mount_end                ; SD driver error number
mount_read: LOADLO R1, 0                ; block 0
        LOADLO R2, DISK_BUFFER          ; into the disk buffer
        CALL   sd_read_block
        CMPI   R1, 0x0000
        JNZ    mount_end
        LOADLO R8, 0                    ; R8 = partition first block, 0 if block 0 is the boot record
        CALL   is_fat32_boot_record     ; some cards have no partition table
        CMPI   R1, 0x0001
        JZ     mount_settings
        LOADB  R5, [DISK_BUFFER + 0x1FE] ; a partition table ends 55 AA
        CMPI   R5, 0x0055
        JNZ    mount_not_a_disk
        LOADB  R5, [DISK_BUFFER + 0x1FF]
        CMPI   R5, 0x00AA
        JNZ    mount_not_a_disk
        LOADLO R1, DISK_BUFFER + 0x1C6  ; first partition start block, 4 bytes at 0x1C6
        CALL   read_u32
        MOV    R8, R1
        LOADLO R2, DISK_BUFFER          ; read its boot record
        CALL   sd_read_block
        CMPI   R1, 0x0000
        JNZ    mount_end
        CALL   is_fat32_boot_record
        CMPI   R1, 0x0001
        JNZ    mount_not_fat32

; boot record is in DISK_BUFFER, work out where the FAT and data area start
mount_settings: STORE R8, [FS_PARTITION_START]
        LOADB  R1, [DISK_BUFFER + 0x0D] ; blocks per cluster, 1 byte
        STORE  R1, [FS_SECTORS_PER_CLUSTER]
        LOADLO R1, DISK_BUFFER + 0x0E   ; reserved blocks before the FAT, 2 bytes
        CALL   read_u16
        ADD    R9, R8, R1               ; R9 = FAT first block
        STORE  R9, [FS_FAT_START]
        LOADLO R1, DISK_BUFFER + 0x24   ; blocks in one FAT, 4 bytes
        CALL   read_u32
        STORE  R1, [FS_FAT_SIZE]
        LOADB  R5, [DISK_BUFFER + 0x10] ; how many FATs, usually 2
        STORE  R5, [FS_FAT_COUNT]
        MUL    R1, R1, R5
        ADD    R1, R1, R9               ; data area starts after all the FATs
        STORE  R1, [FS_DATA_START]
        MOV    R9, R1                   ; R9 = data area first block
        LOADLO R1, DISK_BUFFER + 0x20   ; blocks in the FAT32 part, 4 bytes
        CALL   read_u32
        ADD    R1, R1, R8               ; first block after the FAT32 part
        SUB    R1, R1, R9               ; R1 = blocks in the data area
        LOAD   R5, [FS_SECTORS_PER_CLUSTER]
        CMPI   R5, 0x0000
        JZ     mount_not_fat32          ; 0 blocks per cluster, broken settings
        DIVU   R1, R1, R5               ; R1 = clusters in the data area
        INC    R1                       ; numbered from 2, so the last one is + 1
        STORE  R1, [FS_LAST_CLUSTER]
        LOADLO R1, DISK_BUFFER + 0x2C   ; root folder first cluster, 4 bytes
        CALL   read_u32
        STORE  R1, [FS_ROOT_CLUSTER]
        STORE  R1, [FS_CURRENT_CLUSTER] ; current folder = the root
        STOREB R0, [FS_PATH]            ; its path = ""
        LOADLO R1, 0x0001
        STORE  R1, [FS_STATE]           ; mounted
        LOADLO R1, 0                    ; all right
        JUMP   mount_end
mount_not_a_disk: LOADLO R1, 10
        JUMP   mount_end
mount_not_fat32: LOADLO R1, 11
mount_end: POP R9
        POP    R8
        RET

; cluster_block, in R1 = cluster number, out R1 = its first block
; block = FS_DATA_START + (cluster - 2) x blocks per cluster, uses R5
cluster_block: SUBI R1, R1, 2
        LOAD   R5, [FS_SECTORS_PER_CLUSTER]
        MUL    R1, R1, R5
        LOAD   R5, [FS_DATA_START]
        ADD    R1, R1, R5
        RET

; fat_next, looks up the next cluster in the FAT
; in R1 = cluster number, out R1 = next cluster, or 0 at the end or on a read error
; 4 byte entry per cluster, 128 to a block, block = FS_FAT_START + cluster / 128
; at byte (cluster mod 128) x 4, read into DISK_BUFFER
; R8 = where the entry is in the block
fat_next: PUSH R8
        ANDI   R8, R1, 0x007F           ; cluster mod 128
        SHIFTI R8, R8, 0x02, 0b0000     ; x 4, R8 = entry byte in the block
        SHIFTI R1, R1, 0x07, 0b1000     ; cluster / 128
        LOAD   R5, [FS_FAT_START]
        ADD    R1, R1, R5               ; R1 = the FAT block
        LOADLO R2, DISK_BUFFER
        CALL   sd_read_block
        CMPI   R1, 0x0000
        JNZ    fat_next_end
        ADDIW  R8, R8, DISK_BUFFER      ; DISK_BUFFER is too big for ADDI
        LOAD   R1, [R8]                 ; the entry
        LOADHI R5, 0x0FFF
        ORI    R5, R5, 0xFFFF
        AND    R1, R1, R5               ; FAT32 uses the bottom 28 bits
        LOADHI R5, 0x0FFF
        ORI    R5, R5, 0xFFF8
        CMP    R1, R5
        JC     fat_next_end_mark        ; 0x0FFF_FFF8 or above, end of the chain
        CMPI   R1, 0x0002
        JNC    fat_next_end_mark        ; below 2, damaged chain, treat as the end
        POP    R8
        RET
fat_next_end: LOADLO R1, 0
fat_next_end_mark: LOADLO R1, 0
        POP    R8
        RET

;---- finding a file by its name, and reading it ----

; fs_name, one part of a path into the 11 byte card form in FS_NAME, "text.txt" -> "TEXT    TXT"
; 8 letters name, 3 ending, capitals, padded with spaces, no dot
; "." and ".." stay as they are
; in R1 = pointer to the part, it ends with a /, a space or a 0
; out R1 = 0 or 12 (bad name), R2 = pointer to the character that ended the part, uses R3-R6
; R2 = where the next letter goes, R3 = first byte it may not go to
; R4 = 1 once the dot has been seen
fs_name: LOADB R5, [R1]
        CMPI   R5, 0x002E
        JNZ    fs_name_normal
        ADDI   R2, R1, 1                ; starts with a dot, is it "." or ".."?
        LOADB  R6, [R2]
        CMPI   R6, 0x002E
        JNZ    fs_name_dots_end
        ADDI   R2, R2, 1
        LOADB  R6, [R2]
fs_name_dots_end: CMPI R6, 0x0000       ; the part must end right after the dots
        JZ     fs_name_dots
        CMPI   R6, 0x0020
        JZ     fs_name_dots
        CMPI   R6, 0x002F
        JNZ    fs_name_normal           ; something else follows, a normal name
fs_name_dots: SUB R4, R2, R1            ; R4 = how many dots
        LOADLO R3, FS_NAME
        LOADLO R5, 0x0020
        LOADLO R6, 11
fs_name_dots_blank: STOREB R5, [R3]
        INC    R3
        DEC    R6, 0b0100
        JNZ    fs_name_dots_blank
        LOADLO R5, 0x002E
        STOREB R5, [FS_NAME]            ; "."
        CMPI   R4, 0x0002
        JNZ    fs_name_dots_done
        STOREB R5, [FS_NAME + 1]        ; ".."
fs_name_dots_done: LOADLO R1, 0
        RET
fs_name_normal: LOADLO R2, FS_NAME
        LOADLO R5, 0x0020               ; a space
        LOADLO R6, 11
fs_name_blank: STOREB R5, [R2]          ; fill all 11 bytes with spaces
        INC    R2
        DEC    R6, 0b0100
        JNZ    fs_name_blank
        LOADLO R2, FS_NAME              ; name part, FS_NAME + 0 to + 7
        LOADLO R3, FS_NAME + 8
        LOADLO R4, 0
fs_name_next: LOADB R5, [R1]            ; R5 = next typed character
        CMPI   R5, 0x0000
        JZ     fs_name_end
        CMPI   R5, 0x0020
        JZ     fs_name_end
        CMPI   R5, 0x002F
        JZ     fs_name_end              ; '/', the next part starts after it
        INC    R1
        CMPI   R5, 0x002E               ; '.'
        JNZ    fs_name_letter
        CMPI   R4, 0x0000
        JNZ    fs_name_bad              ; a second dot
        LOADLO R4, 1
        LOADLO R2, FS_NAME + 8          ; ending part, FS_NAME + 8 to + 10
        LOADLO R3, FS_NAME + 11
        JUMP   fs_name_next
fs_name_letter: CMPI R5, 0x0061         ; 'a'
        JNC    fs_name_store            ; below 'a', keep it
        CMPI   R5, 0x007B               ; just past 'z'
        JC     fs_name_store            ; past 'z', keep it
        SUBI   R5, R5, 0x020            ; small letter to capital
fs_name_store: CMP R2, R3
        JC     fs_name_bad              ; this part already has all its letters
        STOREB R5, [R2]
        INC    R2
        JUMP   fs_name_next
fs_name_end: LOADB R5, [FS_NAME]
        CMPI   R5, 0x0020
        JZ     fs_name_bad              ; nothing before the dot
        MOV    R2, R1                   ; where the part ended
        LOADLO R1, 0
        RET
fs_name_bad: LOADLO R1, 12
        RET

; name_matches, do all 11 bytes of the line name match FS_NAME
; in R1 = pointer to a 32 byte folder line, out R1 = 1 match, else 0, uses R2, R5, R6, R7
name_matches: LOADLO R2, FS_NAME
        LOADLO R7, 11                   ; R7 = bytes still to compare
name_matches_next: LOADB R5, [R1]
        LOADB  R6, [R2]
        CMP    R5, R6
        JNZ    name_matches_no
        INC    R1
        INC    R2
        DEC    R7, 0b0100
        JNZ    name_matches_next
        LOADLO R1, 1
        RET
name_matches_no: LOADLO R1, 0
        RET

; fs_find, looks for a file or folder by its path, mounts the card if needed
; starts in the current folder, or in the root if the path starts with /
; "." and ".." in the root mean the root itself
; in R1 = pointer to the path, out R1 = 0 a file, 14 a folder, 13 last part not there
; or 12 bad name, 21 a file in the middle of the path, 22 a folder in the path is missing
; found: FS_FILE_CLUSTER = first cluster, FS_FILE_SIZE = size, FS_LINE_BLOCK / _OFFSET = its line
; always: FS_FOLDER_CLUSTER = folder searched last, FS_FOLDER_LAST = its last cluster
; FS_FREE_BLOCK / FS_FREE_OFFSET = its first free line, or NOTHING
; R8 = folder cluster, R9 = block, R10 = blocks left in the cluster, then the line kind
; R11 = pointer to the line, R12 = pointer into the path
fs_find: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        MOV    R12, R1
        LOAD   R5, [FS_STATE]
        CMPI   R5, 0x0000
        JNZ    fs_find_mounted
        CALL   fs_mount                 ; not mounted yet
        CMPI   R1, 0x0000
        JNZ    fs_find_end
fs_find_mounted: LOAD R8, [FS_CURRENT_CLUSTER]
        LOADB  R5, [R12]
        CMPI   R5, 0x002F
        JNZ    fs_find_part             ; no / at the start, from the current folder
        LOAD   R8, [FS_ROOT_CLUSTER]    ; / at the start, from the root
        INC    R12
        LOADB  R5, [R12]
        CMPI   R5, 0x0000
        JZ     fs_find_is_root          ; just "/", the root itself
        CMPI   R5, 0x0020
        JZ     fs_find_is_root
fs_find_part: STORE R8, [FS_FOLDER_CLUSTER]
        MOV    R1, R12
        CALL   fs_name                  ; this part in card form, in FS_NAME
        CMPI   R1, 0x0000
        JNZ    fs_find_end
        MOV    R12, R2                  ; R12 = where the part ended
        LOAD   R5, [FS_ROOT_CLUSTER]
        CMP    R8, R5
        JNZ    fs_find_search
        LOADB  R5, [FS_NAME]
        CMPI   R5, 0x002E
        JNZ    fs_find_search           ; "." or ".." in the root
fs_find_is_root: LOAD R5, [FS_ROOT_CLUSTER]
        STORE  R5, [FS_FILE_CLUSTER]
        LOADLO R1, 14                   ; a folder, the root
        JUMP   fs_find_next_part
fs_find_search: LOADHI R5, 0xFFFF
        ORI    R5, R5, 0xFFFF
        STORE  R5, [FS_FREE_BLOCK]      ; no free line seen yet
fs_find_cluster: STORE R8, [FS_FOLDER_LAST]
        MOV    R1, R8
        CALL   cluster_block
        MOV    R9, R1                   ; first block of the cluster
        LOAD   R10, [FS_SECTORS_PER_CLUSTER]
fs_find_block: MOV R1, R9
        LOADLO R2, DISK_BUFFER
        CALL   sd_read_block            ; one block of the folder list, 16 lines
        CMPI   R1, 0x0000
        JNZ    fs_find_end
        LOADLO R11, DISK_BUFFER
fs_find_line: LOADB R5, [R11]           ; first byte of the name
        CMPI   R5, 0x0000
        JZ     fs_find_end_of_list      ; 0x00, end of the list, no match
        CMPI   R5, 0x00E5
        JZ     fs_find_deleted          ; 0xE5, deleted
        LOADB  R6, [R11 + 11]           ; kind byte
        CMPI   R6, 0x000F
        JZ     fs_find_skip             ; piece of a long name
        ANDI   R6, R6, 0x0008
        JNZ    fs_find_skip             ; the card name
        MOV    R1, R11
        CALL   name_matches
        CMPI   R1, 0x0000
        JNZ    fs_find_found
fs_find_skip: ADDI R11, R11, 32         ; next line
        CMPI   R11, DISK_BUFFER + 512
        JNZ    fs_find_line
        INC    R9                       ; next block of this cluster
        DEC    R10, 0b0100
        JNZ    fs_find_block
        MOV    R1, R8                   ; cluster finished, ask the FAT
        CALL   fat_next
        MOV    R8, R1
        CMPI   R8, 0x0000
        JNZ    fs_find_cluster
        JUMP   fs_find_missing
fs_find_deleted: MOV R1, R9             ; a deleted line is free, remember it
        MOV    R2, R11
        CALL   note_free_line
        JUMP   fs_find_skip
fs_find_end_of_list: MOV R1, R9         ; the end of list line is free too
        MOV    R2, R11
        CALL   note_free_line
fs_find_missing: LOADLO R1, 13          ; no file or folder by that name
        JUMP   fs_find_next_part
fs_find_found: STORE R9, [FS_LINE_BLOCK] ; where its line is
        LOADLO R5, DISK_BUFFER
        SUB    R5, R11, R5
        STORE  R5, [FS_LINE_OFFSET]
        LOADB  R10, [R11 + 11]          ; R10 = its kind
        ADDI   R1, R11, 20              ; first cluster top half, bytes 20-21
        CALL   read_u16
        SHIFTI R8, R1, 0x10, 0b0000     ; up 16 bits
        ADDI   R1, R11, 26              ; bottom half, bytes 26-27
        CALL   read_u16
        OR     R1, R1, R8
        STORE  R1, [FS_FILE_CLUSTER]
        ANDI   R10, R10, 0x0010
        JNZ    fs_find_folder           ; kind bit 4, a folder
        ADDI   R1, R11, 28              ; a file, size in bytes 28-31
        CALL   read_u32
        STORE  R1, [FS_FILE_SIZE]
        LOADLO R1, 0
        JUMP   fs_find_next_part
fs_find_folder: LOAD R5, [FS_FILE_CLUSTER]
        CMPI   R5, 0x0000
        JNZ    fs_find_folder_ok
        LOAD   R5, [FS_ROOT_CLUSTER]    ; a ".." line says cluster 0 for the root
        STORE  R5, [FS_FILE_CLUSTER]
fs_find_folder_ok: LOADLO R1, 14
fs_find_next_part: LOADB R5, [R12]      ; last part of the path?
        CMPI   R5, 0x002F
        JNZ    fs_find_end              ; yes, R1 is the answer
        INC    R12                      ; no, so this one has to be a folder
        CMPI   R1, 14
        JZ     fs_find_into
        CMPI   R1, 13
        JNZ    fs_find_not_folder
        LOADLO R1, 22                   ; a folder in the path is missing
        JUMP   fs_find_end
fs_find_not_folder: LOADLO R1, 21       ; a file in the middle of the path
        JUMP   fs_find_end
fs_find_into: LOAD R8, [FS_FILE_CLUSTER] ; go into it
        LOADB  R5, [R12]
        CMPI   R5, 0x0000
        JZ     fs_find_end              ; path ended with a /, the folder itself
        CMPI   R5, 0x0020
        JZ     fs_find_end
        JUMP   fs_find_part
fs_find_end: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; file_open, finds a file and gets ready to read it from the start
; in R1 = pointer to the name, out R1 = 0 or an error number
file_open: CALL fs_find
        CMPI   R1, 0x0000
        JNZ    file_open_end
        LOAD   R1, [FS_FILE_SIZE]
        STORE  R1, [FS_FILE_LEFT]       ; whole file still to come
        LOAD   R1, [FS_FILE_CLUSTER]
        CALL   cluster_block
        STORE  R1, [FS_FILE_BLOCK]      ; first block of the first cluster
        LOAD   R1, [FS_SECTORS_PER_CLUSTER]
        STORE  R1, [FS_FILE_BLOCKS]
        LOADLO R1, 0
file_open_end: RET

; file_next_block, reads the next block of the open file, all 512 bytes
; in R1 = pointer to 512 bytes of memory
; out R1 = 0 or an error number, R2 = bytes that belong to the file
; 0x200, fewer in the last block, 0 when finished, R8 = the pointer
; asks the FAT for the next cluster when a cluster is used up
file_next_block: PUSH R8
        MOV    R8, R1
        LOADLO R1, 0
        LOADLO R2, 0
        LOAD   R5, [FS_FILE_LEFT]
        CMPI   R5, 0x0000
        JZ     file_next_end            ; file finished
        LOAD   R5, [FS_FILE_BLOCKS]
        CMPI   R5, 0x0000
        JNZ    file_next_read           ; this cluster still has blocks
        LOAD   R1, [FS_FILE_CLUSTER]    ; cluster used up, ask the FAT
        CALL   fat_next
        CMPI   R1, 0x0000
        JZ     file_next_broken         ; chain ended but the size says more
        STORE  R1, [FS_FILE_CLUSTER]
        CALL   cluster_block
        STORE  R1, [FS_FILE_BLOCK]
        LOAD   R1, [FS_SECTORS_PER_CLUSTER]
        STORE  R1, [FS_FILE_BLOCKS]
file_next_read: LOAD R1, [FS_FILE_BLOCK]
        MOV    R2, R8
        CALL   sd_read_block            ; whole block into the memory at R8
        CMPI   R1, 0x0000
        JNZ    file_next_end
        LOAD   R5, [FS_FILE_BLOCK]
        INC    R5
        STORE  R5, [FS_FILE_BLOCK]      ; next block next time
        LOAD   R5, [FS_FILE_BLOCKS]
        DEC    R5
        STORE  R5, [FS_FILE_BLOCKS]     ; one block fewer in this cluster
        LOAD   R5, [FS_FILE_LEFT]
        LOADLO R2, 0x0200
        CMP    R5, R2
        JC     file_next_full           ; 0x200 or more left, the whole block is the file
        MOV    R2, R5                   ; less, only that many
file_next_full: SUB R5, R5, R2
        STORE  R5, [FS_FILE_LEFT]
        LOADLO R1, 0
        JUMP   file_next_end
file_next_broken: LOADLO R1, 15
file_next_end: POP R8
        RET

; file_read, copies a whole file into memory (jump table entry FILE_READ)
; in R1 = pointer to the name, R2 = pointer to where it goes
; out R1 = 0 or an error number, R2 = size in bytes
; R8 = destination pointer
file_read: PUSH R8
        MOV    R8, R2
        CALL   file_open
        CMPI   R1, 0x0000
        JNZ    file_read_end
        MOV    R1, R8
        CALL   file_read_rest           ; every block, into place
        CMPI   R1, 0x0000
        JNZ    file_read_end
        LOAD   R2, [FS_FILE_SIZE]
file_read_end: POP R8
        RET

; file_read_rest, copies the rest of the open file into memory
; full blocks go straight into place
; the last part block goes through the disk buffer, only the file bytes are copied on
; in R1 = pointer to where the next block goes, out R1 = 0 or an error number
; R8 = where the next block goes
file_read_rest: PUSH R8
        MOV    R8, R1
file_rest_next: LOAD R5, [FS_FILE_LEFT]
        CMPI   R5, 0x0000
        JZ     file_rest_done
        LOADLO R6, 0x0200
        CMP    R5, R6
        JNC    file_rest_last           ; less than a block left, the last block
        MOV    R1, R8
        CALL   file_next_block          ; full block, straight into place
        CMPI   R1, 0x0000
        JNZ    file_rest_end
        ADDI   R8, R8, 0x200
        JUMP   file_rest_next
file_rest_last: LOADLO R1, DISK_BUFFER
        CALL   file_next_block          ; into the disk buffer, R2 = file bytes in it
        CMPI   R1, 0x0000
        JNZ    file_rest_end
        LOADLO R6, DISK_BUFFER          ; R6 = pointer into the disk buffer
file_rest_copy: LOADB R5, [R6]          ; copy just those bytes
        STOREB R5, [R8]
        INC    R6
        INC    R8
        DEC    R2, 0b0100
        JNZ    file_rest_copy
file_rest_done: LOADLO R1, 0
file_rest_end: POP R8
        RET

; note_free_line, remembers the first free line seen in a folder list
; in R1 = folder block, R2 = pointer to the line in the disk buffer, uses R5, R6
note_free_line: LOAD R5, [FS_FREE_BLOCK]
        CMPIS  R5, -1
        JNZ    note_free_done           ; one already noted, keep the first
        STORE  R1, [FS_FREE_BLOCK]
        LOADLO R6, DISK_BUFFER
        SUB    R6, R2, R6
        STORE  R6, [FS_FREE_OFFSET]
note_free_done: RET

; file_size, size of a file without reading it (jump table entry FILE_SIZE)
; in R1 = pointer to the path, out R1 = 0 or an error (13 not found, 14 a folder), R2 = size
file_size: CALL fs_find
        CMPI   R1, 0x0000
        JNZ    file_size_end
        LOAD   R2, [FS_FILE_SIZE]
file_size_end: RET

; ---- the safeguard, programs may not write over the file system ----

; sd_write_checked, SD_WRITE_BLOCK for programs (jump table entry 17)
; writes one block, only where it can not damage the files
; FAT32 card: only the gap before the FAT32 part, block 1 to FS_PARTITION_START - 1
; block 0 and every block of the FAT32 part are refused
; another file system (mount error 11): every block is refused
; no file system (mount error 10): any block
; the kernel file saving calls sd_write_block directly
; in R1 = block number, R2 = pointer to the 512 bytes, out R1 = 0, an SD error, or 16 refused
; R8 = block number, R9 = pointer
sd_write_checked: PUSH R8
        PUSH   R9
        MOV    R8, R1
        MOV    R9, R2
        LOAD   R5, [FS_STATE]
        CMPI   R5, 0x0000
        JNZ    write_check_block        ; mounted, check the block
        CALL   fs_mount                 ; not mounted yet
        CMPI   R1, 0x0000
        JZ     write_check_block
        CMPI   R1, 10
        JZ     write_go                 ; no file system, nothing to protect
        CMPI   R1, 11
        JZ     write_refused            ; another file system, protect all of it
        JUMP   write_checked_end        ; an SD error, hand it back
write_check_block: CMPI R8, 0x0000
        JZ     write_refused            ; block 0, the partition table
        LOAD   R5, [FS_PARTITION_START]
        CMP    R8, R5
        JC     write_refused            ; inside the FAT32 part
write_go: MOV R1, R8
        MOV    R2, R9
        CALL   sd_write_block
        JUMP   write_checked_end
write_refused: LOADLO R1, 16
write_checked_end: POP R9
        POP    R8
        RET
