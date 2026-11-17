; drawing helpers, raised / sunken boxes, hourglass, box, text
; included by winlib.asm

; bevel_box, Windows 95 box, silver with light and dark edges
; in R1 = x, R2 = y, R3 = width, R4 = height
; R5 = 1 raised, 0 pressed in, 2 raised and lit up
; R8-R11 = x, y, width, height, R12 = light colour, R13 = dark colour
bevel_box: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        MOV    R8, R1
        MOV    R9, R2
        MOV    R10, R3
        MOV    R11, R4
        LOADLO R12, WHITE_DOT
        LOADLO R13, SHADOW
        CMPI   R5, 0x0000
        JNZ    bevel_raised
        LOADLO R12, SHADOW
        LOADLO R13, WHITE_DOT
        LOADLO R5, SILVER
        JUMP   bevel_fill
bevel_raised: CMPI R5, 2
        JZ     bevel_lit
        LOADLO R5, SILVER
        JUMP   bevel_fill
bevel_lit: LOADLO R5, BUTTON_HOVER
bevel_fill: CALL box
        MOV    R1, R8
        MOV    R2, R9
        MOV    R3, R10
        LOADLO R4, 1
        MOV    R5, R12
        CALL   box                      ; top edge
        MOV    R1, R8
        MOV    R2, R9
        LOADLO R3, 1
        MOV    R4, R11
        MOV    R5, R12
        CALL   box                      ; left edge
        MOV    R1, R8
        ADD    R2, R9, R11
        SUBI   R2, R2, 1
        MOV    R3, R10
        LOADLO R4, 1
        MOV    R5, R13
        CALL   box                      ; bottom edge
        ADD    R1, R8, R10
        SUBI   R1, R1, 1
        MOV    R2, R9
        LOADLO R3, 1
        MOV    R4, R11
        MOV    R5, R13
        CALL   box                      ; right edge
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; hourglass, turns in the middle of the screen while WM loads
; /SYSTEM/DESIGN/SPRITES/HOURGLAS.PIC, 16 frames of 32 x 32 side by side
; drawn on PAGE_0 under the text screen
; the 4 x 2 text cells in the middle get background 0 = see-through
; hg_tick is the kernels TIMER_JOB, 100 ticks a second
; every 10th tick it copies the next frame
; hourglass_start, reads the strip, clears the cells, frame 0, sets the timer job
; no HOURGLAS.PIC = nothing, uses R1-R7
hourglass_start: STORE R0, [hg_strip]
        LA     R1, nothing_name         ; no app folder, shared sprites
        LA     R2, hourglass_name
        CALL   load_sprite              ; R1 = width, 0 not there, R3 = where
        CMPI   R1, 0x0000
        JZ     hg_done
        STORE  R3, [hg_strip]
        LOADHI R5, TEXT_SCREEN_HIGH     ; the 4 x 2 cells see-through, all 0
        ORI    R5, R5, HG_CELLS
        STORE  R0, [R5]
        STORE  R0, [R5 + 4]
        STORE  R0, [R5 + 8]
        STORE  R0, [R5 + 12]
        STORE  R0, [R5 + 320]           ; next row, + ROW_BYTES
        STORE  R0, [R5 + 324]
        STORE  R0, [R5 + 328]
        STORE  R0, [R5 + 332]
        STORE  R0, [hg_frame]
        CALL   hg_draw                  ; frame 0
        LOADLO R1, LAYER_PIXELS + LAYER_TEXT
        CALLF  GRAPHICS_MODE
        STORE  R0, [hg_ticks]
        LA     R1, hg_tick
        STORE  R1, [TIMER_JOB]          ; timer turns it
hg_done: RET

; hourglass_stop, timer job off first, then the hourglass
hourglass_stop: STORE R0, [TIMER_JOB]
        STORE  R0, [hg_strip]
        RET

; hg_tick, the TIMER_JOB, runs inside the timer interrupt
; plain loads and stores only, R1-R7 only, next frame 0-15 every 10th tick
hg_tick: LOAD  R1, [hg_ticks]
        INC    R1
        STORE  R1, [hg_ticks]
        CMPI   R1, 10
        JNC    hg_tick_done             ; not yet
        STORE  R0, [hg_ticks]
        LOAD   R1, [hg_frame]
        INC    R1
        ANDI   R1, R1, 0x000F
        STORE  R1, [hg_frame]
; hg_draw, copies frame hg_frame to PAGE_0 at (HG_X, HG_Y), dot by dot
; see-through dots 0xFE become HG_BLUE
; R1 = strip pointer, R2 = page pointer, R3 = rows left, R4 = dots left, R5 = dot, R6 = frame
hg_draw: LOAD  R1, [hg_strip]
        CMPI   R1, 0x0000
        JZ     hg_tick_done
        LOAD   R6, [hg_frame]
        SHIFTI R6, R6, 0x05, 0b0000     ; first dot = strip + 32 x frame
        ADD    R1, R1, R6
        LOADHI R2, HG_DOTS_HIGH
        ORI    R2, R2, HG_DOTS_LOW
        LOADLO R3, 32
hg_row: LOADLO R4, 32
hg_dot: LOADB  R5, [R1]
        CMPI   R5, KEY
        JNZ    hg_put
        LOADLO R5, HG_BLUE
hg_put: STOREB R5, [R2]
        INC    R1
        INC    R2
        DEC    R4
        CMPI   R4, 0x0000
        JNZ    hg_dot
        ADDI   R1, R1, 992              ; next row, 1024 - 32
        ADDI   R2, R2, 992
        DEC    R3
        CMPI   R3, 0x0000
        JNZ    hg_row
hg_tick_done: RET

; box, DRAW_RECT, in R1 = x, R2 = y, R3 = width, R4 = height, R5 = colour
box:    SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        SHIFTI R4, R4, 0x10, 0b0000
        OR     R2, R3, R4
        MOV    R3, R5
        JUMPF  DRAW_RECT                ; tail call

; text, DRAW_TEXT, in R1 = x, R2 = y, R3 = pointer to text, R4 = colour
text:   SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        MOV    R2, R3
        MOV    R3, R4
        JUMPF  DRAW_TEXT

; the windows and the texts
