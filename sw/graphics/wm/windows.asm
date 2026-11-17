; windows, empties the window slots, sizes each windows picture
; included by wm.asm

; make_windows, every window slot empty, order 0-7
; then load_apps, the ones that start open get a window
; R8 = window, R9 = its 128 bytes
make_windows: PUSH R8
        PUSH   R9
        PUSH   R10
        LOADLO R8, 0
make_empty: MOV R1, R8
        CALL   window_record
        LOADLO R2, KIND_NONE
        STORE  R2, [R1 + W_KIND]        ; the rest is 0 already
        LOADLO R2, styles
        STORE  R2, [R1 + W_STYLE]       ; default style
        LOADLO R1, order
        SHIFTI R2, R8, 0x02, 0b0000
        ADD    R1, R1, R2
        STORE  R8, [R1]
        INC    R8
        CMPI   R8, WINDOW_COUNT
        JNZ    make_empty
        CALL   load_apps                ; app records and icons, ones not hidden are opened
        CALL   decor_load               ; decorations, DECOR.TXT
        POP    R10
        POP    R9
        POP    R8
        RET

; window_room, makes the windows picture big enough for its height
; rows 1 KB apart in the heap, too small = freed and a new one taken
; new one has 32 rows to spare, up to 480
; no room = W_PICTURE = 0, the window isnt drawn
; in R8 = the windows 128 bytes, out R1 = 1 has one, 0 no room
; R9 = place of its row count, R10 = place of its raw address
; R11 = rows
window_room: PUSH R9
        PUSH   R10
        PUSH   R11
        LOADLO R1, windows              ; word offset, (record - windows) / 128 x 4
        SUB    R1, R8, R1
        SHIFTI R1, R1, 0x07, 0b1000
        SHIFTI R1, R1, 0x02, 0b0000
        LOADLO R9, picture_rows
        ADD    R9, R9, R1
        LOADLO R10, picture_raw
        ADD    R10, R10, R1
        LOAD   R1, [R9]                 ; room for its height already?
        LOAD   R2, [R8 + W_HEIGHT]
        CMPI   R1, 0x0000
        JZ     room_new
        CMP    R1, R2
        JC     room_ok                  ; rows >= height
room_new: LOAD R1, [R10]                ; give the old one back
        CMPI   R1, 0x0000
        JZ     room_take
        CALLF  FREE
        STORE  R0, [R10]
room_take: LOAD R11, [R8 + W_HEIGHT]    ; height + 32, at most 480
        ADDI   R11, R11, 32
        CMPI   R11, 481
        JNC    room_size
        LOADLO R11, 480
room_size: SHIFTI R1, R11, 0x0A, 0b0000 ; x 1 KB, + 1 KB to line it up
        ADDI   R1, R1, 1024
        CALLF  ALLOCATE
        STORE  R1, [R10]
        CMPI   R1, 0x0000
        JZ     room_none
        CALL   align_1k
        STORE  R1, [R8 + W_PICTURE]
        STORE  R11, [R9]
room_ok: LOADLO R1, 1
        JUMP   room_end
room_none: STORE R0, [R8 + W_PICTURE]   ; no room, no picture, not drawn
        STORE  R0, [R9]
        LOADLO R1, 0
room_end: POP R11
        POP    R10
        POP    R9
        RET
