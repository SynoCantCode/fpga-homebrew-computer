; browser, web pages as text
; the page has #url, Go, #status and #page
; Go, event 1 or Enter, fetches the page with net_fetch
; up to 16 KB is copied and shown in #page
; Save, event 2, writes /desktop/NAME.txt
; NAME is from the address, up to 8 letters
; it draws nothing, only WM_GET_TEXT and WM_SET_TEXT
; build with make_app.py
.include "sw/apps/app_defs.asm"
.org APP_BASE
        JUMP   init
        JUMP   tick
        JUMP   key
        JUMP   click
        JUMP   paint
        JUMP   button
        JUMP   close
        .word  0                        ; no ticks

.equ PAGE_MOST, 0x3FFF                  ; most of a page shown, 16 KB - 1 for the 0

; init, 16 KB of heap for the page, in R1 = window
init:   LOADLO R1, 0x4000
        CALLF  ALLOCATE
        LA     R2, page_text
        STORE  R1, [R2]
        RET

; key, Enter is Go, in R1 = window, R2 = key
key:    CMPI   R2, 0x000A
        JZ     go
        RET

; button, Go event 1, Save event 2, in R1 = window, R2 = event
button: CMPI   R2, 1
        JZ     go
        CMPI   R2, 2
        JZ     save
        RET

; go, fetch the address and show it, in R1 = window
; R8 = window, R9 = bytes, R10 = NET_PAGE text, R11 = my copy
go:     PUSH   R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        LA     R2, url_name             ; the typed address
        CALLF  WM_GET_TEXT
        LA     R3, type_text
        CMPI   R1, 0x0000
        JZ     go_say                   ; no #url on the page
        LOADB  R2, [R1]
        CMPI   R2, 0x0000
        JZ     go_say                   ; nothing typed
        LOAD   R5, [NET_CALLS + 16]     ; net_fetch, 0 = kernel doesn't have it
        LA     R3, old_kernel_text
        CMPI   R5, 0x0000
        JZ     go_say
        CALLR  R5                       ; R1 = page bytes or 0, R2 = NET_PAGE
        MOV    R9, R1                   ; takes a few seconds
        MOV    R10, R2
        LA     R3, no_page_text
        CMPI   R9, 0x0000
        JZ     go_say
        LA     R1, page_text            ; my copy, 0 = no room
        LOAD   R11, [R1]
        LA     R3, no_memory_text
        CMPI   R11, 0x0000
        JZ     go_say
        LOADLO R1, PAGE_MOST            ; up to 16 KB
        CMP    R9, R1
        JNC    go_copy                  ; less, take all of it
        MOV    R9, R1
go_copy: MOV   R1, R10
        MOV    R2, R11
        MOV    R3, R9
go_copy_byte: CMPI R3, 0x0000
        JZ     go_copied
        LOADB  R4, [R1]
        STOREB R4, [R2]
        INC    R1
        INC    R2
        DEC    R3
        JUMP   go_copy_byte
go_copied: STOREB R0, [R2]
        LA     R1, page_size            ; kept for Save
        STORE  R9, [R1]
        MOV    R1, R8                   ; show it in #page
        LA     R2, page_name
        MOV    R3, R11
        CALLF  WM_SET_TEXT
        LA     R1, done_text            ; "Done: N bytes"
        LA     R2, status_text
        CALL   text_copy
        MOV    R1, R9
        CALL   number_text
        LA     R1, bytes_text
        CALL   text_copy
        LA     R3, status_text
go_say: MOV    R1, R8                   ; #status says how it went
        LA     R2, status_name
        CALLF  WM_SET_TEXT
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; save, the page to /desktop/NAME.txt
; NAME = first letters and digits of the address, up to 8, or page
; in R1 = window. R8 = window, R9 = where the name goes, R10 = letters left
save:   PUSH   R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        LA     R1, page_size            ; a page loaded?
        LOAD   R1, [R1]
        LA     R3, nothing_yet_text
        CMPI   R1, 0x0000
        JZ     save_say
        LA     R1, desktop_folder       ; make /desktop if it isn't there
        CALLF  FOLDER_MAKE
        LA     R1, desktop_path         ; path = "/desktop/"
        LA     R2, save_path
        CALL   text_copy
        MOV    R9, R2
        MOV    R1, R8                   ; + NAME from the address
        LA     R2, url_name
        CALLF  WM_GET_TEXT
        LOADLO R10, 8
        MOV    R4, R9
save_name: CMPI R1, 0x0000
        JZ     save_name_end
        LOADB  R2, [R1]
        PUSH   R1
        MOV    R1, R2
        CALL   text_lower
        MOV    R2, R1
        POP    R1
        CMPI   R2, 0x0030               ; digit or small letter, else the name ends
        JNC    save_name_end
        CMPI   R2, 0x003A
        JNC    save_take
        CMPI   R2, 0x0061
        JNC    save_name_end
        CMPI   R2, 0x007B
        JC     save_name_end
save_take: STOREB R2, [R9]
        INC    R9
        INC    R1
        DEC    R10
        CMPI   R10, 0x0000
        JNZ    save_name
save_name_end: CMP R9, R4               ; no letters, use "page"
        JNZ    save_type
        LA     R1, page_word
        MOV    R2, R9
        CALL   text_copy
        MOV    R9, R2
save_type: LA  R1, txt_text             ; + ".txt"
        MOV    R2, R9
        CALL   text_copy
        LA     R1, save_path            ; write the page text
        LA     R2, page_text
        LOAD   R2, [R2]
        LA     R3, page_size
        LOAD   R3, [R3]
        CALLF  FILE_WRITE
        LA     R3, not_saved_text
        CMPI   R1, 0x0000
        JNZ    save_say
        LA     R1, saved_text           ; "Saved as /desktop/NAME.txt (an icon next time)"
        LA     R2, status_text
        CALL   text_copy
        LA     R1, save_path
        CALL   text_copy
        LA     R1, next_time_text
        CALL   text_copy
        LA     R3, status_text
save_say: MOV  R1, R8
        LA     R2, status_name
        CALLF  WM_SET_TEXT
        POP    R10
        POP    R9
        POP    R8
        RET

; nothing to do
tick:
click:
paint:
close:  RET

url_name:        .string "url"
page_name:       .string "page"
status_name:     .string "status"
type_text:       .string "Type an address first (example.com)"
old_kernel_text: .string "This kernel can't fetch pages (update KERNEL.BIN)"
no_page_text:    .string "No page: no network, no such site, or no answer"
no_memory_text:  .string "No memory for the page"
done_text:       .string "Done: "
bytes_text:      .string " bytes"
nothing_yet_text: .string "Load a page first (Go), then Save"
not_saved_text:  .string "Couldn't save it (the card full?)"
saved_text:      .string "Saved as "
next_time_text:  .string " (an icon next time)"
desktop_folder:  .string "/desktop"
desktop_path:    .string "/desktop/"
page_word:       .string "page"
txt_text:        .string ".txt"
page_size:       .word 0                ; bytes of the page shown, 0 = none
save_path:       .word 0                ; "/desktop/NAME.txt", 32 bytes
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
page_text:       .word 0                ; pointer to my copy of the page
status_text:     .word 0                ; "Done: 12345 bytes", 64 bytes
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0
        .word  0

.include "sw/apps/lib/text.asm"         ; text_copy, number_text
