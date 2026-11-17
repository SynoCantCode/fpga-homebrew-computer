; shell start, the > prompt, reading a line, running its command
; included by shell.asm

; shell_restart, at boot and after a program ends or crashes
; empty stack, interrupts set up, uploads welcome
shell_restart: LOADLO R15SP, STACK_TOP  ; R15SP = 0x8000, empty stack
        CALLF  kernel_arm
        CALL   heap_init                ; empty heap
        CALL   kernel_check             ; did the program write over the kernel?
        LOADLO R1, waiting
        CALLF  print_line               ; to the PC, "waiting for a program..."

; the note, commands a program left in NEXT_COMMANDS when it ended
; one line at a time into LINE_BUFFER and run
; a run comes back through shell_restart, anything else comes back here
; note empty = the prompt
shell_note: LOADB R1, [NEXT_COMMANDS]
        CMPI   R1, 0x0000
        JZ     shell_prompt
        CALL   note_take                ; first line into LINE_BUFFER
        LOADLO R1, LINE_BUFFER
        CALL   shell_execute
        JUMP   shell_note

; the prompt, then wait for keys or an upload
shell_prompt: LA R1, prompt
        CALLF  screen_text
; get_char also takes the remote control messages from the PC
; K = key, M = mouse, V = view the screen, W = wheel
; anything else from the PC is an upload
shell_wait: LOADLO R1, 1                 ; uploads only start while waiting here
        STORE  R1, [UPLOADS_WELCOME]
        CALLF  get_char                 ; R1 = a character or -1
        STORE  R0, [UPLOADS_WELCOME]
        CMPIS  R1, -1
        JNZ    shell_key
        LOAD   R1, [UART_QUEUE + QUEUE_HEAD]
        LOAD   R2, [UART_QUEUE + QUEUE_TAIL]
        CMP    R1, R2
        JZ     shell_wait               ; nothing from the PC, look again
        LOADB  R3, [R2 + UART_QUEUE + QUEUE_SLOTS] ; first byte waiting
        CMPI   R3, 0x004B
        JZ     shell_wait               ; K, unfinished remote message, get_char takes it later
        CMPI   R3, 0x004D               ; M
        JZ     shell_wait
        CMPI   R3, 0x0056
        JZ     shell_wait
        CMPI   R3, 0x0057               ; W
        JZ     shell_wait
        JUMP   shell_upload             ; anything else is an upload
shell_key: CALLF line_key               ; into the line, R1 = 1 when Enter ends it
        CMPI   R1, 0x0000
        JZ     shell_wait
        LOADLO R1, LINE_BUFFER          ; R1 = pointer to the line
        CALL   shell_execute
        JUMP   shell_prompt

; an upload, take it, remember where it went, run it
; quiet upload starts with Q (0x51), kept in RAM but not run
; normal upload starts with the address, lowest byte first
; that byte is a multiple of 4 so never Q
; the first byte is peeked in the UART queue, not taken out
; kernel upload, address 0x10xx_xxxx, would overwrite this shell
; handed to no_kernel_wait in the ROM, never comes back
; waits for 5 bytes, then peeks the top byte of the address
; byte 3, or byte 4 after a Q
shell_upload: LOADLO R7, 0xFFFF         ; R7 = wait count for 5 bytes
upload_wait: LOAD R5, [UART_QUEUE + QUEUE_HEAD]
        LOAD   R6, [UART_QUEUE + QUEUE_TAIL]
        SUB    R5, R5, R6
        ANDI   R5, R5, 0x003F           ; bytes waiting, head - tail, 64 slots
        CMPI   R5, 0x0005
        JC     upload_peek              ; 5 or more
        DEC    R7, 0b0100
        JNZ    upload_wait
upload_peek: LOAD R5, [UART_QUEUE + QUEUE_TAIL]
        LOADB  R6, [R5 + UART_QUEUE + QUEUE_SLOTS] ; first byte waiting
        LOADLO R4, 3                    ; top byte of the address is byte 3
        CMPI   R6, 0x0051
        JNZ    upload_where
        LOADLO R4, 4                    ; or byte 4 after a Q
upload_where: ADD R5, R5, R4
        ANDI   R5, R5, 0x003F
        LOADB  R5, [R5 + UART_QUEUE + QUEUE_SLOTS]
        CMPI   R5, 0x0010
        JNZ    upload_normal            ; not 0x10xx_xxxx, ordinary program
        LOAD   R5, [UART_QUEUE + QUEUE_TAIL] ; kernel is only 0x1000_0000 - 0x100F_FFFF
        ADD    R5, R5, R4
        SUBI   R5, R5, 1                ; the byte before, bits 23-16
        ANDI   R5, R5, 0x003F
        LOADB  R5, [R5 + UART_QUEUE + QUEUE_SLOTS]
        CMPI   R5, 0x0010
        JC     upload_normal            ; 0x1010_0000 and up = program in SDRAM, not a kernel
        CMPI   R6, 0x0051
        JNZ    upload_kernel
        CALLF  receive_byte             ; take the Q out first
upload_kernel: JUMPF no_kernel_wait     ; the ROM receives the kernel and starts it
upload_normal: CMPI R6, 0x0051
        JZ     shell_upload_quiet
        CMPI   R6, 0x0053
        JZ     shell_upload_file        ; S = a file to save
        CALLF  receive_program          ; R1 = load address, -1 if refused
        CMPIS  R1, -1
        JZ     shell_restart
        STORE  R1, [LAST_PROGRAM]
        LOADLO R2, blank                ; no arguments
        CALLF  run_program
        JUMP   shell_restart            ; program returned, start again
shell_upload_quiet: CALLF receive_byte  ; take the Q out
        CALLF  receive_program          ; then the upload
        CMPIS  R1, -1
        JZ     shell_restart
        STORE  R1, [LAST_PROGRAM]       ; so run starts it
        MOV    R8, R1
        LA     R1, loaded_pc_text
        CALLF  print_line               ; to the PC, "loaded, not run"
        LOADLO R1, 0x000A
        CALLF  screen_char              ; and on the screen, on its own line
        LA     R1, loaded_text
        CALLF  screen_text
        MOV    R1, R8
        CALLF  screen_hex_word
        LA     R1, not_run_text
        CALLF  screen_line
        JUMP   shell_prompt

; shell_execute, finds the command of a line and runs it
; in R1 = pointer to the line
; command_table entry = pointer to name, pointer to routine, 0 name ends it
; R8 = pointer to the command word, R9 = pointer to the table entry
shell_execute: PUSH R8
        PUSH   R9
        CALL   skip_spaces
        MOV    R8, R1
        LOADB  R5, [R8]
        CMPI   R5, 0x0000
        JZ     execute_done             ; empty line
        LA     R9, command_table
execute_next: LOAD R2, [R9]             ; R2 = pointer to the entry name
        CMPI   R2, 0x0000
        JZ     execute_unknown          ; end of the table, unknown command
        MOV    R1, R8
        CALL   word_is                  ; R1 = 1 if the first word is that name
        CMPI   R1, 0x0000
        JNZ    execute_found
        ADDI   R9, R9, 8                ; next entry, 8 bytes on
        JUMP   execute_next
execute_found: MOV R1, R8
        CALL   after_word               ; R1 = pointer to the arguments
        LOAD   R2, [R9 + 4]             ; R2 = pointer to the routine
        CALLR  R2
        JUMP   execute_done
execute_unknown: LA R1, unknown
        CALLF  screen_line
execute_done: POP R9
        POP    R8
        RET

; reading the words of a line
