; SD card commands, sdinfo, ls, cat, sdread, sdwrite, fs errors
; included by shell.asm

; fs_ready, mounts the file system if needed, out R1 = 0 or an error
fs_ready: LOAD R5, [FS_STATE]
        LOADLO R1, 0
        CMPI   R5, 0x0000
        JNZ    fs_ready_done
        JUMPF  fs_mount                 ; tail call
fs_ready_done: RET

; show_sd_error, prints "SD card error N", in R1 = error number
show_sd_error: PUSH R8
        MOV    R8, R1
        LA     R1, sd_error_text
        CALLF  screen_text
        MOV    R1, R8
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        POP    R8
        RET

; show_value, prints a text, a hex number, a new line
; in R1 = pointer to the text, R2 = the number
show_value: PUSH R8
        MOV    R8, R2
        CALLF  screen_text
        MOV    R1, R8
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        POP    R8
        RET

; sdinfo, mounts the card and shows where everything is
command_sdinfo: CALL fs_ready
        CMPI   R1, 0x0000
        JNZ    show_sd_error            ; tail call, R1 = error number
        LA     R1, info_partition
        LOAD   R2, [FS_PARTITION_START]
        CALL   show_value
        LA     R1, info_cluster
        LOAD   R2, [FS_SECTORS_PER_CLUSTER]
        CALL   show_value
        LA     R1, info_fat
        LOAD   R2, [FS_FAT_START]
        CALL   show_value
        LA     R1, info_data
        LOAD   R2, [FS_DATA_START]
        CALL   show_value
        LA     R1, info_root
        LOAD   R2, [FS_ROOT_CLUSTER]
        JUMP   show_value

; ls [PATH], lists a folder, name then size in hex or <DIR>
; reads a block at a time into DISK_BUFFER, 32 byte entries
; follows the FAT to the next cluster
; R8 = cluster, R9 = block, R10 = blocks left in the cluster
; R11 = pointer to the entry
command_ls: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R11, R1                  ; R11 = pointer to the typed path
        CALL   fs_ready
        CMPI   R1, 0x0000
        JNZ    ls_error
        LOADB  R5, [R11]
        CMPI   R5, 0x0000
        JZ     ls_here                  ; nothing typed, current folder
        MOV    R1, R11
        CALLF  fs_find                  ; find that folder
        CMPI   R1, 14
        JZ     ls_that
        CMPI   R1, 0x0000
        JNZ    ls_error
        LOADLO R1, 21                   ; error 21, a file not a folder
        JUMP   ls_error
ls_that: LOAD R8, [FS_FILE_CLUSTER]
        JUMP   ls_cluster
ls_here: LOAD R8, [FS_CURRENT_CLUSTER]
ls_cluster: MOV R1, R8
        CALLF  cluster_block
        MOV    R9, R1                   ; first block of the cluster
        LOAD   R10, [FS_SECTORS_PER_CLUSTER]
ls_block: MOV R1, R9
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block            ; one block = 16 entries
        CMPI   R1, 0x0000
        JNZ    ls_error
        LOADLO R11, DISK_BUFFER
ls_entry: LOADB R5, [R11]               ; first byte of the name
        CMPI   R5, 0x0000
        JZ     ls_done                  ; 0x00 = end of the folder
        CMPI   R5, 0x00E5
        JZ     ls_skip                  ; 0xE5 = deleted file
        LOADB  R6, [R11 + 11]           ; attribute bits
        CMPI   R6, 0x000F
        JZ     ls_skip                  ; 0x0F = long file name piece, skip
        ANDI   R6, R6, 0x0008
        JNZ    ls_skip                  ; bit 3 = volume label, skip
        MOV    R1, R11
        CALL   show_entry
ls_skip: ADDI R11, R11, 32              ; next entry
        CMPI   R11, DISK_BUFFER + 512
        JNZ    ls_entry
        INC    R9                       ; next block
        DEC    R10, 0b0100
        JNZ    ls_block
        MOV    R1, R8                   ; cluster done, ask the FAT for the next
        CALLF  fat_next
        MOV    R8, R1
        CMPI   R8, 0x0000
        JNZ    ls_cluster               ; 0 = end of the chain
        JUMP   ls_done
ls_error: CALL show_fs_error
ls_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; show_entry, prints one folder entry, name, kind, size
; in R1 = pointer to the 32 byte entry, R8 = entry, R9 = letter index
show_entry: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADLO R9, 0
entry_name: ADD R5, R8, R9              ; name, 8 letters padded with spaces
        LOADB  R1, [R5]
        CMPI   R1, 0x0020
        JZ     entry_name_next
        CALLF  screen_char
entry_name_next: INC R9
        CMPI   R9, 8
        JNZ    entry_name
        LOADB  R1, [R8 + 8]             ; type, 3 letters, shown if not all spaces
        CMPI   R1, 0x0020
        JZ     entry_size
        LOADLO R1, 0x002E               ; '.'
        CALLF  screen_char
        LOADLO R9, 8
entry_type: ADD R5, R8, R9
        LOADB  R1, [R5]
        CMPI   R1, 0x0020
        JZ     entry_type_next
        CALLF  screen_char
entry_type_next: INC R9
        CMPI   R9, 11
        JNZ    entry_type
entry_size: LOADB R1, [R8]              ; . and .. show only the name
        CMPI   R1, 0x002E
        JZ     entry_end_line
        LA     R1, two_spaces
        CALLF  screen_text
        LOADB  R5, [R8 + 11]
        ANDI   R5, R5, 0x0010           ; bit 4 = folder
        JZ     entry_file
        LA     R1, kind_folder_text     ; "folder"
        CALLF  screen_line
        JUMP   entry_done
entry_file: LA R1, file_size_text       ; "file  size = d'"
        CALLF  screen_text
        ADDI   R1, R8, 28               ; size is 4 bytes at byte 28
        CALLF  read_u32
        CALL   screen_decimal           ; in decimal
entry_end_line: LOADLO R1, 0x000A
        CALLF  screen_char
entry_done: POP R9
        POP    R8
        RET

; show_fs_error, a sentence for errors 12-27, else "SD card error N"
; in R1 = error number
show_fs_error: CMPI R1, 12
        JZ     fs_error_name
        CMPI   R1, 13
        JZ     fs_error_missing
        CMPI   R1, 14
        JZ     fs_error_folder
        CMPI   R1, 15
        JZ     fs_error_damaged
        CMPI   R1, 16
        JZ     fs_error_refused
        CMPI   R1, 17
        JZ     fs_error_not_program
        CMPI   R1, 18
        JZ     fs_error_no_room
        CMPI   R1, 21
        JZ     fs_error_not_folder
        CMPI   R1, 22
        JZ     fs_error_no_folder
        CMPI   R1, 23
        JZ     fs_error_taken
        CMPI   R1, 24
        JZ     fs_error_cant_move
        CMPI   R1, 25
        JZ     fs_error_no_memory
        CMPI   R1, 26
        JZ     fs_error_not_empty
        CMPI   R1, 27
        JZ     fs_error_cant_delete
        CMPI   R1, 19
        JZ     fs_error_card_full
        CMPI   R1, 20
        JZ     fs_error_folder_full
        JUMP   show_sd_error            ; tail call, R1 = error number
fs_error_name: LA R1, bad_name_text
        JUMPF  screen_line
fs_error_missing: LA R1, missing_text
        JUMPF  screen_line
fs_error_folder: LA R1, folder_text
        JUMPF  screen_line
fs_error_damaged: LA R1, damaged_text
        JUMPF  screen_line
fs_error_refused: LA R1, refused_write_text
        JUMPF  screen_line
fs_error_not_program: LA R1, not_program_text
        JUMPF  screen_line
fs_error_no_room: LA R1, no_room_text
        JUMPF  screen_line
fs_error_not_folder: LA R1, not_folder_text
        JUMPF  screen_line
fs_error_no_folder: LA R1, no_folder_text
        JUMPF  screen_line
fs_error_taken: LA R1, taken_text
        JUMPF  screen_line
fs_error_cant_move: LA R1, cant_move_text
        JUMPF  screen_line
fs_error_no_memory: LA R1, no_memory_text
        JUMPF  screen_line
fs_error_not_empty: LA R1, not_empty_text
        JUMPF  screen_line
fs_error_cant_delete: LA R1, cant_delete_text
        JUMPF  screen_line
fs_error_card_full: LA R1, card_full_text
        JUMPF  screen_line
fs_error_folder_full: LA R1, folder_full_text
        JUMPF  screen_line

; sdread.file NAME ADDR, copies a file into memory at ADDR, hex
; R8 = pointer to the name then the size, R9 = address
command_sdread_file: PUSH R8
        PUSH   R9
        MOV    R8, R1
        CALL   after_word               ; R1 = pointer to the next word
        CALL   parse_hex                ; R1 = address
        CMPI   R2, 0x0000
        JZ     sdread_file_usage
        MOV    R9, R1
        MOV    R1, R8
        MOV    R2, R9
        CALLF  file_read                ; R1 = 0 or an error, R2 = size
        CMPI   R1, 0x0000
        JNZ    sdread_file_error
        MOV    R8, R2
        LA     R1, file_read_text       ; "read SIZE bytes into ADDR"
        CALLF  screen_text
        MOV    R1, R8
        CALLF  screen_hex_word
        LA     R1, file_bytes_text
        CALLF  screen_text
        MOV    R1, R9
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   sdread_file_done
sdread_file_error: CALL show_fs_error
        JUMP   sdread_file_done
sdread_file_usage: LA R1, file_usage_text
        CALLF  screen_line
sdread_file_done: POP R9
        POP    R8
        RET

; cat NAME, shows a text file on the screen
; a block at a time through the disk buffer
; 0x0D is skipped, the screen only needs 0x0A
; R8 = pointer into the buffer, R9 = bytes left in the block
; R10 = last character shown, a new line is added if it wasnt one
command_cat: PUSH R8
        PUSH   R9
        PUSH   R10
        CALLF  file_open
        CMPI   R1, 0x0000
        JNZ    cat_error
        LOADLO R10, 0x000A
cat_block: LOADLO R1, DISK_BUFFER
        CALLF  file_next_block          ; R2 = file bytes in this block, 0 = finished
        CMPI   R1, 0x0000
        JNZ    cat_error
        CMPI   R2, 0x0000
        JZ     cat_finished
        MOV    R9, R2
        LOADLO R8, DISK_BUFFER
cat_char: LOADB R1, [R8]
        INC    R8
        CMPI   R1, 0x000D
        JZ     cat_skip                 ; skip 0x0D
        MOV    R10, R1
        CALLF  screen_char
cat_skip: DEC R9, 0b0100
        JNZ    cat_char
        JUMP   cat_block
cat_finished: CMPI R10, 0x000A
        JZ     cat_done
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   cat_done
cat_error: CALL show_fs_error
cat_done: POP R10
        POP    R9
        POP    R8
        RET

; sum NAME, checksum of a file on the card
; sum = sum x 31 + byte, 32 bits, same as sendfile.py
; prints "sum = 0xHHHHHHHH  size = d'N"
; R8 = next byte, R9 = bytes left in the block, R10 = sum
; R11 = size
command_sum: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        CALLF  file_open
        CMPI   R1, 0x0000
        JNZ    sum_error
        LOADLO R10, 0
        LOADLO R11, 0
sum_block: LOADLO R1, DISK_BUFFER
        CALLF  file_next_block          ; R2 = file bytes in this block, 0 = finished
        CMPI   R1, 0x0000
        JNZ    sum_error
        CMPI   R2, 0x0000
        JZ     sum_finished
        ADD    R11, R11, R2
        MOV    R9, R2
        LOADLO R8, DISK_BUFFER
sum_byte: LOADB R1, [R8]
        INC    R8
        MULI   R10, R10, 31
        ADD    R10, R10, R1
        DEC    R9, 0b0100
        JNZ    sum_byte
        JUMP   sum_block
sum_finished: LA R1, sum_text           ; "sum = 0x"
        CALLF  screen_text
        MOV    R1, R10
        CALLF  screen_hex_word
        LA     R1, sum_size_text        ; "  size = d'"
        CALLF  screen_text
        MOV    R1, R11
        CALL   screen_decimal
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   sum_done
sum_error: CALL show_fs_error
sum_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; go ADDR [ARGS], runs the code at ADDR, hex, R2 = pointer to args
; when it does RET the shell starts again
; ADDR must be a multiple of 4
command_go: CALL parse_hex              ; R1 = address, R2 = 0 if not hex
        CMPI   R2, 0x0000
        JZ     go_usage
        ANDI   R5, R1, 0x0003
        JNZ    not_aligned              ; tail call, not a multiple of 4
        FLUSH                           ; maybe new code, empty the instruction cache
        CALLF  run_program              ; empties the queues, then CALLR R1
        JUMP   shell_restart            ; it returned, start again
go_usage: LA R1, go_usage_text
        JUMPF  screen_line

; sdwrite.file NAME ADDR SIZE, saves SIZE bytes from ADDR as a file, hex
; replaces a file with that name, a .BIN at 0x5000 can be run with run NAME
; R8 = pointer to the name, R9 = address, R10 = size
command_sdwrite_file: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        CALL   after_word               ; R1 = pointer to the next word
        CALL   parse_hex                ; R1 = address, R2 = pointer to the next word, 0 = no number
        CMPI   R2, 0x0000
        JZ     sdwrite_file_usage
        MOV    R9, R1
        MOV    R1, R2
        CALL   parse_hex                ; R1 = size
        CMPI   R2, 0x0000
        JZ     sdwrite_file_usage
        MOV    R10, R1
        MOV    R1, R8
        MOV    R2, R9
        MOV    R3, R10
        CALL   file_write               ; write it
        CMPI   R1, 0x0000
        JNZ    sdwrite_file_error
        LA     R1, saved_text           ; "saved SIZE bytes from ADDR"
        CALLF  screen_text
        MOV    R1, R10
        CALLF  screen_hex_word
        LA     R1, saved_from_text
        CALLF  screen_text
        MOV    R1, R9
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   sdwrite_file_done
sdwrite_file_error: CALL show_fs_error
        JUMP   sdwrite_file_done
sdwrite_file_usage: LA R1, sdwrite_file_usage_text
        CALLF  screen_line
sdwrite_file_done: POP R10
        POP    R9
        POP    R8
        RET

; sdinfo.file NAME, where a file is on the card
; its size, then each cluster and its blocks
; at most 16 clusters shown
; R8 = cluster, R9 = lines left, R10 = first block of the cluster
command_sdinfo_file: PUSH R8
        PUSH   R9
        PUSH   R10
        CALLF  fs_find                  ; sets FS_FILE_CLUSTER, FS_FILE_SIZE
        CMPI   R1, 0x0000
        JNZ    where_error
        LA     R1, where_size_text      ; "size N bytes. Its clusters (and blocks):"
        CALLF  screen_text
        LOAD   R1, [FS_FILE_SIZE]
        CALLF  screen_hex_word
        LA     R1, where_clusters_text
        CALLF  screen_line
        LOAD   R8, [FS_FILE_CLUSTER]
        LOADLO R9, 16
where_next: CMPI R8, 0x0000
        JZ     where_done               ; 0 = no more clusters
        MOV    R1, R8
        CALLF  screen_hex_word          ; "CLUSTER = blocks FIRST-LAST"
        LA     R1, where_blocks_text
        CALLF  screen_text
        MOV    R1, R8
        CALLF  cluster_block
        MOV    R10, R1
        CALLF  screen_hex_word
        LA     R1, where_dash_text
        CALLF  screen_text
        LOAD   R5, [FS_SECTORS_PER_CLUSTER]
        ADD    R1, R10, R5
        SUBI   R1, R1, 1                ; last block of the cluster
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        MOV    R1, R8
        CALLF  fat_next                 ; next cluster, 0 at the end
        MOV    R8, R1
        DEC    R9, 0b0100
        JNZ    where_next
        CMPI   R8, 0x0000
        JZ     where_done
        LA     R1, where_more_text      ; more than 16
        CALLF  screen_line
        JUMP   where_done
where_error: CALL show_fs_error
where_done: POP R10
        POP    R9
        POP    R8
        RET

; cd PATH, changes the current folder, cd alone shows it
; R8 = pointer to the typed path
command_cd: LOADB R5, [R1]
        CMPI   R5, 0x0000
        JZ     cd_show
        PUSH   R8
        MOV    R8, R1
        CALLF  fs_find
        CMPI   R1, 14
        JZ     cd_go                    ; a folder, go there
        CMPI   R1, 0x0000
        JNZ    cd_error
        LOADLO R1, 21                   ; error 21, a file not a folder
cd_error: CALL show_fs_error
        JUMP   cd_done
cd_go: LOAD R5, [FS_FILE_CLUSTER]
        STORE  R5, [FS_CURRENT_CLUSTER]
        MOV    R1, R8
        CALL   path_update              ; update the path text
cd_done: POP R8
        RET
cd_show: LOADB R5, [FS_PATH]
        CMPI   R5, 0x0000
        JZ     cd_root
        LOADLO R1, FS_PATH              ; the path text
        JUMPF  screen_line
cd_root: LA R1, slash_text              ; root, "/"
        JUMPF  screen_line
