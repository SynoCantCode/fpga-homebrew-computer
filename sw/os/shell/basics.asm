; shell basics, help, clear, type, run, reboot
; included by shell.asm

; help, lists the commands
command_help: LA R1, help_text
        JUMPF  screen_text

; clear, blank screen
command_clear: JUMPF screen_clear

; echo TEXT, shows the text back
command_echo: JUMPF screen_line

; type, free typing on the screen until Esc
command_type: LA R1, type_text
        CALLF  screen_line
type_next: CALLF get_char
        CMPIS  R1, -1
        JZ     type_next
        CMPI   R1, 0x001B               ; Esc, back to the shell
        JZ     type_done
        CALLF  screen_char
        JUMP   type_next
type_done: LOADLO R1, 0x000A
        JUMPF  screen_char

; run, runs the last program again
; run NAME [ARGS], loads a .BIN from the card to PROGRAM_START, R2 = args
command_run: LOADB R5, [R1]             ; anything after run?
        CMPI   R5, 0x0000
        JNZ    run_file
        LOAD   R1, [LAST_PROGRAM]
        CMPI   R1, 0x0000
        JZ     run_nothing
        LOADLO R2, blank                ; no arguments
        CALLF  run_program
        JUMP   shell_restart            ; program returned, start again
run_nothing: LA R1, run_text
        JUMPF  screen_line
run_file: PUSH R8
        PUSH   R9
        MOV    R8, R1                   ; R8 = pointer to NAME ARGS
        CALL   program_load             ; R1 = 0 or an error, R2 = where it loaded
        CMPI   R1, 0x0000
        JNZ    run_file_error
        STORE  R2, [LAST_PROGRAM]       ; so a plain run runs it again
        FLUSH                           ; new code, empty the instruction cache
        MOV    R9, R2
        MOV    R1, R8
        CALL   after_word               ; R1 = pointer to the arguments
        MOV    R2, R1
        MOV    R1, R9
        CALLF  run_program              ; no POPs, shell_restart resets the stack
        JUMP   shell_restart            ; program returned, start again
run_file_error: POP R9
        POP    R8
        JUMP   show_fs_error            ; tail call, R1 = error number

; reboot, back to address 0, RAM is kept
command_reboot: DI
        JUMPR  R0                       ; PC = 0, the start-up entry
