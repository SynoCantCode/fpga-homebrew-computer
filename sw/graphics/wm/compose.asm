; wm compose, draws the whole screen on the hidden page, then shows it
; included by programs/wm.asm

; compose, draws the screen back to front on the hidden page
; R8 = place in the order, R9 = window record, R10 = front window number
compose: PUSH  R8
        PUSH   R9
        PUSH   R10
        LOAD   R1, [wall_width]         ; the wallpaper
        CMPI   R1, PIXELS_ACROSS
        JNZ    compose_teal
        LOAD   R1, [wall_height]
        CMPI   R1, PIXELS_DOWN
        JZ     compose_wallpaper
compose_teal: LOADLO R1, TEAL           ; none or smaller than the screen, teal around it
        CALLF  DRAW_CLEAR
        LOAD   R1, [wall_width]
        CMPI   R1, 0x0000
        JZ     compose_decor
compose_wallpaper: LOADLO R1, PIXELS_ACROSS
        LOAD   R2, [wall_width]
        SUB    R1, R1, R2
        SHIFTI R1, R1, 0x01, 0b1000     ; centred
        LOADLO R3, PIXELS_DOWN
        LOAD   R4, [wall_height]
        SUB    R3, R3, R4
        SHIFTI R3, R3, 0x01, 0b1000
        SHIFTI R3, R3, 0x10, 0b0000
        OR     R1, R1, R3
        SHIFTI R4, R4, 0x10, 0b0000
        OR     R2, R2, R4               ; its size
        LOADHI R3, PICTURE_STORE_HIGH
        LOADLO R4, 0
        CALLF  DRAW_COPY
compose_decor: CALL decor_draw           ; decorations, on the wallpaper, under the rest
compose_icons: LOADLO R8, 0             ; the icons, 32 x 32, columns of 5, titles under them
        LOADLO R10, 0                   ; R8 = app, R10 = place
compose_icon: LOAD R1, [app_count]
        CMP    R8, R1
        JC     compose_icons_done
        MOV    R1, R8
        CALL   app_record
        MOV    R9, R1
        LOAD   R1, [R9 + W_ICON]
        CMPI   R1, 0x0000
        JZ     compose_next_icon
        LOAD   R1, [icon_moved]         ; the dragged one is drawn at the pointer, after the others
        CMPI   R1, 0x0000
        JZ     compose_placed
        LOAD   R1, [icon_drag]
        DEC    R1
        CMP    R1, R8
        JZ     compose_next_icon
compose_placed: LOAD R10, [R9 + A_PLACE] ; R10 = its place on the grid, none = not drawn
        CMPIS  R10, 0
        JGE    compose_has_place
        JUMP   compose_next_icon
compose_has_place: LOADLO R1, 0         ; icon under the pointer goes 2 dots up, shadow under it, name white
        LOAD   R2, [hover_place]        ; R1 = how far up, 0 or 2
        CMP    R2, R10
        JNZ    compose_icon_lift
        DIVUI  R1, R10, 5               ; shadow, a flat oval from its y + 30
        MULI   R1, R1, 80
        ADDI   R1, R1, 34
        MODUI  R2, R10, 5
        MULI   R2, R2, 80
        ADDI   R2, R2, 54
        PUSH   R1
        PUSH   R2
        LOADLO R3, 12
        LOADLO R4, 3
        LOADLO R5, ICON_SHADOW
        CALL   box
        POP    R2
        POP    R1
        SUBI   R1, R1, 4
        ADDI   R2, R2, 1
        LOADLO R3, 20
        LOADLO R4, 1
        LOADLO R5, ICON_SHADOW
        CALL   box
        LOADLO R1, 2
compose_icon_lift: PUSH R1
        DIVUI  R1, R10, 5               ; 24 + 80 x column, 24 + 80 x row - how far up
        MULI   R1, R1, 80
        ADDI   R1, R1, 24
        MODUI  R2, R10, 5
        MULI   R2, R2, 80
        ADDI   R2, R2, 24
        POP    R6
        SUB    R2, R2, R6
        PUSH   R6
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        LOADHI R2, 32
        ORI    R2, R2, 32
        LOAD   R3, [icons]
        ORI    R3, R3, KEY              ; the base + the colour to skip
        SHIFTI R4, R8, 0x05, 0b0000     ; from (32 x app, 0) in the icons picture
        CALLF  DRAW_SPRITE
        LOAD   R1, [R9 + W_TITLE]       ; title under it, centred, in its label colour
        CALL   text_length
        SHIFTI R2, R2, 0x02, 0b0000
        DIVUI  R1, R10, 5
        MULI   R1, R1, 80
        ADDI   R1, R1, 40
        SUB    R1, R1, R2
        CMPIS  R1, 0
        JGE    compose_label_x
        LOADLO R1, 0
compose_label_x: MODUI R2, R10, 5
        MULI   R2, R2, 80
        ADDI   R2, R2, 60
        LOAD   R3, [R9 + W_TITLE]
        LOAD   R4, [R9 + A_LABEL]
        POP    R6                       ; lifted, name white
        CMPI   R6, 0x0000
        JZ     compose_label
        LOADLO R4, WHITE_DOT
compose_label: CALL text
compose_next_icon: INC R8
        JUMP   compose_icon
compose_icons_done: CALL drag_icon_draw  ; an icon being dragged, at the pointer
        CALL   front_window             ; R1 = front window number, -1 if none
        MOV    R10, R1
        CALL   front_is_full            ; full screen window at the front, taskbar goes under it
        CMPI   R1, 0x0000
        JZ     compose_windows
        CALL   taskbar
compose_windows:
        LOADLO R8, 0                    ; the windows, back to front
compose_window: LOADLO R1, order
        SHIFTI R2, R8, 0x02, 0b0000
        ADD    R1, R1, R2
        LOAD   R1, [R1]
        CALL   window_record            ; R9 = its record
        MOV    R9, R1
        LOAD   R1, [R9 + W_VISIBLE]
        CMPI   R1, 0x0000
        JZ     compose_next_window
        LOAD   R1, [R9 + W_PICTURE]     ; no picture, not shown
        CMPI   R1, 0x0000
        JZ     compose_next_window
        LOAD   R1, [R9 + W_X]           ; copy its picture to its place
        LOAD   R2, [R9 + W_Y]
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        LOAD   R2, [R9 + W_WIDTH]
        LOAD   R3, [R9 + W_HEIGHT]
        SHIFTI R3, R3, 0x10, 0b0000
        OR     R2, R2, R3
        LOAD   R3, [R9 + W_PICTURE]
        LOADLO R4, 0
        LOAD   R5, [R9 + W_STYLE]
        LOAD   R5, [R5 + S_PICTURE]
        CMPI   R5, 0x0000
        JNZ    compose_shaped
        CALLF  DRAW_COPY
        JUMP   compose_copied
compose_shaped: ORI R3, R3, KEY         ; drawn style, see-through where the picture is 0xFE
        CALLF  DRAW_SPRITE
compose_copied: LOADLO R1, order        ; is it the front one?
        SHIFTI R2, R8, 0x02, 0b0000
        ADD    R1, R1, R2
        LOAD   R1, [R1]
        LOADLO R2, 0
        CMP    R1, R10
        JNZ    compose_title
        LOADLO R2, 1
compose_title: MOV R1, R9
        CALL   title_bar
compose_next_window: INC R8
        CMPI   R8, WINDOW_COUNT
        JNZ    compose_window
        CALL   front_is_full            ; the taskbar on top, unless it went under
        CMPI   R1, 0x0000
        JNZ    compose_flip
        CALL   taskbar
compose_flip:
        CALL   draw_menu                ; right-click menu, on top of everything
        CALLF  DRAW_FLIP                ; show it at the next frame
        POP    R10
        POP    R9
        POP    R8
        RET

; ---- right-click menus ----
