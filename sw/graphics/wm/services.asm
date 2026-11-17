; services, the ones only WM gives apps, WM_WALLPAPER, WM_APP_INFO, WM_SET_ICON, WM_OPEN
; included by wm.asm

; api_wallpaper, in R1 = path of a .PIC, 0 = none, plain teal
; out R1 = its width, 0 = none or not read
api_wallpaper: CMPI R1, 0x0000
        JNZ    wall_new
        STORE  R0, [wall_width]
        STORE  R0, [wall_height]
        JUMP   wall_shown
wall_new: LOADLO R2, wall_name
        CALL   text_copy
        LOADLO R1, wall_name
        LOADHI R2, PICTURE_STORE_HIGH
        CALL   load_picture
        STORE  R1, [wall_width]
        STORE  R2, [wall_height]
wall_shown: LOADLO R1, 1
        STORE  R1, [redraw]
        LOAD   R1, [wall_width]
        RET

; api_app_info, for Settings, out R1 = app name, 0 = no app there
; R2 = title, R3 = icon file name, 0 = default, R4 = label colour
api_app_info: LOAD R2, [app_count]     ; in R1 = app number, 0 up to app_count
        CMP    R1, R2
        JC     info_none
        CALL   app_record
        LOAD   R6, [R1 + A_KIND]        ; 0 = an app, else a file on the desktop
        LOAD   R5, [R1 + W_ICON]        ; on the desktop?
        LOAD   R4, [R1 + A_LABEL]
        LOAD   R2, [R1 + W_TITLE]
        LOAD   R3, [R1 + W_ICON_NAME]
        LOAD   R1, [R1 + W_NAME]
        RET
info_none: LOADLO R1, 0
        LOADLO R5, 0
        LOADLO R6, 0
        RET

; api_set_desktop, WM_SET_DESKTOP, an apps icon on or off the desktop
; Settings always keeps its icon
; in R1 = app number, R2 = 1 on, 0 off, out R1 = 1 done, 0 refused
api_set_desktop: LOAD R3, [app_count]
        CMP    R1, R3
        JC     desktop_refused
        PUSH   R1
        PUSH   R2
        CALL   is_settings              ; R1 = 1 if its Settings
        POP    R2
        POP    R3
        CMPI   R1, 0x0000
        JNZ    desktop_refused
        MOV    R1, R3                   ; app or file alike, a files icon off is in ICONS.TXT
        CMPI   R2, 0x0000               ; an apps in APPS.TXT
        JZ     desktop_off
        CALL   put_icon
        JUMP   desktop_done
desktop_off: CALL remove_icon
desktop_done: LOADLO R1, 1
        RET
desktop_refused: LOADLO R1, 0
        RET

; api_set_icon, changes an apps desktop icon
; in R1 = window, R2 = picture file name, must stay, 0 = default, R8, R12 = window
api_set_icon: PUSH R8
        PUSH   R12
        MOV    R12, R1
        PUSH   R2
        CALL   app_record
        MOV    R8, R1
        POP    R2
        STORE  R2, [R8 + W_ICON_NAME]
        STORE  R0, [R8 + W_ICON_FRAMES]
        CALL   load_icon
        CMPI   R1, 0x0000
        JNZ    set_icon_done
        LOAD   R1, [DRAW_PAGE]          ; none found, the little computer
        STORE  R1, [saved_page]
        LOAD   R1, [icons]
        STORE  R1, [DRAW_PAGE]
        SHIFTI R1, R12, 0x05, 0b0000
        LOADLO R2, 0
        LOADLO R3, 32
        LOADLO R4, 32
        LOADLO R5, KEY
        CALL   box
        SHIFTI R1, R12, 0x05, 0b0000
        CALL   icon_computer
        LOAD   R1, [saved_page]
        STORE  R1, [DRAW_PAGE]
set_icon_done: LOADLO R1, 1
        STORE  R1, [redraw]
        LOAD   R1, [R8 + A_KIND]        ; a files icon is kept in ICONS.TXT
        CMPI   R1, 0x0000               ; an apps in its PAGE.TXT, by Settings
        JZ     set_icon_end
        CALL   save_layout
set_icon_end: POP R12
        POP    R8
        RET

; api_set_label, changes an icons label colour, in R2 = colour
api_set_label: PUSH R2                  ; in R1 = app number
        CALL   app_record
        POP    R2
        STORE  R2, [R1 + A_LABEL]
        LOAD   R2, [R1 + A_KIND]        ; a file on the desktop, kept in ICONS.TXT
        LOADLO R1, 1
        STORE  R1, [redraw]
        CMPI   R2, 0x0000
        JZ     set_label_end
        CALL   save_layout
set_label_end: RET

; api_open, opens an apps window at the front
; in R1 = app name, out R1 = 1, 0 = no such app
api_open: CALL find_app_number          ; R1 = its number, or -1
        CMPIS  R1, -1
        JNZ    open_found
        LOADLO R1, 0
        RET
open_found: CALL launch_app
        LOADLO R1, 1
        RET

; api_icon, in paint, an apps desktop icon as it looks, see-through, 32 x 32
; in R2 = x, R3 = y, from the content or canvas top left
api_icon: PUSH  R1                      ; in R1 = app number
        MOV    R1, R2                   ; where it goes, paint_spot checks its in view
        MOV    R2, R3
        LOADLO R7, 32
        CALL   paint_spot
        POP    R4
        CMPI   R7, 0x0000
        JZ     api_icon_hidden
        SHIFTI R4, R4, 0x05, 0b0000     ; source x = 32 x the app
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        LOADHI R2, 32
        ORI    R2, R2, 32
        LOAD   R3, [icons]
        ORI    R3, R3, KEY
        CALLF  DRAW_SPRITE
api_icon_hidden: RET
