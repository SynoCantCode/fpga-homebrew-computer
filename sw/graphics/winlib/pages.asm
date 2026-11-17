; pages, PAGE.TXT read into a window line by line, elements into cells, images
; included by winlib.asm

; load_page, an apps window from /APPS/NAME/PAGE.TXT
; defaults first, titled with its name, 30 x 6 cells, open, with an icon
; then each line with page_line, then its ICON.PIC
; in R1 = window 0-3 with W_NAME set, out R1 = 1 made, 0 no page
; R8 = its 128 bytes, R9 = line, R10 = page end, R11 = line end, R12 = window
load_page: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        MOV    R12, R1
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [R8 + W_NAME]
        LA     R2, page_name
        CALL   make_path                ; "/apps/NAME/page.txt"
        CALL   load_text
        CMPI   R1, 0x0000
        JZ     page_none
        MOV    R9, R1
        MOV    R10, R2
        LOADLO R1, KIND_PAGE
        STORE  R1, [R8 + W_KIND]
        LOADLO R1, 1
        STORE  R1, [R8 + W_VISIBLE]
        STORE  R1, [R8 + W_ICON]
        LOAD   R1, [R8 + W_NAME]
        STORE  R1, [R8 + W_TITLE]
        LOADLO R1, 30
        STORE  R1, [R8 + W_COLUMNS]
        LOADLO R1, 6
        STORE  R1, [R8 + W_ROWS]
        SHIFTI R1, R12, 0x05, 0b0000    ; (112 + 32 x N, 48 + 32 x N)
        ADDI   R2, R1, 112
        STORE  R2, [R8 + W_X]
        ADDI   R2, R1, 48
        STORE  R2, [R8 + W_Y]
        LOADLO R1, 0x0400               ; elements, 32 x 32 bytes
        CALLF  ALLOCATE
        STORE  R1, [R8 + W_ELEMENTS]
        STORE  R0, [R8 + W_ELEMENT_COUNT]
        STORE  R0, [text_colour]        ; text starts black
        SHIFTI R1, R12, 0x02, 0b0000    ; icon label white, unless the page says label NN
        LOADLO R2, label_colours
        ADD    R1, R1, R2
        LOADLO R2, WHITE_DOT
        STORE  R2, [R1]
page_next_line: CMP R9, R10
        JC     page_read                ; end of the page
        LOADB  R1, [R9]
        CMPI   R1, 0x0000
        JNZ    page_line_found
        INC    R9
        JUMP   page_next_line
page_line_found: MOV R11, R9            ; line end found first, reading writes 0s into the line
page_find_end: LOADB R1, [R11]
        CMPI   R1, 0x0000
        JZ     page_found_end
        INC    R11
        JUMP   page_find_end
page_found_end: MOV R1, R9
        MOV    R2, R8
        CALL   page_line
        MOV    R9, R11
        JUMP   page_next_line
page_read: LOAD R1, [icons]              ; its icon, none in Studio
        CMPI   R1, 0x0000
        JZ     page_made
        LOAD   R2, [R8 + W_ICON_NAME]
        CALL   load_icon
        JUMP   page_made

; load_icon, a windows desktop icon into the icons picture at (32 x N, 0)
; the file named, else its ICON.PIC, else GEAR.PIC, else the icon stays
; wider than 32 = frames side by side, animated by anim_tick
; in R8 = the 128 bytes, R12 = window number, R2 = pointer to file name or 0
; out R1 = 1 icon found, 0 not, uses R1-R7
load_icon: LOAD R1, [R8 + W_ICON_STRIP]  ; reuse the icons memory if it had one
        STORE  R1, [sprite_place]       ; so changing icons takes no new heap
        CALL   load_icon_now            ; every sprite is 32 tall, fits the same 32 KB
        STORE  R0, [sprite_place]
        RET
load_icon_now: PUSH R2
        CMPI   R2, 0x0000
        JNZ    licon_named
        LA     R2, icon_name
licon_named: LOAD R1, [R8 + W_NAME]
        CALL   load_sprite              ; R1 = width, 0 none, R2 = height, R3 = where
        POP    R4
        CMPI   R1, 0x0000
        JNZ    licon_found
        CMPI   R4, 0x0000               ; name not there, nothing
        JNZ    licon_none
        LOAD   R1, [R8 + W_NAME]        ; default, the gear
        LA     R2, default_icon_name
        CALL   load_sprite
        CMPI   R1, 0x0000
        JZ     licon_none
licon_found: STORE R3, [R8 + W_ICON_STRIP]  ; wider than 32 = animated icon
        SHIFTI R4, R1, 0x05, 0b1000
        STORE  R4, [R8 + W_ICON_FRAMES]
        STORE  R0, [R8 + W_ICON_FRAME]
        CMPI   R1, 33
        JNC    licon_width
        LOADLO R1, 32                   ; at most 32 x 32
licon_width: CMPI R2, 33
        JNC    licon_height
        LOADLO R2, 32
licon_height: SHIFTI R2, R2, 0x10, 0b0000
        OR     R2, R2, R1               ; R2 = size
        PUSH   R2
        PUSH   R3
        LOAD   R1, [DRAW_PAGE]
        STORE  R1, [saved_page]
        LOAD   R1, [icons]
        STORE  R1, [DRAW_PAGE]          ; icons picture, its 32 x 32 see-through first
        SHIFTI R1, R12, 0x05, 0b0000
        LOADLO R2, 0
        LOADLO R3, 32
        LOADLO R4, 32
        LOADLO R5, KEY
        CALL   box
        POP    R3
        POP    R2
        SHIFTI R1, R12, 0x05, 0b0000    ; then the picture at (32 x N, 0)
        LOADLO R4, 0
        CALLF  DRAW_COPY
        LOAD   R1, [saved_page]
        STORE  R1, [DRAW_PAGE]
        LOADLO R1, 1
        RET
licon_none: LOADLO R1, 0
        RET

page_made: LOADLO R1, 1
        JUMP   page_end
page_none: LOADLO R1, 0
page_end: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; page_line, one line of a page, first word says what it is
; unknown word, empty line or ; note is skipped
; in R1 = pointer to the line, ends with 0, R2 = the window
page_line: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        MOV    R8, R2
        CALL   read_word                ; R1 = after it, R2 = start, R3 = length
        MOV    R9, R1
        CMPI   R3, 0x0000
        JZ     line_done
        LOADB  R1, [R2]
        CMPI   R1, 0x003B
        JZ     line_done
        PUSH   R2                       ; #NAME after the keyword?
        PUSH   R3                       ; kept in element_name for this lines element
        STORE  R0, [element_name]       ; rest of the line goes on after it
        MOV    R1, R9
        CALL   skip_spaces
        LOADB  R2, [R1]
        CMPI   R2, 0x0023
        JNZ    line_unnamed
        INC    R1
        CALL   read_word                ; R2 = name start, R1 = just after it
        STORE  R2, [element_name]
        LOADB  R3, [R1]
        CMPI   R3, 0x0000
        JZ     line_name_end
        STOREB R0, [R1]                 ; 0 after the name
        INC    R1
line_name_end: MOV R9, R1
line_unnamed: POP R3
        POP    R2
        LA     R4, word_title
        CALL   word_is
        CMPI   R5, 1
        JZ     line_title
        LA     R4, word_size
        CALL   word_is
        CMPI   R5, 1
        JZ     line_size
        LA     R4, word_place
        CALL   word_is
        CMPI   R5, 1
        JZ     line_place
        LA     R4, word_hidden
        CALL   word_is
        CMPI   R5, 1
        JZ     line_hidden
        LA     R4, word_colour
        CALL   word_is
        CMPI   R5, 1
        JZ     line_colour
        LA     R4, word_text
        CALL   word_is
        CMPI   R5, 1
        JZ     line_text
        LA     R4, word_wrap
        CALL   word_is
        CMPI   R5, 1
        JZ     line_wrap
        LA     R4, word_button
        CALL   word_is
        CMPI   R5, 1
        JZ     line_button
        LA     R4, word_image
        CALL   word_is
        CMPI   R5, 1
        JZ     line_image
        LA     R4, word_box
        CALL   word_is
        CMPI   R5, 1
        JZ     line_box
        LA     R4, word_canvas
        CALL   word_is
        CMPI   R5, 1
        JZ     line_canvas
        LA     R4, word_style
        CALL   word_is
        CMPI   R5, 1
        JZ     line_style
        LA     R4, word_input
        CALL   word_is
        CMPI   R5, 1
        JZ     line_input
        LA     R4, word_fullscreen
        CALL   word_is
        CMPI   R5, 1
        JZ     line_fullscreen
        LA     R4, word_animate
        CALL   word_is
        CMPI   R5, 1
        JZ     line_animate
        LA     R4, word_icon
        CALL   word_is
        CMPI   R5, 1
        JZ     line_icon
        LA     R4, word_label
        CALL   word_is
        CMPI   R5, 1
        JZ     line_label
        LA     R4, word_shell
        CALL   word_is
        CMPI   R5, 1
        JZ     line_shell
        JUMP   line_done
line_title: MOV R1, R9                  ; title TEXT
        CALL   skip_spaces
        STORE  R1, [R8 + W_TITLE]
        JUMP   line_done
line_size: MOV R1, R9                   ; size COLUMNS ROWS, 12-76 x 2-26
        CALL   read_number
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        CMPI   R10, 12
        JC     size_columns_least
        LOADLO R10, 12
size_columns_least: CMPI R10, 77
        JNC    size_columns_most
        LOADLO R10, 76
size_columns_most: CMPI R11, 2
        JC     size_rows_least
        LOADLO R11, 2
size_rows_least: CMPI R11, 27
        JNC    size_rows_most
        LOADLO R11, 26
size_rows_most: STORE R10, [R8 + W_COLUMNS]
        STORE  R11, [R8 + W_ROWS]
        JUMP   line_done
line_place: MOV R1, R9                  ; place X Y, snapped to 8 x 16, kept on the screen
        CALL   read_number
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        CMPI   R10, 601
        JNC    place_x_ok
        LOADLO R10, 600
place_x_ok: CMPI R11, 433
        JNC    place_y_ok
        LOADLO R11, 432
place_y_ok: ANDI R10, R10, 0xFFF8
        ANDI   R11, R11, 0xFFF0
        STORE  R10, [R8 + W_X]
        STORE  R11, [R8 + W_Y]
        JUMP   line_done
line_hidden: STORE R0, [R8 + W_VISIBLE] ; hidden, starts closed
        LOADLO R1, 1
        STORE  R1, [R8 + W_HIDDEN]
        JUMP   line_done
line_shell: STORE R0, [R8 + W_VISIBLE]  ; shell COMMAND, full screen app, opening it runs the command in the shell
        MOV    R1, R9                   ; WM ends, so it never starts open
        CALL   skip_spaces
        MOV    R9, R1
        LOADLO R10, 0
        LOADLO R11, 0
        LOADLO R12, E_SHELL
        JUMP   line_store_text
line_colour: MOV R1, R9                 ; colour NN in hex, for the text lines after it
        CALL   read_hex
        STORE  R2, [text_colour]
        JUMP   line_done
line_text: MOV R1, R9                   ; text COLUMN ROW TEXT
        CALL   read_number
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        CALL   skip_spaces
        MOV    R9, R1
        LOADLO R12, E_TEXT_LINE
        JUMP   line_store_text
line_wrap: MOV R1, R9                   ; wrap ROW TEXT
        CALL   read_number
        LOADLO R10, 0
        MOV    R11, R2
        CALL   skip_spaces
        MOV    R9, R1
        LOADLO R12, E_WRAP
line_store_text: MOV R1, R8             ; text or paragraph element
        CALL   new_element
        CMPI   R1, 0x0000
        JZ     line_done                ; full, left out
        STOREB R12, [R1]
        STOREB R10, [R1 + 1]
        STOREB R11, [R1 + 2]
        LOAD   R2, [text_colour]
        STOREB R2, [R1 + 3]
        STORE  R9, [R1 + 4]
        JUMP   line_done
line_button: MOV R1, R9                 ; button COLUMN ROW LABEL ACTION
        CALL   read_number
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        MOV    R9, R1
        MOV    R1, R8
        CALL   new_element
        CMPI   R1, 0x0000
        JZ     line_done
        MOV    R12, R1
        LOADLO R2, E_BUTTON
        STOREB R2, [R12]
        STOREB R10, [R12 + 1]
        STOREB R11, [R12 + 2]
        MOV    R1, R9
        CALL   read_word                ; label, one word
        STORE  R2, [R12 + 4]
        LOADB  R4, [R1]
        STOREB R0, [R1]                 ; ended by a 0
        CMPI   R4, 0x0000
        JZ     line_done                ; no action, does nothing
        INC    R1
        CALL   read_word                ; action
        MOV    R9, R1
        LA     R4, word_close
        CALL   word_is
        CMPI   R5, 1
        JZ     button_close
        LA     R4, word_open
        CALL   word_is
        CMPI   R5, 1
        JNZ    button_event
        LOADLO R2, ACTION_OPEN          ; open NAME
        STORE  R2, [R12 + 8]
        MOV    R1, R9
        CALL   read_word
        STOREB R0, [R1]
        STORE  R2, [R12 + 12]
        JUMP   line_done
button_close: LOADLO R2, ACTION_CLOSE
        STORE  R2, [R12 + 8]
        JUMP   line_done
button_event: LA R4, word_event         ; event N, the apps button handler gets N
        CALL   word_is
        CMPI   R5, 1
        JNZ    line_done
        MOV    R1, R9
        CALL   read_number
        STORE  R2, [R12 + 12]
        LOADLO R2, ACTION_EVENT
        STORE  R2, [R12 + 8]
        JUMP   line_done
line_image: MOV R1, R9                  ; image COLUMN ROW FILE.PIC
        CALL   read_number
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        CALL   read_word
        STOREB R0, [R1]                 ; file name, ended by a 0
        MOV    R9, R2
        MOV    R1, R8
        CALL   new_element
        CMPI   R1, 0x0000
        JZ     line_done
        MOV    R12, R1                  ; kind stays 0 unless the picture loads
        STORE  R9, [R12 + 16]           ; file name, to write the page back
        STOREB R10, [R12 + 1]
        STOREB R11, [R12 + 2]
        LOAD   R1, [R8 + W_NAME]
        MOV    R2, R9
        CALL   load_sprite              ; app folder, else /SYSTEM/DESIGN/SPRITES/
        CMPI   R1, 0x0000
        JZ     line_done
        STORE  R3, [R12 + 4]            ; where
        STORE  R1, [R12 + 8]            ; width
        STORE  R2, [R12 + 12]           ; height
        LOADLO R1, E_IMAGE
        STOREB R1, [R12]
        JUMP   line_done
line_style: MOV R1, R9                  ; style NAME
        CALL   read_word
        STOREB R0, [R1]
        MOV    R1, R2
        CALL   find_style
        STORE  R1, [R8 + W_STYLE]
        JUMP   line_done
line_label: MOV R1, R9                  ; label NN, icon label colour in hex
        CALL   read_hex
        LOADLO R3, windows
        SUB    R1, R8, R3
        SHIFTI R1, R1, 0x07, 0b1000     ; window number
        SHIFTI R1, R1, 0x02, 0b0000
        LOADLO R3, label_colours        ; its place in label_colours
        ADD    R1, R1, R3
        STORE  R2, [R1]
        JUMP   line_done
line_icon: MOV R1, R9                   ; icon NAME.PIC, its desktop icon
        CALL   read_word
        STOREB R0, [R1]
        STORE  R2, [R8 + W_ICON_NAME]
        JUMP   line_done
line_animate: MOV R1, R9                ; animate COLUMN ROW FILE.PIC FRAMEWIDTH FRAMES SPEED
        CALL   read_number
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        CALL   read_word
        MOV    R12, R2                  ; file name
        LOADB  R4, [R1]
        STOREB R0, [R1]
        CMPI   R4, 0x0000
        JZ     line_done
        INC    R1
        CALL   read_number
        PUSH   R2                       ; frame width
        CALL   read_number
        PUSH   R2                       ; frames
        CALL   read_number
        PUSH   R2                       ; speed
        MOV    R1, R8
        CALL   new_element
        MOV    R9, R1
        CMPI   R9, 0x0000
        JNZ    animate_room
        POP    R2
        POP    R2
        POP    R2
        JUMP   line_done
animate_room: POP R2
        STORE  R12, [R9 + 16]           ; file name, to write the page back
        STOREB R2, [R9 + 3]             ; speed
        POP    R2
        STORE  R2, [R9 + 12]            ; frames, height goes in the top half below
        POP    R2
        STORE  R2, [R9 + 8]             ; frame width
        STOREB R10, [R9 + 1]
        STOREB R11, [R9 + 2]
        LOAD   R1, [R8 + W_NAME]        ; strip from the app folder, else the sprites
        MOV    R2, R12
        CALL   load_sprite
        CMPI   R1, 0x0000
        JZ     line_done                ; kind stays 0
        STORE  R3, [R9 + 4]
        SHIFTI R2, R2, 0x10, 0b0000
        LOAD   R1, [R9 + 12]
        OR     R1, R1, R2
        STORE  R1, [R9 + 12]
        LOADLO R1, E_ANIM
        STOREB R1, [R9]
        LOADLO R1, 1
        STORE  R1, [R8 + W_ANIMATES]
        JUMP   line_done
line_fullscreen: MOV R1, R9             ; fullscreen no, no full screen button
        CALL   read_word
        LA     R4, word_no
        CALL   word_is
        STORE  R5, [R8 + W_NO_FULL]
        JUMP   line_done
line_input: MOV R1, R9                  ; input COLUMN ROW WIDTH HEIGHT
        CALL   read_number
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        CALL   read_number
        MOV    R12, R2
        CALL   read_number
        PUSH   R2                       ; height
        LOADLO R1, 0x0104               ; buffer, INPUT_MAX letters, a cursor, a 0
        CALLF  ALLOCATE
        MOV    R9, R1
        POP    R2
        CMPI   R9, 0x0000
        JZ     line_done
        STOREB R0, [R9]                 ; empty
        PUSH   R2
        MOV    R1, R8
        CALL   new_element
        POP    R2
        CMPI   R1, 0x0000
        JZ     line_done
        LOADLO R3, E_INPUT
        STOREB R3, [R1]
        STOREB R10, [R1 + 1]
        STOREB R11, [R1 + 2]
        LOAD   R3, [text_colour]
        STOREB R3, [R1 + 3]
        STORE  R9, [R1 + 4]
        STORE  R12, [R1 + 8]
        STORE  R2, [R1 + 12]
        JUMP   line_done
line_canvas: MOV R1, R9                 ; canvas COLUMN ROW WIDTH HEIGHT [PROGRAM], where a real app draws
        CALL   read_number              ; PROGRAM = which APP.BIN runs in it, else the apps own
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        CALL   read_number
        MOV    R12, R2
        CALL   read_number
        PUSH   R2
        CALL   read_word                ; program path, empty text if none
        STOREB R0, [R1]
        MOV    R9, R2
        MOV    R1, R8
        CALL   new_element
        POP    R2
        CMPI   R1, 0x0000
        JZ     line_done
        LOADLO R3, E_CANVAS
        STOREB R3, [R1]
        STOREB R10, [R1 + 1]
        STOREB R11, [R1 + 2]
        STORE  R9, [R1 + 4]
        STORE  R12, [R1 + 8]
        STORE  R2, [R1 + 12]
        JUMP   line_done
line_box: MOV R1, R9                    ; box COLUMN ROW WIDTH HEIGHT TEXT
        CALL   read_number
        MOV    R10, R2
        CALL   read_number
        MOV    R11, R2
        CALL   read_number
        MOV    R12, R2                  ; width
        CALL   read_number
        PUSH   R2                       ; height
        CALL   skip_spaces
        MOV    R9, R1
        MOV    R1, R8
        CALL   new_element
        POP    R2
        CMPI   R1, 0x0000
        JZ     line_done
        LOADLO R3, E_BOX
        STOREB R3, [R1]
        STOREB R10, [R1 + 1]
        STOREB R11, [R1 + 2]
        LOAD   R3, [text_colour]
        STOREB R3, [R1 + 3]
        STORE  R9, [R1 + 4]
        STORE  R12, [R1 + 8]
        STORE  R2, [R1 + 12]
        JUMP   line_done
line_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; new_element, new empty element, in R1 = the windows 128 bytes
; out R1 = pointer to its 32 bytes or 0 if MAX_ELEMENTS, uses R2, R3
new_element: LOAD R2, [R1 + W_ELEMENT_COUNT]
        CMPI   R2, MAX_ELEMENTS
        JZ     new_element_full
        ADDI   R3, R2, 1
        STORE  R3, [R1 + W_ELEMENT_COUNT]
        SHIFTI R2, R2, 0x05, 0b0000
        LOAD   R3, [R1 + W_ELEMENTS]
        ADD    R1, R3, R2
        STORE  R0, [R1]
        STORE  R0, [R1 + 4]
        STORE  R0, [R1 + 8]
        STORE  R0, [R1 + 12]
        STORE  R0, [R1 + 16]
        STORE  R0, [R1 + 20]
        LOAD   R2, [element_name]       ; its name if the line had one
        STORE  R2, [R1 + E_NAME]
        STORE  R0, [element_name]
        STORE  R0, [R1 + 28]
        RET
new_element_full: LOADLO R1, 0
        RET

; page_into_cells, texts, paragraphs, boxes and button labels into the cells
; button frames drawn here, behind the labels
; rows the window doesnt have and buttons wider than it are left out
; in R1 = the windows 128 bytes
; R8 = window, R9 = element, R10 = elements left, R11 = column, R12 = row
page_into_cells: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        MOV    R8, R1
        LOAD   R9, [R8 + W_ELEMENTS]
        LOAD   R10, [R8 + W_ELEMENT_COUNT]
into_next: CMPI R10, 0x0000
        JZ     into_done
        LOADB  R11, [R9 + 1]
        LOADB  R12, [R9 + 2]
        LOAD   R1, [R8 + W_ROWS]
        LOAD   R2, [scroll_now]
        ADD    R1, R1, R2
        CMP    R12, R1
        JC     into_skip                ; below the last row in view
        LOADB  R1, [R9]
        CMPI   R1, E_WRAP
        JZ     into_wrap                ; paragraphs and boxes, wrap_box uses page rows
        CMPI   R1, E_BOX
        JZ     into_wrap
        SUB    R12, R12, R2             ; page row to window row
        CMPIS  R12, 0
        JGE    into_kind
        JUMP   into_skip                ; scrolled away above
into_kind: CMPI R1, E_TEXT_LINE
        JZ     into_text
        CMPI   R1, E_BUTTON
        JZ     into_button
        CMPI   R1, E_INPUT
        JZ     into_input
        CMPI   R1, E_CANVAS
        JZ     into_canvas
        JUMP   into_skip
into_canvas: LOAD R6, [R8 + W_STYLE]    ; canvas, a dark box
        SHIFTI R1, R11, 0x03, 0b0000
        LOAD   R4, [R6 + S_CONTENT_L]
        ADD    R1, R1, R4
        SHIFTI R2, R12, 0x04, 0b0000
        LOAD   R4, [R6 + S_CONTENT_T]
        ADD    R2, R2, R4
        LOAD   R3, [R9 + 8]
        SHIFTI R3, R3, 0x03, 0b0000
        CALL   vis_height               ; rows, cut at the windows last
        SHIFTI R4, R4, 0x04, 0b0000
        LOADLO R5, 0x02
        CALL   box
        LOAD   R4, [R9 + 4]             ; program path in white on its top row
        CMPI   R4, 0x0000
        JZ     into_skip
        MOV    R1, R8
        MOV    R2, R11
        MOV    R3, R12
        LOADLO R5, WHITE_DOT
        CALL   put_text
        JUMP   into_skip
into_input: LOAD R5, [R8 + W_STYLE]     ; input, white box with a grey line round it
        SHIFTI R1, R11, 0x03, 0b0000
        LOAD   R4, [R5 + S_CONTENT_L]
        ADD    R1, R1, R4
        SUBI   R1, R1, 1
        SHIFTI R2, R12, 0x04, 0b0000
        LOAD   R4, [R5 + S_CONTENT_T]
        ADD    R2, R2, R4
        SUBI   R2, R2, 1
        LOAD   R3, [R9 + 8]
        SHIFTI R3, R3, 0x03, 0b0000
        ADDI   R3, R3, 2
        CALL   vis_height               ; rows, cut at the windows last
        SHIFTI R4, R4, 0x04, 0b0000
        ADDI   R4, R4, 2
        CALL   field_box
        LOAD   R1, [focus_element]      ; its text, with a _ after it if typing goes here
        CMP    R1, R9
        JNZ    into_input_text
        LOAD   R1, [R9 + 4]
        CALL   text_length
        ADD    R1, R1, R2
        LOADLO R2, 0x005F
        STOREB R2, [R1]
        STOREB R0, [R1 + 1]
        MOV    R1, R8
        MOV    R2, R9
        CALL   wrap_box
        LOAD   R1, [R9 + 4]             ; take the _ off again
        CALL   text_length
        ADD    R1, R1, R2
        SUBI   R1, R1, 1
        STOREB R0, [R1]
        JUMP   into_skip
into_input_text: MOV R1, R8
        MOV    R2, R9
        CALL   wrap_box
        JUMP   into_skip
into_text: MOV R1, R8
        MOV    R2, R11
        MOV    R3, R12
        LOAD   R4, [R9 + 4]
        LOADB  R5, [R9 + 3]
        CALL   put_text
        JUMP   into_skip
into_wrap: MOV R1, R8                   ; paragraph or box, wrapped
        MOV    R2, R9
        CALL   wrap_box
        JUMP   into_skip
into_button: LOAD R1, [R9 + 4]
        CALL   text_length                   ; R2 = label length
        ADD    R3, R11, R2
        ADDI   R3, R3, 2                ; button = label + a cell each side
        LOAD   R1, [R8 + W_COLUMNS]
        CMP    R1, R3
        JNC    into_skip                ; wider than the window, left out
        ADDI   R3, R2, 2
        SHIFTI R3, R3, 0x03, 0b0000     ; width in dots
        LOAD   R5, [R8 + W_STYLE]
        SHIFTI R1, R11, 0x03, 0b0000    ; place of the cell
        LOAD   R4, [R5 + S_CONTENT_L]
        ADD    R1, R1, R4
        SHIFTI R2, R12, 0x04, 0b0000
        LOAD   R4, [R5 + S_CONTENT_T]
        ADD    R2, R2, R4
        LOADLO R4, 16
        LOADLO R5, 1
        LOAD   R6, [hover_button]       ; pointer over it, lit up
        CMP    R6, R9
        JNZ    into_button_box
        LOADLO R5, 2
into_button_box: CALL bevel_box
        MOV    R1, R8                   ; label, one cell in
        ADDI   R2, R11, 1
        MOV    R3, R12
        LOAD   R4, [R9 + 4]
        LOADLO R5, BLACK_DOT
        CALL   put_text
into_skip: ADDI R9, R9, ELEMENT_BYTES
        DEC    R10
        JUMP   into_next
into_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; page_images, a pages pictures into its picture, colour 0xFE skipped
; in R1 = the windows 128 bytes, R8 = window, R9 = element, R10 = elements left
page_images: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        LOAD   R9, [R8 + W_ELEMENTS]
        LOAD   R10, [R8 + W_ELEMENT_COUNT]
images_next: CMPI R10, 0x0000
        JZ     images_done
        LOADB  R1, [R9]
        CMPI   R1, E_ANIM
        JZ     images_anim
        CMPI   R1, E_IMAGE
        JNZ    images_skip
        LOAD   R5, [R8 + W_STYLE]
        LOADB  R1, [R9 + 1]             ; at (left margin + column x 8, top margin + row x 16)
        SHIFTI R1, R1, 0x03, 0b0000
        LOAD   R4, [R5 + S_CONTENT_L]
        ADD    R1, R1, R4
        LOADB  R2, [R9 + 2]
        CALL   image_row                ; row in the window, -1 = not wholly in view
        CMPIS  R2, 0
        JGE    image_in_1
        JUMP   images_skip
image_in_1: SHIFTI R2, R2, 0x04, 0b0000
        LOAD   R4, [R5 + S_CONTENT_T]
        ADD    R2, R2, R4
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        LOAD   R2, [R9 + 8]             ; size
        LOAD   R3, [R9 + 12]
        SHIFTI R3, R3, 0x10, 0b0000
        OR     R2, R2, R3
        LOAD   R3, [R9 + 4]
        ORI    R3, R3, KEY
        LOADLO R4, 0
        CALLF  DRAW_SPRITE
images_skip: ADDI R9, R9, ELEMENT_BYTES
        DEC    R10
        JUMP   images_next
images_anim: LOAD R5, [R8 + W_STYLE]    ; animation, frame = (timer x speed / 100) mod frames
        LOADB  R1, [R9 + 1]
        SHIFTI R1, R1, 0x03, 0b0000
        LOAD   R4, [R5 + S_CONTENT_L]
        ADD    R1, R1, R4
        LOADB  R2, [R9 + 2]
        CALL   image_row                ; row in the window, -1 = not wholly in view
        CMPIS  R2, 0
        JGE    image_in_2
        JUMP   images_skip
image_in_2: SHIFTI R2, R2, 0x04, 0b0000
        LOAD   R4, [R5 + S_CONTENT_T]
        ADD    R2, R2, R4
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2               ; where
        PUSH   R1
        LOAD   R1, [TIMER]
        LOADB  R2, [R9 + 3]
        MUL    R1, R1, R2
        DIVUI  R1, R1, TICKS_PER_SECOND ; frames since the start
        LOAD   R2, [R9 + 12]
        ANDI   R2, R2, 0xFFFF
        CMPI   R2, 0x0000
        JNZ    images_frames
        LOADLO R2, 1
images_frames: MODU R1, R1, R2          ; this frame
        LOAD   R4, [R9 + 8]
        MUL    R4, R1, R4               ; its x in the strip
        LOAD   R2, [R9 + 12]            ; size = frame width x strip height
        SHIFTI R2, R2, 0x10, 0b1000
        SHIFTI R2, R2, 0x10, 0b0000
        LOAD   R3, [R9 + 8]
        OR     R2, R2, R3
        LOAD   R3, [R9 + 4]
        ORI    R3, R3, KEY
        POP    R1
        CALLF  DRAW_SPRITE
        JUMP   images_skip
images_done: POP R10
        POP    R9
        POP    R8
        RET
