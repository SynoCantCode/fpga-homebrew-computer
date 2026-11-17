; fs_write.asm, the file system writing half, and loading programs, part of KERNEL.BIN
; the reading half stays in the ROM (fs.asm), the ROM needs it to load KERNEL.BIN
; ROM routines are reached with CALLF / JUMPF, names from rom_symbols.asm

; program_load, copies a .BIN program from the card into the SDRAM at PROGRAM_SDRAM (0x1018_0000)
; the whole file is the program bytes, assembled with .org PROGRAM_SDRAM, up to 512 KB
; in R1 = pointer to the name, out R1 = 0 or an error (17 = not a .BIN, 18 = too big)
; R2 = program address, PROGRAM_SDRAM
program_load: CALLF file_open
        CMPI   R1, 0x0000
        JNZ    program_load_end
        CALL   name_is_bin
        CMPI   R1, 0x0000
        JZ     program_not              ; only .BIN files are programs
        LOAD   R5, [FS_FILE_SIZE]
        LOADHI R6, PROGRAM_SDRAM_SIZE_HIGH ; 512 KB room for a program
        CMP    R6, R5
        JNC    program_no_room          ; too big
        LOADHI R1, PROGRAM_SDRAM_HIGH   ; programs are assembled for PROGRAM_SDRAM
        CALLF  file_read_rest           ; whole file into place
        CMPI   R1, 0x0000
        JNZ    program_load_end
        LOADHI R2, PROGRAM_SDRAM_HIGH
        LOADLO R1, 0
        RET
program_not: LOADLO R1, 17
        RET
program_no_room: LOADLO R1, 18
program_load_end: RET

;---- saving files ----

; name_is_bin, does the name in FS_NAME end in .BIN, out R1 = 1 or 0, uses R5
name_is_bin: LOADLO R1, 0
        LOADB  R5, [FS_NAME + 8]
        CMPI   R5, 0x0042               ; 'B'
        JNZ    name_is_bin_done
        LOADB  R5, [FS_NAME + 9]
        CMPI   R5, 0x0049               ; 'I'
        JNZ    name_is_bin_done
        LOADB  R5, [FS_NAME + 10]
        CMPI   R5, 0x004E               ; 'N'
        JNZ    name_is_bin_done
        LOADLO R1, 1
name_is_bin_done: RET

; find_free_cluster, looks through the FAT from cluster 2 for a slot that is 0
; out R1 = cluster number, or 0 if the card is full
; R8 = cluster looked at, R9 = FAT block in the disk buffer, R10 = last cluster
find_free_cluster: PUSH R8
        PUSH   R9
        PUSH   R10
        LOADLO R8, 2
        LOADHI R9, 0xFFFF
        ORI    R9, R9, 0xFFFF
        LOAD   R10, [FS_LAST_CLUSTER]
free_look: CMP R10, R8
        JNC    free_none                ; past the last cluster, none free
        SHIFTI R1, R8, 0x07, 0b1000     ; cluster / 128
        LOAD   R5, [FS_FAT_START]
        ADD    R1, R1, R5               ; R1 = FAT block of its slot
        CMP    R1, R9
        JZ     free_have_block          ; already in the disk buffer
        MOV    R9, R1
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    free_none
free_have_block: ANDI R5, R8, 0x007F
        SHIFTI R5, R5, 0x02, 0b0000     ; (cluster mod 128) x 4, slot byte in the block
        ADDIW  R5, R5, DISK_BUFFER
        LOAD   R5, [R5]
        LOADHI R6, 0x0FFF
        ORI    R6, R6, 0xFFFF
        AND    R5, R5, R6               ; bottom 28 bits
        CMPI   R5, 0x0000
        JZ     free_found               ; 0 = free cluster
        INC    R8
        JUMP   free_look
free_found: MOV R1, R8
        JUMP   free_end
free_none: LOADLO R1, 0
free_end: POP R10
        POP    R9
        POP    R8
        RET

; set_fat, writes the FAT slot of a cluster in every copy of the FAT
; in R1 = cluster, R2 = new value, 0 = free, 0x0FFFFFFF = the end, else the next cluster
; out R1 = 0 or an error, only the bottom 28 bits change
; R8 = cluster, then pointer to its slot, R9 = value, R10 = block, R11 = copies left
set_fat: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        MOV    R9, R2
        SHIFTI R10, R8, 0x07, 0b1000    ; cluster / 128
        LOAD   R5, [FS_FAT_START]
        ADD    R10, R10, R5             ; R10 = FAT block in the first copy
        MOV    R1, R10
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    set_fat_end
        ANDI   R8, R8, 0x007F
        SHIFTI R8, R8, 0x02, 0b0000
        ADDIW  R8, R8, DISK_BUFFER      ; R8 = pointer to the slot in the disk buffer
        LOAD   R5, [R8]
        LOADHI R6, 0xF000
        AND    R5, R5, R6               ; keep the top 4 bits
        LOADHI R6, 0x0FFF
        ORI    R6, R6, 0xFFFF
        AND    R9, R9, R6
        OR     R5, R5, R9
        STORE  R5, [R8]
        LOAD   R11, [FS_FAT_COUNT]
set_fat_copy: MOV R1, R10
        LOADLO R2, DISK_BUFFER
        CALLF  sd_write_block           ; kernel writer, no safeguard
        CMPI   R1, 0x0000
        JNZ    set_fat_end
        LOAD   R5, [FS_FAT_SIZE]
        ADD    R10, R10, R5             ; same block in the next copy
        DEC    R11, 0b0100
        JNZ    set_fat_copy
        LOADLO R1, 0
set_fat_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; free_chain, frees the clusters of a file, every slot of the chain becomes 0
; in R1 = first cluster (below 2 = nothing to free), out R1 = 0 or an error
; R8 = cluster, R9 = next one, R10 = count that stops a looping chain
free_chain: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        LOAD   R10, [FS_LAST_CLUSTER]
free_chain_next: CMPI R8, 0x0002
        JNC    free_chain_done          ; below 2, end of the chain
        LOAD   R5, [FS_LAST_CLUSTER]
        CMP    R5, R8
        JNC    free_chain_done          ; past the last cluster, damaged, stop
        MOV    R1, R8
        CALLF  fat_next                 ; next cluster, 0 = it ended here
        MOV    R9, R1
        MOV    R1, R8
        LOADLO R2, 0
        CALL   set_fat                  ; free this one
        CMPI   R1, 0x0000
        JNZ    free_chain_end
        MOV    R8, R9
        DEC    R10, 0b0100
        JNZ    free_chain_next
free_chain_done: LOADLO R1, 0
free_chain_end: POP R10
        POP    R9
        POP    R8
        RET

; file_write, saves bytes from memory as a file (jump table entry FILE_WRITE)
; in R1 = pointer to the name, R2 = pointer to the bytes, R3 = how many
; out R1 = 0 or an error (12 bad name, 14 a folder has that name, 19 card full, 20 folder full)
; the order keeps the card safe if something fails part way
; 1. find the name, an old file is kept for the moment, a new name gets a free line
; 2. for each cluster: take a free one, mark it end, link the previous one to it
; then write its blocks
; 3. when every byte is on the card, write the file line
; 4. then free the old file clusters
; if 2 fails the new clusters are freed again, the old file is untouched
; R8 = where the next block comes from, R9 = bytes left, R10 = cluster being filled
; R11 = previous cluster (0 = none), R12 = first cluster, R14 = blocks left in this cluster
file_write: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R14
        STORE  R2, [FS_WRITE_ADDR]
        STORE  R3, [FS_WRITE_SIZE]
        STORE  R0, [FS_OLD_CLUSTER]
        CALLF  fs_find
        CMPI   R1, 0x0000
        JZ     write_replace            ; name already there, replace that file
        CMPI   R1, 13
        JNZ    write_end                ; bad name, a folder, or a card error
        LOAD   R5, [FS_FREE_BLOCK]      ; new file, use the first free line fs_find passed
        CMPIS  R5, -1
        JNZ    write_have_line
        CALL   grow_folder              ; no free line, the folder gets one more cluster
        CMPI   R1, 0x0000
        JNZ    write_end
write_have_line: LOAD R5, [FS_FREE_BLOCK]
        STORE  R5, [FS_LINE_BLOCK]
        LOAD   R5, [FS_FREE_OFFSET]
        STORE  R5, [FS_LINE_OFFSET]
        JUMP   write_prepare
write_replace: LOAD R5, [FS_FILE_CLUSTER]
        STORE  R5, [FS_OLD_CLUSTER]     ; freed at the very end
write_prepare: LOAD R8, [FS_WRITE_ADDR]
        LOAD   R9, [FS_WRITE_SIZE]
        STORE  R9, [FS_FILE_SIZE]       ; file size
        LOADLO R11, 0
        LOADLO R12, 0
        LOADLO R14, 0
write_loop: CMPI R9, 0x0000
        JZ     write_line               ; every byte is on the card
        CMPI   R14, 0x0000
        JNZ    write_block
        CALL   find_free_cluster        ; need a new cluster, take a free one
        CMPI   R1, 0x0000
        JZ     write_card_full
        MOV    R10, R1
        LOADHI R2, 0x0FFF
        ORI    R2, R2, 0xFFFF
        CALL   set_fat                  ; mark it taken, end of the chain
        CMPI   R1, 0x0000
        JNZ    write_failed
        CMPI   R11, 0x0000
        JZ     write_first
        MOV    R1, R11
        MOV    R2, R10
        CALL   set_fat                  ; link the previous cluster to this one
        CMPI   R1, 0x0000
        JNZ    write_failed
        JUMP   write_took
write_first: MOV R12, R10               ; first cluster of the file
write_took: MOV R11, R10
        MOV    R1, R10
        CALLF  cluster_block
        STORE  R1, [FS_FILE_BLOCK]      ; its first block
        LOAD   R14, [FS_SECTORS_PER_CLUSTER]
write_block: MOV R2, R8                 ; next 512 bytes from memory
        LOAD   R1, [FS_FILE_BLOCK]
        CALLF  sd_write_block           ; 512 bytes from R2 into the block
        CMPI   R1, 0x0000
        JNZ    write_failed
        LOAD   R5, [FS_FILE_BLOCK]
        INC    R5
        STORE  R5, [FS_FILE_BLOCK]
        DEC    R14
        ADDI   R8, R8, 0x200
        LOADLO R5, 0x0200
        CMP    R9, R5
        JNC    write_all_done           ; less than a block left, that was the last
        SUB    R9, R9, R5
        JUMP   write_loop
write_all_done: LOADLO R9, 0
        JUMP   write_loop
write_line: MOV R1, R12                 ; every byte is on the card, write the file line in the folder
        LOAD   R2, [FS_FILE_SIZE]
        LOADLO R3, 0x0020               ; kind = an ordinary file
        CALL   put_line
        CMPI   R1, 0x0000
        JNZ    write_failed
        LOAD   R1, [FS_OLD_CLUSTER]     ; new file is safe, free the old clusters
        CALL   free_chain
        JUMP   write_end
write_card_full: LOADLO R1, 19
        JUMP   write_failed
write_failed: MOV R9, R1                ; failed part way, give the new clusters back
        MOV    R1, R12
        CALL   free_chain
        MOV    R1, R9
write_end: POP R14
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; put_line, writes a line into a folder list at FS_LINE_BLOCK / FS_LINE_OFFSET, name from FS_NAME
; in R1 = first cluster, R2 = size, R3 = kind (0x20 file, 0x10 folder), out R1 = 0 or an error
; no times or dates, R8 = cluster, R9 = size, R10 = kind
put_line: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        MOV    R9, R2
        MOV    R10, R3
        LOAD   R1, [FS_LINE_BLOCK]      ; read the block of the line
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    put_line_end
        LOAD   R6, [FS_LINE_OFFSET]
        ADDIW  R6, R6, DISK_BUFFER      ; R6 = pointer to the line
        LOADLO R7, FS_NAME
        LOADLO R3, 11
put_line_name: LOADB R5, [R7]           ; the name, 11 bytes
        STOREB R5, [R6]
        INC    R7
        INC    R6
        DEC    R3, 0b0100
        JNZ    put_line_name
        STOREB R10, [R6]                ; the kind
        SUBI   R6, R6, 11
        STORE  R0, [R6 + 12]            ; no times or dates
        STORE  R0, [R6 + 16]
        SHIFTI R5, R8, 0x10, 0b1000
        STORE  R5, [R6 + 20]            ; first cluster top half, bytes 20-21
        SHIFTI R5, R8, 0x10, 0b0000
        STORE  R5, [R6 + 24]            ; bottom half, bytes 26-27
        STORE  R9, [R6 + 28]            ; the size
        LOAD   R1, [FS_LINE_BLOCK]
        LOADLO R2, DISK_BUFFER
        CALLF  sd_write_block           ; write the block back
put_line_end: POP R10
        POP    R9
        POP    R8
        RET

; zero_cluster, fills every block of a cluster with zeros
; in R1 = cluster, out R1 = 0 or an error, R8 = block, R9 = blocks left
zero_cluster: PUSH R8
        PUSH   R9
        CALLF  cluster_block
        MOV    R8, R1
        LOADLO R5, DISK_BUFFER
        LOADLO R6, 0x0080               ; 0x80 words = 512 bytes
zero_fill: STORE R0, [R5]
        ADDI   R5, R5, 4
        DEC    R6, 0b0100
        JNZ    zero_fill
        LOAD   R9, [FS_SECTORS_PER_CLUSTER]
zero_write: MOV R1, R8
        LOADLO R2, DISK_BUFFER
        CALLF  sd_write_block
        CMPI   R1, 0x0000
        JNZ    zero_end
        INC    R8
        DEC    R9, 0b0100
        JNZ    zero_write
        LOADLO R1, 0
zero_end: POP R9
        POP    R8
        RET

; grow_folder, gives the folder fs_find just searched one more cluster, all zeros
; linked after FS_FOLDER_LAST, out R1 = 0, FS_FREE_BLOCK / FS_FREE_OFFSET = its first line
; or an error (19 = card full), R8 = new cluster
grow_folder: PUSH R8
        CALL   find_free_cluster
        CMPI   R1, 0x0000
        JZ     grow_full
        MOV    R8, R1
        LOADHI R2, 0x0FFF
        ORI    R2, R2, 0xFFFF
        CALL   set_fat                  ; taken, end of the folder chain
        CMPI   R1, 0x0000
        JNZ    grow_end
        MOV    R1, R8
        CALL   zero_cluster             ; every line free
        CMPI   R1, 0x0000
        JNZ    grow_end
        LOAD   R1, [FS_FOLDER_LAST]
        MOV    R2, R8
        CALL   set_fat                  ; link the old last cluster to the new one
        CMPI   R1, 0x0000
        JNZ    grow_end
        MOV    R1, R8
        CALLF  cluster_block
        STORE  R1, [FS_FREE_BLOCK]
        STORE  R0, [FS_FREE_OFFSET]
        LOADLO R1, 0
        JUMP   grow_end
grow_full: LOADLO R1, 19
grow_end: POP R8
        RET

; folder_make, makes a new empty folder (jump table entry FOLDER_MAKE)
; in R1 = pointer to the path, out R1 = 0 or an error (23 = name taken, 19 = card full)
; first two lines are "." (itself) and ".." (folder above, cluster 0 for the root), rest zeros
; then a line with kind 0x10 in the folder above points to it
; R8 = new folder cluster, R9 = cluster of the folder above
folder_make: PUSH R8
        PUSH   R9
        CALLF  fs_find
        CMPI   R1, 13
        JZ     make_new                 ; no such name yet
        CMPI   R1, 0x0000
        JZ     make_taken
        CMPI   R1, 14
        JZ     make_taken
        JUMP   make_end                 ; bad name, missing folder in the path, card error
make_taken: LOADLO R1, 23
        JUMP   make_end
make_new: LOAD R5, [FS_FREE_BLOCK]
        CMPIS  R5, -1
        JNZ    make_have_line
        CALL   grow_folder              ; folder above is full, grow it
        CMPI   R1, 0x0000
        JNZ    make_end
make_have_line: LOAD R5, [FS_FREE_BLOCK]
        STORE  R5, [FS_LINE_BLOCK]
        LOAD   R5, [FS_FREE_OFFSET]
        STORE  R5, [FS_LINE_OFFSET]
        LOAD   R9, [FS_FOLDER_CLUSTER]
        CALL   find_free_cluster
        CMPI   R1, 0x0000
        JZ     make_full
        MOV    R8, R1
        LOADHI R2, 0x0FFF
        ORI    R2, R2, 0xFFFF
        CALL   set_fat                  ; taken, a one cluster list
        CMPI   R1, 0x0000
        JNZ    make_failed
        MOV    R1, R8
        CALL   zero_cluster             ; the disk buffer is all zeros too
        CMPI   R1, 0x0000
        JNZ    make_failed
        LOADHI R5, 0x2020               ; first block, line 0 = ".", line 1 = ".."
        ORI    R5, R5, 0x202E           ; ". " + 2 spaces, bytes 0-3, lowest first
        STORE  R5, [DISK_BUFFER]
        LOADHI R5, 0x2020
        ORI    R5, R5, 0x2E2E           ; ".." + 2 spaces
        STORE  R5, [DISK_BUFFER + 32]
        LOADHI R5, 0x2020
        ORI    R5, R5, 0x2020           ; 4 spaces, bytes 4-7
        STORE  R5, [DISK_BUFFER + 4]
        STORE  R5, [DISK_BUFFER + 36]
        LOADHI R5, 0x1020
        ORI    R5, R5, 0x2020           ; 3 spaces (bytes 8-10), then kind 0x10 (byte 11)
        STORE  R5, [DISK_BUFFER + 8]
        STORE  R5, [DISK_BUFFER + 40]
        SHIFTI R5, R8, 0x10, 0b1000     ; ".", its own cluster
        STORE  R5, [DISK_BUFFER + 20]
        SHIFTI R5, R8, 0x10, 0b0000
        STORE  R5, [DISK_BUFFER + 24]
        LOAD   R5, [FS_ROOT_CLUSTER]    ; "..", the folder above, 0 for the root
        CMP    R9, R5
        JNZ    make_parent
        LOADLO R9, 0
make_parent: SHIFTI R5, R9, 0x10, 0b1000
        STORE  R5, [DISK_BUFFER + 52]
        SHIFTI R5, R9, 0x10, 0b0000
        STORE  R5, [DISK_BUFFER + 56]
        MOV    R1, R8
        CALLF  cluster_block
        LOADLO R2, DISK_BUFFER
        CALLF  sd_write_block
        CMPI   R1, 0x0000
        JNZ    make_failed
        MOV    R1, R8                   ; its line in the folder above, kind 0x10, size 0
        LOADLO R2, 0
        LOADLO R3, 0x0010
        CALL   put_line
        CMPI   R1, 0x0000
        JNZ    make_failed
        JUMP   make_end
make_full: LOADLO R1, 19
        JUMP   make_end
make_failed: MOV R9, R1                 ; give the cluster back
        MOV    R1, R8
        CALL   free_chain
        MOV    R1, R9
make_end: POP R9
        POP    R8
        RET

; file_delete, deletes a file or an empty folder (jump table entry FILE_DELETE)
; first byte of its line becomes 0xE5, then its clusters are freed
; a folder is empty with only "." and "..", deleted lines and free ones
; 27 = the root, "." / ".." or the current folder, 26 = folder not empty
; in R1 = pointer to the path, out R1 = 0 or an error (13 not found, 26, 27)
; R8 = first cluster, R9 = folder cluster being checked, R10 = block, R11 = blocks left
file_delete: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        CALLF  fs_find
        CMPI   R1, 0x0000
        JZ     delete_it                ; a file
        CMPI   R1, 14
        JNZ    delete_end               ; not found or a bad name
        LOAD   R8, [FS_FILE_CLUSTER]    ; a folder, can it go?
        LOAD   R5, [FS_ROOT_CLUSTER]
        CMP    R8, R5
        JZ     delete_refused
        LOADB  R5, [FS_NAME]
        CMPI   R5, 0x002E
        JZ     delete_refused           ; "." or ".."
        LOAD   R5, [FS_CURRENT_CLUSTER]
        CMP    R8, R5
        JZ     delete_refused           ; the current folder
        MOV    R9, R8
delete_check_cluster: MOV R1, R9        ; is it empty? check every line of its list
        CALLF  cluster_block
        MOV    R10, R1
        LOAD   R11, [FS_SECTORS_PER_CLUSTER]
delete_check_block: MOV R1, R10
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    delete_end
        LOADLO R6, DISK_BUFFER
delete_check_line: LOADB R5, [R6]
        CMPI   R5, 0x0000
        JZ     delete_it                ; end of the list, empty, it can go
        CMPI   R5, 0x00E5
        JZ     delete_next_line         ; deleted, fine
        CMPI   R5, 0x002E
        JZ     delete_next_line         ; "." or "..", fine
        LOADLO R1, 26                   ; anything else, not empty
        JUMP   delete_end
delete_next_line: ADDI R6, R6, 32
        CMPI   R6, DISK_BUFFER + 512
        JNZ    delete_check_line
        INC    R10
        DEC    R11, 0b0100
        JNZ    delete_check_block
        MOV    R1, R9
        CALLF  fat_next
        MOV    R9, R1
        CMPI   R9, 0x0000
        JNZ    delete_check_cluster
delete_it: LOAD R8, [FS_FILE_CLUSTER]
        LOAD   R1, [FS_LINE_BLOCK]
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    delete_end
        LOAD   R6, [FS_LINE_OFFSET]
        ADDIW  R6, R6, DISK_BUFFER
        LOADLO R5, 0x00E5
        STOREB R5, [R6]                 ; deleted
        LOAD   R1, [FS_LINE_BLOCK]
        LOADLO R2, DISK_BUFFER
        CALLF  sd_write_block
        CMPI   R1, 0x0000
        JNZ    delete_end
        MOV    R1, R8
        CALL   free_chain               ; free its clusters
        JUMP   delete_end
delete_refused: LOADLO R1, 27
delete_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

;---- moving and copying ----

; line_block_copy, copies 32 bytes (one folder line)
; in R1 = pointer to the 32 bytes, R2 = pointer to where they go, uses R5, R6
line_block_copy: LOADLO R6, 32
line_copy_next: LOADB R5, [R1]
        STOREB R5, [R2]
        INC    R1
        INC    R2
        DEC    R6, 0b0100
        JNZ    line_copy_next
        RET

; file_move, renames or moves a file or folder (jump table entry FILE_MOVE)
; only its line moves, the FAT does not change
; new line is written first, then the old one is marked deleted
; a moved folder gets its ".." line pointed at the new parent
; refused (24): the root, "." or "..", a folder into itself
; if the new path is a folder it goes into it, keeping its name, path built in FS_MOVE_PATH
; in R1 = pointer to the old path, R2 = pointer to the new path, out R1 = 0 or an error
; R8 = new path, R9 = kind, R10 = folder it goes into, R11 = old path, then a cluster being checked
file_move: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R2
        MOV    R11, R1
        CALLF  fs_find                  ; the old one
        CMPI   R1, 0x0000
        JZ     move_found
        CMPI   R1, 14
        JNZ    move_end                 ; not there or a bad name
move_found: LOAD R5, [FS_FILE_CLUSTER]
        STORE  R5, [FS_MOVE_CLUSTER]
        LOAD   R6, [FS_ROOT_CLUSTER]
        CMP    R5, R6
        JZ     move_refused             ; the root can not move
        LOADB  R5, [FS_NAME]
        CMPI   R5, 0x002E
        JZ     move_refused             ; "." or ".."
        LOAD   R1, [FS_LINE_BLOCK]
        STORE  R1, [FS_MOVE_BLOCK]
        LOAD   R5, [FS_LINE_OFFSET]
        STORE  R5, [FS_MOVE_OFFSET]
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block            ; its line, kept in FS_MOVE_LINE
        CMPI   R1, 0x0000
        JNZ    move_end
        LOAD   R1, [FS_MOVE_OFFSET]
        ADDIW  R1, R1, DISK_BUFFER
        LOADLO R2, FS_MOVE_LINE
        CALL   line_block_copy
        LOADB  R9, [FS_MOVE_LINE + 11]  ; R9 = its kind
move_find_new: MOV R1, R8
        CALLF  fs_find                  ; the new name, must not be there yet
        CMPI   R1, 13
        JZ     move_name_free
        CMPI   R1, 14
        JZ     move_into_folder         ; a folder, go into it
        CMPI   R1, 0x0000
        JNZ    move_end
move_taken: LOADLO R1, 23
        JUMP   move_end
move_into_folder: LOADLO R5, FS_MOVE_PATH
        CMP    R8, R5
        JZ     move_taken               ; already tried, that folder holds a folder with this name
        MOV    R1, R8
        MOV    R2, R11
        CALL   join_path                ; FS_MOVE_PATH = the folder + "/" + the old name
        LOADLO R8, FS_MOVE_PATH
        JUMP   move_find_new
move_name_free: LOAD R10, [FS_FOLDER_CLUSTER] ; where it goes
        ANDI   R5, R9, 0x0010
        JZ     move_line                ; a file, no loop possible
        MOV    R11, R10                 ; a folder must not go into itself, walk up the ".." lines
        LOADLO R7, 0x0100               ; to the root, at most 0x100 steps
move_check: LOAD R5, [FS_MOVE_CLUSTER]
        CMP    R11, R5
        JZ     move_refused             ; the moved folder itself, or inside it
        LOAD   R5, [FS_ROOT_CLUSTER]
        CMP    R11, R5
        JZ     move_line                ; reached the root, no loop
        PUSH   R7
        MOV    R1, R11
        CALLF  cluster_block
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block            ; first block of the folder, line 1 is ".."
        POP    R7
        CMPI   R1, 0x0000
        JNZ    move_end
        LOADLO R1, DISK_BUFFER + 32 + 20
        CALLF  read_u16
        SHIFTI R11, R1, 0x10, 0b0000
        LOADLO R1, DISK_BUFFER + 32 + 26
        CALLF  read_u16
        OR     R11, R11, R1             ; the folder above
        CMPI   R11, 0x0000
        JZ     move_line                ; 0 = the root
        DEC    R7, 0b0100
        JNZ    move_check
        JUMP   move_refused             ; too deep, damaged card
move_line: LOAD R5, [FS_FREE_BLOCK]     ; a free line in the folder it goes into
        CMPIS  R5, -1
        JNZ    move_have_line
        CALL   grow_folder
        CMPI   R1, 0x0000
        JNZ    move_end
move_have_line: LOAD R1, [FS_FREE_BLOCK]
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    move_end
        LOADLO R1, FS_NAME              ; new name over the first 11 bytes of the kept line
        LOADLO R2, FS_MOVE_LINE
        LOADLO R6, 11
move_rename: LOADB R5, [R1]
        STOREB R5, [R2]
        INC    R1
        INC    R2
        DEC    R6, 0b0100
        JNZ    move_rename
        LOADLO R1, FS_MOVE_LINE         ; whole line into its new place
        LOAD   R2, [FS_FREE_OFFSET]
        ADDIW  R2, R2, DISK_BUFFER
        CALL   line_block_copy
        LOAD   R1, [FS_FREE_BLOCK]
        LOADLO R2, DISK_BUFFER
        CALLF  sd_write_block           ; 1. new line is on the card
        CMPI   R1, 0x0000
        JNZ    move_end
        LOAD   R1, [FS_MOVE_BLOCK]
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    move_end
        LOAD   R6, [FS_MOVE_OFFSET]
        ADDIW  R6, R6, DISK_BUFFER
        LOADLO R5, 0x00E5
        STOREB R5, [R6]
        LOAD   R1, [FS_MOVE_BLOCK]
        LOADLO R2, DISK_BUFFER
        CALLF  sd_write_block           ; 2. old line is deleted
        CMPI   R1, 0x0000
        JNZ    move_end
        ANDI   R5, R9, 0x0010
        JZ     move_end                 ; a file, done
        LOAD   R1, [FS_MOVE_CLUSTER]    ; 3. a folder, its ".." line points at the new parent
        CALLF  cluster_block
        MOV    R11, R1
        LOADLO R2, DISK_BUFFER
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    move_end
        LOAD   R5, [FS_ROOT_CLUSTER]
        CMP    R10, R5
        JNZ    move_parent
        LOADLO R10, 0                   ; root is written as cluster 0
move_parent: SHIFTI R5, R10, 0x10, 0b1000
        STORE  R5, [DISK_BUFFER + 52]
        SHIFTI R5, R10, 0x10, 0b0000
        STORE  R5, [DISK_BUFFER + 56]
        MOV    R1, R11
        LOADLO R2, DISK_BUFFER
        CALLF  sd_write_block
        JUMP   move_end
move_refused: LOADLO R1, 24
move_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; join_path, builds FS_MOVE_PATH = folder path + "/" + last part of another path
; "docs" + "games/a.txt" -> "docs/a.txt"
; in R1 = pointer to the folder path, R2 = pointer to the other path, uses R1-R7
join_path: LOADLO R3, FS_MOVE_PATH      ; R3 = where the next letter goes
        LOADLO R4, FS_MOVE_PATH + 0x60  ; folder part may go up to here
        LOADLO R7, FS_MOVE_PATH + 0x7F  ; whole path up to here
join_folder: LOADB R5, [R1]
        CMPI   R5, 0x0000
        JZ     join_folder_done
        CMPI   R5, 0x0020
        JZ     join_folder_done
        CMP    R3, R4
        JC     join_folder_done         ; too long, stop
        STOREB R5, [R3]
        INC    R1
        INC    R3
        JUMP   join_folder
join_folder_done: SUBI R6, R3, 1        ; add a "/" unless the folder path already ends with one
        LOADB  R5, [R6]
        CMPI   R5, 0x002F
        JZ     join_name
        LOADLO R5, 0x002F
        STOREB R5, [R3]
        INC    R3
join_name: MOV R6, R2                   ; R6 = start of the last part of the other path
join_scan: LOADB R5, [R2]
        CMPI   R5, 0x0000
        JZ     join_copy
        CMPI   R5, 0x0020
        JZ     join_copy
        INC    R2
        CMPI   R5, 0x002F
        JNZ    join_scan
        MOV    R6, R2
        JUMP   join_scan
join_copy: LOADB R5, [R6]
        CMPI   R5, 0x0000
        JZ     join_end
        CMPI   R5, 0x0020
        JZ     join_end
        CMP    R3, R7
        JC     join_end
        STOREB R5, [R3]
        INC    R6
        INC    R3
        JUMP   join_copy
join_end: STOREB R0, [R3]
        RET

; file_copy, copies a file (jump table entry FILE_COPY), through memory from the heap
; ALLOCATE, read the old file in, save it under the new name, FREE
; in R1 = pointer to old path, R2 = pointer to new path, out R1 = 0 or an error (25 = no memory)
; R8 = old path, R9 = new path, R10 = borrowed memory, R11 = size
file_copy: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        MOV    R9, R2
        CALLF  fs_find                  ; how big is it, and is it a file
        CMPI   R1, 0x0000
        JNZ    copy_end
        LOAD   R11, [FS_FILE_SIZE]
        ADDI   R1, R11, 1               ; at least 1 byte, so an empty file works
        CALL   allocate
        CMPI   R1, 0x0000
        JZ     copy_no_memory
        MOV    R10, R1
        MOV    R1, R8
        MOV    R2, R10
        CALLF  file_read                ; old file into the borrowed memory
        CMPI   R1, 0x0000
        JNZ    copy_give_back
        MOV    R1, R9
        MOV    R2, R10
        MOV    R3, R11
        CALL   file_write               ; saved under the new name
copy_give_back: MOV R8, R1              ; keep the answer
        MOV    R1, R10
        CALL   free                     ; give the memory back
        MOV    R1, R8
        JUMP   copy_end
copy_no_memory: LOADLO R1, 25
copy_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

