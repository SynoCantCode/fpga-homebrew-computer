; pointer, the mouse pointer picture, POINTER.PTR
; included by wm.asm

; load_pointer, pointer look from /SYSTEM/DESIGN/POINTER.PTR
; 16 words = 16 rows, 2 bits a dot, 0 see-through, 1-3 colours, then 3 colours 0x00RRGGBB
; no file = the ROM arrow stays
load_pointer: LA R1, pointer_path
        CALL   read_pointer
        CMPI   R1, 0x0000
        JZ     busy_none
        PUSH   R1
        CALL   show_pointer
        POP    R1
        CALLF  FREE
        RET

; show_pointer, 16 rows into POINTER_PICTURE, 3 colours into POINTER_COLOUR_1-3
; in R1 = pointer to the 76 bytes, 0 = no change, uses R1-R5
show_pointer: CMPI R1, 0x0000
        JZ     busy_none
        LOADHI R3, 0xFFFF               ; R3 = POINTER_PICTURE, 0xFFFF_9100
        ORI    R3, R3, 0x9100
        MOV    R4, R1
        LOADLO R5, 16
pointer_row: LOAD R2, [R4]
        STORE  R2, [R3]
        ADDI   R3, R3, 4
        ADDI   R4, R4, 4
        DEC    R5
        CMPI   R5, 0x0000
        JNZ    pointer_row
        LOAD   R2, [R1 + 64]
        STORE  R2, [POINTER_COLOUR_1]
        LOAD   R2, [R1 + 68]
        STORE  R2, [POINTER_COLOUR_2]
        LOAD   R2, [R1 + 72]
        STORE  R2, [POINTER_COLOUR_3]
busy_none: RET

; read_pointer, a .PTR file into the heap
; in R1 = path, out R1 = pointer to its 76 bytes or 0, R8 = path then memory
read_pointer: PUSH R8
        MOV    R8, R1
        CALLF  FILE_SIZE
        CMPI   R1, 0x0000
        JNZ    read_pointer_none
        CMPI   R2, 76                   ; exactly 19 words
        JNZ    read_pointer_none
        LOADLO R1, 76
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     read_pointer_done
        MOV    R2, R1
        MOV    R1, R8
        MOV    R8, R2
        CALLF  FILE_READ
        CMPI   R1, 0x0000
        JNZ    read_pointer_free
        MOV    R1, R8
        JUMP   read_pointer_done
read_pointer_free: MOV R1, R8
        CALLF  FREE
read_pointer_none: LOADLO R1, 0
read_pointer_done: POP R8
        RET

; services an app calls, CALLF WM_BOX and so on
