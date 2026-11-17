; clock, date and time from the DS3231 chip, I2C address 0x68
; read once a second, "YYYY-MM-DD" on row 1, "HH:MM:SS" on row 2
; no chip answering, shows "running for" and MM:SS
; the window is an ordinary page, this only draws the text
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
        .word  1                        ; one tick a second

; tick, read the chip's 7 registers into chip, then redraw
; seconds, minutes, hours, weekday, date, month, year, all BCD
; have_chip = 1 if it answered. in R1 = window, R8 = window
tick:   PUSH   R8
        MOV    R8, R1
        LOADLO R1, CLOCK_CHIP
        LOADLO R2, 0
        LOADLO R3, 7
        LA     R4, chip
        CALLF  I2C_READ                 ; R1 = 0, it answered
        LA     R6, have_chip
        LOADLO R2, 1
        CMPI   R1, 0x0000
        JZ     tick_answered
        LOADLO R2, 0
tick_answered: STORE R2, [R6]
        MOV    R1, R8
        CALLF  WM_REDRAW
        POP    R8
        RET

; paint, date and time, or "running for" and MM:SS without the chip
paint:  LA     R6, have_chip
        LOAD   R1, [R6]
        CMPI   R1, 0x0000
        JZ     paint_running
        LA     R7, chip                 ; date, "20" YY "-" MM "-" DD
        LA     R6, line
        LOADLO R1, 0x0032               ; '2'
        STOREB R1, [R6]
        LOADLO R1, 0x0030               ; '0'
        STOREB R1, [R6 + 1]
        LOADB  R1, [R7 + 6]             ; year
        ADDI   R2, R6, 2
        CALL   bcd_text
        LOADLO R1, 0x002D               ; '-'
        STOREB R1, [R6 + 4]
        LOADB  R1, [R7 + 5]             ; month, bit 7 is the century
        ANDI   R1, R1, 0x001F
        ADDI   R2, R6, 5
        CALL   bcd_text
        LOADLO R1, 0x002D
        STOREB R1, [R6 + 7]
        LOADB  R1, [R7 + 4]             ; date
        ANDI   R1, R1, 0x003F
        ADDI   R2, R6, 8
        CALL   bcd_text
        STOREB R0, [R6 + 10]
        LOADLO R1, 0
        LOADLO R2, 0
        LA     R3, line
        LOADLO R4, 0x00
        CALLF  WM_TEXT
        LA     R7, chip                 ; time, HH ":" MM ":" SS
        LA     R6, time
        LOADB  R1, [R7 + 2]             ; hours, 24 hour, top 2 bits off
        ANDI   R1, R1, 0x003F
        MOV    R2, R6
        CALL   bcd_text
        LOADLO R1, 0x003A               ; ':'
        STOREB R1, [R6 + 2]
        LOADB  R1, [R7 + 1]             ; minutes
        ANDI   R1, R1, 0x007F
        ADDI   R2, R6, 3
        CALL   bcd_text
        LOADLO R1, 0x003A
        STOREB R1, [R6 + 5]
        LOADB  R1, [R7]                 ; seconds
        ANDI   R1, R1, 0x007F
        ADDI   R2, R6, 6
        CALL   bcd_text
        STOREB R0, [R6 + 8]
        JUMP   paint_time

paint_running: LOAD R1, [TIMER]         ; no chip, timer hundredths to "MM:SS"
        DIVUI  R1, R1, TICKS_PER_SECOND
        LA     R6, time
        DIVUI  R2, R1, 60               ; minutes, up to 99
        MODUI  R2, R2, 100
        DIVUI  R3, R2, 10
        ADDI   R3, R3, 0x0030
        STOREB R3, [R6]
        MODUI  R3, R2, 10
        ADDI   R3, R3, 0x0030
        STOREB R3, [R6 + 1]
        LOADLO R3, 0x003A               ; ':'
        STOREB R3, [R6 + 2]
        MODUI  R2, R1, 60               ; seconds
        DIVUI  R3, R2, 10
        ADDI   R3, R3, 0x0030
        STOREB R3, [R6 + 3]
        MODUI  R3, R2, 10
        ADDI   R3, R3, 0x0030
        STOREB R3, [R6 + 4]
        STOREB R0, [R6 + 5]
        LOADLO R1, 0
        LOADLO R2, 0
        LA     R3, running_text
        LOADLO R4, 0x00
        CALLF  WM_TEXT
paint_time: LOADLO R1, 0                ; second row, the time, navy
        LOADLO R2, 16
        LA     R3, time
        LOADLO R4, 0x38
        CALLF  WM_TEXT
        RET

; init, read the chip at once. key, click, close do nothing
init:   JUMP   tick
key:    RET
click:  RET
close:  RET

; button, event 1 Internet, sets the clock with net_time, NET_CALLS + 8
; events 2 and 3, +1H and -1H, clock_shift, NET_CALLS + 12
; the time zone is kept in the chip
; #note says how it went, then the chip is read again
; in R1 = window, R2 = event. R8 = window
button: PUSH   R8
        MOV    R8, R1
        CMPI   R2, 1
        JNZ    button_shift
        LOAD   R5, [NET_CALLS + 8]      ; net_time, 0 = kernel doesn't have it
        CMPI   R5, 0x0000
        JZ     button_old
        CALLR  R5                       ; R1 = 1, set
        LA     R3, internet_text
        CMPI   R1, 0x0000
        JNZ    button_said
        LA     R3, no_internet_text
        JUMP   button_said
button_shift: LOADLO R1, 1              ; +1h = 1, -1h = -1
        CMPI   R2, 2
        JZ     button_hours
        NOT    R1, R0
button_hours: LOAD R5, [NET_CALLS + 12] ; clock_shift
        CMPI   R5, 0x0000
        JZ     button_old
        CALLR  R5                       ; R1 = 1, moved
        LA     R3, moved_text
        CMPI   R1, 0x0000
        JNZ    button_said
        LA     R3, no_chip_text
        JUMP   button_said
button_old: LA R3, old_kernel_text
button_said: MOV R1, R8                 ; what happened, in #note
        LA     R2, note_name
        CALLF  WM_SET_TEXT
        MOV    R1, R8                   ; read the chip again and draw
        CALL   tick
        POP    R8
        RET

running_text: .string "running for"
note_name:        .string "note"
internet_text:    .string "Set from the internet"
no_internet_text: .string "No time from the net"
moved_text:       .string "Moved an hour"
no_chip_text:     .string "No clock chip"
old_kernel_text:  .string "Kernel too old"
have_chip: .word 0                      ; 1 = the chip answered the last read
chip:   .word 0                         ; chip registers 0-6, 8 bytes
        .word 0
line:   .word 0                         ; "YYYY-MM-DD" + a 0, 12 bytes
        .word 0
        .word 0
time:   .word 0                         ; "HH:MM:SS" + a 0, 12 bytes
        .word 0
        .word 0

.include "sw/apps/lib/text.asm"       ; text_copy, text_lower, number_text
