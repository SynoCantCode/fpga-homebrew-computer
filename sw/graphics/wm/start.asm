; start, starting up, the main loop, quitting
; included by wm.asm

start:  PUSH   R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        PUSH   R14
        MOV    R8, R2                   ; R2 = arguments, maybe a wallpaper name
        LOADLO R5, PROGRAM_DATA         ; all variables 0 first
clear_variables: STORE R0, [R5]
        ADDI   R5, R5, 4
        CMPI   R5, VARIABLES_END
        JNZ    clear_variables
        NOT    R1, R0
        STORE  R1, [focus_window]       ; -1 = no input has the focus
        STORE  R1, [hover_place]        ; -1 = pointer not over an icon
        STORE  R1, [hover_task]
        STORE  R1, [hover_title]
        LOADLO R1, 1                    ; buttons count as held at the start
        STORE  R1, [last_buttons]       ; only a new press is a click
        STORE  R1, [last_right]
        CALL   mouse_wake
        CALL   hourglass_start          ; hourglass turns while everything loads
        CALL   take_name                ; wallpaper name into wall_name, the default wallpaper if none
        LOADLO R1, wall_name            ; wallpaper into the picture store
        LOADHI R2, PICTURE_STORE_HIGH
        CALL   load_picture
        STORE  R1, [wall_width]         ; 0 = not loaded, plain teal desktop
        STORE  R2, [wall_height]
        CALL   init_styles              ; style 0, the default
        CALL   load_pointer             ; mouse pointer look, POINTER.PTR, if there is one
        CALL   make_icons
        CALL   make_windows
        CALL   tray_load                ; tray pictures, first look at time and network
        CALL   hourglass_stop           ; loaded, hourglass stops
        LOADLO R1, LAYER_PIXELS + LAYER_POINTER
        CALLF  GRAPHICS_MODE            ; pixels and pointer on, text screen off
        CALL   compose

main:   LOAD   R1, [quit_now]           ; a note for the shell written? WM ends
        CMPI   R1, 0x0000
        JNZ    quit
        CALL   shell_check              ; a full screen app opened? the same
        CMPI   R1, 0x0000
        JNZ    quit
        CALLF  GET_CHAR
        LOAD   R2, [search_open]        ; search list open? it gets the keys
        CMPI   R2, 0x0000               ; Esc too
        JZ     main_key
        CMPIS  R1, -1
        JZ     main_mouse
        CALL   search_key
        JUMP   main_mouse
main_key: CMPI R1, 0x001B
        JZ     quit                     ; Esc
        CMPIS  R1, -1
        JZ     main_mouse               ; nothing typed
        CALL   route_key                ; key to the input with the focus, or the front app
main_mouse: CALLF MOUSE_STATE           ; R1 = pointer, a point, R2 = buttons
        STORE  R1, [mouse_point]
        PUSH   R2
        CALL   wheel_check              ; wheel turned? window under the pointer scrolls
        POP    R2
        PUSH   R2
        CALL   hover_check              ; over a desktop icon? it pops out
        CALL   hover_controls           ; over a button? it lights up
        POP    R2
        SHIFTI R3, R2, 0x01, 0b1000     ; right button, a menu or an icon drag
        ANDI   R3, R3, 0x0001
        LOAD   R4, [last_right]
        STORE  R3, [last_right]
        PUSH   R2
        CALL   right_button
        POP    R2
main_left: ANDI R2, R2, 0x0001
        LOAD   R3, [last_buttons]
        STORE  R2, [last_buttons]
        CMPI   R2, 0x0000
        JNZ    main_down
        STORE  R0, [dragging]           ; let go
        STORE  R0, [resizing]
        JUMP   main_clock
main_down: CMPI R3, 0x0000
        JNZ    main_held
        LOAD   R1, [menu_open]          ; a menu showing, the click is the menus
        CMPI   R1, 0x0000
        JZ     main_click
        CALL   menu_click
        JUMP   main_clock
main_click: CALL click                  ; just went down, a click
        JUMP   main_clock
main_held: LOAD R4, [dragging]
        CMPI   R4, 0x0000
        JZ     main_resizing
        CALL   drag
        JUMP   main_clock
main_resizing: LOAD R4, [resizing]
        CMPI   R4, 0x0000
        JZ     main_clock
        CALL   resize
main_clock: LOAD R1, [TIMER]            ; animation step due? 10 a second
        DIVUI  R1, R1, ANIM_TICKS
        LOAD   R2, [last_anim]
        CMP    R1, R2
        JZ     main_second
        STORE  R1, [last_anim]
        CALL   anim_tick
main_second: CALL tray_tick             ; new second? tray time and network checked
main_redraw: CALL app_ticks             ; app ticks, then the ones that asked are drawn again
        CALL   app_dirty
        LOAD   R1, [redraw]
        CMPI   R1, 0x0000
        JZ     main
        STORE  R0, [redraw]
        CALL   compose
        JUMP   main

quit:   CALLF  DRAW_WAIT                ; wait for the blitters last job
        STORE  R0, [GRAPHICS_PAGE]      ; page 0 shown
        LOADHI R1, PAGE_0_HIGH
        STORE  R1, [DRAW_PAGE]          ; page 0 drawn on
        LOADLO R1, LAYER_TEXT
        CALLF  GRAPHICS_MODE            ; back to the text screen
        CALLF  SCREEN_CLEAR
        POP    R14
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET                             ; back to the shell, it gives the heap back
