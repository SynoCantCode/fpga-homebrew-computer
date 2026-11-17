; icons, the wallpaper name and the desktop icons picture
; included by wm.asm

; take_name, wallpaper name from the arguments at R8, or the default wallpaper
take_name: LOADB R1, [R8]
        CMPI   R1, 0x0000
        JNZ    take_typed
        LA     R8, default_wallpaper
take_typed: LOADLO R5, wall_name
        LOADLO R6, 0x003F
take_next: LOADB R1, [R8]
        CMPI   R1, 0x0000
        JZ     take_done
        CMPI   R1, 0x0020
        JZ     take_done
        STOREB R1, [R5]
        INC    R8
        INC    R5
        DEC    R6, 0b0100
        JNZ    take_next
take_done: STOREB R0, [R5]
        RET

; make_icons, desktop icons, 32 x 32 each, side by side in one picture
; window N icon at (32 x N, 0), around the drawing is KEY, see-through
; every app starts with a computer, its ICON.PIC replaces it
; R8 = count
make_icons: PUSH R8
        LOADHI R1, 0
        ORI    R1, R1, 0x8400           ; 33 KB, 32 rows of 1 KB + 1 KB to line it up
        CALLF  ALLOCATE
        CALL   align_1k
        STORE  R1, [icons]
        LOAD   R1, [DRAW_PAGE]
        STORE  R1, [saved_page]
        LOAD   R1, [icons]
        STORE  R1, [DRAW_PAGE]          ; draw into the icons picture
        LOADLO R8, 0                    ; all KEY first, 1024 dots as 4 boxes of 256
icon_clear: MOV R1, R8
        LOADLO R2, 0
        LOADLO R3, 256
        LOADLO R4, 32
        LOADLO R5, KEY
        CALL   box
        ADDI   R8, R8, 256
        CMPI   R8, 1024
        JNZ    icon_clear
        LOADLO R8, 0
icon_computers: SHIFTI R1, R8, 0x05, 0b0000
        CALL   icon_computer
        INC    R8
        CMPI   R8, APPS_MAX
        JNZ    icon_computers
icons_made:
        LOAD   R1, [saved_page]
        STORE  R1, [DRAW_PAGE]
        POP    R8
        RET

; icon_computer, draws the computer icon into the icons picture
; in R1 = left edge, R9 = left edge
icon_computer: PUSH R9
        MOV    R9, R1
        ADDI   R1, R9, 3                ; monitor
        LOADLO R2, 2
        LOADLO R3, 26
        LOADLO R4, 20
        LOADLO R5, BLACK_DOT
        CALL   box
        ADDI   R1, R9, 4
        LOADLO R2, 3
        LOADLO R3, 24
        LOADLO R4, 18
        LOADLO R5, SILVER
        CALL   box
        ADDI   R1, R9, 7                ; screen, sky blue
        LOADLO R2, 6
        LOADLO R3, 18
        LOADLO R4, 12
        LOADLO R5, 0x46
        CALL   box
        ADDI   R1, R9, 13               ; stand and keyboard
        LOADLO R2, 22
        LOADLO R3, 6
        LOADLO R4, 3
        LOADLO R5, SHADOW
        CALL   box
        ADDI   R1, R9, 2
        LOADLO R2, 25
        LOADLO R3, 28
        LOADLO R4, 5
        LOADLO R5, SILVER
        CALL   box
        POP    R9
        RET
