; SHOW, shows a picture file.   run show.bin NAME.PIC   any key goes back
; pictures are made on the PC by make_picture.py
; .PIC = "PIC1", width (2 bytes), height (2 bytes), then one byte per dot
; the file is read into heap memory, its rows laid out 1 KB apart
; in PICTURE_STORE (0x1010_0000), then copied to the screen, centred
; R8 = file name, then its memory, R9 = size, then width, R10 = height
; R11, R12 = pointers from / to, R13 = a count
.include "sw/os/devices.asm"
.org PROGRAM_SDRAM

start:  PUSH   R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        MOV    R8, R2                   ; R2 = the file's name
        LOADB  R1, [R8]
        CMPI   R1, 0x0000
        JZ     no_name
        MOV    R1, R8
        CALLF  FILE_SIZE                ; R1 = 0 or an error, R2 = size
        CMPI   R1, 0x0000
        JNZ    file_error
        MOV    R9, R2
        CMPI   R9, 8
        JNC    not_a_picture            ; shorter than its header
        MOV    R1, R9
        CALLF  ALLOCATE                 ; room for the whole file
        CMPI   R1, 0x0000
        JZ     no_room
        MOV    R2, R1
        MOV    R1, R8
        MOV    R8, R2                   ; R8 = the file's memory
        CALLF  FILE_READ
        CMPI   R1, 0x0000
        JNZ    file_error_free
        LOAD   R1, [R8]                 ; "PIC1"?
        LOADHI R2, 0x3143
        ORI    R2, R2, 0x4950           ; 'P' 'I' 'C' '1', lowest byte first
        CMP    R1, R2
        JNZ    not_a_picture_free
        LOADB  R9, [R8 + 4]             ; width, 2 bytes, lowest first
        LOADB  R1, [R8 + 5]
        SHIFTI R1, R1, 0x08, 0b0000
        OR     R9, R9, R1
        LOADB  R10, [R8 + 6]            ; height
        LOADB  R1, [R8 + 7]
        SHIFTI R1, R1, 0x08, 0b0000
        OR     R10, R10, R1
        CMPI   R9, PIXELS_ACROSS + 1
        JC     too_big_free
        CMPI   R10, PIXELS_DOWN + 1
        JC     too_big_free
        ; row y goes to PICTURE_STORE + y x 1024
        ADDI   R11, R8, 8               ; R11 = pointer to the file's next dot
        LOADHI R12, PICTURE_STORE_HIGH  ; R12 = pointer to the row in the store
        MOV    R13, R10                 ; R13 = rows left
copy_row: CMPI R13, 0x0000
        JZ     copied
        LOADLO R4, 0                    ; R4 = dot in the row
copy_dot: CMP  R4, R9
        JC     copy_row_done
        LOADB  R1, [R11]
        ADD    R2, R12, R4
        STOREB R1, [R2]
        INC    R11
        INC    R4
        JUMP   copy_dot
copy_row_done: ADDI R12, R12, 0x400     ; next row of the store
        DEC    R13
        JUMP   copy_row
copied: MOV    R1, R8
        CALLF  FREE                     ; free the file's memory
        LOADLO R1, LAYER_PIXELS
        CALLF  GRAPHICS_MODE            ; pixels only
        LOADLO R1, 0x0000
        CALLF  DRAW_CLEAR               ; black around it
        LOADLO R1, PIXELS_ACROSS
        SUB    R1, R1, R9
        SHIFTI R1, R1, 0x01, 0b1000     ; x = (640 - width) / 2
        LOADLO R2, PIXELS_DOWN
        SUB    R2, R2, R10
        SHIFTI R2, R2, 0x01, 0b1000     ; y = (480 - height) / 2
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2               ; where it goes
        SHIFTI R2, R10, 0x10, 0b0000
        OR     R2, R2, R9               ; its size
        LOADHI R3, PICTURE_STORE_HIGH   ; from the store
        LOADLO R4, 0                    ; its top-left
        CALLF  DRAW_COPY
        CALLF  DRAW_FLIP                ; show the page
wait_key: CALLF GET_CHAR
        CMPIS  R1, -1
        JZ     wait_key                 ; any key, back
        LOADLO R1, LAYER_TEXT
        CALLF  GRAPHICS_MODE
        JUMP   done

no_name: LA     R1, usage_text
        CALLF  SCREEN_LINE
        JUMP   done
file_error_free: MOV R9, R1             ; the error number
        MOV    R1, R8
        CALLF  FREE
        MOV    R1, R9
file_error: MOV R9, R1
        LA     R1, file_error_text
        CALLF  SCREEN_TEXT
        MOV    R1, R9
        CALLF  SCREEN_HEX_WORD
        LOADLO R1, 0x000A
        CALLF  SCREEN_CHAR
        JUMP   done
no_room: LA     R1, no_room_text
        CALLF  SCREEN_LINE
        JUMP   done
too_big_free: MOV R1, R8
        CALLF  FREE
        LA     R1, too_big_text
        CALLF  SCREEN_LINE
        JUMP   done
not_a_picture_free: MOV R1, R8
        CALLF  FREE
not_a_picture: LA     R1, not_picture_text
        CALLF  SCREEN_LINE
done:   POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

usage_text:       .string "use: run show.bin NAME.PIC   (pictures from make_picture.py)"
file_error_text:  .string "can't read it: file error "
no_room_text:     .string "not enough memory for it"
too_big_text:     .string "that picture is bigger than 640 x 480"
not_picture_text: .string "that isn't a .PIC picture (made by make_picture.py)"
