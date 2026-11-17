; a windows header, title, x, full screen and _ buttons, decorations
; included by winlib.asm

; title_bar, draws a windows header on the screen from its style
; 8 strips going from one colour to another, title, close box
; then the styles decorations, see-through pictures
; in R1 = the windows 128 bytes, R2 = 1 if its the front one
; R8 = window, R9 = front flag, R10 = strip / count, R11 = strip width / pointer
; R12 = style, R13 = header left / decoration x, R14 = header top / decoration y
title_bar: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        PUSH   R14
        MOV    R8, R1
        MOV    R9, R2
        LOAD   R12, [R8 + W_STYLE]
        LOAD   R13, [R12 + S_HEAD_L]    ; header left edge
        LOAD   R1, [R8 + W_X]
        ADD    R13, R13, R1
        LOAD   R1, [R12 + S_HEAD_T]     ; top
        LOAD   R2, [R8 + W_HEIGHT]
        CALL   from_edge
        LOAD   R2, [R8 + W_Y]
        ADD    R14, R1, R2
        LOAD   R11, [R8 + W_WIDTH]      ; width, the windows less the margins
        LOAD   R1, [R12 + S_HEAD_L]
        SUB    R11, R11, R1
        LOAD   R1, [R12 + S_HEAD_R]
        SUB    R11, R11, R1
        STORE  R11, [head_width]
        SHIFTI R11, R11, 0x03, 0b1000   ; a strip, an 8th of it
        LOAD   R1, [R12 + S_PICTURE]
        CMPI   R1, 0x0000
        JNZ    title_words              ; drawn style, picture has the header already
        LOADLO R10, 0
title_strip: MUL R1, R11, R10
        ADD    R1, R1, R13              ; strip x
        MOV    R3, R11
        CMPI   R10, 7
        JNZ    title_strip_width
        LOAD   R3, [head_width]         ; last strip reaches the right side exactly
        MULI   R4, R11, 7
        SUB    R3, R3, R4
title_strip_width: MOV R2, R14
        LOAD   R4, [R12 + S_HEAD_H]
        LOAD   R5, [R12 + S_HEAD_FROM]
        LOAD   R6, [R12 + S_HEAD_TO]
        CMPI   R9, 0x0000
        JNZ    title_colours
        LOAD   R5, [R12 + S_HEAD_BACK_FROM]
        LOAD   R6, [R12 + S_HEAD_BACK_TO]
title_colours: CALL blend               ; R5 = this strips colour
        CALL   box
        INC    R10
        CMPI   R10, 8
        JNZ    title_strip
title_words: LOAD R1, [R12 + S_TITLE_X] ; title, where the style says
        LOAD   R2, [head_width]
        CALL   from_edge
        ADD    R10, R1, R13
        LOAD   R1, [R12 + S_TITLE_Y]
        LOAD   R2, [R12 + S_HEAD_H]
        CALL   from_edge
        ADD    R2, R1, R14
        MOV    R1, R10
        LOAD   R3, [R8 + W_TITLE]
        LOAD   R4, [R12 + S_TITLE_FRONT]
        CMPI   R9, 0x0000
        JNZ    title_text_colour
        LOAD   R4, [R12 + S_TITLE_BACK]
title_text_colour: CALL text
        LOAD   R1, [R12 + S_CLOSE_DRAW] ; close box, unless the picture has its own
        CMPI   R1, 0x0000
        JZ     title_decorations
        MOV    R1, R8
        CALL   close_place
        MOV    R10, R1
        MOV    R11, R2
        LOADLO R3, 16
        LOADLO R4, 16
        LOADLO R6, 1
        CALL   title_lit                ; R5 = 1 raised, 2 lit up
        CALL   bevel_box
        ADDI   R1, R10, 4
        MOV    R2, R11
        LA     R3, close_text
        LOADLO R4, BLACK_DOT
        CALL   text
        LOAD   R1, [R12 + S_FULL_DRAW]  ; full screen button, a box with a window in it
        CMPI   R1, 0x0000               ; unless the picture has its own or the page says fullscreen no
        JZ     title_min
        LOAD   R1, [R8 + W_NO_FULL]
        CMPI   R1, 0x0000
        JNZ    title_min
        MOV    R1, R8
        CALL   full_place
        MOV    R10, R1
        MOV    R11, R2
        LOADLO R3, 16
        LOADLO R4, 16
        LOADLO R6, 2
        CALL   title_lit                ; R5 = 1 raised, 2 lit up
        CALL   bevel_box
        ADDI   R1, R10, 4               ; little window, outline and a thick top
        ADDI   R2, R11, 4
        LOADLO R3, 8
        LOADLO R4, 8
        LOADLO R5, BLACK_DOT
        CALL   box
        ADDI   R1, R10, 5
        ADDI   R2, R11, 6
        LOADLO R3, 6
        LOADLO R4, 5
        LOADLO R5, SILVER
        CALL   box
title_min: LOAD R1, [R12 + S_MIN_DRAW]  ; minimise button, a box with a line along its bottom
        CMPI   R1, 0x0000               ; unless the picture has its own
        JZ     title_decorations
        MOV    R1, R8
        CALL   min_place
        MOV    R10, R1
        MOV    R11, R2
        LOADLO R3, 16
        LOADLO R4, 16
        LOADLO R6, 3
        CALL   title_lit                ; R5 = 1 raised, 2 lit up
        CALL   bevel_box
        ADDI   R1, R10, 4
        ADDI   R2, R11, 10
        LOADLO R3, 7
        LOADLO R4, 2
        LOADLO R5, BLACK_DOT
        CALL   box
title_decorations: CALL title_hover      ; white frame round a title button under the pointer
        LOAD   R10, [R12 + S_DECO_COUNT] ; decorations
        ADDI   R11, R12, S_DECO
title_deco: CMPI R10, 0x0000
        JZ     title_done
        LOAD   R1, [R11 + 12]           ; x
        LOAD   R2, [R8 + W_WIDTH]
        CALL   from_edge
        LOAD   R2, [R8 + W_X]
        ADD    R13, R1, R2
        LOAD   R1, [R11 + 16]           ; y
        LOAD   R2, [R8 + W_HEIGHT]
        CALL   from_edge
        LOAD   R2, [R8 + W_Y]
        ADD    R14, R1, R2
        CMPIS  R13, 0
        JGE    title_deco_x
        JUMP   title_deco_next          ; off the left of the screen, left out
title_deco_x: CMPIS R14, 0
        JGE    title_deco_y
        JUMP   title_deco_next          ; off the top
title_deco_y: SHIFTI R14, R14, 0x10, 0b0000
        OR     R1, R13, R14
        LOAD   R2, [R11 + 4]            ; size
        LOAD   R3, [R11 + 8]
        SHIFTI R3, R3, 0x10, 0b0000
        OR     R2, R2, R3
        LOAD   R3, [R11]
        ORI    R3, R3, KEY
        LOADLO R4, 0
        CALLF  DRAW_SPRITE
title_deco_next: ADDI R11, R11, 20
        DEC    R10
        JUMP   title_deco
title_done: POP R14
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; full_place, where the full screen button is on the screen
; in R1 = the windows 128 bytes, out R1 = x, R2 = y, uses R3-R5
full_place: MOV R5, R1
        LOAD   R3, [R5 + W_STYLE]
        LOAD   R1, [R3 + S_FULL_Y]
        LOAD   R2, [R5 + W_HEIGHT]
        CALL   from_edge
        LOAD   R2, [R5 + W_Y]
        ADD    R4, R1, R2
        LOAD   R1, [R3 + S_FULL_X]
        LOAD   R2, [R5 + W_WIDTH]
        CALL   from_edge
        LOAD   R2, [R5 + W_X]
        ADD    R1, R1, R2
        MOV    R2, R4
        RET

; scrolling, the window shows rows scroll to scroll + its rows of the page
