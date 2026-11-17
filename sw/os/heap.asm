; heap, the kernels memory allocator
; 5 MB of SDRAM from HEAP_START to HEAP_END
; each piece starts with an 8 byte label
; [label][bytes][label][bytes]...
; word 0 = piece size with the label, multiple of 8
; word 4 = 1 taken, 0 free
; the pointer given out = just after the label
; the shell resets the heap every time it starts

; heap_init, the whole heap becomes one free piece
heap_init: LOADHI R5, HEAP_START_HIGH   ; R5 = first label, 0x1030_0000
        LOADHI R6, HEAP_SIZE_HIGH       ; R6 = heap size, 0x0050_0000
        STORE  R6, [R5]                 ; first label, size = whole heap
        STORE  R0, [R5 + 4]             ; free
        RET

; allocate, first fit, splits a piece thats too big
; in R1 = bytes wanted, out R1 = pointer or 0
; uses R1-R7, R5 = label, R6 = heap end, R7 = piece size
allocate: CMPI R1, 0x0000
        JZ     allocate_none            ; 0 bytes, nothing to give
        ADDI   R1, R1, 7                ; round up to a multiple of 8
        SHIFTI R1, R1, 0x03, 0b1000     ; divide by 8
        SHIFTI R2, R1, 0x03, 0b0000     ; times 8
        ADDI   R2, R2, 8                ; + 8 for the label, R2 = size needed
        LOADHI R5, HEAP_START_HIGH      ; R5 = first label
        LOADHI R6, HEAP_END_HIGH        ; R6 = heap end, 0x1080_0000
allocate_next: CMP R5, R6
        JC     allocate_none            ; past the end, nothing big enough
        LOAD   R7, [R5]                 ; R7 = piece size
        CMPI   R7, 0x0000
        JZ     allocate_none            ; size 0 = damaged labels, give up
        LOAD   R3, [R5 + 4]             ; R3 = 1 taken, 0 free
        CMPI   R3, 0x0000
        JNZ    allocate_skip            ; taken, next piece
        CMP    R7, R2
        JNC    allocate_skip            ; too small, next piece
        SUB    R4, R7, R2               ; R4 = what would be left over
        CMPI   R4, 16
        JNC    allocate_whole           ; less than 16 left, take the whole piece
        ADD    R3, R5, R2               ; split, R3 = label of the new free piece
        STORE  R4, [R3]                 ; its size = the left over
        STORE  R0, [R3 + 4]             ; free
        STORE  R2, [R5]                 ; this piece shrinks to the size needed
allocate_whole: LOADLO R3, 0x0001
        STORE  R3, [R5 + 4]             ; taken
        ADDI   R1, R5, 8                ; R1 = pointer just past the label
        RET
allocate_skip: ADD R5, R5, R7           ; next label is right after this piece
        JUMP   allocate_next
allocate_none: LOADLO R1, 0x0000        ; no room
        RET

; free, gives a piece back and joins free neighbours
; in R1 = pointer from allocate, 0 = nothing to do
; uses R1-R7
free: CMPI R1, 0x0000
        JZ     free_done
        SUBI   R1, R1, 8                ; R1 = the pieces label
        STORE  R0, [R1 + 4]             ; free
        LOADHI R5, HEAP_START_HIGH      ; join free neighbours, R5 = label
        LOADHI R6, HEAP_END_HIGH
free_next: LOAD R7, [R5]                ; R7 = piece size
        CMPI   R7, 0x0000
        JZ     free_done                ; damaged labels, stop
        ADD    R2, R5, R7               ; R2 = next label
        CMP    R2, R6
        JC     free_done                ; last piece
        LOAD   R3, [R5 + 4]
        LOAD   R4, [R2 + 4]
        OR     R3, R3, R4               ; 0 only if both free
        JNZ    free_move_on
        LOAD   R4, [R2]                 ; both free, this piece takes the next one
        ADD    R7, R7, R4
        STORE  R7, [R5]
        JUMP   free_next                ; stay here, the one after may be free too
free_move_on: MOV R5, R2
        JUMP   free_next
free_done: RET
