; start, starting up, the main loop, quitting, the timer tick
; included by studio.asm

start:  PUSH   R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        PUSH   R14
        MOV    R8, R2                   ; R2 = arguments, the apps name
        LOADLO R5, PROGRAM_DATA         ; zero the variables
studio_clear: STORE R0, [R5]
        ADDI   R5, R5, 4
        CMPI   R5, STUDIO_END
        JNZ    studio_clear
        NOT    R1, R0
        STORE  R1, [focus_window]       ; no input takes typing
        LOADLO R5, app_name             ; the name, up to 8 letters or a space
        LOADLO R6, 8
studio_name: LOADB R1, [R8]
        CMPI   R1, 0x0000
        JZ     studio_named
        CMPI   R1, 0x0020
        JZ     studio_named
        STOREB R1, [R5]
        INC    R8
        INC    R5
        DEC    R6, 0b0100
        JNZ    studio_name
studio_named: STOREB R0, [R5]
        LOADB  R1, [app_name]
        CMPI   R1, 0x0000
        JNZ    studio_go
        CALL   choose_app               ; no name, pick one on the start screen, R1 = 0 = Esc
        CMPI   R1, 0x0000
        JNZ    studio_go
        CALLF  SCREEN_CLEAR
        JUMP   studio_end
studio_go: CALL mouse_wake              ; wake the mouse
        CALL   init_styles
        LA     R1, styles_list_path     ; styles for the Style button
        CALL   load_text
        STORE  R1, [style_list]
        STORE  R2, [style_list_end]
        LA     R1, apps_list_path       ; apps a button can open
        CALL   load_text
        STORE  R1, [app_list]
        STORE  R2, [app_list_end]
        CALL   load_sprite_list         ; sprites for the Sprite button
        CALL   open_app
        LOADLO R1, 0                    ; its program APP.BIN, if it has one
        CALL   load_app
        LOADLO R1, 0
        CALL   draw_window
        LOADLO R1, LAYER_PIXELS + LAYER_POINTER
        CALLF  GRAPHICS_MODE
        LA     R1, hello_text
        STORE  R1, [status]
        CALL   studio_compose

studio_main: CALLF GET_CHAR
        CMPI   R1, 0x001B
        JZ     studio_quit              ; Esc
        CMPIS  R1, -1
        JZ     studio_mouse
        CALL   studio_key
studio_mouse: CALLF MOUSE_STATE         ; R1 = pointer, R2 = buttons
        STORE  R1, [mouse_point]
        ANDI   R2, R2, 0x0001
        LOAD   R3, [last_buttons]
        STORE  R2, [last_buttons]
        CMPI   R2, 0x0000
        JNZ    studio_down
        STORE  R0, [holding]            ; let go
        JUMP   studio_redraw
studio_down: CMPI R3, 0x0000
        JNZ    studio_held
        CALL   studio_click             ; just went down
        JUMP   studio_redraw
studio_held: CALL studio_drag
studio_redraw: CALL studio_tick         ; next animation frame?
        CALL   app_ticks                ; its programs ticks and redraws
        CALL   app_dirty
        LOAD   R1, [redraw]
        CMPI   R1, 0x0000
        JZ     studio_main
        STORE  R0, [redraw]
        CALL   studio_compose
        JUMP   studio_main

studio_quit: CALLF DRAW_WAIT
        STORE  R0, [GRAPHICS_PAGE]      ; pages back as at start
        LOADHI R1, PAGE_0_HIGH
        STORE  R1, [DRAW_PAGE]
        LOADLO R1, LAYER_TEXT
        CALLF  GRAPHICS_MODE
        CALLF  SCREEN_CLEAR
studio_end: POP R14
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; studio_tick, 10 times a second, redraws the window
; only if the page has an animation, uses R1, R2
studio_tick: LOAD R1, [TIMER]
        DIVUI  R1, R1, ANIM_TICKS
        LOAD   R2, [last_anim]
        CMP    R1, R2
        JNZ    tick_due
        RET
tick_due: STORE R1, [last_anim]
        LOADLO R1, 0
        CALL   window_record
        LOAD   R2, [R1 + W_ANIMATES]
        CMPI   R2, 0x0000
        JNZ    tick_draw
        RET
tick_draw: LOADLO R1, 0
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
        RET

; services WM gives apps that Studio doesn't
