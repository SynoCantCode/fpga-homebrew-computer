; kbench, how fast KERNEL.BIN's code runs from the SDRAM
; calls ALLOCATE of 100 bytes then FREE, 30,000 times
; timed with the TIMER, hundredths of a second
; R8 = time at the start, R9 = rounds left
.include "sw/os/devices.asm"
.org PROGRAM_SDRAM

start:  PUSH   R8
        PUSH   R9
        LOAD   R8, [TIMER]
        LOADLO R9, 30000
round:  LOADLO R1, 100
        CALLF  ALLOCATE                 ; R1 = the memory
        CALLF  FREE                     ; give it back
        DEC    R9, 0b0100
        JNZ    round
        LOAD   R9, [TIMER]
        SUB    R9, R9, R8               ; R9 = hundredths it took
        LA     R1, result_text
        CALLF  SCREEN_TEXT
        DIVUI  R1, R9, 100              ; seconds
        CALL   show_decimal
        LOADLO R1, 0x002E
        CALLF  SCREEN_CHAR
        MODUI  R1, R9, 100              ; hundredths, always 2 digits
        DIVUI  R1, R1, 10
        CALL   show_decimal
        MODUI  R1, R9, 10
        CALL   show_decimal
        LA     R1, seconds_text
        CALLF  SCREEN_LINE
        POP    R9
        POP    R8
        RET

; show_decimal, shows R1 in decimal, digits pushed then popped
show_decimal: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADLO R9, 0
decimal_split: MODUI R1, R8, 10
        ADDI   R1, R1, 0x0030
        PUSH   R1
        INC    R9
        DIVUI  R8, R8, 10
        CMPI   R8, 0x0000
        JNZ    decimal_split
decimal_show: POP R1
        CALLF  SCREEN_CHAR
        DEC    R9, 0b0100
        JNZ    decimal_show
        POP    R9
        POP    R8
        RET

result_text:  .string "30,000 x ALLOCATE + FREE (KERNEL.BIN code): "
seconds_text: .string " s"
