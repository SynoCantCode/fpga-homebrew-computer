; files and paths, load_text, make_path, sprites
; included by winlib.asm

; find_app, in R1 = pointer to an apps name, out R1 = its window 0-3 or -1
; case ignored, R8 = name, R9 = window
find_app: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADLO R9, 0
find_next: CMPI R9, APP_SLOTS
        JZ     find_none
        MOV    R1, R9
        CALL   window_record
        LOAD   R2, [R1 + W_KIND]
        CMPI   R2, KIND_PAGE
        JNZ    find_skip
        LOAD   R2, [R1 + W_NAME]
        MOV    R1, R8
        CALL   text_same
        CMPI   R3, 1
        JZ     find_found
find_skip: INC R9
        JUMP   find_next
find_found: MOV R1, R9
        JUMP   find_end
find_none: NOT R1, R0
find_end: POP R9
        POP    R8
        RET

; text_same, in R1, R2 = pointers to two texts, out R3 = 1 same, 0 not
; case ignored, uses R1, R2, R4, R5
text_same: LOADB R4, [R1]
        LOADB  R5, [R2]
        CMPI   R4, 0x0041
        JNC    same_small_1
        CMPI   R4, 0x005B
        JC     same_small_1
        ADDI   R4, R4, 0x20
same_small_1: CMPI R5, 0x0041
        JNC    same_small_2
        CMPI   R5, 0x005B
        JC     same_small_2
        ADDI   R5, R5, 0x20
same_small_2: CMP R4, R5
        JNZ    same_differ
        CMPI   R4, 0x0000
        JZ     same_yes
        INC    R1
        INC    R2
        JUMP   text_same
same_yes: LOADLO R3, 1
        RET
same_differ: LOADLO R3, 0
        RET

; load_text, whole text file into the heap, 0 after it
; line ends 0x0D, 0x0A become 0s, tabs become spaces
; in R1 = pointer to path, out R1 = pointer to text or 0, R2 = its end
load_text: PUSH R8
        PUSH   R9
        MOV    R8, R1
        CALLF  FILE_SIZE
        CMPI   R1, 0x0000
        JNZ    text_failed
        MOV    R9, R2
        ADDI   R1, R9, 1
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     text_failed
        MOV    R2, R1
        MOV    R1, R8
        MOV    R8, R2
        CALLF  FILE_READ
        CMPI   R1, 0x0000
        JNZ    text_free
        ADD    R9, R8, R9               ; R9 = end
        STOREB R0, [R9]
        MOV    R1, R8
text_scan: CMP R1, R9
        JC     text_done
        LOADB  R2, [R1]
        CMPI   R2, 0x000D
        JZ     text_line_end
        CMPI   R2, 0x000A
        JZ     text_line_end
        CMPI   R2, 0x0009
        JNZ    text_scan_next
        LOADLO R2, 0x0020
        STOREB R2, [R1]
        JUMP   text_scan_next
text_line_end: STOREB R0, [R1]
text_scan_next: INC R1
        JUMP   text_scan
text_done: MOV R1, R8
        MOV    R2, R9
        JUMP   text_end
text_free: MOV R1, R8
        CALLF  FREE
text_failed: LOADLO R1, 0
text_end: POP R9
        POP    R8
        RET

; make_path, "/apps/" + app name + "/" + file name, built in path
; in R1, R2 = pointers to the two names, out R1 = path
make_path: MOV R3, R2
        MOV    R2, R1
        LA     R1, apps_prefix

; build_path, folder path + name + "/" + file name, built in path
; in R1, R2, R3 = pointers to the three, out R1 = path
build_path: PUSH R8
        PUSH   R9
        MOV    R8, R2
        MOV    R9, R3
        LOADLO R2, path
        CALL   text_copy
        MOV    R1, R8
        CALL   text_copy
        LOADLO R3, 0x002F               ; '/'
        STOREB R3, [R2]
        INC    R2
        MOV    R1, R9
        CALL   text_copy
        LOADLO R1, path
        POP    R9
        POP    R8
        RET

; load_sprite, picture from /APPS/NAME/FILE, else /SYSTEM/DESIGN/SPRITES/FILE
; else /SYSTEM/DESIGN/BIGSPRTS/FILE, only when sprite_place is 0
; in R1 = pointer to app name, R2 = pointer to file name
; out like load_picture, R1 = width or 0, R2 = height, R3 = where
load_sprite: PUSH R8
        PUSH   R9
        MOV    R8, R1
        MOV    R9, R2
        CALL   make_path
        LOAD   R2, [sprite_place]       ; 0 = room from the heap, else that memory
        CALL   load_picture
        CMPI   R1, 0x0000
        JNZ    load_sprite_done
        LA     R1, design_prefix
        LA     R2, sprites_name
        MOV    R3, R9
        CALL   build_path               ; "/system/design/sprites/FILE"
        LOAD   R2, [sprite_place]
        CALL   load_picture
        CMPI   R1, 0x0000
        JNZ    load_sprite_done
        LOAD   R2, [sprite_place]       ; an icon, no big sprites
        CMPI   R2, 0x0000
        JNZ    load_sprite_done
        LA     R1, design_prefix
        LA     R2, bigsprts_name
        MOV    R3, R9
        CALL   build_path               ; "/system/design/bigsprts/FILE"
        LOADLO R2, 0
        CALL   load_picture
load_sprite_done: POP R9
        POP    R8
        RET

; app host, real apps loaded, called, ticked and drawn
; each program starts with the same jump table
