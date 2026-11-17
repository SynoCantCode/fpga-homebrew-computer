; time.asm, the DS3231 clock chip, set from the internet (NTP) or moved an hour
; the chip keeps 7 BCD bytes in registers 0-6
; seconds, minutes, hours (24 hour), day of the week (1 Sunday ... 7 Saturday),
; date, month, year (00-99 = 2000-2099)
; clock_to_seconds and seconds_to_clock go to and from seconds since 2000-01-01 00:00:00
; a year has 366 days when it divides by 4
; month days are in time_months, February + 1 in a leap year
; the time zone = hours to add to UTC, kept in the chips register 7
; register 7 is the first alarms seconds, the alarms arent used
; it holds the offset + 32, -12..+14 is 20..46, anything else counts as 0
; clock_shift moves the clock and the time zone
; for programs NET_CALLS + 8 = net_time, + 12 = clock_shift, in the shell net time

; time_read_chip, the 7 registers into time_bytes, out R1 = 0, or 1 if no answer, uses R1-R4
time_read_chip: LOADLO R1, CLOCK_CHIP
        LOADLO R2, 0
        LOADLO R3, 7
        LOADLO     R4, TIME_BYTES
        CALLF  I2C_READ
        RET

; time_write_chip, time_bytes into the 7 registers, out R1 = 0, or 1 if no answer
time_write_chip: LOADLO R1, CLOCK_CHIP
        LOADLO R2, 0
        LOADLO R3, 7
        LOADLO     R4, TIME_BYTES
        CALLF  I2C_WRITE
        RET

; time_from_bcd, 0x59 to 59, in R1, out R1, uses R2
time_from_bcd: SHIFTI R2, R1, 0x04, 0b1000
        ANDI   R2, R2, 0x000F
        MULI   R2, R2, 10
        ANDI   R1, R1, 0x000F
        ADD    R1, R1, R2
        RET

; time_to_bcd, 59 to 0x59, in R1 = 0-99, out R1, uses R2
time_to_bcd: DIVUI R2, R1, 10
        MODUI  R1, R1, 10
        SHIFTI R2, R2, 0x04, 0b0000
        OR     R1, R1, R2
        RET

; time_year_days, in R1 = year 0-99, out R1 = 365, or 366 if it divides by 4
; uses R2
time_year_days: ANDI R2, R1, 0x0003
        LOADLO R1, 365
        CMPI   R2, 0x0000
        JNZ    n_year_days_done
        LOADLO R1, 366
n_year_days_done: RET

; time_month_days, in R1 = month 1-12, R2 = year 0-99, out R1 = days, uses R2, R3
time_month_days: LA R3, time_months
        ADD    R3, R3, R1
        SUBI   R3, R3, 1
        LOADB  R3, [R3]
        CMPI   R1, 2
        JNZ    n_month_plain
        ANDI   R2, R2, 0x0003           ; February in a leap year, 29
        CMPI   R2, 0x0000
        JNZ    n_month_plain
        INC    R3
n_month_plain: MOV R1, R3
        RET

; clock_to_seconds, time_bytes as seconds since 2000-01-01 00:00:00, out R1
; R8 = days so far, R9 = year, R10 = time_bytes, R6 = month, R7 = year / month counted
clock_to_seconds: PUSH R8
        PUSH   R9
        PUSH   R10
        LOADLO     R10, TIME_BYTES
        LOADB  R1, [R10 + 6]            ; year
        CALL   time_from_bcd
        MOV    R9, R1
        LOADLO R8, 0
        LOADLO R7, 0
n_cts_year: CMP R7, R9                  ; days of each year before it
        JC     n_cts_months
        MOV    R1, R7
        CALL   time_year_days
        ADD    R8, R8, R1
        INC    R7
        JUMP   n_cts_year
n_cts_months: LOADB R1, [R10 + 5]       ; month, century bit 7 off
        ANDI   R1, R1, 0x001F
        CALL   time_from_bcd
        MOV    R6, R1
        LOADLO R7, 1
n_cts_month: CMP R7, R6                 ; days of each month before it
        JC     n_cts_date
        MOV    R1, R7
        MOV    R2, R9
        CALL   time_month_days
        ADD    R8, R8, R1
        INC    R7
        JUMP   n_cts_month
n_cts_date: LOADB R1, [R10 + 4]         ; days of this month before today
        ANDI   R1, R1, 0x003F
        CALL   time_from_bcd
        ADD    R8, R8, R1
        DEC    R8
        LOADHI R1, 0x0001               ; x 86400 (0x15180) seconds a day
        ORI    R1, R1, 0x5180
        MUL    R8, R8, R1
        LOADB  R1, [R10 + 2]            ; + hours x 3600
        ANDI   R1, R1, 0x003F
        CALL   time_from_bcd
        MULI   R1, R1, 3600
        ADD    R8, R8, R1
        LOADB  R1, [R10 + 1]            ; + minutes x 60
        ANDI   R1, R1, 0x007F
        CALL   time_from_bcd
        MULI   R1, R1, 60
        ADD    R8, R8, R1
        LOADB  R1, [R10]                ; + seconds
        ANDI   R1, R1, 0x007F
        CALL   time_from_bcd
        ADD    R1, R8, R1
        POP    R10
        POP    R9
        POP    R8
        RET

; seconds_to_clock, seconds since 2000-01-01 00:00:00 into time_bytes and the chip
; in R1 = seconds, out R1 = 0, or 1 if no answer
; R8 = days left, R9 = second of the day / year, R10 = time_bytes, R7 = month
seconds_to_clock: PUSH R8
        PUSH   R9
        PUSH   R10
        LOADLO     R10, TIME_BYTES
        LOADHI R2, 0x0001               ; 86400 seconds a day
        ORI    R2, R2, 0x5180
        DIVU   R8, R1, R2               ; R8 = whole days
        MODU   R9, R1, R2               ; R9 = second of today
        DIVUI  R1, R9, 3600             ; hours, bit 6 = 0 for 24 hour
        CALL   time_to_bcd
        STOREB R1, [R10 + 2]
        MODUI  R9, R9, 3600
        DIVUI  R1, R9, 60               ; minutes
        CALL   time_to_bcd
        STOREB R1, [R10 + 1]
        MODUI  R1, R9, 60               ; seconds
        CALL   time_to_bcd
        STOREB R1, [R10]
        ADDI   R1, R8, 6                ; day of the week, 2000-01-01 was a Saturday (7)
        MODUI  R1, R1, 7
        INC    R1
        STOREB R1, [R10 + 3]
        LOADLO R9, 0                    ; year, take whole years off
n_stc_year: MOV R1, R9
        CALL   time_year_days
        CMP    R8, R1
        JNC    n_stc_months             ; fewer days left than the year has, its this one
        SUB    R8, R8, R1
        INC    R9
        JUMP   n_stc_year
n_stc_months: MOV R1, R9
        CALL   time_to_bcd
        STOREB R1, [R10 + 6]
        LOADLO R7, 1                    ; month, take whole months off
n_stc_month: MOV R1, R7
        MOV    R2, R9
        CALL   time_month_days
        CMP    R8, R1
        JNC    n_stc_date
        SUB    R8, R8, R1
        INC    R7
        JUMP   n_stc_month
n_stc_date: MOV R1, R7
        CALL   time_to_bcd
        STOREB R1, [R10 + 5]
        ADDI   R1, R8, 1                ; date = days left + 1
        CALL   time_to_bcd
        STOREB R1, [R10 + 4]
        CALL   time_write_chip
        POP    R10
        POP    R9
        POP    R8
        RET

; time_offset_get, the time zone from register 7
; out R1 = hours to add to UTC, -12..+14, 0 if none, uses R1-R4
time_offset_get: LOADLO R1, CLOCK_CHIP
        LOADLO R2, 7
        LOADLO R3, 1
        LOADLO     R4, TIME_ZONE
        CALLF  I2C_READ
        CMPI   R1, 0x0000
        JNZ    n_offset_none
        LOADLO     R1, TIME_ZONE
        LOADB  R1, [R1]
        ANDI   R1, R1, 0x007F
        CMPI   R1, 20
        JNC    n_offset_none            ; under 20
        CMPI   R1, 47
        JC     n_offset_none            ; 47 or more
        SUBI   R1, R1, 32
        RET
n_offset_none: LOADLO R1, 0
        RET

; time_offset_put, a time zone into register 7 if its in -12..+14
; in R1 = hours, uses R1-R4
time_offset_put: ADDI R1, R1, 32
        CMPI   R1, 20
        JNC    n_offset_put_end
        CMPI   R1, 47
        JC     n_offset_put_end
        LOADLO     R4, TIME_ZONE
        STOREB R1, [R4]
        LOADLO R1, CLOCK_CHIP
        LOADLO R2, 7
        LOADLO R3, 1
        CALLF  I2C_WRITE
n_offset_put_end: RET

; clock_shift (NET_CALLS + 12), moves the clock and the time zone some hours
; in R1 = hours, 1 or -1, out R1 = 1 done, 0 no chip
; R8 = hours
clock_shift: PUSH R8
        MOV    R8, R1
        CALL   time_read_chip
        CMPI   R1, 0x0000
        JNZ    n_shift_fail
        CALL   clock_to_seconds
        MULI   R2, R8, 3600
        ADD    R1, R1, R2
        CALL   seconds_to_clock
        CALL   time_offset_get
        ADD    R1, R1, R8
        CALL   time_offset_put
        LOADLO R1, 1
        JUMP   n_shift_end
n_shift_fail: LOADLO R1, 0
n_shift_end: POP R8
        RET

; net_time (NET_CALLS + 8, net time), sets the clock by NTP, net_connect first if no IP
; pool.ntp.org found by DNS
; 48 byte question in UDP from port 53001 to port 123
; first byte 0x1B, version 3, mode 3 client, the rest 0
; answer byte 40 = transmit time, seconds since 1900, 32 bits, big-endian
; - 0xBC17C200 = seconds since 2000, + time zone x 3600, 2 tries of 2 seconds
; out R1 = 1 set, 0 not, R8 = frame sent / the time, R9 = tries left, R10 = when to stop
net_time: PUSH R8
        PUSH   R9
        PUSH   R10
        LOAD   R1, [NET_IP]             ; no IP? ask for one
        CMPI   R1, 0x0000
        JNZ    n_time_ip
        CALL   net_connect
        LOAD   R1, [NET_IP]
        CMPI   R1, 0x0000
        JZ     n_time_fail
n_time_ip: LA R1, time_server           ; server name, DNS into NET_TARGET,
        CALL   net_take_name            ; then ARP for the next hop
        CALL   net_resolve
        CMPI   R1, 0x0000
        JZ     n_time_fail
        LOADLO R1, NET_TARGET
        CALL   net_route
        CMPI   R1, 0x0000
        JZ     n_time_fail
        LOADLO R9, 2
n_time_try: LOADHI R8, NET_SENDING_HIGH
        ORI    R8, R8, NET_SENDING_LOW
        ADDI   R2, R8, 42               ; question at 42, 0x1B and 47 zeros
        LOADLO R3, 48
n_time_clear: STOREB R0, [R2]
        INC    R2
        DEC    R3
        CMPI   R3, 0x0000
        JNZ    n_time_clear
        LOADLO R1, 0x001B
        STOREB R1, [R8 + 42]
        LOADLO R1, NET_HOP_MAC          ; Ethernet, IP (UDP = 17), UDP 53001 to 123
        LOADLO R2, 0x0800
        CALL   net_eth_header
        LOADLO R1, 76                   ; 20 + 8 + 48
        LOADLO R2, 17
        LOADLO R3, NET_TARGET
        CALL   net_ip_header
        LOADLO R1, 53001
        ADDI   R2, R8, 34
        CALL   net_put16
        LOADLO R1, 123
        ADDI   R2, R8, 36
        CALL   net_put16
        LOADLO R1, 56                   ; UDP length, 8 + 48
        ADDI   R2, R8, 38
        CALL   net_put16
        STOREB R0, [R8 + 40]            ; no UDP checksum
        STOREB R0, [R8 + 41]
        LOADLO R1, 90                   ; 14 + 20 + 8 + 48
        CALL   enc_send
        LOAD   R10, [TIMER]             ; wait 2 seconds for the answer
        ADDI   R10, R10, 200
n_time_wait: CALL enc_receive
        CMPI   R1, 0x0000
        JZ     n_time_late
        CALL   net_time_answer          ; R1 = 1 if its the answer, R2 = its time
        CMPI   R1, 0x0000
        JNZ    n_time_got
n_time_late: LOAD R1, [TIMER]
        CMP    R1, R10
        JNC    n_time_wait
        DEC    R9
        CMPI   R9, 0x0000
        JNZ    n_time_try
n_time_fail: LOADLO R1, 0
        JUMP   n_time_end
n_time_got: LOADHI R1, 0xBC17           ; seconds since 1900 to since 2000
        ORI    R1, R1, 0xC200
        SUB    R8, R2, R1
        CALL   time_offset_get          ; + the time zone
        MULI   R1, R1, 3600
        ADD    R1, R8, R1
        CALL   seconds_to_clock
        LOADLO R1, 1
n_time_end: POP R10
        POP    R9
        POP    R8
        RET

; net_time_answer, is the received frame the time servers answer?
; in R1 = length, out R1 = 1 and R2 = transmit time, at frame byte 82
; anything else is answered like net listen, R1 = 0, R8 = the frame
net_time_answer: PUSH R8
        PUSH   R1
        LOADHI R8, NET_RECEIVED_HIGH
        ADDI   R1, R8, 12
        CALL   net_get16
        CMPI   R1, 0x0800
        JNZ    n_timea_other
        LOADB  R1, [R8 + 23]
        CMPI   R1, 17
        JNZ    n_timea_other
        ADDI   R1, R8, 34               ; from port 123
        CALL   net_get16
        CMPI   R1, 123
        JNZ    n_timea_other
        ADDI   R1, R8, 36               ; to ours
        CALL   net_get16
        LOADLO R2, 53001
        CMP    R1, R2
        JNZ    n_timea_other
        POP    R1
        ADDI   R1, R8, 82
        CALL   net_get32
        MOV    R2, R1
        LOADLO R1, 1
        POP    R8
        RET
n_timea_other: POP R1
        CALL   net_answer
        LOADLO R1, 0
        POP    R8
        RET

; net time, the shell command, prints HH:MM (UTC+N) or why not
; pops the R8 command_net pushed
net_time_command: CALL net_time
        CMPI   R1, 0x0000
        JNZ    n_timec_set
        LA     R1, net_time_fail_text
        POP    R8
        JUMPF  screen_line
n_timec_set: LA R1, net_time_text
        CALLF  screen_text
        LOADLO     R8, TIME_BYTES
        LOADB  R1, [R8 + 2]
        CALL   time_print_bcd
        LOADLO R1, 0x003A               ; ':'
        CALLF  screen_char
        LOADB  R1, [R8 + 1]
        CALL   time_print_bcd
        LA     R1, net_time_zone_text   ; " (UTC"
        CALLF  screen_text
        CALL   time_offset_get          ; sign, then the hours
        MOV    R8, R1
        LOADLO R1, 0x002B               ; '+'
        CMPIS  R8, 0
        JGE    n_timec_sign
        LOADLO R1, 0x002D               ; '-'
        SUB    R8, R0, R8
n_timec_sign: CALLF screen_char
        MOV    R1, R8
        CALL   net_print_decimal
        LA     R1, net_time_end_text    ; ")"
        POP    R8
        JUMPF  screen_line

; time_print_bcd, a BCD byte as 2 digits, in R1
time_print_bcd: PUSH R1
        SHIFTI R1, R1, 0x04, 0b1000
        ANDI   R1, R1, 0x000F
        ADDI   R1, R1, 0x0030
        CALLF  screen_char
        POP    R1
        ANDI   R1, R1, 0x000F
        ADDI   R1, R1, 0x0030
        JUMPF  screen_char

; TIME_BYTES = the 7 registers, TIME_ZONE = register 7, both in RAM
time_months: .byte 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 0, 0, 0, 0 ; days in each month
time_server: .string "pool.ntp.org"
net_time_name: .string "time"
net_time_text: .string "the clock is set from the internet: "
net_time_zone_text: .string " (UTC"
net_time_end_text: .string ")"
net_time_fail_text: .string "no time from the internet (no network, or the time server didn't answer)"
