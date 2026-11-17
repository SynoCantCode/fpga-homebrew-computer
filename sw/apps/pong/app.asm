; pong, an app in a window of the window manager
; menu, 1 = one player, 2 = two players, 3 = speed 1x, 2x, 5x
; one player, you are the right paddle, arrows or W / S
; two players, left W / S, right arrows
; R = new game, M = menu
; a new game waits 3 seconds, each point 1 second
; 25 ticks a second, ball moves and bounces, window drawn again
; build: python project/tools/assembler/make_app.py sw/apps/pong/app.asm
.include "sw/apps/app_defs.asm"
.org APP_BASE
        JUMP   init
        JUMP   tick
        JUMP   key
        JUMP   click
        JUMP   paint
        JUMP   button
        JUMP   close
        .word  25                       ; ticks a second

; game variables in vars, through R13
.equ V_WINDOW,  0                       ; window number
.equ V_W,       4                       ; court size in dots
.equ V_H,       8
.equ V_BX,      12                      ; ball top left
.equ V_BY,      16
.equ V_DX,      20                      ; ball move per tick
.equ V_DY,      24
.equ V_LEFT,    28                      ; paddle tops
.equ V_RIGHT,   32
.equ V_SCORE_L, 36                      ; scores
.equ V_SCORE_R, 40
.equ V_TEXT,    44                      ; score as text, 12 bytes
.equ V_MODE,    56                      ; 0 = menu, 1 = one player, 2 = two players
.equ V_SPEED,   60                      ; steps per tick, 1, 2 or 5
.equ V_WAIT,    64                      ; ticks left before the ball moves
.equ WAIT_POINT, 25                     ; 1 second after a point
.equ WAIT_START, 75                     ; 3 seconds for a new game
.equ PADDLE_W,  6
.equ PADDLE_H,  40
.equ BALL,      8
.equ PLAYER_STEP, 16                    ; paddle move per key at 1x
.equ CPU_STEP,  3                       ; computer paddle step, slower than the ball

; init, scores 0 and serve, in R1 = window
init:   PUSH   R13
        LA     R13, vars
        STORE  R1, [R13 + V_WINDOW]
        STORE  R0, [R13 + V_SCORE_L]
        STORE  R0, [R13 + V_SCORE_R]
        STORE  R0, [R13 + V_MODE]       ; menu first
        LOADLO R1, 1
        STORE  R1, [R13 + V_SPEED]      ; 1x
        CALL   measure
        CALL   serve
        POP    R13
        RET

; measure, court size from the window, uses R1-R7
measure: LOAD  R1, [R13 + V_WINDOW]
        CALLF  WM_SIZE
        STORE  R1, [R13 + V_W]
        STORE  R2, [R13 + V_H]
        RET

; serve, ball and paddles to the middle, uses R1, R2
serve:  LOAD   R1, [R13 + V_W]
        SHIFTI R1, R1, 0x01, 0b1000
        SUBI   R1, R1, 4
        STORE  R1, [R13 + V_BX]
        LOAD   R1, [R13 + V_H]
        SHIFTI R1, R1, 0x01, 0b1000
        SUBI   R1, R1, 4
        STORE  R1, [R13 + V_BY]
        LOADLO R1, 4
        STORE  R1, [R13 + V_DX]
        LOADLO R1, 3
        STORE  R1, [R13 + V_DY]
        LOAD   R1, [R13 + V_H]
        SUBI   R1, R1, PADDLE_H
        SHIFTI R1, R1, 0x01, 0b1000
        STORE  R1, [R13 + V_LEFT]
        STORE  R1, [R13 + V_RIGHT]
        LOADLO R1, WAIT_POINT           ; ball waits a second
        STORE  R1, [R13 + V_WAIT]
        RET

; tick, V_SPEED steps then redraw
; in R1 = window, R12 = steps left
tick:   PUSH   R13
        PUSH   R12
        LA     R13, vars
        CALL   measure
        LOAD   R12, [R13 + V_MODE]      ; nothing moves on the menu
        CMPI   R12, 0x0000
        JZ     tick_done
        LOAD   R12, [R13 + V_WAIT]      ; pause after a serve, just count down
        CMPI   R12, 0x0000
        JZ     tick_moving
        DEC    R12
        STORE  R12, [R13 + V_WAIT]
        JUMP   tick_drawn
tick_moving: LOAD R12, [R13 + V_SPEED]
tick_step: CALL step
        DEC    R12
        CMPI   R12, 0x0000
        JNZ    tick_step
tick_drawn: LOAD R1, [R13 + V_WINDOW]
        CALLF  WM_REDRAW
tick_done: POP R12
        POP    R13
        RET

; step, one step of the game, uses R1-R7
; ball moves and bounces, computer follows, paddles hit, points
step:   LOAD   R1, [R13 + V_BX]         ; move the ball
        LOAD   R2, [R13 + V_DX]
        ADD    R1, R1, R2
        STORE  R1, [R13 + V_BX]
        LOAD   R1, [R13 + V_BY]
        LOAD   R2, [R13 + V_DY]
        ADD    R1, R1, R2
        CMPIS  R1, 0                    ; off the top, go down
        JGE    tick_top
        LOADLO R1, 0
        CALL   flip_dy
tick_top: LOAD R3, [R13 + V_H]          ; off the bottom, go up
        SUBI   R3, R3, BALL
        SUB    R4, R3, R1
        CMPIS  R4, 0
        JGE    tick_bottom
        MOV    R1, R3
        CALL   flip_dy
tick_bottom: STORE R1, [R13 + V_BY]
        LOAD   R1, [R13 + V_MODE]       ; one player, computer moves the left paddle
        CMPI   R1, 1
        JNZ    tick_hits
        CALL   computer
tick_hits: CALL hit_left
        CALL   hit_right
        LOAD   R1, [R13 + V_BX]         ; past the left edge, point to the right
        CMPIS  R1, -BALL
        JGE    tick_left_in
        LOAD   R1, [R13 + V_SCORE_R]
        INC    R1
        STORE  R1, [R13 + V_SCORE_R]
        CALL   serve
        JUMP   step_done
tick_left_in: LOAD R2, [R13 + V_W]      ; past the right edge, point to the left
        SUB    R2, R2, R1
        CMPIS  R2, 0
        JGE    step_done
        LOAD   R1, [R13 + V_SCORE_L]
        INC    R1
        STORE  R1, [R13 + V_SCORE_L]
        CALL   serve
step_done: RET

; flip_dy, ball up / down reversed, uses R2
flip_dy: LOAD  R2, [R13 + V_DY]
        SUB    R2, R0, R2
        STORE  R2, [R13 + V_DY]
        RET

; computer, left paddle follows the ball by CPU_STEP, uses R1-R4
computer: LOAD R1, [R13 + V_LEFT]
        ADDI   R2, R1, 20               ; half the paddle
        LOAD   R3, [R13 + V_BY]
        ADDI   R3, R3, 4                ; half the ball
        SUB    R3, R3, R2               ; how far the ball is below the paddle middle
        CMPIS  R3, CPU_STEP
        JGE    computer_down
        CMPIS  R3, -CPU_STEP
        JGE    computer_kept
        SUBI   R1, R1, CPU_STEP
        JUMP   computer_kept
computer_down: ADDI R1, R1, CPU_STEP
computer_kept: JUMP keep_paddle_left

; keep_paddle_left, clamp R1 and store as the left paddle, uses R1-R4
keep_paddle_left: CALL keep_paddle
        STORE  R1, [R13 + V_LEFT]
        RET

; keep_paddle, in/out R1 = paddle top, kept on the court, uses R2, R4
keep_paddle: CMPIS R1, 0
        JGE    keep_top
        LOADLO R1, 0
keep_top: LOAD R2, [R13 + V_H]
        SUBI   R2, R2, PADDLE_H
        SUB    R4, R2, R1
        CMPIS  R4, 0
        JGE    keep_done
        MOV    R1, R2
keep_done: RET

; hit_left, ball going left at the left paddle (x 8-13) bounces right, uses R1-R4
hit_left: LOAD R1, [R13 + V_DX]
        CMPIS  R1, 0
        JGE    hit_left_no              ; going right
        LOAD   R1, [R13 + V_BX]
        SUBI   R1, R1, 8 + PADDLE_W
        CMPIS  R1, 1
        JGE    hit_left_no              ; not there yet
        LOAD   R1, [R13 + V_BX]
        CMPIS  R1, 8 - BALL
        JGE    hit_left_beside
        JUMP   hit_left_no              ; already past it
hit_left_beside: LOAD R2, [R13 + V_LEFT]
        CALL   beside
        CMPI   R1, 0x0000
        JZ     hit_left_no
        LOADLO R1, 8 + PADDLE_W
        STORE  R1, [R13 + V_BX]
        LOAD   R1, [R13 + V_DX]
        SUB    R1, R0, R1
        STORE  R1, [R13 + V_DX]
hit_left_no: RET

; hit_right, ball going right at the right paddle bounces left
hit_right: LOAD R1, [R13 + V_DX]
        CMPIS  R1, 1
        JGE    hit_right_moving
        RET
hit_right_moving: LOAD R3, [R13 + V_W]
        SUBI   R3, R3, 8 + PADDLE_W     ; R3 = paddle left edge
        LOAD   R1, [R13 + V_BX]
        ADDI   R1, R1, BALL
        SUB    R4, R1, R3               ; ball right edge past the paddle left edge?
        CMPIS  R4, 0
        JGE    hit_right_there
        RET
hit_right_there: CMPIS R4, PADDLE_W + BALL
        JGE    hit_right_no             ; already past it
        PUSH   R3
        LOAD   R2, [R13 + V_RIGHT]
        CALL   beside
        POP    R3
        CMPI   R1, 0x0000
        JZ     hit_right_no
        SUBI   R1, R3, BALL
        STORE  R1, [R13 + V_BX]
        LOAD   R1, [R13 + V_DX]
        SUB    R1, R0, R1
        STORE  R1, [R13 + V_DX]
hit_right_no: RET

; beside, is the ball level with a paddle
; in R2 = paddle top, out R1 = 1 if so, uses R1-R4
beside: LOAD   R1, [R13 + V_BY]
        ADDI   R3, R1, BALL
        SUB    R3, R3, R2               ; ball bottom below the paddle top?
        CMPIS  R3, 1
        JGE    beside_top
        LOADLO R1, 0
        RET
beside_top: ADDI R4, R2, PADDLE_H       ; ball top above the paddle bottom?
        SUB    R4, R4, R1
        CMPIS  R4, 1
        JGE    beside_yes
        LOADLO R1, 0
        RET
beside_yes: LOADLO R1, 1
        RET

; key, menu 1 / 2 pick players, 3 speed, playing R new game, M menu
; W / S and the arrows move the paddles
; in R2 = key
key:    PUSH   R13
        LA     R13, vars
        LOAD   R3, [R13 + V_MODE]
        CMPI   R3, 0x0000
        JNZ    key_playing
        CMPI   R2, 0x0031               ; 1
        JZ     key_mode
        CMPI   R2, 0x0032               ; 2
        JZ     key_mode
        CMPI   R2, 0x0033               ; 3, next speed, 1x 2x 5x
        JNZ    key_done
        LOAD   R1, [R13 + V_SPEED]
        LOADLO R2, 2
        CMPI   R1, 1
        JZ     key_speed
        LOADLO R2, 5
        CMPI   R1, 2
        JZ     key_speed
        LOADLO R2, 1
key_speed: STORE R2, [R13 + V_SPEED]
        JUMP   key_drawn
key_mode: SUBI R2, R2, 0x0030
        STORE  R2, [R13 + V_MODE]
        JUMP   key_new_game
key_playing: CMPI R2, 0x0072            ; r, new game
        JZ     key_new_game
        CMPI   R2, 0x006D               ; m, menu
        JNZ    key_paddles
        STORE  R0, [R13 + V_MODE]
        JUMP   key_drawn
key_paddles: CMPI R2, KEY_UP            ; arrows, always the right paddle
        JZ     key_right_up
        CMPI   R2, KEY_DOWN
        JZ     key_right_down
        CMPI   R3, 2                    ; W / S, left paddle with two players
        JZ     key_left
        CMPI   R2, 0x0077               ; right paddle with one
        JZ     key_right_up
        CMPI   R2, 0x0073
        JZ     key_right_down
        JUMP   key_done
key_left: CALL player_step
        LOAD   R1, [R13 + V_LEFT]
        CMPI   R2, 0x0077               ; w
        JZ     key_left_up
        CMPI   R2, 0x0073               ; s
        JNZ    key_done
        ADD    R1, R1, R5
        JUMP   key_left_moved
key_left_up: SUB R1, R1, R5
key_left_moved: CALL keep_paddle_left
        JUMP   key_drawn
key_right_up: CALL player_step
        LOAD   R1, [R13 + V_RIGHT]
        SUB    R1, R1, R5
        JUMP   key_right_moved
key_right_down: CALL player_step
        LOAD   R1, [R13 + V_RIGHT]
        ADD    R1, R1, R5
key_right_moved: CALL keep_paddle
        STORE  R1, [R13 + V_RIGHT]
        JUMP   key_drawn
key_new_game: STORE R0, [R13 + V_SCORE_L]
        STORE  R0, [R13 + V_SCORE_R]
        CALL   serve
        LOADLO R1, WAIT_START           ; new game, 3 seconds first
        STORE  R1, [R13 + V_WAIT]
key_drawn: LOAD R1, [R13 + V_WINDOW]
        CALLF  WM_REDRAW
key_done: POP  R13
        RET

; player_step, 16 dots at 1x, 24 at 2x, 32 at 5x, out R5, uses R4
player_step: LOAD R4, [R13 + V_SPEED]
        LOADLO R5, PLAYER_STEP
        CMPI   R4, 1
        JZ     player_step_done
        LOADLO R5, 24
        CMPI   R4, 2
        JZ     player_step_done
        LOADLO R5, 32
player_step_done: RET

; paint, court, line, scores, paddles, ball
paint:  PUSH   R13
        PUSH   R12
        LA     R13, vars
        CALL   measure
        LOADLO R1, 0                    ; black court
        LOADLO R2, 0
        LOAD   R3, [R13 + V_W]
        LOAD   R4, [R13 + V_H]
        LOADLO R5, 0x00
        CALLF  WM_BOX
        LOAD   R1, [R13 + V_MODE]       ; menu?
        CMPI   R1, 0x0000
        JZ     paint_menu
        LOADLO R12, 0                   ; middle line, 2 x 8 dashes, 16 apart
paint_dash: LOAD R1, [R13 + V_W]
        SHIFTI R1, R1, 0x01, 0b1000
        SUBI   R1, R1, 1
        MOV    R2, R12
        LOADLO R3, 2
        LOADLO R4, 8
        LOADLO R5, 0xF1
        CALLF  WM_BOX
        ADDI   R12, R12, 16
        LOAD   R1, [R13 + V_H]
        SUBI   R1, R1, 8
        SUB    R1, R1, R12
        CMPIS  R1, 0
        JGE    paint_dash
        LOAD   R1, [R13 + V_SCORE_L]    ; scores, each side of the line
        ADDI   R2, R13, V_TEXT
        CALLF  WM_NUMBER
        LOAD   R1, [R13 + V_W]
        SHIFTI R1, R1, 0x01, 0b1000
        SUBI   R1, R1, 40
        LOADLO R2, 4
        ADDI   R3, R13, V_TEXT
        LOADLO R4, 0x0F
        CALLF  WM_TEXT
        LOAD   R1, [R13 + V_SCORE_R]
        ADDI   R2, R13, V_TEXT
        CALLF  WM_NUMBER
        LOAD   R1, [R13 + V_W]
        SHIFTI R1, R1, 0x01, 0b1000
        ADDI   R1, R1, 24
        LOADLO R2, 4
        ADDI   R3, R13, V_TEXT
        LOADLO R4, 0x0F
        CALLF  WM_TEXT
        LOAD   R1, [R13 + V_WAIT]       ; pause, seconds left in the middle
        CMPI   R1, 0x0000
        JZ     paint_paddles
        ADDI   R1, R1, 24
        DIVUI  R1, R1, 25
        ADDI   R2, R13, V_TEXT
        CALLF  WM_NUMBER
        LOAD   R1, [R13 + V_W]
        SHIFTI R1, R1, 0x01, 0b1000
        SUBI   R1, R1, 4
        LOAD   R2, [R13 + V_H]
        SHIFTI R2, R2, 0x01, 0b1000
        SUBI   R2, R2, 40
        ADDI   R3, R13, V_TEXT
        LOADLO R4, 0x88
        CALLF  WM_TEXT
paint_paddles: LOADLO R1, 8             ; left paddle
        LOAD   R2, [R13 + V_LEFT]
        LOADLO R3, PADDLE_W
        LOADLO R4, PADDLE_H
        LOADLO R5, 0x0F
        CALLF  WM_BOX
        LOAD   R1, [R13 + V_W]          ; right paddle
        SUBI   R1, R1, 8 + PADDLE_W
        LOAD   R2, [R13 + V_RIGHT]
        LOADLO R3, PADDLE_W
        LOADLO R4, PADDLE_H
        LOADLO R5, 0x0F
        CALLF  WM_BOX
        LOAD   R1, [R13 + V_BX]         ; ball, only while on the court
        CMPIS  R1, 0
        JGE    paint_ball_left
        JUMP   paint_done
paint_ball_left: LOAD R2, [R13 + V_W]
        SUBI   R2, R2, BALL
        SUB    R2, R2, R1
        CMPIS  R2, 0
        JGE    paint_ball
        JUMP   paint_done
paint_ball: LOAD R2, [R13 + V_BY]
        LOADLO R3, BALL
        LOADLO R4, BALL
        LOADLO R5, 0x88                 ; yellow
        CALLF  WM_BOX
        JUMP   paint_done
paint_menu: LA R3, menu_title           ; menu lines, each centred
        LOADLO R2, 40
        LOADLO R4, 0x88
        CALL   centred
        LA     R3, menu_one
        LOADLO R2, 96
        LOADLO R4, 0x0F
        CALL   centred
        LA     R3, menu_two
        LOADLO R2, 120
        LOADLO R4, 0x0F
        CALL   centred
        LA     R3, menu_speed_1         ; 3, current speed
        LOAD   R1, [R13 + V_SPEED]
        CMPI   R1, 1
        JZ     paint_speed
        LA     R3, menu_speed_2
        CMPI   R1, 2
        JZ     paint_speed
        LA     R3, menu_speed_5
paint_speed: LOADLO R2, 144
        LOADLO R4, 0x0F
        CALL   centred
        LA     R3, menu_keys
        LOADLO R2, 176
        LOADLO R4, 0xF1
        CALL   centred
        LA     R3, menu_keys2
        LOADLO R2, 200
        LOADLO R4, 0xF1
        CALL   centred
paint_done: POP R12
        POP    R13
        RET

; centred, text across the middle, in R2 = y, R3 = pointer, R4 = colour, uses R1-R7
centred: LOADLO R5, 0                   ; length
        MOV    R6, R3
centred_count: LOADB R1, [R6]
        CMPI   R1, 0x0000
        JZ     centred_counted
        INC    R5
        INC    R6
        JUMP   centred_count
centred_counted: SHIFTI R5, R5, 0x03, 0b0000
        LOAD   R1, [R13 + V_W]          ; x = (width - text width) / 2
        SUB    R1, R1, R5
        SHIFTI R1, R1, 0x01, 0b1000
        CALLF  WM_TEXT
        RET

; button, event 1 = new game
button: PUSH   R13
        LA     R13, vars
        STORE  R0, [R13 + V_SCORE_L]
        STORE  R0, [R13 + V_SCORE_R]
        CALL   serve
        LOAD   R1, [R13 + V_WINDOW]
        CALLF  WM_REDRAW
        POP    R13
        RET

; click, close: nothing to do
click:  RET
close:  RET

menu_title: .string "P  O  N  G"
menu_one:   .string "1   one player (vs the computer)"
menu_two:   .string "2   two players"
menu_speed_1: .string "3   speed: 1x"
menu_speed_2: .string "3   speed: 2x"
menu_speed_5: .string "3   speed: 5x"
menu_keys:  .string "left: W / S     right: arrows"
menu_keys2: .string "R: a new game   M: this menu"
vars:   .word 0                         ; 20 words, V_WINDOW to V_WAIT
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
