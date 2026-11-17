; kernel_check.asm, did something write over the kernel?
; no memory protection, a program can write over KERNEL.BIN
; KERNEL.BINs words are added up at start, kept in KERNEL_SUM
; the shell adds them up again each time it starts
; different = warn once, save your work and reboot
; KERNEL.BIN keeps its variables in RAM so the sum stays the same

; kernel_sum, adds up the words from 0x1000_0000 to kernel_end
; out R1 = the sum, uses R1-R4
kernel_sum: LOADHI R2, 0x1000
        LA     R3, kernel_end
        LOADLO R1, 0
kernel_sum_next: CMP R2, R3
        JC     kernel_sum_done          ; the end
        LOAD   R4, [R2]
        ADD    R1, R1, R4
        ADDI   R2, R2, 4
        JUMP   kernel_sum_next
kernel_sum_done: RET

; kernel_check, sum again, warns on the screen once if not KERNEL_SUM
; uses R1-R4
kernel_check: CALL kernel_sum
        LOAD   R2, [KERNEL_SUM]
        CMP    R1, R2
        JZ     kernel_check_done        ; same, fine
        LOAD   R1, [KERNEL_WARNED]
        CMPI   R1, 0x0000
        JNZ    kernel_check_done        ; warned already
        LOADLO R1, 1
        STORE  R1, [KERNEL_WARNED]
        LA     R1, kernel_damaged_text
        CALLF  screen_line
kernel_check_done: RET

kernel_damaged_text: .string "WARNING: a program wrote over the kernel in memory. Save your work and reboot."
