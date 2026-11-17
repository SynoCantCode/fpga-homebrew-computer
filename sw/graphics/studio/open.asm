; open, loads the app being designed into window 0
; included by studio.asm

; open_app, reads the apps page with load_page into window 0
; no page = a new empty one, 30 x 6 cells, in the middle
; R8 = the windows 128 bytes
open_app: PUSH R8
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOADLO R1, KIND_NONE
        STORE  R1, [R8 + W_KIND]
        LOADLO R1, styles
        STORE  R1, [R8 + W_STYLE]
        LOADLO R1, app_name
        STORE  R1, [R8 + W_NAME]
        LOADLO R1, 0
        CALL   load_page
        CMPI   R1, 0x0000
        JNZ    open_read
        LOADLO R1, KIND_PAGE            ; a new app, an empty page
        STORE  R1, [R8 + W_KIND]
        LOADLO R1, WHITE_DOT            ; icon label white
        STORE  R1, [label_colours]
        LOADLO R1, app_name
        STORE  R1, [R8 + W_TITLE]
        LOADLO R1, 30
        STORE  R1, [R8 + W_COLUMNS]
        LOADLO R1, 6
        STORE  R1, [R8 + W_ROWS]
        MOV    R1, R8
        CALL   window_size
        CALL   center_window            ; in the middle
        LOADLO R1, 0x0400               ; elements, 32 x 32 bytes
        CALLF  ALLOCATE
        STORE  R1, [R8 + W_ELEMENTS]
        STORE  R0, [R8 + W_ELEMENT_COUNT]
        LA     R1, new_text
        STORE  R1, [status]
open_read: LOADLO R1, 1
        STORE  R1, [R8 + W_VISIBLE]
        MOV    R1, R8
        CALL   window_size
        CALL   keep_on_screen
        STORE  R0, [style_pick]         ; style name for the Style button, 0 = default
        LOAD   R1, [R8 + W_STYLE]
        LOADLO R2, styles
        CMP    R1, R2
        JZ     open_style_known
        LOAD   R1, [R1 + S_NAME]
        STORE  R1, [style_pick]
open_style_known:
        LOADHI R1, 0x0007               ; picture, 481 KB, room for 480 rows
        ORI    R1, R1, 0x8400
        CALLF  ALLOCATE
        CALL   align_1k
        STORE  R1, [R8 + W_PICTURE]
        LOADLO R1, 0x12C0               ; cells, 80 x 30 x 2 bytes
        CALLF  ALLOCATE
        STORE  R1, [R8 + W_CELLS]
        LOADLO R1, 0
        CALL   draw_window
        POP    R8
        RET
