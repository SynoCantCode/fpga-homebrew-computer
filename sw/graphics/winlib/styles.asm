; styles, STYLE.TXT read, nine-slice drawing of frames
; included by winlib.asm

; init_styles, style 0 = default_style, no others loaded
init_styles: LA R1, default_style
        LOADLO R2, styles
        LOADLO R3, 0
init_styles_copy: ADD R4, R1, R3
        LOAD   R4, [R4]
        ADD    R5, R2, R3
        STORE  R4, [R5]
        ADDI   R3, R3, 4
        CMPI   R3, STYLE_BYTES
        JNZ    init_styles_copy
        LOADLO R1, 1
        STORE  R1, [style_count]
        RET

; find_style, a style by name, loaded already or read from
; /SYSTEM/DESIGN/WINDOWS/NAME/STYLE.TXT, a copy of the default changed by style_line
; in R1 = pointer to the name, it must stay
; out R1 = pointer to the style, the default if no file or no room
; R8 = name, R9 = which style / line end, R10 = style, R11 = line, R12 = file end
find_style: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        MOV    R8, R1
        LOADLO R9, 1
find_style_next: LOAD R1, [style_count]
        CMP    R9, R1
        JC     find_style_load          ; not loaded
        MULI   R10, R9, STYLE_BYTES
        LOADLO R1, styles
        ADD    R10, R10, R1
        LOAD   R2, [R10 + S_NAME]
        MOV    R1, R8
        CALL   text_same
        CMPI   R3, 1
        JZ     find_style_found
        INC    R9
        JUMP   find_style_next
find_style_load: CMPI R9, MAX_STYLES
        JZ     find_style_default       ; no room for more
        MULI   R10, R9, STYLE_BYTES     ; new style, a copy of the default first
        LOADLO R1, styles
        ADD    R10, R10, R1
        LOADLO R2, 0
find_style_copy: ADD R3, R1, R2
        LOAD   R3, [R3]
        ADD    R4, R10, R2
        STORE  R3, [R4]
        ADDI   R2, R2, 4
        CMPI   R2, STYLE_BYTES
        JNZ    find_style_copy
        STORE  R0, [R10 + S_DECO_COUNT]
        STORE  R8, [R10 + S_NAME]
        LA     R1, styles_prefix        ; its file
        MOV    R2, R8
        LA     R3, style_file
        CALL   build_path
        CALL   load_text
        CMPI   R1, 0x0000
        JZ     find_style_default       ; no such style, the default
        MOV    R11, R1
        MOV    R12, R2
        ADDI   R1, R9, 1
        STORE  R1, [style_count]        ; one more loaded
find_style_line: CMP R11, R12
        JC     find_style_found         ; end of the file
        LOADB  R1, [R11]
        CMPI   R1, 0x0000
        JNZ    find_style_line_found
        INC    R11
        JUMP   find_style_line
find_style_line_found: MOV R9, R11      ; line end found first, reading writes 0s into the line
find_style_end: LOADB R1, [R9]
        CMPI   R1, 0x0000
        JZ     find_style_ended
        INC    R9
        JUMP   find_style_end
find_style_ended: MOV R1, R11
        MOV    R2, R10
        CALL   style_line
        MOV    R11, R9
        JUMP   find_style_line
find_style_found: MOV R1, R10
        JUMP   find_style_done
find_style_default: LOADLO R1, styles
find_style_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; style_line, one line of a STYLE.TXT
; places in dots, below 0 = from the right / bottom, colours in hex
; in R1 = pointer to the line, R2 = style, R8 = style, R9 = rest of the line
style_line: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        MOV    R8, R2
        CALL   read_word
        MOV    R9, R1
        CMPI   R3, 0x0000
        JZ     style_done
        LA     R4, word_content
        CALL   word_is
        CMPI   R5, 1
        JZ     style_content
        LA     R4, word_frame
        CALL   word_is
        CMPI   R5, 1
        JZ     style_frame
        LA     R4, word_panel
        CALL   word_is
        CMPI   R5, 1
        JZ     style_panel
        LA     R4, word_header
        CALL   word_is
        CMPI   R5, 1
        JZ     style_header
        LA     R4, word_title
        CALL   word_is
        CMPI   R5, 1
        JZ     style_title
        LA     R4, word_close_box
        CALL   word_is
        CMPI   R5, 1
        JZ     style_close
        LA     R4, word_decoration
        CALL   word_is
        CMPI   R5, 1
        JZ     style_decoration
        LA     R4, word_picture
        CALL   word_is
        CMPI   R5, 1
        JZ     style_picture
        LA     R4, word_full
        CALL   word_is
        CMPI   R5, 1
        JZ     style_full
        LA     R4, word_min
        CALL   word_is
        CMPI   R5, 1
        JZ     style_min
        JUMP   style_done
style_content: MOV R1, R9               ; content LEFT TOP RIGHT BOTTOM
        CALL   read_signed
        STORE  R2, [R8 + S_CONTENT_L]
        CALL   read_signed
        STORE  R2, [R8 + S_CONTENT_T]
        CALL   read_signed
        STORE  R2, [R8 + S_CONTENT_R]
        CALL   read_signed
        STORE  R2, [R8 + S_CONTENT_B]
        JUMP   style_done
style_frame: MOV R1, R9                 ; frame FILL LIGHT DARK
        CALL   read_hex
        STORE  R2, [R8 + S_FRAME_FILL]
        CALL   read_hex
        STORE  R2, [R8 + S_FRAME_LIGHT]
        CALL   read_hex
        STORE  R2, [R8 + S_FRAME_DARK]
        JUMP   style_done
style_panel: MOV R1, R9                 ; panel LEFT TOP RIGHT BOTTOM COLOUR EDGE
        CALL   read_signed
        STORE  R2, [R8 + S_PANEL_L]
        CALL   read_signed
        STORE  R2, [R8 + S_PANEL_T]
        CALL   read_signed
        STORE  R2, [R8 + S_PANEL_R]
        CALL   read_signed
        STORE  R2, [R8 + S_PANEL_B]
        CALL   read_hex
        STORE  R2, [R8 + S_PANEL_COLOUR]
        CALL   read_hex
        STORE  R2, [R8 + S_PANEL_EDGE]
        JUMP   style_done
style_header: MOV R1, R9                ; header LEFT TOP RIGHT HEIGHT FROM TO BACKFROM BACKTO
        CALL   read_signed
        STORE  R2, [R8 + S_HEAD_L]
        CALL   read_signed
        STORE  R2, [R8 + S_HEAD_T]
        CALL   read_signed
        STORE  R2, [R8 + S_HEAD_R]
        CALL   read_signed
        STORE  R2, [R8 + S_HEAD_H]
        CALL   read_hex
        STORE  R2, [R8 + S_HEAD_FROM]
        CALL   read_hex
        STORE  R2, [R8 + S_HEAD_TO]
        CALL   read_hex
        STORE  R2, [R8 + S_HEAD_BACK_FROM]
        CALL   read_hex
        STORE  R2, [R8 + S_HEAD_BACK_TO]
        JUMP   style_done
style_title: MOV R1, R9                 ; title X Y FRONT BACK, X Y in the header
        CALL   read_signed
        STORE  R2, [R8 + S_TITLE_X]
        CALL   read_signed
        STORE  R2, [R8 + S_TITLE_Y]
        CALL   read_hex
        STORE  R2, [R8 + S_TITLE_FRONT]
        CALL   read_hex
        STORE  R2, [R8 + S_TITLE_BACK]
        JUMP   style_done
style_close: MOV R1, R9                 ; close X Y
        CALL   read_signed
        STORE  R2, [R8 + S_CLOSE_X]
        CALL   read_signed
        STORE  R2, [R8 + S_CLOSE_Y]
        CALL   skip_spaces              ; a 3rd number? 0 = dont draw the box
        LOADB  R3, [R1]
        CMPI   R3, 0x0000
        JZ     style_done
        CALL   read_number
        STORE  R2, [R8 + S_CLOSE_DRAW]
        JUMP   style_done
style_full: MOV R1, R9                  ; full X Y [DRAW], full screen button
        CALL   read_signed
        STORE  R2, [R8 + S_FULL_X]
        CALL   read_signed
        STORE  R2, [R8 + S_FULL_Y]
        CALL   skip_spaces
        LOADB  R3, [R1]
        CMPI   R3, 0x0000
        JZ     style_done
        CALL   read_number
        STORE  R2, [R8 + S_FULL_DRAW]
        JUMP   style_done
style_min: MOV R1, R9                   ; min X Y [DRAW], minimise button
        CALL   read_signed
        STORE  R2, [R8 + S_MIN_X]
        CALL   read_signed
        STORE  R2, [R8 + S_MIN_Y]
        CALL   skip_spaces
        LOADB  R3, [R1]
        CMPI   R3, 0x0000
        JZ     style_done
        CALL   read_number
        STORE  R2, [R8 + S_MIN_DRAW]
        JUMP   style_done
style_picture: MOV R1, R9               ; picture FILE.PIC LEFT TOP RIGHT BOTTOM, the slice lines
        CALL   read_word
        MOV    R12, R2
        LOADB  R4, [R1]
        STOREB R0, [R1]
        CMPI   R4, 0x0000
        JZ     style_done
        INC    R1
        CALL   read_number
        STORE  R2, [R8 + S_SLICE_L]
        CALL   read_number
        STORE  R2, [R8 + S_SLICE_T]
        CALL   read_number
        STORE  R2, [R8 + S_SLICE_R]
        CALL   read_number
        STORE  R2, [R8 + S_SLICE_B]
        LA     R1, styles_prefix        ; picture from the styles folder
        LOAD   R2, [R8 + S_NAME]
        MOV    R3, R12
        CALL   build_path
        LOADLO R2, 0
        CALL   load_picture
        CMPI   R1, 0x0000
        JZ     style_done
        STORE  R3, [R8 + S_PICTURE]
        STORE  R1, [R8 + S_PIC_W]
        STORE  R2, [R8 + S_PIC_H]
        JUMP   style_done
style_decoration: LOAD R1, [R8 + S_DECO_COUNT]   ; decoration FILE.PIC X Y, up to 2
        CMPI   R1, 2
        JZ     style_done
        MOV    R1, R9
        CALL   read_word                ; file name
        MOV    R12, R2
        LOADB  R4, [R1]
        STOREB R0, [R1]                 ; ended by a 0
        CMPI   R4, 0x0000
        JZ     style_done               ; no place given
        INC    R1
        CALL   read_signed
        MOV    R10, R2
        CALL   read_signed
        MOV    R11, R2
        LA     R1, styles_prefix        ; picture from the window styles folder
        LOAD   R2, [R8 + S_NAME]
        MOV    R3, R12
        CALL   build_path
        LOADLO R2, 0
        CALL   load_picture
        CMPI   R1, 0x0000
        JNZ    style_deco_found
        LA     R1, design_prefix        ; else the sprites
        LA     R2, sprites_name
        MOV    R3, R12
        CALL   build_path
        LOADLO R2, 0
        CALL   load_picture
style_deco_found: CMPI R1, 0x0000
        JZ     style_done
        LOAD   R4, [R8 + S_DECO_COUNT]  ; its 20 bytes, base, width, height, x, y
        MULI   R5, R4, 20
        ADDI   R5, R5, S_DECO
        ADD    R5, R5, R8
        STORE  R3, [R5]
        STORE  R1, [R5 + 4]
        STORE  R2, [R5 + 8]
        STORE  R10, [R5 + 12]
        STORE  R11, [R5 + 16]
        INC    R4
        STORE  R4, [R8 + S_DECO_COUNT]
style_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; nine_slice, draws a window from its styles picture, DRAW_PAGE already set
; 4 lines cut the picture into 9 pieces, corners copied
; edges repeat along the sides, middle fills the rest
; picture | L | middle | R |    window | L | repeated | R |
; in R1 = the windows 128 bytes, R8 = window, R9 = style, R10 = piece row 0-2, R11 = column 0-2
nine_slice: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        LOAD   R9, [R8 + W_STYLE]
        LOAD   R1, [R9 + S_PICTURE]
        STORE  R1, [t_src]
        LOAD   R1, [R8 + W_PICTURE]
        STORE  R1, [t_self]
        LOAD   R1, [R9 + S_SLICE_L]     ; across, the 3 columns of pieces
        LOAD   R2, [R9 + S_SLICE_R]
        LOAD   R3, [R9 + S_PIC_W]
        LOAD   R4, [R8 + W_WIDTH]
        STORE  R0, [slice_sx]           ; from 0, L, picture width - R
        STORE  R1, [slice_sx + 4]
        SUB    R5, R3, R2
        STORE  R5, [slice_sx + 8]
        STORE  R1, [slice_pw]           ; L, middle width, R wide
        SUB    R5, R3, R1
        SUB    R5, R5, R2
        STORE  R5, [slice_pw + 4]
        STORE  R2, [slice_pw + 8]
        STORE  R0, [slice_dx]           ; to 0, L, window width - R
        STORE  R1, [slice_dx + 4]
        SUB    R5, R4, R2
        STORE  R5, [slice_dx + 8]
        STORE  R1, [slice_dw]           ; filling L, the rest, R
        SUB    R5, R4, R1
        SUB    R5, R5, R2
        STORE  R5, [slice_dw + 4]
        STORE  R2, [slice_dw + 8]
        LOAD   R1, [R9 + S_SLICE_T]     ; down, the 3 rows, same way
        LOAD   R2, [R9 + S_SLICE_B]
        LOAD   R3, [R9 + S_PIC_H]
        LOAD   R4, [R8 + W_HEIGHT]
        STORE  R0, [slice_sy]
        STORE  R1, [slice_sy + 4]
        SUB    R5, R3, R2
        STORE  R5, [slice_sy + 8]
        STORE  R1, [slice_ph]
        SUB    R5, R3, R1
        SUB    R5, R5, R2
        STORE  R5, [slice_ph + 4]
        STORE  R2, [slice_ph + 8]
        STORE  R0, [slice_dy]
        STORE  R1, [slice_dy + 4]
        SUB    R5, R4, R2
        STORE  R5, [slice_dy + 8]
        STORE  R1, [slice_dh]
        SUB    R5, R4, R1
        SUB    R5, R5, R2
        STORE  R5, [slice_dh + 4]
        STORE  R2, [slice_dh + 8]
        LOADLO R10, 0
slice_row: LOADLO R11, 0
slice_piece: SHIFTI R1, R11, 0x02, 0b0000   ; this piece, its columns numbers
        LOAD   R3, [R1 + slice_sx]
        STORE  R3, [t_sx]
        LOAD   R3, [R1 + slice_pw]
        STORE  R3, [t_pw]
        LOAD   R3, [R1 + slice_dx]
        STORE  R3, [t_dx]
        LOAD   R3, [R1 + slice_dw]
        STORE  R3, [t_dw]
        SHIFTI R2, R10, 0x02, 0b0000    ; and its rows
        LOAD   R3, [R2 + slice_sy]
        STORE  R3, [t_sy]
        LOAD   R3, [R2 + slice_ph]
        STORE  R3, [t_ph]
        LOAD   R3, [R2 + slice_dy]
        STORE  R3, [t_dy]
        LOAD   R3, [R2 + slice_dh]
        STORE  R3, [t_dh]
        CALL   tile
        INC    R11
        CMPI   R11, 3
        JNZ    slice_piece
        INC    R10
        CMPI   R10, 3
        JNZ    slice_row
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; tile, one piece repeated to fill a box, the t_ variables
; copied once, then doubled across, 1, 2, 4, 8 pieces
; then the row doubled down the same way
; R8 = box width, R9 = box height, R10 = row filled so far, R11 = rows filled
tile:   PUSH   R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        LOAD   R8, [t_dw]
        LOAD   R9, [t_dh]
        LOAD   R10, [t_pw]
        LOAD   R11, [t_ph]
        CMPIS  R8, 1                    ; nothing to fill, or nothing to fill it with
        JGE    tile_w
        JUMP   tile_done
tile_w: CMPIS  R9, 1
        JGE    tile_h
        JUMP   tile_done
tile_h: CMPIS  R10, 1
        JGE    tile_pw
        JUMP   tile_done
tile_pw: CMPIS R11, 1
        JGE    tile_first
        JUMP   tile_done
tile_first: CMP R10, R8                 ; first piece, cut to the box
        JNC    tile_first_w
        MOV    R10, R8
tile_first_w: CMP R11, R9
        JNC    tile_first_h
        MOV    R11, R9
tile_first_h: LOAD R1, [t_dx]
        LOAD   R2, [t_dy]
        MOV    R3, R10
        MOV    R4, R11
        LOAD   R5, [t_src]
        LOAD   R6, [t_sx]
        LOAD   R7, [t_sy]
        CALL   copy_piece
tile_across: CMP R10, R8                ; across, copy whats done next to itself
        JC     tile_down
        SUB    R3, R8, R10              ; as much as is done, or whats left
        CMP    R3, R10
        JNC    tile_across_n
        MOV    R3, R10
tile_across_n: PUSH R3
        LOAD   R1, [t_dx]
        ADD    R1, R1, R10
        LOAD   R2, [t_dy]
        MOV    R4, R11
        LOAD   R5, [t_self]
        LOAD   R6, [t_dx]
        LOAD   R7, [t_dy]
        CALL   copy_piece
        POP    R3
        ADD    R10, R10, R3
        JUMP   tile_across
tile_down: CMP R11, R9                  ; down, copy the rows done below themselves
        JC     tile_done
        SUB    R4, R9, R11
        CMP    R4, R11
        JNC    tile_down_n
        MOV    R4, R11
tile_down_n: PUSH R4
        LOAD   R1, [t_dx]
        LOAD   R2, [t_dy]
        ADD    R2, R2, R11
        MOV    R3, R8
        LOAD   R5, [t_self]
        LOAD   R6, [t_dx]
        LOAD   R7, [t_dy]
        CALL   copy_piece
        POP    R4
        ADD    R11, R11, R4
        JUMP   tile_down
tile_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; copy_piece, DRAW_COPY, in R1, R2 = x, y to, R3, R4 = width, height
; R5 = source base, R6, R7 = x, y in the source
copy_piece: SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        SHIFTI R4, R4, 0x10, 0b0000
        OR     R2, R3, R4
        MOV    R3, R5
        SHIFTI R7, R7, 0x10, 0b0000
        OR     R4, R6, R7
        JUMPF  DRAW_COPY                ; tail call

; read_signed, next decimal number, maybe with a - before it
; in R1 = pointer, out R1 = just after it, R2 = value, uses R3
read_signed: CALL skip_spaces
        LOADB  R3, [R1]
        CMPI   R3, 0x002D
        JNZ    read_number              ; no -, an ordinary number
        INC    R1
        CALL   read_number
        SUB    R2, R0, R2
        RET
