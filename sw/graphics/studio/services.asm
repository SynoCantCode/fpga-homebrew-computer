; services, the ones Studio answers differently from WM
; included by studio.asm

; studio_app_info, WM_APP_INFO, only window 0, in R1 = window
; out R1 = name or 0, R2 = title, R3 = icon name, R4 = label colour
studio_app_info: CMPI R1, 0x0000
        JNZ    studio_ignore_0
        CALL   window_record
        LOAD   R2, [R1 + W_TITLE]
        LOAD   R3, [R1 + W_ICON_NAME]
        LOAD   R4, [label_colours]
        LOADLO R1, app_name
        RET
studio_ignore_0: LOADLO R1, 0
        RET

; studio_no_wallpaper, WM_WALLPAPER, out R1 = 0
studio_no_wallpaper: LOADLO R1, 0
studio_ignore: RET

; window_room, asked by draw_window, the picture is there already
; out R1 = 1
window_room: LOADLO R1, 1
        RET

; opening the app
