; screen, the window being designed, the toolbar, the outline
; included by studio.asm

; studio_compose, draws the workspace on the hidden page, then shows it
; toolbar, window, outline, status line, R8 = window
studio_compose: PUSH R8
        LOADLO R1, WHITE_DOT
        CALLF  DRAW_CLEAR
        CALL   toolbar
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [R8 + W_X]           ; the windows picture
        LOAD   R2, [R8 + W_Y]
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        LOAD   R2, [R8 + W_WIDTH]
        LOAD   R3, [R8 + W_HEIGHT]
        SHIFTI R3, R3, 0x10, 0b0000
        OR     R2, R2, R3
        LOAD   R3, [R8 + W_PICTURE]
        LOADLO R4, 0
        LOAD   R5, [R8 + W_STYLE]
        LOAD   R5, [R5 + S_PICTURE]
        CMPI   R5, 0x0000
        JNZ    compose_shaped
        CALLF  DRAW_COPY
        JUMP   compose_header
compose_shaped: ORI R3, R3, KEY         ; a drawn style, see-through corners
        CALLF  DRAW_SPRITE
compose_header: MOV R1, R8              ; its header, at the front
        LOADLO R2, 1
        CALL   title_bar
        CALL   outline_selected
        CALL   icon_preview
        LOADLO R1, 0                    ; the status line
        LOADLO R2, STATUS_Y
        LOADLO R3, PIXELS_ACROSS
        LOADLO R4, PIXELS_DOWN - STATUS_Y
        LOADLO R5, 1
        CALL   bevel_box
        LOADLO R1, 8
        LOADLO R2, STATUS_Y + 2
        LOAD   R3, [status]
        LOADLO R4, BLACK_DOT
        CALL   text
        CALLF  DRAW_FLIP
        POP    R8
        RET

; icon_preview, top right, a teal square with the apps icon
; its title under it, centred, in its label colour
icon_preview: LOADLO R1, 544            ; teal square
        LOADLO R2, 32
        LOADLO R3, 96
        LOADLO R4, 64
        LOADLO R5, TEAL
        CALL   box
        LOADLO R1, 0
        CALL   window_record
        LOAD   R1, [R1 + W_ICON_NAME]
        CMPI   R1, 0x0000
        JNZ    preview_named
        LA     R1, default_icon_name
preview_named: CALL get_sprite          ; R1 = width or 0, R2 = height, R3 = base
        CMPI   R1, 0x0000
        JZ     preview_label
        LOADHI R1, 36                   ; the icon at 576, 36
        ORI    R1, R1, 576
        LOADHI R2, 32
        ORI    R2, R2, 32
        ORI    R3, R3, KEY
        LOADLO R4, 0
        CALLF  DRAW_SPRITE
preview_label: LOADLO R1, 0             ; title centred, x = 592 - 4 x its letters
        CALL   window_record
        LOAD   R1, [R1 + W_TITLE]
        CALL   text_length
        SHIFTI R2, R2, 0x02, 0b0000
        LOADLO R1, 592
        SUB    R1, R1, R2
        CMPIS  R1, 544
        JGE    preview_x
        LOADLO R1, 544
preview_x: LOADLO R2, 72
        PUSH   R1
        LOADLO R1, 0
        CALL   window_record
        LOAD   R3, [R1 + W_TITLE]
        POP    R1
        LOAD   R4, [label_colours]
        CALL   text
        RET

; toolbar, the bar along the top and its buttons, 4 dots apart
; a button = its label + 4 dots each side
; R8 = pointer into the labels, R9 = next buttons x
toolbar: PUSH  R8
        PUSH   R9
        LOADLO R1, 0
        LOADLO R2, 0
        LOADLO R3, PIXELS_ACROSS
        LOADLO R4, TOOLBAR_H
        LOADLO R5, 1
        CALL   bevel_box
        LA     R8, toolbar_labels
        LOADLO R9, 4
toolbar_next: LOAD R1, [R8]
        CMPI   R1, 0x0000
        JZ     toolbar_done
        CALL   text_length                   ; R2 = label length
        SHIFTI R3, R2, 0x03, 0b0000
        ADDI   R3, R3, 8                ; button width
        PUSH   R3
        MOV    R1, R9
        LOADLO R2, 4
        LOADLO R4, 20
        LOADLO R5, 1
        CALL   bevel_box
        ADDI   R1, R9, 4                ; its label
        LOADLO R2, 6
        LOAD   R3, [R8]
        LOADLO R4, BLACK_DOT
        CALL   text
        POP    R3
        ADD    R9, R9, R3
        ADDI   R9, R9, 4
        ADDI   R8, R8, 4
        JUMP   toolbar_next
toolbar_done: POP R9
        POP    R8
        RET

; toolbar_at, which toolbar button is at an x
; in R1 = x, out R1 = its number or -1
; 0 Text, 1 Box, 2 Input, 3 Button, 4 Sprite, 5 Canvas, 6 Style
; 7 Colour, 8 Action, 9 Save, 10 Desktop, 11 Icon
; R8 = pointer into the labels, R9 = button x, R10 = x asked, R11 = number
toolbar_at: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R10, R1
        LA     R8, toolbar_labels
        LOADLO R9, 4
        LOADLO R11, 0
toolbar_at_next: LOAD R1, [R8]
        CMPI   R1, 0x0000
        JZ     toolbar_at_none
        CALL   text_length
        SHIFTI R3, R2, 0x03, 0b0000
        ADDI   R3, R3, 8
        CMP    R10, R9
        JNC    toolbar_at_none          ; left of it, in the gap
        ADD    R4, R9, R3
        CMP    R10, R4
        JNC    toolbar_at_found         ; inside it
        ADD    R9, R4, R0
        ADDI   R9, R9, 4
        ADDI   R8, R8, 4
        INC    R11
        JUMP   toolbar_at_next
toolbar_at_found: MOV R1, R11
        JUMP   toolbar_at_end
toolbar_at_none: NOT R1, R0
toolbar_at_end: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; outline_selected, a blue line round the selected element
; or round the header if the title is selected
; R8 = window, R9-R12 = x, y, width, height
outline_selected: LOAD R1, [selected]
        CMPI   R1, 0x0000
        JNZ    outline_go
        LOAD   R1, [title_selected]
        CMPI   R1, 0x0000
        JNZ    outline_go
        RET
outline_go: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [selected]
        CMPI   R1, 0x0000
        JNZ    outline_element
        LOAD   R9, [R8 + W_X]           ; the title, outline the header
        LOAD   R10, [R8 + W_Y]
        LOAD   R11, [R8 + W_WIDTH]
        LOAD   R12, [R8 + W_STYLE]
        LOAD   R12, [R12 + S_CONTENT_T]
        JUMP   outline_lines
outline_element: MOV R2, R8
        CALL   element_cells            ; R1 = column, R2 = row, R3 = width, R4 = height
        LOAD   R5, [scroll_rows]        ; scrolled away above, no outline
        SUB    R2, R2, R5
        CMPIS  R2, 0
        JGE    outline_in_view
        JUMP   outline_done
outline_in_view:
        LOAD   R5, [R8 + W_STYLE]
        SHIFTI R9, R1, 0x03, 0b0000
        LOAD   R6, [R5 + S_CONTENT_L]
        ADD    R9, R9, R6
        LOAD   R6, [R8 + W_X]
        ADD    R9, R9, R6
        SUBI   R9, R9, 2                ; 2 dots out
        SHIFTI R10, R2, 0x04, 0b0000
        LOAD   R6, [R5 + S_CONTENT_T]
        ADD    R10, R10, R6
        LOAD   R6, [R8 + W_Y]
        ADD    R10, R10, R6
        SUBI   R10, R10, 2
        SHIFTI R11, R3, 0x03, 0b0000
        ADDI   R11, R11, 4
        SHIFTI R12, R4, 0x04, 0b0000
        ADDI   R12, R12, 4
outline_lines: MOV R1, R9               ; top
        MOV    R2, R10
        MOV    R3, R11
        LOADLO R4, 2
        LOADLO R5, OUTLINE
        CALL   box
        MOV    R1, R9                   ; bottom
        ADD    R2, R10, R12
        SUBI   R2, R2, 2
        MOV    R3, R11
        LOADLO R4, 2
        LOADLO R5, OUTLINE
        CALL   box
        MOV    R1, R9                   ; left
        MOV    R2, R10
        LOADLO R3, 2
        MOV    R4, R12
        LOADLO R5, OUTLINE
        CALL   box
        ADD    R1, R9, R11              ; right
        SUBI   R1, R1, 2
        MOV    R2, R10
        LOADLO R3, 2
        MOV    R4, R12
        LOADLO R5, OUTLINE
        CALL   box
        LOAD   R1, [selected]           ; box or input, a size handle in its bottom right corner
        CMPI   R1, 0x0000
        JZ     outline_done
        LOADB  R1, [R1]
        CMPI   R1, E_BOX
        JZ     outline_handle
        CMPI   R1, E_CANVAS
        JZ     outline_handle
        CMPI   R1, E_INPUT
        JNZ    outline_done
outline_handle: ADD R1, R9, R11
        SUBI   R1, R1, 8
        ADD    R2, R10, R12
        SUBI   R2, R2, 8
        LOADLO R3, 8
        LOADLO R4, 8
        LOADLO R5, OUTLINE
        CALL   box
outline_done:
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; element_cells, the cells an element covers, at least 1 x 1
; in R1 = pointer to the element, R2 = its window
; out R1 = column, R2 = row, R3 = width, R4 = height
; uses R5, R6
element_cells: MOV R5, R1
        MOV    R6, R2
        LOADB  R2, [R5]
        CMPI   R2, E_TEXT_LINE
        JZ     cells_text
        CMPI   R2, E_WRAP
        JZ     cells_wrap
        CMPI   R2, E_BUTTON
        JZ     cells_button
        CMPI   R2, E_IMAGE
        JZ     cells_image
        CMPI   R2, E_ANIM
        JZ     cells_anim
        LOAD   R3, [R5 + 8]             ; box, input, their own size
        LOAD   R4, [R5 + 12]
        JUMP   cells_place
cells_text: LOAD R1, [R5 + 4]
        PUSH   R5
        CALL   text_length
        POP    R5
        MOV    R3, R2
        LOADLO R4, 1
        JUMP   cells_place
cells_button: LOAD R1, [R5 + 4]
        PUSH   R5
        CALL   text_length
        POP    R5
        ADDI   R3, R2, 2
        LOADLO R4, 1
        JUMP   cells_place
cells_wrap: PUSH R5                     ; paragraph, the whole width, its wrapped rows
        PUSH   R6
        LOAD   R1, [R5 + 4]
        LOAD   R2, [R6 + W_COLUMNS]
        CALL   text_rows
        MOV    R4, R1
        POP    R6
        POP    R5
        LOAD   R3, [R6 + W_COLUMNS]
        LOADB  R2, [R5 + 2]
        LOADLO R1, 0
        JUMP   cells_sized
cells_image: LOAD R3, [R5 + 8]
        LOAD   R4, [R5 + 12]
        JUMP   cells_round
cells_anim: LOAD R3, [R5 + 8]
        LOAD   R4, [R5 + 12]
        SHIFTI R4, R4, 0x10, 0b1000
cells_round: ADDI R3, R3, 7             ; dots to cells, rounded up
        SHIFTI R3, R3, 0x03, 0b1000
        ADDI   R4, R4, 15
        SHIFTI R4, R4, 0x04, 0b1000
cells_place: LOADB R1, [R5 + 1]
        LOADB  R2, [R5 + 2]
cells_sized: CMPIS R3, 1
        JGE    cells_width
        LOADLO R3, 1
cells_width: CMPIS R4, 1
        JGE    cells_done
        LOADLO R4, 1
cells_done: RET

; the mouse
