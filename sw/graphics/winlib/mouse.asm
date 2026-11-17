; mouse woken up, by WM and Studio at their start

; mouse_wake, calls the kernels mouse_start at KERNEL_CALLS + 4
; mouse starts sending, wheel on if it has one, 4 byte packets
; 0 there = just send 0xF4, plain mouse, uses R1-R7
mouse_wake: LOAD R5, [KERNEL_CALLS + 4]
        CMPI   R5, 0x0000
        JZ     mouse_wake_plain
        CALLR  R5
        RET
mouse_wake_plain: LOADLO R1, 0x00F4
        STORE  R1, [MOUSE_DATA]
        RET
