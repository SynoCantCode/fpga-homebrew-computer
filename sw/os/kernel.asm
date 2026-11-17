; kernel part 1, the interrupt handler and the queues
; in the boot ROM, variables in RAM at KERNEL_VARIABLES

; interrupt_handler, the CPU jumps here on an interrupt or a trap
; flags and return address are pushed already, IE = 0
; saves every register it uses
; CAUSE = 0 is an interrupt, anything else is a trap
; every device that asked is checked
interrupt_handler: PUSH R3
        GETCAUSE R3                      ; R3 = CAUSE
        CMPI   R3, 0x0000
        JNZ    program_stopped          ; a trap, the program crashed
        PUSH   R4
        PUSH   R5
        PUSH   R6
        PUSH   R7
        PUSH   R8
        LOAD   R7, [INTERRUPTS_PENDING] ; R7 = pending, one bit per device

; timer, acknowledge it, then call TIMER_JOB if set
        ANDI   R3, R7, INTERRUPT_TIMER
        JZ     not_timer
        STORE  R0, [TIMER]              ; acknowledge, any value
        LOAD   R3, [TIMER_JOB]          ; R3 = the job, 0 = none
        CMPI   R3, 0x0000
        JZ     not_timer
        PUSH   R1                       ; the job may use R1-R7
        PUSH   R2
        CALLR  R3
        POP    R2
        POP    R1

; keyboard, its byte goes in the keyboard queue
not_timer: ANDI R3, R7, INTERRUPT_KEYBOARD
        JZ     not_keyboard
        LOAD   R3, [KEYBOARD_DATA]
        LOADLO R6, KEY_QUEUE
        CALL   queue_put

; mouse, same, into the mouse queue
not_keyboard: ANDI R3, R7, INTERRUPT_MOUSE
        JZ     not_mouse
        LOAD   R3, [MOUSE_DATA]
        LOADLO R6, MOUSE_QUEUE
        CALL   queue_put

; UART, a byte from the PC into the UART queue
not_mouse: ANDI R3, R7, INTERRUPT_UART
        JZ     handler_done
        LOAD   R3, [UART_DATA]
        LOADLO R6, UART_QUEUE
        CALL   queue_put

handler_done: POP R8
        POP    R7
        POP    R6
        POP    R5
        POP    R4
        POP    R3
        RETI                            ; back to the program, IE = 1 again

; queue_put, puts the byte in R3 into the queue at R6
; a full queue drops the byte
; only the handler calls this, only it writes the head
; uses R4, R5, R8
queue_put: LOAD R4, [R6 + QUEUE_HEAD]   ; R4 = head, the slot the byte goes in
        ADDI   R5, R4, 1
        ANDI   R5, R5, QUEUE_MASK       ; R5 = next head, wrapped
        LOAD   R8, [R6 + QUEUE_TAIL]
        CMP    R5, R8
        JZ     put_done                 ; full, drop the byte
        ADD    R8, R6, R4               ; R8 = queue + slot number
        STOREB R3, [R8 + QUEUE_SLOTS]   ; the byte goes in first
        STORE  R5, [R6 + QUEUE_HEAD]    ; then the head moves
put_done: RET

; queue_get, takes the oldest byte out of a queue
; in R1 = pointer to the queue
; out R1 = the byte, or -1 if empty
; only readers call this, only they write the tail
; uses R5, R6, R7
queue_get: LOAD R5, [R1 + QUEUE_TAIL]   ; R5 = tail, the slot of the oldest byte
        LOAD   R6, [R1 + QUEUE_HEAD]    ; R6 = head
        CMP    R5, R6
        JZ     queue_empty              ; head = tail, empty
        ADD    R6, R1, R5               ; R6 = queue + slot number
        LOADB  R7, [R6 + QUEUE_SLOTS]   ; R7 = the byte, it comes out first
        ADDI   R5, R5, 1
        ANDI   R5, R5, QUEUE_MASK       ; next tail, wrapped
        STORE  R5, [R1 + QUEUE_TAIL]    ; then the tail moves
        MOV    R1, R7                   ; R1 = the byte
        RET
queue_empty: NOT R1, R0                 ; R1 = -1
        RET

; queue entries, point R1 at the queue, then JUMP to queue_get
; a JUMP so queue_gets RET goes back to the caller
; out R1 = next byte or -1
get_key_byte: LOADLO R1, KEY_QUEUE
        JUMP   queue_get
; GET_MOUSE_BYTE also checks the PC remote when the queue is empty
; a mouse packet from the PC goes into the queue
get_mouse_byte: LOADLO R1, MOUSE_QUEUE
        CALL   queue_get
        CMPIS  R1, -1
        JNZ    mouse_byte_done
        CALL   remote_check
        LOADLO R1, MOUSE_QUEUE
        JUMP   queue_get
mouse_byte_done: RET
get_serial_byte: LOADLO R1, UART_QUEUE
        JUMP   queue_get

; get_char, next character typed or -1, never waits
; the queue holds raw bytes, scan codes, F0 = release, E0 = extended
; F0 / E0, noted in KEYBOARD_NOTES for the next byte
; Shift, 0x12 left, 0x59 right, kept in KEYBOARD_SHIFT
; a release or an extended key, no character
; a press, character from keymap_normal or keymap_shift, 0 = none
; out R1 = character or -1, uses R1-R7
get_char: LOADLO R1, KEY_QUEUE          ; R1 = keyboard queue
        CALL   queue_get                ; R1 = next raw byte or -1
        CMPIS  R1, -1
        JZ     char_remote              ; queue empty, maybe a key from the PC
        CMPI   R1, 0x00F0
        JZ     note_release
        CMPI   R1, 0x00E0
        JZ     note_extended
        LOAD   R2, [KEYBOARD_NOTES]     ; R2 = notes about this byte
        STORE  R0, [KEYBOARD_NOTES]     ; used up
        ANDI   R3, R2, 0x0002
        JNZ    extended_key             ; E0 came first
        CMPI   R1, 0x0012               ; left Shift?
        JZ     shift_key
        CMPI   R1, 0x0059               ; right Shift?
        JZ     shift_key
        CMPI   R2, 0x0000               ; a release, no character
        JNZ    get_char                 ; next byte
        CMPI   R1, 0x0080               ; past the end of the tables?
        JC     get_char
        LOADLO R3, keymap_normal        ; R3 = normal table
        LOAD   R4, [KEYBOARD_SHIFT]
        CMPI   R4, 0x0000
        JZ     look_up
        LOADLO R3, keymap_shift         ; or the Shift table
look_up: ADD R3, R3, R1                 ; R3 = table + scan code
        LOADB  R1, [R3]                 ; R1 = character, 0 = none
        CMPI   R1, 0x0000
        JZ     get_char                 ; no character, next byte
char_done: RET
; keyboard empty, take a key from the PC remote if there is one
; in REMOTE_KEY already or remote_check finds one, else -1
char_remote: LOAD R1, [REMOTE_KEY]
        CMPI   R1, 0x0000
        JNZ    char_remote_take
        CALL   remote_check
        LOAD   R1, [REMOTE_KEY]
        CMPI   R1, 0x0000
        JZ     char_none
char_remote_take: STORE R0, [REMOTE_KEY] ; used up
        RET
char_none: NOT R1, R0                   ; -1, nothing typed
        RET

; extended key, E0 + scan code, gives KEY_UP (0x80) and on
; releases and other extended keys give nothing
extended_key: ANDI R3, R2, 0x0001
        JNZ    get_char                 ; a release, nothing
        LOADLO R3, extended_keys        ; R3 = table, scan code then its code
extended_next: LOADB R4, [R3]
        CMPI   R4, 0x0000
        JZ     get_char                 ; end of the table, unknown key
        CMP    R4, R1
        JZ     extended_found
        ADDI   R3, R3, 2
        JUMP   extended_next
extended_found: LOADB R1, [R3 + 1]
        RET
extended_keys: .byte 0x75, 0x80, 0x72, 0x81 ; up, down
.byte 0x6B, 0x82, 0x74, 0x83            ; left, right
.byte 0x6C, 0x84, 0x69, 0x85            ; Home, End
.byte 0x71, 0x86, 0x7D, 0x87            ; Delete, Page Up
.byte 0x7A, 0x88, 0x00, 0x00            ; Page Down, end of table

note_release: LOAD R2, [KEYBOARD_NOTES]
        ORI    R2, R2, 0x0001           ; bit 0, next key is a release
        STORE  R2, [KEYBOARD_NOTES]
        JUMP   get_char
note_extended: LOAD R2, [KEYBOARD_NOTES]
        ORI    R2, R2, 0x0002           ; bit 1, next key is extended
        STORE  R2, [KEYBOARD_NOTES]
        JUMP   get_char
shift_key: ANDI R2, R2, 0x0001          ; R2 = 1 release, 0 press
        XORI   R2, R2, 0x0001           ; flip, 1 = Shift held
        STORE  R2, [KEYBOARD_SHIFT]
        JUMP   get_char

; program_stopped, the program caused a trap
; CAUSE 0x0001_0003 stack overflow, 0x0001_0000 divide by zero
; 0x0001_0002 misaligned LOAD/STORE, or a TRAP instruction
; 1. empty the stack
; 2. print "program stopped: CAUSE 0x00010003" to the PC and the monitor
; 3. LEDs 0, 1 and 3
; 4. back to the shell, IE is still 0 here
program_stopped: LOADLO R15SP, STACK_TOP ; empty stack, 0x8000
        GETCAUSE R8                      ; R8 = CAUSE
        LOADLO R1, stopped_text
        CALL   print_text
        SHIFTI R1, R8, 0x18, 0b1000     ; CAUSEs 4 bytes, highest first
        CALL   print_byte_hex
        SHIFTI R1, R8, 0x10, 0b1000
        CALL   print_byte_hex
        SHIFTI R1, R8, 0x08, 0b1000
        CALL   print_byte_hex
        MOV    R1, R8
        CALL   print_byte_hex
        LOADLO R1, 0x000D               ; new line, CR, LF
        CALL   send_byte
        LOADLO R1, 0x000A
        CALL   send_byte
        LOADLO R1, stopped_text         ; same on the monitor
        CALL   screen_text
        MOV    R1, R8
        CALL   screen_hex_word
        LOADLO R1, 0x000A
        CALL   screen_char
        LOADLO R1, 0x000B               ; LEDs 0, 1 and 3
        STORE  R1, [LEDS]
        JUMP   to_restart               ; back to the shell, through the bridge

stopped_text: .string "program stopped: CAUSE 0x"

; queues_clear, empties the three queues and the keyboard state
; called once at boot, RAM keeps old values over a reset
queues_clear: STORE R0, [LINE_LENGTH]
        STORE  R0, [KEYBOARD_SHIFT]
        STORE  R0, [KEYBOARD_NOTES]
        STORE  R0, [KEY_QUEUE + QUEUE_HEAD]
        STORE  R0, [KEY_QUEUE + QUEUE_TAIL]
        STORE  R0, [MOUSE_QUEUE + QUEUE_HEAD]
        STORE  R0, [MOUSE_QUEUE + QUEUE_TAIL]
        STORE  R0, [UART_QUEUE + QUEUE_HEAD]
        STORE  R0, [UART_QUEUE + QUEUE_TAIL]
        RET
