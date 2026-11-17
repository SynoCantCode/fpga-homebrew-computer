; keys, typing into a text, the name and title, page up and down
; included by studio.asm

; studio_key, a key typed
; Delete removes the element, Backspace and letters change its text
; in R1 = key, R8 = element
studio_key: CMPI R1, KEY_PAGE_UP       ; Page Up, Page Down scroll the page
        JZ     key_page
        CMPI   R1, KEY_PAGE_DOWN
        JZ     key_page
        CMPI   R1, KEY_DELETE
        JZ     delete_selected
        LOAD   R2, [title_selected]
        CMPI   R2, 0x0000
        JNZ    title_key
        PUSH   R8
        LOAD   R8, [selected]
        CMPI   R8, 0x0000
        JZ     key_done
        CMPI   R1, 0x0009               ; Tab, typing goes to its name or back
        JZ     name_toggle
        LOAD   R2, [name_for]
        CMP    R2, R8
        JZ     name_key
        LOADB  R2, [R8]
        CMPI   R2, E_IMAGE
        JZ     key_done                 ; pictures and animations have no text
        CMPI   R2, E_ANIM
        JZ     key_done
        PUSH   R1
        LOADB  R2, [R8 + OWN_TEXT]
        CMPI   R2, 0x0000
        JNZ    key_own
        LOADLO R1, 0x0104               ; its own copy first
        CALLF  ALLOCATE
        MOV    R2, R1
        LOAD   R1, [R8 + 4]
        STORE  R2, [R8 + 4]
        CALL   text_copy
        LOADLO R1, 1
        STOREB R1, [R8 + OWN_TEXT]
key_own: POP R6                         ; R6 = key
        LOAD   R1, [R8 + 4]
        CALL   text_length                   ; R2 = length
        LOAD   R5, [R8 + 4]
        ADD    R5, R5, R2               ; R5 = its end
        CMPI   R6, 0x0008
        JNZ    key_letter
        CMPI   R2, 0x0000
        JZ     key_done
        SUBI   R5, R5, 1
        STOREB R0, [R5]
        JUMP   key_changed
key_letter: CMPI R6, 0x000A
        JNZ    key_not_enter
        LOADB  R3, [R8]                 ; Enter, new line in a box or paragraph
        CMPI   R3, E_BOX
        JZ     key_enter
        CMPI   R3, E_WRAP
        JZ     key_enter
        CMPI   R3, E_INPUT              ; or in an input
        JNZ    key_done
        CMPI   R2, INPUT_MAX
        JC     key_done
        STOREB R6, [R5]                 ; a real Enter, 0x0A
        STOREB R0, [R5 + 1]
        JUMP   key_check
key_enter: CMPI R2, INPUT_MAX - 1
        JC     key_done
        LOADLO R3, 0x005C
        STOREB R3, [R5]
        LOADLO R3, 0x006E
        STOREB R3, [R5 + 1]
        STOREB R0, [R5 + 2]
        JUMP   key_check
key_not_enter: CMPI R6, 0x0020
        JNC    key_done                 ; not a letter
        CMPI   R6, 0x007F
        JC     key_done
        CMPI   R2, INPUT_MAX
        JC     key_done                 ; full
        LOADB  R3, [R8]
        CMPI   R3, E_BUTTON
        JNZ    key_put
        CMPI   R6, 0x0020
        JNZ    key_put
        LOADLO R6, 0x005F               ; button label is one word, space becomes _
key_put: STOREB R6, [R5]
        STOREB R0, [R5 + 1]
key_check: PUSH R5                      ; still fits?
        MOV    R1, R8
        CALL   element_fits
        POP    R5
        CMPI   R1, 0x0000
        JNZ    key_changed
        STOREB R0, [R5]                 ; no, take it off again
        LA     R1, fits_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   key_done
key_changed: LOADLO R1, 0
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
key_done: POP R8
        RET

; names, an elements #name, what its program finds it by
; name_toggle, Tab, typing goes to the name or back to the text
; R8 = element, pushed by studio_key
name_toggle: LOAD R2, [name_for]
        CMP    R2, R8
        JZ     name_off
        STORE  R8, [name_for]
        LOADB  R2, [R8 + OWN_NAME]
        CMPI   R2, 0x0000
        JNZ    name_show
        LOADLO R1, NAME_MOST + 1        ; own copy, NAME_MOST letters + the 0
        CALLF  ALLOCATE
        STOREB R0, [R1]
        LOAD   R2, [R8 + E_NAME]
        STORE  R1, [R8 + E_NAME]
        CMPI   R2, 0x0000
        JZ     name_owned
        MOV    R4, R1                   ; copy the old name in
        MOV    R1, R2
        MOV    R2, R4
        CALL   text_copy
name_owned: LOADLO R1, 1
        STOREB R1, [R8 + OWN_NAME]
name_show: LA  R1, name_status_text     ; status line shows the name
        LOAD   R2, [R8 + E_NAME]
        CALL   say_two
        JUMP   key_done
name_off: STORE R0, [name_for]
        LA     R1, name_back_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   key_done
; name_key, a key for the name, no space, # or /, up to NAME_MOST
; in R1 = key, R8 = element
name_key: MOV  R6, R1
        LOAD   R5, [R8 + E_NAME]
        MOV    R1, R5
        CALL   text_length                   ; R2 = length
        ADD    R5, R5, R2               ; R5 = its end
        CMPI   R6, 0x0008
        JNZ    name_letter
        CMPI   R2, 0x0000
        JZ     name_show
        SUBI   R5, R5, 1
        STOREB R0, [R5]
        JUMP   name_show
name_letter: CMPI R6, 0x0021
        JNC    name_show
        CMPI   R6, 0x007F
        JC     name_show
        CMPI   R6, 0x0023
        JZ     name_show
        CMPI   R6, 0x002F
        JZ     name_show
        CMPI   R2, NAME_MOST
        JZ     name_show
        STOREB R6, [R5]
        STOREB R0, [R5 + 1]
        JUMP   name_show

; key_page, window 0 scrolls rows - 1, in R1 = key
key_page: PUSH R1
        LOADLO R1, 0
        CALL   window_record
        LOAD   R2, [R1 + W_ROWS]
        SUBI   R2, R2, 1
        POP    R3
        LOADLO R1, 0
        CMPI   R3, KEY_PAGE_DOWN
        JZ     scroll_by
        SUB    R2, R0, R2
        JUMP   scroll_by

; title_key, a key typed while the title is selected
; up to TITLE_MAX and columns - 6 letters
; in R1 = key, R8 = window, R6 = key
title_key: PUSH R8
        PUSH   R1
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R1, [title_own]
        CMPI   R1, 0x0000
        JNZ    tkey_owned
        LOADLO R1, 0x0040               ; its own copy first
        CALLF  ALLOCATE
        MOV    R2, R1
        LOAD   R1, [R8 + W_TITLE]
        STORE  R2, [R8 + W_TITLE]
        CALL   text_copy
        LOADLO R1, 1
        STORE  R1, [title_own]
tkey_owned: POP R6
        LOAD   R1, [R8 + W_TITLE]
        CALL   text_length                   ; R2 = length
        LOAD   R5, [R8 + W_TITLE]
        ADD    R5, R5, R2               ; R5 = its end
        CMPI   R6, 0x0008
        JNZ    tkey_letter
        CMPI   R2, 0x0000
        JZ     tkey_done
        SUBI   R5, R5, 1
        STOREB R0, [R5]
        JUMP   tkey_changed
tkey_letter: CMPI R6, 0x0020
        JNC    tkey_done               ; not a letter
        CMPI   R6, 0x007F
        JC     tkey_done
        CMPI   R2, TITLE_MAX
        JC     tkey_full
        LOAD   R3, [R8 + W_COLUMNS]
        SUBI   R3, R3, 6
        CMP    R2, R3
        JC     tkey_full
        STOREB R6, [R5]
        STOREB R0, [R5 + 1]
tkey_changed: LOADLO R1, 1             ; header is drawn each time, no draw_window
        STORE  R1, [redraw]
        JUMP   tkey_done
tkey_full: LA R1, title_full_text
        STORE  R1, [status]
        LOADLO R1, 1
        STORE  R1, [redraw]
tkey_done: POP R8
        RET

; all_fit, is everything inside window 0
; out R1 = 1 yes, 0 no, uses R1-R7
; R8 = window, R9 = element, R10 = count
all_fit: PUSH  R8
        PUSH   R9
        PUSH   R10
        LOADLO R1, 0
        CALL   window_record
        MOV    R8, R1
        LOAD   R9, [R8 + W_ELEMENTS]
        LOAD   R10, [R8 + W_ELEMENT_COUNT]
all_fit_next: CMPI R10, 0x0000
        JZ     all_fit_yes
        LOADB  R1, [R9]
        CMPI   R1, 0x0000
        JZ     all_fit_skip             ; empty
        CMPI   R1, E_WRAP
        JZ     all_fit_text             ; a paragraph is as wide as the window
        MOV    R1, R9
        MOV    R2, R8
        CALL   element_cells            ; R1 = column, R2 = row, R3 = width, R4 = height
        ADD    R1, R1, R3
        LOAD   R3, [R8 + W_COLUMNS]
        CMP    R3, R1
        JNC    all_fit_no               ; right edge past the last column
        ADD    R2, R2, R4
        LOADLO R4, PAGE_MAX
        CMP    R4, R2
        JNC    all_fit_no               ; bottom past PAGE_MAX
all_fit_text: LOADB R1, [R9 + 2]
        LOADLO R2, PAGE_MAX
        CMP    R1, R2
        JC     all_fit_no               ; paragraph row past the last row
        MOV    R1, R9
        CALL   element_fits
        CMPI   R1, 0x0000
        JZ     all_fit_no
all_fit_skip: ADDI R9, R9, ELEMENT_BYTES
        DEC    R10
        JUMP   all_fit_next
all_fit_yes: LOADLO R1, 1
        JUMP   all_fit_end
all_fit_no: LOADLO R1, 0
all_fit_end: POP R10
        POP    R9
        POP    R8
        RET
