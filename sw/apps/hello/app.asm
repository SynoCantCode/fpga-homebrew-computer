; hello, a starting point for a new app
; handlers and services are in app_defs.asm
; tick, 10 a second, the square moves and bounces at the edges
; click, the square jumps there
; button, event 1, next colour
; paint, dark blue canvas and the square
; build and send with send_app.py hello
.include "sw/apps/app_defs.asm"
.org APP_BASE
        JUMP   init
        JUMP   tick
        JUMP   key
        JUMP   click
        JUMP   paint
        JUMP   button
        JUMP   close
        .word  10                       ; ticks a second

; variables, words inside the app
window:  .word 0                        ; the window number
x:       .word 0                        ; square top-left in the canvas
y:       .word 0
dx:      .word 4                        ; step each tick
dy:      .word 2
colour:  .word 0x88                     ; colour, yellow
.equ SIZE, 16                           ; square size

; init, remember the window
init:   LA     R6, window
        STORE  R1, [R6]
        RET

; tick, move the square, bounce at the edges, redraw
tick:   CALLF  WM_SIZE                  ; R1 = canvas width, R2 = height
        SUBI   R3, R1, SIZE             ; R3, R4 = biggest x and y
        SUBI   R4, R2, SIZE
        LA     R6, x                    ; x moves
        LOAD   R1, [R6]
        LA     R5, dx
        LOAD   R2, [R5]
        ADD    R1, R1, R2
        CALL   bounce                   ; R1 kept in 0..R3, R2 turned at an edge
        STORE  R1, [R6]
        STORE  R2, [R5]
        MOV    R3, R4                   ; then y
        LA     R6, y
        LOAD   R1, [R6]
        LA     R5, dy
        LOAD   R2, [R5]
        ADD    R1, R1, R2
        CALL   bounce
        STORE  R1, [R6]
        STORE  R2, [R5]
        LA     R6, window
        LOAD   R1, [R6]
        CALLF  WM_REDRAW
        RET

; bounce, in R1 = place, R2 = step, R3 = biggest place
; out R1 kept in 0..R3, R2 turned round at an edge. uses R7
bounce: CMPIS  R1, 0
        JGE    bounce_low
        LOADLO R1, 0
        SUB    R2, R0, R2               ; 0 - step, the other way
        RET
bounce_low: SUB R7, R3, R1
        CMPIS  R7, 0
        JGE    bounce_done
        MOV    R1, R3
        SUB    R2, R0, R2
bounce_done: RET

; click, the square jumps there, R2 = x, R3 = y in the canvas
click:  LA     R6, x
        STORE  R2, [R6]
        LA     R6, y
        STORE  R3, [R6]
        CALLF  WM_REDRAW                ; R1 is still the window
        RET

; button, R2 = event, event 1 is the next colour
button: CMPI   R2, 1
        JNZ    button_done
        LA     R6, colour
        LOAD   R2, [R6]
        ADDI   R2, R2, 0x10             ; next colour family, same shade
        ANDI   R2, R2, 0x00FF
        STORE  R2, [R6]
        CALLF  WM_REDRAW
button_done: RET

; paint, the canvas dark blue, then the square
paint:  CALLF  WM_SIZE                  ; canvas size
        MOV    R3, R1
        MOV    R4, R2
        LOADLO R1, 0
        LOADLO R2, 0
        LOADLO R5, 0x34                 ; dark blue
        CALLF  WM_BOX
        LA     R6, x
        LOAD   R1, [R6]
        LA     R6, y
        LOAD   R2, [R6]
        LOADLO R3, SIZE
        LOADLO R4, SIZE
        LA     R6, colour
        LOAD   R5, [R6]
        CALLF  WM_BOX
        RET

; key, close do nothing
key:    RET
close:  RET
