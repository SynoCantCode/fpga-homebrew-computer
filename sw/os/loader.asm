; loader, three routines the shell calls
; kernel_arm sets the interrupts up
; receive_program takes an upload from the PC into RAM
; run_program runs a program and comes back when it RETs
; the bytes come through the UART queue

; kernel_arm, sets IVEC, the interrupts and the stack limit
; called every time the shell starts
; IVEC = interrupt_handler, timer, keyboard, mouse and UART on, TIMER_JOB = 0
; SLIM = 0xF010, a push below it traps
; the 16 bytes from 0xF000 are for the crash handler, then EI
kernel_arm: LOADLO R1, interrupt_handler
        SETIVEC R1
        STORE  R0, [TIMER_JOB]          ; no timer job
        LOADLO R1, INTERRUPT_TIMER + INTERRUPT_KEYBOARD + INTERRUPT_MOUSE + INTERRUPT_UART
        STORE  R1, [INTERRUPTS_ENABLED]
        LOADLO R1, STACK_LIMIT + STACK_RESERVE
        SETSLIM R1
        STORE  R0, [REMOTE_KEY]         ; no key from the PC waiting
        LOADLO R1, LAYER_TEXT
        STORE  R1, [GRAPHICS_CONTROL]   ; screen back to text only
        EI
        RET

; receive_program, takes one upload from the PC
; 4 bytes load address, 4 bytes length, then the bytes
; numbers come lowest byte first
; out R1 = address it was loaded at, or -1 if refused
; refused below PROGRAM_START (0x5000), the ROM and kernel variables
; R8 = load address, R9 = where the next byte goes
; R10 = bytes still coming
receive_program: PUSH R8
        PUSH   R9
        PUSH   R10
        CALL   receive_word
        MOV    R8, R1
        MOV    R9, R1
        CALL   receive_word
        MOV    R10, R1
        CMPI   R10, 0x0000
        JZ     receive_refused_quietly  ; nothing to load
; C = 0 means R9 is below PROGRAM_START
        CMPI   R9, PROGRAM_START
        JNC    receive_refuse
; in the block RAM, below 0x0001_0000, it must end below the stack
        LOADHI R1, 0x0001
        CMP    R9, R1
        JC     receive_store            ; 0x0001_0000 or above, not the block RAM
        ADD    R1, R9, R10              ; just past its end
        CMPI   R1, STACK_LIMIT + 1
        JC     receive_refuse           ; it would run into the stack

; each byte goes where R9 points, then R9 + 1
receive_store: CALL receive_byte
        STOREB R1, [R9]
        INC    R9
        DEC    R10, 0b0100              ; one fewer, sets Z
        JNZ    receive_store
        MOV    R1, R8                   ; R1 = where it was loaded
        JUMP   receive_done

; bad address, still take all the bytes, then say so
receive_refuse: CALL receive_byte
        DEC    R10, 0b0100
        JNZ    receive_refuse
        LOADLO R1, refused
        CALL   print_line               ; to the PC
        LOADLO R1, refused
        CALL   screen_line              ; and the monitor
receive_refused_quietly: NOT R1, R0     ; R1 = -1
receive_done: POP R10
        POP    R9
        POP    R8
        RET

; run_program, runs a program with empty queues
; in R1 = first instruction, R2 = pointer to its arguments, 0 ended
; the program starts with both still in R1 and R2
; comes back here when the program RETs
; DI so no interrupt sees a half cleared queue
run_program: DI
        CALL   queues_clear             ; only uses R0, R1 is still the address
        EI
        CALLR  R1                       ; run it
        RET
