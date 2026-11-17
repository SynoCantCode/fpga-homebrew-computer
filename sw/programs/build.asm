; build, assembles an app with the PC's help, helper.py must be running
; run build.bin NAME
; 1. /APPS/NAME/APP.ASM is sent to the PC over USB
; 0x01, "BUILD NAME", a line end, the file's text, 0x04
; 2. the PC answers 'R' + size, 4 bytes lowest first, + APP.BIN's bytes
; or 'E' + the error message + a 0
; 3. APP.BIN is saved as /APPS/NAME/APP.BIN, or the error is shown
; waits up to 30 seconds for the answer
; runs in the SDRAM, LA for its labels, CALLF for the kernel
; R8 = app name, R9 = the file or APP.BIN in memory
; R10 = a size, R11 = a count, R12 = when to give up
.include "sw/os/devices.asm"

.org PROGRAM_SDRAM
start:  PUSH   R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        LA     R8, app_name             ; the name typed after build.bin, 8 letters at most
        LOADLO R3, 8
name_next: LOADB R1, [R2]
        CMPI   R1, 0x0000
        JZ     name_done
        CMPI   R1, 0x0020
        JZ     name_done
        STOREB R1, [R8]
        INC    R2
        INC    R8
        DEC    R3
        CMPI   R3, 0x0000
        JNZ    name_next
name_done: STOREB R0, [R8]
        LA     R8, app_name
        LOADB  R1, [R8]
        CMPI   R1, 0x0000
        JNZ    have_name
        LA     R1, usage_text
        CALLF  SCREEN_LINE
        JUMP   the_end
have_name: LA  R1, asm_name             ; the source, /apps/NAME/app.asm
        CALL   make_path
        LA     R1, path
        CALLF  FILE_SIZE                ; R2 = its size
        CMPI   R1, 0x0000
        JZ     have_file
        LA     R1, no_file_text
        CALLF  SCREEN_TEXT
        LA     R1, path
        CALLF  SCREEN_LINE
        JUMP   the_problem
have_file: MOV R10, R2
        ADDI   R1, R10, 1
        CALLF  ALLOCATE
        MOV    R9, R1
        LA     R1, path
        MOV    R2, R9
        CALLF  FILE_READ
        ADD    R1, R9, R10
        STOREB R0, [R1]                 ; a 0 after it, PRINT_TEXT sends up to the 0
        LA     R1, sending_text
        CALLF  SCREEN_LINE
drain:  CALLF  GET_SERIAL_BYTE          ; throw away anything waiting from the PC
        CMPIS  R1, -1
        JNZ    drain
        LOADLO R1, 0x0001               ; 0x01 "BUILD NAME" line end, the text, 0x04
        CALLF  SEND_BYTE
        LA     R1, build_word
        CALLF  PRINT_TEXT
        MOV    R1, R8
        CALLF  PRINT_TEXT
        LOADLO R1, 0x000A
        CALLF  SEND_BYTE
        MOV    R1, R9
        CALLF  PRINT_TEXT
        LOADLO R1, 0x0004
        CALLF  SEND_BYTE
        MOV    R1, R9                   ; free the text
        CALLF  FREE
        LA     R1, waiting_text
        CALLF  SCREEN_LINE
        LOAD   R12, [TIMER]             ; wait up to 30 seconds for the answer
        LOADLO R1, 3000
        ADD    R12, R12, R1
        CALL   next_byte                ; R1 = 'R' APP.BIN follows, 'E' an error, -1 no answer
        CMPI   R1, 0x0052
        JZ     answer_bin
        CMPI   R1, 0x0045
        JZ     answer_error
        LA     R1, no_answer_text
        CALLF  SCREEN_LINE
        JUMP   the_problem
answer_error: LA R1, failed_text        ; show the assembler's message as it comes
        CALLF  SCREEN_LINE
error_next: CALL next_byte
        CMPIS  R1, -1
        JZ     error_done
        CMPI   R1, 0x0000
        JZ     error_done
        CMPI   R1, 0x000D
        JZ     error_next
        CALLF  SCREEN_CHAR
        JUMP   error_next
error_done: LOADLO R1, 0x000A
        CALLF  SCREEN_CHAR
        JUMP   the_problem
answer_bin: LOADLO R10, 0               ; its size, 4 bytes, lowest first
        LOADLO R11, 0
size_next: CALL next_byte
        CMPIS  R1, -1
        JZ     cut_off
        SHIFTI R2, R11, 0x03, 0b0000
        SHIFT  R1, R1, R2, 0b0000       ; move the byte up to its place
        OR     R10, R10, R1
        INC    R11
        CMPI   R11, 4
        JNZ    size_next
        MOV    R1, R10
        CALLF  ALLOCATE
        MOV    R9, R1
        CMPI   R9, 0x0000
        JZ     cut_off
        LOADLO R11, 0                   ; its bytes
bin_next: CMP  R11, R10
        JC     bin_done
        CALL   next_byte
        CMPIS  R1, -1
        JZ     cut_off
        ADD    R2, R9, R11
        STOREB R1, [R2]
        INC    R11
        JUMP   bin_next
bin_done: LA   R1, bin_name             ; save /apps/NAME/app.bin
        CALL   make_path
        LA     R1, path
        MOV    R2, R9
        MOV    R3, R10
        CALLF  FILE_WRITE
        CMPI   R1, 0x0000
        JNZ    not_saved
        LA     R1, built_text
        CALLF  SCREEN_TEXT
        MOV    R1, R10
        CALLF  SCREEN_HEX_WORD
        LA     R1, built_text_2
        CALLF  SCREEN_LINE
        JUMP   the_end
not_saved: LA  R1, not_saved_text
        CALLF  SCREEN_LINE
        JUMP   the_problem
cut_off: LA    R1, cut_off_text
        CALLF  SCREEN_LINE
the_problem: LA R1, key_text            ; a problem stays on the screen
        CALLF  SCREEN_LINE              ; until a key is pressed
key_wait: CALLF GET_CHAR
        CMPIS  R1, -1
        JZ     key_wait
the_end: POP   R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; next_byte, waits for a byte from the PC until the timer reaches R12, out R1 = byte or -1
next_byte: CALLF GET_SERIAL_BYTE
        CMPIS  R1, -1
        JZ     next_wait
        RET
next_wait: LOAD R2, [TIMER]
        SUB    R2, R12, R2
        CMPIS  R2, 0
        JGE    next_byte
        NOT    R1, R0
        RET

; make_path, "/apps/" + app_name + "/" + a file name, in path
; in R1 = pointer to the file name. uses R1-R4
make_path: PUSH R1
        LA     R1, apps_folder
        LA     R2, path
        CALL   copy
        LA     R1, app_name
        CALL   copy
        LOADLO R3, 0x002F
        STOREB R3, [R2]
        INC    R2
        POP    R1
        JUMP   copy

; copy, in R1 = from, R2 = to, out R2 = the 0 written. uses R3
copy:   LOADB  R3, [R1]
        STOREB R3, [R2]
        CMPI   R3, 0x0000
        JZ     copy_done
        INC    R1
        INC    R2
        JUMP   copy
copy_done: RET

usage_text:     .string "use: run build.bin NAME   (sends /apps/NAME/app.asm to the PC's helper.py, saves app.bin)"
no_file_text:   .string "no such file: "
sending_text:   .string "sending it to the PC (helper.py)..."
waiting_text:   .string "waiting for the PC to assemble it..."
no_answer_text: .string "no answer from the PC: is helper.py running? (python project/tools/sender/helper.py)"
failed_text:    .string "it didn't assemble:"
built_text:     .string "built: app.bin saved, 0x"
built_text_2:   .string " bytes. run wm.bin to try it"
not_saved_text: .string "app.bin came back but couldn't be saved (is the card in?)"
cut_off_text:   .string "the answer stopped part way: try again"
key_text:       .string "press a key to go on"
build_word:     .string "BUILD "
apps_folder:    .string "/apps/"
asm_name:       .string "app.asm"
bin_name:       .string "app.bin"
app_name:       .word 0                 ; app name, up to 8 letters + a 0
                .word 0
                .word 0
path:           .word 0                 ; the path is built here, 48 bytes
                .word 0
                .word 0
                .word 0
                .word 0
                .word 0
                .word 0
                .word 0
                .word 0
                .word 0
                .word 0
                .word 0
