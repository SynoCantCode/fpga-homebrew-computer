; start_screen, choose an app or a new one, placing its window
; included by studio.asm

; the start screen, no name given
; choose_app, lists the apps in /apps/apps.txt as 1-8, N = a new one
; out R1 = 1 app_name filled in, 0 = Esc
; R8 = list, R9 = its end, R10 = apps listed, R11 = place in the list
choose_app: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        CALLF  SCREEN_CLEAR
        LA     R1, choose_title
        CALLF  SCREEN_LINE
        LA     R1, apps_list_path       ; the apps, a name a line
        CALL   load_text
        MOV    R8, R1
        MOV    R9, R2
        LOADLO R10, 0
        CMPI   R8, 0x0000
        JZ     choose_listed            ; no APPS.TXT, only N
        LOADLO R11, 0
choose_list: MOV R1, R11                ; next name after R11, the first after 0
        MOV    R2, R8
        MOV    R3, R9
        CALL   next_name
        CMPI   R1, 0x0000
        JZ     choose_listed
        MOV    R11, R1
        CALL   page_is_full             ; full screen app, not listed
        CMPI   R1, 0x0000
        JNZ    choose_list
        SHIFTI R2, R10, 0x02, 0b0000    ; keep its name for its number
        ADDIW  R2, R2, choose_names
        STORE  R11, [R2]
        MOV    R1, R11
        CALL   copy_name                ; into app_name, to show it
        INC    R10
        LOADLO R1, 0x0020
        CALLF  SCREEN_CHAR
        LOADLO R1, 0x0020
        CALLF  SCREEN_CHAR
        ADDI   R1, R10, 0x0030          ; its number, '1' up
        CALLF  SCREEN_CHAR
        LOADLO R1, 0x0020
        CALLF  SCREEN_CHAR
        LOADLO R1, 0x0020
        CALLF  SCREEN_CHAR
        LOADLO R1, app_name
        CALLF  SCREEN_LINE
        CMPI   R10, 8
        JNZ    choose_list              ; 8 at most
choose_listed: LA R1, choose_new
        CALLF  SCREEN_LINE
        LA     R1, choose_esc
        CALLF  SCREEN_LINE
choose_key: CALLF GET_CHAR              ; a key, a number, N or Esc
        CMPIS  R1, -1
        JZ     choose_key
        CMPI   R1, 0x001B
        JZ     choose_none
        ORI    R2, R1, 0x0020           ; N or n
        CMPI   R2, 0x006E
        JZ     choose_typed
        SUBI   R2, R1, 0x0031           ; '1' = 0
        CMP    R2, R10
        JC     choose_key               ; not one of the numbers
        SHIFTI R2, R2, 0x02, 0b0000     ; the name with that number
        ADDIW  R2, R2, choose_names
        LOAD   R1, [R2]
        CALL   copy_name
        JUMP   choose_picked
choose_typed: LA R1, choose_ask         ; N, type the new apps name
        CALLF  SCREEN_TEXT
        LOADLO R10, 0                   ; R10 = letters so far
choose_letter: CALLF GET_CHAR
        CMPIS  R1, -1
        JZ     choose_letter
        CMPI   R1, 0x001B
        JZ     choose_none
        CMPI   R1, 0x000A
        JZ     choose_enter
        CMPI   R1, 0x0008
        JZ     choose_back
        CMPI   R1, 0x0021               ; a letter, 0x21-0x7E, not /
        JNC    choose_letter
        CMPI   R1, 0x007F
        JC     choose_letter
        CMPI   R1, 0x002F
        JZ     choose_letter
        CMPI   R10, 8
        JZ     choose_letter
        ADDIW  R2, R10, app_name
        STOREB R1, [R2]
        INC    R10
        CALLF  SCREEN_CHAR
        JUMP   choose_letter
choose_back: CMPI R10, 0x0000
        JZ     choose_letter
        DEC    R10
        CALLF  SCREEN_CHAR              ; R1 = Backspace, the screen takes it off
        JUMP   choose_letter
choose_enter: CMPI R10, 0x0000
        JZ     choose_letter
        ADDIW  R2, R10, app_name
        STOREB R0, [R2]
choose_picked: LOADLO R1, 1
        JUMP   choose_done
choose_none: LOADLO R1, 0
choose_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; page_is_full, is this a full screen app, its page has a shell line
; in R1 = pointer to its name, out R1 = 1 yes, 0 no
; R8 = its page, R9 = its end, R10 = a line, R11 = answer
page_is_full: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        CALL   copy_name                ; /apps/NAME/page.txt
        LOADLO R1, app_name
        LA     R2, page_name
        CALL   make_path
        CALL   load_text
        MOV    R8, R1
        MOV    R9, R2
        LOADLO R11, 0
        CMPI   R8, 0x0000
        JZ     pagefull_done
        MOV    R10, R8
pagefull_line: CMP R10, R9
        JC     pagefull_free
        MOV    R1, R10                  ; first word shell?
        CALL   read_word
        LA     R4, word_shell
        CALL   word_is
        CMPI   R5, 1
        JZ     pagefull_yes
pagefull_skip: LOADB R1, [R10]          ; next line
        INC    R10
        CMPI   R1, 0x0000
        JNZ    pagefull_skip
        JUMP   pagefull_line
pagefull_yes: LOADLO R11, 1
pagefull_free: MOV R1, R8
        CALLF  FREE
pagefull_done: MOV R1, R11
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; copy_name, a name from the list into app_name, up to 8 letters
; in R1 = pointer to it, uses R1, R2, R4, R5
copy_name: LOADLO R4, app_name
        LOADLO R5, 8
copy_name_next: CMPI R5, 0x0000
        JZ     copy_name_end
        LOADB  R2, [R1]
        CMPI   R2, 0x0021
        JNC    copy_name_end
        STOREB R2, [R4]
        INC    R1
        INC    R4
        DEC    R5
        JUMP   copy_name_next
copy_name_end: STOREB R0, [R4]
        RET

; center_window, window 0 in the middle, top at STUDIO_Y
; x a multiple of 8, uses R1-R3
center_window: LOADLO R1, 0
        CALL   window_record
        LOADLO R2, PIXELS_ACROSS
        LOAD   R3, [R1 + W_WIDTH]
        SUB    R2, R2, R3
        SHIFTI R2, R2, 0x01, 0b1000
        CMPIS  R2, 0
        JGE    center_x
        LOADLO R2, 0
center_x: ANDI R2, R2, 0xFFF8
        STORE  R2, [R1 + W_X]
        LOADLO R2, STUDIO_Y
        STORE  R2, [R1 + W_Y]
        RET

; keep_on_screen, keeps window 0 between the toolbar and status line
; x a multiple of 8, uses R1-R5
keep_on_screen: LOADLO R1, 0
        CALL   window_record
        LOAD   R2, [R1 + W_X]
        LOADLO R3, PIXELS_ACROSS
        LOAD   R4, [R1 + W_WIDTH]
        SUB    R3, R3, R4               ; R3 = the most x can be
        SUB    R5, R3, R2
        CMPIS  R5, 0
        JGE    keep_right
        MOV    R2, R3
keep_right: CMPIS R2, 0
        JGE    keep_left
        LOADLO R2, 0
keep_left: ANDI R2, R2, 0xFFF8
        STORE  R2, [R1 + W_X]
        LOAD   R2, [R1 + W_Y]
        LOADLO R3, STATUS_Y
        LOAD   R4, [R1 + W_HEIGHT]
        SUB    R3, R3, R4               ; R3 = the most y can be
        SUB    R5, R3, R2
        CMPIS  R5, 0
        JGE    keep_bottom
        MOV    R2, R3
keep_bottom: CMPIS R2, TOOLBAR_H + 4
        JGE    keep_top
        LOADLO R2, TOOLBAR_H + 4
keep_top: STORE R2, [R1 + W_Y]
        RET

; the screen
