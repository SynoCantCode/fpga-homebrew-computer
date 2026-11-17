; saving, writes the page as PAGE.TXT, adds the app to APPS.TXT
; included by studio.asm

; save_page, writes the page as text into /APPS/NAME/PAGE.TXT
; makes the apps folder first, R8 = window, R9 = element
; R10 = count, R11 = text colour so far
save_page: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        CALL   out_open
        LA     R1, w_comment            ; the first line, a note with the name
        CALL   put_text_out
        LOADLO R1, app_name
        CALL   put_text_out
        LA     R1, w_made
        CALL   put_line_end_after
        LA     R1, w_title              ; title TEXT
        CALL   put_text_out
        LOAD   R1, [R8 + W_TITLE]
        CALL   put_line_end_after
        LOAD   R1, [R8 + W_STYLE]       ; style NAME, not the default
        LOADLO R2, styles
        CMP    R1, R2
        JZ     save_size
        LA     R1, w_style
        CALL   put_text_out
        LOAD   R1, [R8 + W_STYLE]
        LOAD   R1, [R1 + S_NAME]
        CALL   put_line_end_after
save_size: LA  R1, w_size               ; size COLUMNS ROWS
        CALL   put_text_out
        LOAD   R1, [R8 + W_COLUMNS]
        CALL   put_number
        CALL   put_space
        LOAD   R1, [R8 + W_ROWS]
        CALL   put_number
        CALL   put_newline
        LA     R1, w_place              ; place X Y
        CALL   put_text_out
        LOAD   R1, [R8 + W_X]
        CALL   put_number
        CALL   put_space
        LOAD   R1, [R8 + W_Y]
        CALL   put_number
        CALL   put_newline
        LOAD   R1, [R8 + W_HIDDEN]
        CMPI   R1, 0x0000
        JZ     save_full
        LA     R1, w_hidden
        CALL   put_line_end_after
save_full: LOAD R1, [R8 + W_NO_FULL]
        CMPI   R1, 0x0000
        JZ     save_icon
        LA     R1, w_fullscreen_no
        CALL   put_line_end_after
save_icon: LOAD R1, [R8 + W_ICON_NAME]
        CMPI   R1, 0x0000
        JZ     save_elements
        LA     R1, w_icon
        CALL   put_text_out
        LOAD   R1, [R8 + W_ICON_NAME]
        CALL   put_line_end_after
        LOAD   R1, [label_colours]      ; label NN, not white
        CMPI   R1, WHITE_DOT
        JZ     save_elements
        LA     R1, w_label
        CALL   put_text_out
        LOAD   R1, [label_colours]
        CALL   put_hex2
        CALL   put_newline
save_elements: LOAD R9, [R8 + W_ELEMENTS]
        LOAD   R10, [R8 + W_ELEMENT_COUNT]
        LOADLO R11, 0                   ; text starts black
save_next: CMPI R10, 0x0000
        JZ     save_write
        LOADB  R1, [R9]
        CMPI   R1, 0x0000
        JZ     save_skip                ; empty, a picture that didn't load
        CMPI   R1, E_BUTTON             ; coloured text? its colour line first
        JZ     save_kind
        CMPI   R1, E_IMAGE
        JZ     save_kind
        CMPI   R1, E_ANIM
        JZ     save_kind
        CMPI   R1, E_SHELL
        JZ     save_kind
        LOADB  R2, [R9 + 3]
        CMP    R2, R11
        JZ     save_kind
        MOV    R11, R2
        LA     R1, w_colour
        CALL   put_text_out
        MOV    R1, R11
        CALL   put_hex2
        CALL   put_newline
save_kind: LOADB R1, [R9]
        CMPI   R1, E_TEXT_LINE
        JZ     save_text
        CMPI   R1, E_WRAP
        JZ     save_wrap
        CMPI   R1, E_BOX
        JZ     save_box
        CMPI   R1, E_INPUT
        JZ     save_input
        CMPI   R1, E_BUTTON
        JZ     save_button
        CMPI   R1, E_IMAGE
        JZ     save_image
        CMPI   R1, E_ANIM
        JZ     save_anim
        CMPI   R1, E_CANVAS
        JZ     save_canvas
        CMPI   R1, E_SHELL
        JZ     save_shell
        JUMP   save_skip
save_shell: LA R1, w_shell              ; shell COMMAND, kept as it is
        CALL   put_text_out
        LOAD   R1, [R9 + 4]
        CALL   put_line_end_after
        JUMP   save_skip
save_canvas: LA R1, w_canvas            ; canvas COLUMN ROW WIDTH HEIGHT [PROGRAM]
        CALL   put_text_out
        CALL   put_column_row
        CALL   put_size
        LOAD   R1, [R9 + 4]
        CMPI   R1, 0x0000
        JZ     save_canvas_end
        LOADB  R2, [R1]
        CMPI   R2, 0x0000
        JZ     save_canvas_end
        CALL   put_space
        LOAD   R1, [R9 + 4]
        CALL   put_text_out
save_canvas_end: CALL put_newline
        JUMP   save_skip
save_text: LA  R1, w_text               ; text COLUMN ROW TEXT
        CALL   put_text_out
        CALL   put_column_row
        LOAD   R1, [R9 + 4]
        CALL   put_line_end_after
        JUMP   save_skip
save_wrap: LA  R1, w_wrap               ; wrap ROW TEXT
        CALL   put_text_out
        CALL   put_name
        LOADB  R1, [R9 + 2]
        CALL   put_number
        CALL   put_space
        LOAD   R1, [R9 + 4]
        CALL   put_line_end_after
        JUMP   save_skip
save_box: LA   R1, w_box                ; box COLUMN ROW WIDTH HEIGHT TEXT
        CALL   put_text_out
        CALL   put_column_row
        CALL   put_size
        CALL   put_space
        LOAD   R1, [R9 + 4]
        CALL   put_line_end_after
        JUMP   save_skip
save_input: LA R1, w_input              ; input COLUMN ROW WIDTH HEIGHT
        CALL   put_text_out
        CALL   put_column_row
        CALL   put_size
        CALL   put_newline
        JUMP   save_skip
save_button: LA R1, w_button            ; button COLUMN ROW LABEL ACTION
        CALL   put_text_out
        CALL   put_column_row
        LOAD   R1, [R9 + 4]
        CALL   put_text_out
        LOAD   R1, [R9 + 8]
        CMPI   R1, ACTION_CLOSE
        JNZ    save_button_open
        LA     R1, w_close
        CALL   put_line_end_after
        JUMP   save_skip
save_button_open: CMPI R1, ACTION_OPEN
        JNZ    save_button_event
        LA     R1, w_open
        CALL   put_text_out
        LOAD   R1, [R9 + 12]
        CALL   put_line_end_after
        JUMP   save_skip
save_button_event: CMPI R1, ACTION_EVENT
        JNZ    save_button_none
        LA     R1, w_event
        CALL   put_text_out
        LOAD   R1, [R9 + 12]
        CALL   put_number
        CALL   put_newline
        JUMP   save_skip
save_button_none: CALL put_newline
        JUMP   save_skip
save_image: LA R1, w_image              ; image COLUMN ROW FILE
        CALL   put_text_out
        CALL   put_column_row
        LOAD   R1, [R9 + 16]
        CALL   put_line_end_after
        JUMP   save_skip
save_anim: LA  R1, w_animate            ; animate COLUMN ROW FILE FRAMEWIDTH FRAMES SPEED
        CALL   put_text_out
        CALL   put_column_row
        LOAD   R1, [R9 + 16]
        CALL   put_text_out
        CALL   put_space
        LOAD   R1, [R9 + 8]
        CALL   put_number
        CALL   put_space
        LOAD   R1, [R9 + 12]
        ANDI   R1, R1, 0xFFFF
        CALL   put_number
        CALL   put_space
        LOADB  R1, [R9 + 3]
        CALL   put_number
        CALL   put_newline
save_skip: ADDI R9, R9, ELEMENT_BYTES
        DEC    R10
        JUMP   save_next
save_write: LA R1, apps_prefix          ; the folder, /apps/NAME
        LOADLO R2, path
        CALL   text_copy
        LOADLO R1, app_name
        CALL   text_copy
        LOADLO R1, path
        CALLF  FOLDER_MAKE
        LOADLO R1, app_name             ; the file, /apps/NAME/page.txt
        LA     R2, page_name
        CALL   make_path
        CALL   tb_save                  ; write it, free the buffer
        LA     R2, saved_text
        CMPI   R1, 0x0000
        JZ     save_said
        LA     R2, not_saved_text
save_said: STORE R2, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; add_to_desktop, adds the apps name to /APPS/APPS.TXT if not there
; R8 = the lists next line, R9 = its end
add_to_desktop: PUSH R8
        PUSH   R9
        CALL   out_open
        LA     R1, apps_list_path
        CALL   load_text                ; R1 = the list or 0
        CMPI   R1, 0x0000
        JZ     desktop_add
        MOV    R8, R1
        MOV    R9, R2
desktop_line: CMP R8, R9
        JC     desktop_add              ; the end, not in the list
        LOADB  R1, [R8]
        CMPI   R1, 0x0000
        JNZ    desktop_this
        INC    R8
        JUMP   desktop_line
desktop_this: MOV R1, R8                ; is this line the name?
        LOADLO R2, app_name
        CALL   text_same
        CMPI   R3, 1
        JZ     desktop_there
        MOV    R1, R8                   ; no, copy it on
        CALL   put_line_end_after
desktop_end: LOADB R1, [R8]
        CMPI   R1, 0x0000
        JZ     desktop_line
        INC    R8
        JUMP   desktop_end
desktop_there: LA R1, there_text
        STORE  R1, [status]
        JUMP   desktop_done
desktop_add: LOADLO R1, app_name
        CALL   put_line_end_after
        LA     R1, apps_list_path
        CALL   tb_save                  ; write it, free the buffer
        LA     R2, desktop_text
        CMPI   R1, 0x0000
        JZ     desktop_said
        LA     R2, not_saved_text
desktop_said: STORE R2, [status]
desktop_done: LOADLO R1, 1
        STORE  R1, [redraw]
        POP    R9
        POP    R8
        RET

; writing text into the out buffer
