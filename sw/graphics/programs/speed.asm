; SPEED, measures the graphics card.   run speed.bin
; 1. the CPU fills the screen 10 times, 4 dots per STORE
; 2. the blitter fills it 10 times with DRAW_CLEAR
; 3. a moving window, drawn on the hidden page and flipped, 120 times
; the window goes 4 dots right each time
; timed with TIMER, hundredths of a second, results on the text screen
; test 3 cant go over 60 pictures a second
; R8 = start time, R9-R14 = counts and pointers
.include "sw/os/devices.asm"
; variables, in block RAM at PROGRAM_DATA
.equ cpu_time, PROGRAM_DATA + 0
.equ blit_time, PROGRAM_DATA + 4
.equ move_time, PROGRAM_DATA + 8
.org PROGRAM_SDRAM

start:  PUSH   R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        PUSH   R14
        LOADLO R1, LAYER_PIXELS
        CALLF  GRAPHICS_MODE

        ; 1. the CPU, 10 screens, 4 dots per STORE
        LOAD   R8, [TIMER]
        LOADLO R9, 10                   ; R9 = screens left
cpu_screen: LOAD R10, [DRAW_PAGE]       ; R10 = pointer to the row's start
        LOADLO R14, 0x0011
        MUL    R14, R14, R9             ; a different grey each time
        LOADHI R1, 0x0101
        ORI    R1, R1, 0x0101
        MUL    R14, R14, R1             ; in all 4 bytes
        LOADLO R11, PIXELS_DOWN         ; R11 = rows left
cpu_row: MOV   R12, R10                 ; R12 = pointer along the row
        LOADLO R13, 160                 ; R13 = words in the row
cpu_word: STORE R14, [R12]
        ADDI   R12, R12, 4
        DEC    R13, 0b0100
        JNZ    cpu_word
        ADDI   R10, R10, 0x400
        DEC    R11, 0b0100
        JNZ    cpu_row
        DEC    R9, 0b0100
        JNZ    cpu_screen
        LOAD   R1, [TIMER]
        SUB    R1, R1, R8
        STORE  R1, [cpu_time]

        ; 2. the blitter, 10 screens
        LOAD   R8, [TIMER]
        LOADLO R9, 10
blit_screen: LOADLO R1, 0x0011
        MUL    R1, R1, R9
        CALLF  DRAW_CLEAR
        DEC    R9, 0b0100
        JNZ    blit_screen
        CALLF  DRAW_WAIT                ; the last one finished
        LOAD   R1, [TIMER]
        SUB    R1, R1, R8
        STORE  R1, [blit_time]

        ; 3. a moving window, redrawn and flipped every time
        LOAD   R8, [TIMER]
        LOADLO R9, 0                    ; R9 = the frame
frame:  LOADLO R10, 0                   ; the sky, 8 bands of 60 rows, colour 4's shades
sky_band: MULI R1, R10, 60
        SHIFTI R1, R1, 0x10, 0b0000     ; (0, band x 60)
        LOADHI R2, 60
        ORI    R2, R2, PIXELS_ACROSS    ; 640 x 60
        LOADLO R3, 0x004D
        SUB    R3, R3, R10
        CALLF  DRAW_RECT
        INC    R10
        CMPI   R10, 8
        JNZ    sky_band
        SHIFTI R10, R9, 0x02, 0b0000    ; window x = 4 x the frame
        LOADHI R1, 160
        OR     R1, R1, R10              ; (x, 160)
        LOADHI R2, 120
        ORI    R2, R2, 160              ; 160 x 120
        LOADLO R3, 0x00F0               ; silver
        CALLF  DRAW_RECT
        ADDI   R1, R10, 3
        LOADHI R2, 163
        OR     R1, R1, R2               ; title bar at (x + 3, 163)
        LOADHI R2, 18
        ORI    R2, R2, 154              ; 154 x 18
        LOADLO R3, 0x0038               ; navy
        CALLF  DRAW_RECT
        ADDI   R1, R10, 6
        LOADHI R2, 164
        OR     R1, R1, R2
        LA     R2, title_text
        LOADLO R3, 0x000F               ; white letters
        CALLF  DRAW_TEXT
        ADDI   R1, R10, 8
        LOADHI R2, 200
        OR     R1, R1, R2
        LA     R2, body_text
        LOADLO R3, 0x0000               ; black letters
        CALLF  DRAW_TEXT
        CALLF  DRAW_FLIP                ; show it, draw the next on the other page
        INC    R9
        CMPI   R9, 120
        JNZ    frame
        LOAD   R1, [TIMER]
        SUB    R1, R1, R8
        STORE  R1, [move_time]

        ; the results
        LOADLO R1, LAYER_TEXT
        CALLF  GRAPHICS_MODE
        LA     R1, cpu_text
        CALLF  SCREEN_TEXT
        LOAD   R1, [cpu_time]
        CALL   show_time
        LA     R1, blit_text
        CALLF  SCREEN_TEXT
        LOAD   R1, [blit_time]
        CALL   show_time
        LA     R1, move_text
        CALLF  SCREEN_TEXT
        LOAD   R1, [move_time]
        CALL   show_time
        LA     R1, rate_text
        CALLF  SCREEN_TEXT
        LOAD   R2, [move_time]          ; frames a second = 120 x 100 / the hundredths
        CMPI   R2, 0x0000
        JZ     no_rate
        LOADLO R1, 12000
        DIVU   R1, R1, R2
        CALL   show_decimal
no_rate: LA     R1, frames_text
        CALLF  SCREEN_LINE
        POP    R14
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; show_time, in R1 = hundredths of a second, shown like "1.37 s"
show_time: PUSH R8
        MOV    R8, R1
        DIVUI  R1, R8, 100
        CALL   show_decimal
        LOADLO R1, 0x002E               ; '.'
        CALLF  SCREEN_CHAR
        MODUI  R1, R8, 100
        CMPI   R1, 10
        JC     two_digits
        MOV    R8, R1
        LOADLO R1, 0x0030               ; a leading 0, like ".07"
        CALLF  SCREEN_CHAR
        MOV    R1, R8
two_digits: CALL show_decimal
        LA     R1, seconds_text
        CALLF  SCREEN_LINE
        POP    R8
        RET

; show_decimal, in R1 = a number, shown in decimal
show_decimal: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADLO R9, 0
decimal_split: MODUI R1, R8, 10
        ADDI   R1, R1, 0x0030
        PUSH   R1
        INC    R9
        DIVUI  R8, R8, 10
        CMPI   R8, 0x0000
        JNZ    decimal_split
decimal_show: POP R1
        CALLF  SCREEN_CHAR
        DEC    R9, 0b0100
        JNZ    decimal_show
        POP    R9
        POP    R8
        RET

title_text: .string "Moving window"
body_text:  .string "drawn 120 times"
cpu_text:   .string "the CPU, 10 whole screens:     "
blit_text:  .string "the blitter, 10 whole screens: "
move_text:  .string "a moving window, 120 pictures: "
rate_text:  .string "  = "
frames_text: .string " pictures a second (60 is the screen's most)"
seconds_text: .string " s"
