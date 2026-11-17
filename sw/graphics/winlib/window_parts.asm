; where a windows parts are, canvas, lit buttons, the _ and x places
; included by winlib.asm

; canvas_of, a pages first canvas, in R1 = the windows 128 bytes
; out R1 = pointer to the canvas element or 0, uses R2-R4
canvas_of: LOAD R2, [R1 + W_ELEMENTS]
        LOAD   R3, [R1 + W_ELEMENT_COUNT]
canvas_next: CMPI R3, 0x0000
        JZ     canvas_none
        LOADB  R4, [R2]
        CMPI   R4, E_CANVAS
        JZ     canvas_found
        ADDI   R2, R2, ELEMENT_BYTES
        DEC    R3
        JUMP   canvas_next
canvas_found: MOV R1, R2
        RET
canvas_none: LOADLO R1, 0
        RET

; title_lit, out R5 = 2 lit up if the pointer is over the button, else 1
; in R6 = 1 close, 2 full, 3 minimise, R8 = the windows 128 bytes, uses R5-R7
title_lit: LOADLO R5, windows
        SUB    R7, R8, R5
        SHIFTI R7, R7, 0x07, 0b1000
        SHIFTI R7, R7, 0x02, 0b0000
        OR     R7, R7, R6               ; window x 4 + which
        LOADLO R5, 1
        LOAD   R6, [hover_title]
        CMP    R6, R7
        JNZ    title_lit_done
        LOADLO R5, 2
title_lit_done: RET

; title_hover, 16 x 16 white frame round the title button under the pointer
; in R8 = the windows 128 bytes, uses R1-R7
title_hover: LOAD R1, [hover_title]
        CMPIS  R1, -1
        JNZ    title_hover_some
        RET
title_hover_some: LOADLO R2, windows    ; this windows?
        SUB    R3, R8, R2
        SHIFTI R3, R3, 0x07, 0b1000
        SHIFTI R2, R1, 0x02, 0b1000
        CMP    R2, R3
        JZ     title_hover_this
        RET
title_hover_this: ANDI R6, R1, 0x0003
        MOV    R1, R8
        CMPI   R6, 1
        JNZ    title_hover_full
        CALL   close_place
        JUMP   title_hover_frame
title_hover_full: CMPI R6, 2
        JNZ    title_hover_min
        CALL   full_place
        JUMP   title_hover_frame
title_hover_min: CALL min_place
title_hover_frame: PUSH R1              ; R1, R2 = top left, four white lines
        PUSH   R2
        LOADLO R3, 16
        LOADLO R4, 1
        LOADLO R5, WHITE_DOT
        CALL   box
        POP    R2
        POP    R1
        PUSH   R1
        PUSH   R2
        ADDI   R2, R2, 15
        LOADLO R3, 16
        LOADLO R4, 1
        LOADLO R5, WHITE_DOT
        CALL   box
        POP    R2
        POP    R1
        PUSH   R1
        PUSH   R2
        LOADLO R3, 1
        LOADLO R4, 16
        LOADLO R5, WHITE_DOT
        CALL   box
        POP    R2
        POP    R1
        ADDI   R1, R1, 15
        LOADLO R3, 1
        LOADLO R4, 16
        LOADLO R5, WHITE_DOT
        JUMP   box

; min_place, where the minimise button is on the screen
; in R1 = the windows 128 bytes, out R1 = x, R2 = y, uses R3-R5
min_place: MOV R5, R1
        LOAD   R3, [R5 + W_STYLE]
        LOAD   R1, [R3 + S_MIN_Y]
        LOAD   R2, [R5 + W_HEIGHT]
        CALL   from_edge
        LOAD   R2, [R5 + W_Y]
        ADD    R4, R1, R2
        LOAD   R1, [R3 + S_MIN_X]
        LOAD   R2, [R5 + W_WIDTH]
        CALL   from_edge
        LOAD   R2, [R5 + W_X]
        ADD    R1, R1, R2
        MOV    R2, R4
        RET

; blend, in R5 = first colour, R6 = last, R10 = strip 0-7
; out R5 = first + (last - first) x strip / 7, uses R6
blend:  CMP    R6, R5
        JC     blend_up
        SUB    R6, R5, R6               ; going down
        MUL    R6, R6, R10
        DIVUI  R6, R6, 7
        SUB    R5, R5, R6
        RET
blend_up: SUB  R6, R6, R5               ; going up
        MUL    R6, R6, R10
        DIVUI  R6, R6, 7
        ADD    R5, R5, R6
        RET

; from_edge, in R1 = place from a style, R2 = the size its in
; out R1 = place from the left / top, below 0 = size + it
from_edge: CMPIS R1, 0
        JGE    from_edge_done
        ADD    R1, R1, R2
from_edge_done: RET

; close_place, where the close box is on the screen
; in R1 = the windows 128 bytes, out R1 = x, R2 = y, uses R3-R5
close_place: MOV R5, R1
        LOAD   R3, [R5 + W_STYLE]
        LOAD   R1, [R3 + S_CLOSE_Y]
        LOAD   R2, [R5 + W_HEIGHT]
        CALL   from_edge
        LOAD   R2, [R5 + W_Y]
        ADD    R4, R1, R2
        LOAD   R1, [R3 + S_CLOSE_X]
        LOAD   R2, [R5 + W_WIDTH]
        CALL   from_edge
        LOAD   R2, [R5 + W_X]
        ADD    R1, R1, R2
        MOV    R2, R4
        RET
