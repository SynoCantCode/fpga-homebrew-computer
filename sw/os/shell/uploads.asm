; numbers on the screen, files sent from the PC
; included by shell.asm

; screen_decimal, shows a number in decimal, no leading zeros
; divides by 10, pushes each digit, then pops them
; in R1 = the number, uses R1-R7
; R8 = what is left, R9 = digits on the stack
screen_decimal: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADLO R9, 0
decimal_split: MODUI R5, R8, 10         ; rightmost digit
        DIVUI  R8, R8, 10               ; the rest
        ADDI   R5, R5, 0x30             ; to a character, '0' = 0x30
        PUSH   R5
        INC    R9
        CMPI   R8, 0x0000
        JNZ    decimal_split
decimal_show: POP R1                    ; leftmost digit first
        CALLF  screen_char
        DEC    R9, 0b0100
        JNZ    decimal_show
        POP    R9
        POP    R8
        RET

; shell_upload_file, a file from the PC saved on the card, not run
; 'S', the path then a 0, 4 bytes size lowest first, the file bytes
; collected in heap memory, saved with file_write, memory freed
; every byte has a time limit, receive_timed
; R8 = size, R9 = the memory, R10 = pointer for the next byte
; R11 = bytes still to come
shell_upload_file: CALLF receive_byte   ; the 'S'
        LOADLO R10, FS_MOVE_PATH        ; path into FS_MOVE_PATH, 0x7F letters at most
        LOADLO R11, 0x007F
file_name_next: CALL receive_timed
        CMPIS  R1, -1
        JZ     file_incomplete
        STOREB R1, [R10]
        CMPI   R1, 0x0000
        JZ     file_name_done
        INC    R10
        DEC    R11, 0b0100
        JNZ    file_name_next
        STOREB R0, [R10]                ; too long, cut off
file_name_done: LOADLO R8, 0            ; size, 4 bytes, lowest first
        LOADLO R11, 4
        LOADLO R10, 0                   ; R10 = shift for the next byte
file_size_next: CALL receive_timed
        CMPIS  R1, -1
        JZ     file_incomplete
        SHIFT  R1, R1, R10, 0b0000      ; shifted 0, 8, 16, 24 bits
        OR     R8, R8, R1
        ADDI   R10, R10, 8
        DEC    R11, 0b0100
        JNZ    file_size_next
        ADDI   R1, R8, 1                ; allocate at least 1 byte
        CALL   allocate
        MOV    R9, R1
        MOV    R10, R1
        MOV    R11, R8
        CMPI   R9, 0x0000
        JZ     file_no_room
        DI                              ; interrupts off, the bytes come through receive_direct
file_bytes_next: CMPI R11, 0x0000       ; 1,000,000 baud = a byte every 10 us, too fast for the handler
        JZ     file_received            ; all bytes in
        CALL   receive_direct
        CMPIS  R1, -1
        JZ     file_incomplete_free
        STOREB R1, [R10]
        INC    R10
        DEC    R11
        JUMP   file_bytes_next
file_received: EI                       ; interrupts on again
        LOADLO R1, FS_MOVE_PATH
        MOV    R2, R9
        MOV    R3, R8
        CALL   file_write               ; onto the card
        MOV    R10, R1                  ; R10 = the answer
        MOV    R1, R9
        CALL   free                     ; give the memory back
        LOADLO R1, 0x000A
        CALLF  screen_char
        MOV    R1, R10
        CMPI   R1, 0x0000
        JNZ    file_save_failed
        LA     R1, file_saved_text      ; "saved PATH (d'N bytes)"
        CALLF  screen_text
        LOADLO R1, FS_MOVE_PATH
        CALLF  screen_text
        LA     R1, file_saved_size_text
        CALLF  screen_text
        MOV    R1, R8
        CALL   screen_decimal
        LA     R1, file_saved_end_text
        CALLF  screen_line
        LA     R1, file_saved_pc_text
        CALLF  print_line               ; and to the PC
        JUMP   shell_prompt
file_save_failed: CALL show_fs_error
        LA     R1, file_failed_pc_text
        CALLF  print_line
        JUMP   shell_prompt
file_no_room: LA R1, no_memory_text     ; too big for the heap, swallow the bytes
        CALLF  screen_line
file_swallow: CMPI R11, 0x0000
        JZ     file_failed_pc
        CALL   receive_timed
        CMPIS  R1, -1
        JZ     file_failed_pc
        DEC    R11
        JUMP   file_swallow
file_incomplete_free: EI
        MOV    R1, R9
        CALL   free
file_incomplete: LA R1, incomplete_text
        CALLF  screen_line
file_failed_pc: LA R1, file_failed_pc_text
        CALLF  print_line
        JUMP   shell_prompt

; receive_direct, next byte from the PC with interrupts off
; a byte in the UART goes to the back of the queue
; then the oldest comes out of the front, order is kept
; queue empty = straight from UART_DATA, waits about a second
; out R1 = the byte or -1, uses R1-R7
receive_direct: LOAD R1, [UART_STATUS]
        ANDI   R1, R1, BYTE_WAITING
        JZ     receive_direct_queue
        LOAD   R3, [UART_DATA]          ; just arrived, to the back of the queue, R3 = the byte
        LOADLO R6, UART_QUEUE           ; R6 = the queue, queue_put uses R4, R5 and R8
        PUSH   R8
        CALLF  queue_put
        POP    R8
receive_direct_queue: CALLF get_serial_byte ; the oldest, from the front
        CMPIS  R1, -1
        JNZ    receive_direct_done
        LOADHI R7, 0x0010               ; queue empty, R7 = wait count, about a second
receive_direct_wait: LOAD R1, [UART_STATUS]
        ANDI   R1, R1, BYTE_WAITING
        JNZ    receive_direct_take
        DEC    R7, 0b0100
        JNZ    receive_direct_wait
        NOT    R1, R0                   ; -1, none came
        RET
receive_direct_take: LOAD R1, [UART_DATA]
receive_direct_done: RET

; receive_timed, next byte from the PC, waits about a second
; out R1 = the byte or -1, uses R1-R7
receive_timed: LOADHI R7, 0x0010        ; R7 = wait count
receive_timed_next: CALLF get_serial_byte
        CMPIS  R1, -1
        JNZ    receive_timed_done
        DEC    R7, 0b0100
        JNZ    receive_timed_next
receive_timed_done: RET
