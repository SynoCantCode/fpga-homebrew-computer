; greet, an app that only uses named pieces, no drawing
; key, Enter in #name makes "Hello, NAME!"
; and puts it in #greeting
; button, event 1 Clear, empties the input and the greeting
; build and send with send_app.py greet
.include "sw/apps/app_defs.asm"
.org APP_BASE
        JUMP   init
        JUMP   tick
        JUMP   key
        JUMP   click
        JUMP   paint
        JUMP   button
        JUMP   close
        .word  0                        ; no ticks

; variables
answer: .word 0                         ; "Hello, NAME!", 40 bytes
        .word 0                         ; the greeting shows it from here so it must stay
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
.equ MOST_LETTERS, 24                   ; most letters of the name, 7 + 24 + "!" + the 0

; key, Enter in the one row input. in R1 = window, R2 = key
; R8 = window
key:    CMPI   R2, 0x000A
        JNZ    key_done
        PUSH   R8
        MOV    R8, R1
        LA     R2, name_name            ; R1 = what's typed in #name
        CALLF  WM_GET_TEXT
        CMPI   R1, 0x0000
        JZ     key_pop                  ; no piece called name
        LOADB  R2, [R1]
        CMPI   R2, 0x0000
        JZ     key_pop                  ; nothing typed
        MOV    R5, R1                   ; "Hello, " + name + "!"
        LA     R1, hello_text
        LA     R2, answer
        CALL   text_copy
        LOADLO R4, MOST_LETTERS
key_letter: LOADB R3, [R5]
        CMPI   R3, 0x0000
        JZ     key_end
        STOREB R3, [R2]
        INC    R2
        INC    R5
        DEC    R4
        CMPI   R4, 0x0000
        JNZ    key_letter
key_end: LOADLO R3, 0x0021
        STOREB R3, [R2]
        STOREB R0, [R2 + 1]
        MOV    R1, R8                   ; #greeting shows it
        LA     R2, greeting_name
        LA     R3, answer
        CALLF  WM_SET_TEXT
key_pop: POP   R8
key_done: RET

; button, event 1 Clear. in R1 = window, R2 = event
button: CMPI   R2, 1
        JNZ    button_done
        PUSH   R8
        MOV    R8, R1
        LA     R2, name_name            ; empty the input
        LA     R3, empty_text
        CALLF  WM_SET_TEXT
        MOV    R1, R8
        LA     R2, greeting_name
        LA     R3, nobody_text
        CALLF  WM_SET_TEXT
        POP    R8
button_done: RET

; nothing to do
init:
tick:
click:
paint:
close:  RET

name_name:     .string "name"
greeting_name: .string "greeting"
hello_text:    .string "Hello, "
nobody_text:   .string "(nobody yet)"
empty_text:    .string ""

.include "sw/apps/lib/text.asm"       ; text_copy, text_lower, number_text
