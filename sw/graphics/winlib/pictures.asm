; window records, .PIC files loaded
; included by winlib.asm

; window_record, in R1 = window number, out R1 = pointer to its 128 bytes, uses R2
window_record: SHIFTI R1, R1, 0x07, 0b0000
        LOADLO R2, windows
        ADD    R1, R1, R2
        RET

; load_picture, a .PIC file into memory, rows 1 KB apart for the blitter
; .PIC = "PIC1", width, height, a byte a dot
; in R1 = pointer to path, R2 = where, a multiple of 1 KB, or 0 = from the heap
; out R1 = width or 0 if it couldnt, R2 = height, R3 = where
; R8 = file memory then next dot, R9 = width, R10 = height, R11 = answer
; R12 = path / row, R13 = where, R4 = dot in the row, R5 = rows left
load_picture: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        MOV    R12, R1
        MOV    R13, R2
        LOADLO R11, 0
        LOADLO R10, 0
        MOV    R1, R12
        CALLF  FILE_SIZE                ; R2 = size
        CMPI   R1, 0x0000
        JNZ    picture_done
        MOV    R8, R2
        CMPI   R8, 8
        JNC    picture_done             ; shorter than its header
        MOV    R1, R8
        CALLF  ALLOCATE                 ; room for the whole file
        CMPI   R1, 0x0000
        JZ     picture_done
        STORE  R1, [file_memory]
        MOV    R2, R1
        MOV    R1, R12
        CALLF  FILE_READ
        CMPI   R1, 0x0000
        JNZ    picture_free
        LOAD   R8, [file_memory]
        LOAD   R1, [R8]                 ; "PIC1"?
        LOADHI R2, 0x3143
        ORI    R2, R2, 0x4950
        CMP    R1, R2
        JNZ    picture_free
        LOADB  R9, [R8 + 4]             ; width
        LOADB  R1, [R8 + 5]
        SHIFTI R1, R1, 0x08, 0b0000
        OR     R9, R9, R1
        LOADB  R10, [R8 + 6]            ; height
        LOADB  R1, [R8 + 7]
        SHIFTI R1, R1, 0x08, 0b0000
        OR     R10, R10, R1
        CMPI   R9, 0x0000
        JZ     picture_free
        CMPI   R9, 1025                 ; up to 1024 wide, a rows 1 KB
        JC     picture_free
        CMPI   R10, PIXELS_DOWN + 1
        JC     picture_free
        CMPI   R13, 0x0000
        JNZ    picture_room
        SHIFTI R1, R10, 0x0A, 0b0000    ; room from the heap, height x 1 KB + 1 KB
        ADDI   R1, R1, 0x400
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     picture_free
        STORE  R1, [picture_got]        ; what ALLOCATE gave, FREE needs it
        CALL   align_1k
        MOV    R13, R1
picture_room: MOV R11, R9               ; worked, answer = width
        ADDI   R8, R8, 8
        MOV    R12, R13
        MOV    R5, R10
picture_row: CMPI R5, 0x0000
        JZ     picture_free
        LOADLO R4, 0
picture_dot: CMP R4, R9
        JC     picture_row_done
        LOADB  R1, [R8]
        ADD    R2, R12, R4
        STOREB R1, [R2]
        INC    R8
        INC    R4
        JUMP   picture_dot
picture_row_done: ADDI R12, R12, 0x400
        DEC    R5
        JUMP   picture_row
picture_free: LOAD R1, [file_memory]    ; free the file, the picture stays
        CALLF  FREE
picture_done: MOV R1, R11
        MOV    R2, R10
        MOV    R3, R13
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; align_1k, in R1 = address, out R1 = next multiple of 1 KB (0x400), uses R1, R2
align_1k: ADDI R1, R1, 0x3FF
        LOADHI R2, 0xFFFF
        ORI    R2, R2, 0xFC00
        AND    R1, R1, R2
        RET
