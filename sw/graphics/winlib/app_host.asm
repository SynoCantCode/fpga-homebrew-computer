; app host, loads APP.BIN, calls it, ticks it, the services apps call
; included by winlib.asm

; load_app, loads a windows APP.BIN if its folder has one
; code copied to a 64 KB boundary in the heap, addresses fixed for that place
; then FLUSH, tick rate, init
; in R1 = the window, page already loaded
; R8 = window number, R9 = its 128 bytes, R10 = file size, R11 = code place, R12 = file, R13 = count
load_app: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        MOV    R8, R1
        CALL   window_record
        MOV    R9, R1
        MOV    R1, R9                   ; program named by the canvas
        CALL   canvas_of
        CMPI   R1, 0x0000
        JZ     app_own
        LOAD   R1, [R1 + 4]
        CMPI   R1, 0x0000
        JZ     app_own
        LOADB  R2, [R1]
        CMPI   R2, 0x0000
        JZ     app_own
        LOADLO R2, path
        CALL   text_copy
        LOADLO R1, path
        JUMP   app_find
app_own: LOAD R1, [R9 + W_NAME]         ; else its own /apps/NAME/app.bin
        LA     R2, app_bin_name
        CALL   make_path
app_find: CALLF FILE_SIZE               ; R2 = size
        CMPI   R1, 0x0000
        JNZ    app_none                 ; no APP.BIN, just a page
        MOV    R10, R2
        MOV    R1, R10
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     app_none
        MOV    R12, R1
        LOADLO R1, path
        MOV    R2, R12
        CALLF  FILE_READ
        CMPI   R1, 0x0000
        JNZ    app_free
        LOAD   R1, [R12]                ; "APP1"?
        LOADHI R2, 0x3150
        ORI    R2, R2, 0x5041
        CMP    R1, R2
        JNZ    app_free
        LOAD   R1, [R12 + 4]            ; room for the code + 64 KB
        LOADHI R2, 0x0001
        ADD    R1, R1, R2
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     app_free
        LOADLO R2, windows              ; keep the address in app_raw, freed on close
        SUB    R2, R9, R2
        SHIFTI R2, R2, 0x07, 0b1000
        SHIFTI R2, R2, 0x02, 0b0000
        LOADLO R3, app_raw
        ADD    R2, R2, R3
        STORE  R1, [R2]
        LOADHI R2, 0x0001               ; up to the next multiple of 64 KB
        ADD    R1, R1, R2
        SUBI   R1, R1, 1
        SHIFTI R1, R1, 0x10, 0b1000
        SHIFTI R11, R1, 0x10, 0b0000
        LOAD   R13, [R12 + 4]           ; copy the code, a word at a time
        ADDI   R3, R12, 16
        MOV    R4, R11
app_copy: CMPI R13, 0x0000
        JZ     app_copied
        LOAD   R5, [R3]
        STORE  R5, [R4]
        ADDI   R3, R3, 4
        ADDI   R4, R4, 4
        SUBI   R13, R13, 4
        JUMP   app_copy
app_copied: LOAD R1, [R12 + 12]         ; R6 = (place - LINK) / 64 KB
        SUB    R6, R11, R1
        SHIFTI R6, R6, 0x10, 0b1000
        LOAD   R13, [R12 + 8]           ; words to fix, after the code
        LOAD   R1, [R12 + 4]
        ADDI   R3, R12, 16
        ADD    R3, R3, R1
app_fix: CMPI  R13, 0x0000
        JZ     app_fixed
        LOAD   R1, [R3]                 ; offset
        ADD    R1, R1, R11
        LOAD   R2, [R3 + 4]             ; step
        MUL    R2, R2, R6
        LOAD   R4, [R1]
        ADD    R4, R4, R2
        STORE  R4, [R1]
        ADDI   R3, R3, 8
        DEC    R13
        JUMP   app_fix
app_fixed: FLUSH
        STORE  R11, [R9 + W_APP]
        LOAD   R1, [R11 + APP_RATE]     ; ticks a second, every 100 / that timer ticks
        CMPI   R1, 0x0000
        JZ     app_rate
        LOADLO R2, TICKS_PER_SECOND
        DIVU   R1, R2, R1
        CMPI   R1, 0x0000
        JNZ    app_rate
        LOADLO R1, 1
app_rate: STORE R1, [R9 + W_APP_TICK]
        LOAD   R2, [TIMER]
        ADD    R2, R2, R1
        STORE  R2, [R9 + W_APP_NEXT]
        MOV    R1, R12                  ; free the file
        CALLF  FREE
        MOV    R1, R8                   ; started
        LOADLO R2, APP_INIT
        CALL   app_call
        JUMP   app_none
app_free: MOV R1, R12
        CALLF  FREE
app_none: POP R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; app_call, calls one of a windows app handlers
; in R1 = window, R2 = which handler, R3, R4 = passed as R2, R3, uses R1-R7
app_call: PUSH R8
        MOV    R8, R1
        PUSH   R2
        CALL   window_record
        POP    R2
        LOAD   R7, [R1 + W_APP]
        CMPI   R7, 0x0000
        JZ     app_call_none
        ADD    R7, R7, R2
        MOV    R1, R8
        MOV    R2, R3
        MOV    R3, R4
        CALLR  R7
app_call_none: POP R8
        RET

; app_ticks, ticks each open app whose tick is due
; R8 = window, R9 = its 128 bytes
app_ticks: PUSH R8
        PUSH   R9
        LOADLO R8, 0
ticks_next: MOV R1, R8
        CALL   window_record
        MOV    R9, R1
        LOAD   R1, [R9 + W_APP]
        CMPI   R1, 0x0000
        JZ     ticks_skip
        LOAD   R1, [R9 + W_APP_TICK]
        CMPI   R1, 0x0000
        JZ     ticks_skip
        LOAD   R1, [R9 + W_VISIBLE]     ; hidden or minimised = paused
        CMPI   R1, 0x0000
        JZ     ticks_skip
        LOAD   R1, [TIMER]
        LOAD   R2, [R9 + W_APP_NEXT]
        SUB    R3, R1, R2
        CMPIS  R3, 0
        JGE    ticks_due
        JUMP   ticks_skip
ticks_due: LOAD R2, [R9 + W_APP_TICK]
        ADD    R1, R1, R2
        STORE  R1, [R9 + W_APP_NEXT]
        MOV    R1, R8
        LOADLO R2, APP_TICK
        CALL   app_call
ticks_skip: INC R8
        CMPI   R8, APP_SLOTS
        JNZ    ticks_next
        POP    R9
        POP    R8
        RET

; app_dirty, redraws each app window that asked with WM_REDRAW
; R8 = window
app_dirty: PUSH R8
        LOADLO R8, 0
dirty_next: MOV R1, R8
        CALL   window_record
        LOAD   R2, [R1 + W_DIRTY]
        CMPI   R2, 0x0000
        JZ     dirty_skip
        STORE  R0, [R1 + W_DIRTY]
        MOV    R1, R8
        CALL   draw_window
        LOADLO R1, 1
        STORE  R1, [redraw]
dirty_skip: INC R8
        CMPI   R8, APP_SLOTS
        JNZ    dirty_next
        POP    R8
        RET

; paint_spot, app place to a place in the window picture
; app places start at the content or canvas top left
; page row N is y = N x 16, paint_y has the scroll in it
; not drawn if it sticks out above or below the content
; in R1 = x, R2 = y, R7 = height, out R1, R2 = place, R7 = 1 draw, 0 dont, uses R6
paint_spot: LOAD R6, [paint_x]
        ADD    R1, R1, R6
        LOAD   R6, [paint_y]
        ADD    R2, R2, R6
        LOAD   R6, [paint_top]          ; top below the content top?
        SUB    R6, R2, R6
        CMPIS  R6, 0
        JGE    spot_top_in
        LOADLO R7, 0
        RET
spot_top_in: ADD R6, R2, R7             ; bottom above the content bottom?
        LOAD   R7, [paint_bottom]
        SUB    R6, R7, R6
        CMPIS  R6, 0
        JGE    spot_in
        LOADLO R7, 0
        RET
spot_in: LOADLO R7, 1
        RET

; api_box, filled box in the apps window
; in R1 = x, R2 = y, R3 = width, R4 = height, R5 = colour
api_box: MOV   R7, R4
        CALL   paint_spot
        CMPI   R7, 0x0000
        JZ     api_box_hidden
        JUMP   box
api_box_hidden: RET

; api_text, 8 x 16 text in the apps window
; in R1 = x, R2 = y, R3 = pointer to the text, R4 = colour
api_text: LOADLO R7, 16
        CALL   paint_spot
        CMPI   R7, 0x0000
        JZ     api_text_hidden
        JUMP   text
api_text_hidden: RET

; api_size, size of a windows content or canvas
; in R1 = window, out R1 = width, R2 = height in dots
api_size: CALL window_record
        PUSH   R1
        CALL   canvas_of
        POP    R2
        CMPI   R1, 0x0000
        JZ     size_content
        LOAD   R4, [R2 + W_ROWS]        ; height = rows in view
        LOADLO R5, windows
        SUB    R5, R2, R5
        SHIFTI R5, R5, 0x07, 0b1000
        SHIFTI R5, R5, 0x02, 0b0000
        LOADLO R6, scroll_rows
        ADD    R5, R5, R6
        LOAD   R5, [R5]
        ADD    R4, R4, R5               ; page row just below the window
        LOADB  R5, [R1 + 2]
        SUB    R4, R4, R5               ; - canvas row = rows in view
        LOAD   R2, [R1 + 12]
        CMP    R4, R2
        JC     size_canvas
        MOV    R2, R4
size_canvas: SHIFTI R2, R2, 0x04, 0b0000
        LOAD   R1, [R1 + 8]
        SHIFTI R1, R1, 0x03, 0b0000
        RET
size_content: MOV R1, R2
        LOAD   R2, [R1 + W_ROWS]
        SHIFTI R2, R2, 0x04, 0b0000
        LOAD   R1, [R1 + W_COLUMNS]
        SHIFTI R1, R1, 0x03, 0b0000
        RET

; api_redraw, redraw a window after its handler, in R1 = window
api_redraw: CALL window_record
        LOADLO R2, 1
        STORE  R2, [R1 + W_DIRTY]
        RET

; named pieces, a page line can name its element, like input #city 0 2 20 1
; named_element, finds a windows element by name, case ignored
; in R1 = window, R2 = pointer to name without #, out R1 = element or 0, uses R1-R7
named_element: PUSH R2
        CALL   window_record
        POP    R2
        LOAD   R6, [R1 + W_ELEMENTS]
        LOAD   R7, [R1 + W_ELEMENT_COUNT]
named_next: CMPI R7, 0x0000
        JZ     named_none
        LOAD   R1, [R6 + E_NAME]
        CMPI   R1, 0x0000
        JZ     named_skip
        PUSH   R2
        CALL   text_same                ; R3 = 1 same
        POP    R2
        CMPI   R3, 1
        JZ     named_found
named_skip: ADDI R6, R6, ELEMENT_BYTES
        DEC    R7
        JUMP   named_next
named_found: MOV R1, R6
        RET
named_none: LOADLO R1, 0
        RET

; api_get_text, WM_GET_TEXT, a named elements text
; in R1 = window, R2 = pointer to name, out R1 = pointer to text or 0
api_get_text: CALL named_element
        CMPI   R1, 0x0000
        JZ     get_text_done
        LOAD   R1, [R1 + 4]
get_text_done: RET

; api_set_text, WM_SET_TEXT, new text for a named element, window redrawn
; an input copies it, up to INPUT_MAX letters
; anything else keeps the pointer, so the text must stay
; in R1 = window, R2 = pointer to name, R3 = pointer to text, out R1 = 1 or 0
api_set_text: PUSH R1
        PUSH   R3
        CALL   named_element
        POP    R3
        CMPI   R1, 0x0000
        JZ     set_text_none
        LOADB  R4, [R1]
        CMPI   R4, E_INPUT
        JZ     set_text_input
        STORE  R3, [R1 + 4]
        JUMP   set_text_drawn
set_text_input: LOAD R2, [R1 + 4]       ; an input, into its own buffer
        LOADLO R5, INPUT_MAX
set_text_copy: CMPI R5, 0x0000
        JZ     set_text_end
        LOADB  R4, [R3]
        CMPI   R4, 0x0000
        JZ     set_text_end
        STOREB R4, [R2]
        INC    R2
        INC    R3
        DEC    R5
        JUMP   set_text_copy
set_text_end: STOREB R0, [R2]
set_text_drawn: POP R1
        CALL   api_redraw
        LOADLO R1, 1
        RET
set_text_none: POP R1
        LOADLO R1, 0
        RET

; api_number, number to decimal text, in R1 = number, R2 = where, 11 letters
number_text:                            ; name the text builder uses
api_number: MOV R5, R2
        LOADLO R3, 0
number_digit: MODUI R4, R1, 10          ; push the digits, last first
        ADDI   R4, R4, 0x0030
        PUSH   R4
        INC    R3
        DIVUI  R1, R1, 10
        CMPI   R1, 0x0000
        JNZ    number_digit
number_out: POP R4                      ; pop them, first first
        STOREB R4, [R5]
        INC    R5
        DEC    R3
        CMPI   R3, 0x0000
        JNZ    number_out
        STOREB R0, [R5]
        MOV    R2, R5                   ; out R2 = the 0 written
        RET
