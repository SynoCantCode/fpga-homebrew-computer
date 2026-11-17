; ENC28J60 driver, start the chip, send and receive frames

; net_pause, 2 timer ticks, 10-20 ms, uses R1, R2
net_pause: LOAD R1, [TIMER]
        ADDI   R1, R1, 2
n_net_pause_wait: LOAD R2, [TIMER]
        CMP    R2, R1
        JNC    n_net_pause_wait
        RET

;---- the driver ----
; enc_start, reset and set up the chip, uses R1-R7
; buffer split, receive 0x0000-0x19FF, send from 0x1A00
; half duplex, frames up to 1518 bytes, our MAC, receiving on
enc_start: CALL enc_on                  ; SRC, soft reset
        LOADLO R1, 0x00FF
        CALLF  spi_swap
        CALL   enc_off
        CALL   net_pause
        CALL   net_pause
        LOADLO R6, 100                  ; wait for its clock, CLKRDY in ESTAT
n_start_clock: LOADLO R1, ESTAT
        CALL   enc_read
        ANDI   R1, R1, 0x0001
        JNZ    n_start_clock_ready
        CALL   net_pause
        DEC    R6
        CMPI   R6, 0x0000
        JNZ    n_start_clock
n_start_clock_ready: LOADLO R1, 0       ; bank 0, the buffer
        CALL   enc_bank
        LOADLO R1, 0x08                 ; ERXST, receive start
        LOADLO R2, RX_START
        CALL   enc_write16
        LOADLO R1, 0x0A                 ; ERXND, receive end
        LOADLO R2, RX_END
        CALL   enc_write16
        LOADLO R1, 0x0C                 ; ERXRDPT, how far we have read
        LOADLO R2, RX_END
        CALL   enc_write16
        LOADLO R1, 0x00                 ; ERDPT, where our reads start
        LOADLO R2, RX_START
        CALL   enc_write16
        LOADLO R1, 1                    ; bank 1, ERXFCON, only our MAC, broadcasts, good CRC
        CALL   enc_bank
        LOADLO R1, 0x18
        LOADLO R2, 0x00A1
        CALL   enc_write
        LOADLO R1, 2                    ; bank 2, the MAC layer
        CALL   enc_bank
        LOADLO R1, 0x00                 ; MACON1, MARXEN, RXPAUS, TXPAUS
        LOADLO R2, 0x000D
        CALL   enc_write
        LOADLO R1, 0x02                 ; MACON3, pad to 60, add the CRC, check lengths
        LOADLO R2, 0x0032
        CALL   enc_write
        LOADLO R1, 0x03                 ; MACON4, DEFER, wait for a quiet cable
        LOADLO R2, 0x0040
        CALL   enc_write
        LOADLO R1, 0x0A                 ; MAMXFL, frames up to 1518 bytes
        LOADLO R2, 1518
        CALL   enc_write16
        LOADLO R1, 0x04                 ; MABBIPG, back to back gap
        LOADLO R2, 0x0012
        CALL   enc_write
        LOADLO R1, 0x06                 ; MAIPGL, MAIPGH, the other gaps
        LOADLO R2, 0x0C12
        CALL   enc_write16
        LOADLO R1, 3                    ; bank 3, our MAC, MAADR1-6 at 0x04 0x05 0x02 0x03 0x00 0x01
        CALL   enc_bank
        LA     R6, net_mac
        LOADLO R1, 0x04
        LOADB  R2, [R6]
        CALL   enc_write
        LOADLO R1, 0x05
        LOADB  R2, [R6 + 1]
        CALL   enc_write
        LOADLO R1, 0x02
        LOADB  R2, [R6 + 2]
        CALL   enc_write
        LOADLO R1, 0x03
        LOADB  R2, [R6 + 3]
        CALL   enc_write
        LOADLO R1, 0x00
        LOADB  R2, [R6 + 4]
        CALL   enc_write
        LOADLO R1, 0x01
        LOADB  R2, [R6 + 5]
        CALL   enc_write
        LOADLO R1, 0x10                 ; PHY PHCON2, HDLDIS, do not hear our own frames
        LOADLO R2, 0x0100
        CALL   enc_phy_write
        LOADLO R1, 0x00                 ; PHY PHCON1, half duplex
        LOADLO R2, 0x0000
        CALL   enc_phy_write
        LOADLO R1, ECON1                ; receiving on
        LOADLO R2, 0x0004
        CALL   enc_set
        LOADLO R1, RX_START
        STORE  R1, [NET_NEXT]
        LOADLO R1, 1
        STORE  R1, [NET_STARTED]
        RET

; enc_send, send the frame in NET_SENDING, in R1 = length, 60-1514
; R8 = length, R9 = pointer, R10 = count
enc_send: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        LOADLO R10, 1000                ; wait for the last one to go, TXRTS off in ECON1
n_send_idle: LOADLO R1, ECON1
        CALL   enc_read
        ANDI   R1, R1, 0x0008
        JZ     n_send_ready
        DEC    R10
        CMPI   R10, 0x0000
        JNZ    n_send_idle
n_send_ready: LOADLO R1, ECON1          ; errata, reset the sending side first
        LOADLO R2, 0x0080
        CALL   enc_set
        LOADLO R1, ECON1
        LOADLO R2, 0x0080
        CALL   enc_clear
        LOADLO R1, 0                    ; bank 0
        CALL   enc_bank
        LOADLO R1, 0x02                 ; EWRPT, WBM writes into the send part
        LOADLO R2, TX_START
        CALL   enc_write16
        CALL   enc_on                   ; WBM, control byte 0, then the frame
        LOADLO R1, 0x007A
        CALLF  spi_swap
        LOADLO R1, 0x0000
        CALLF  spi_swap
        LOADHI R9, NET_SENDING_HIGH
        ORI    R9, R9, NET_SENDING_LOW
        MOV    R10, R8
n_send_byte: LOADB R1, [R9]
        CALLF  spi_swap
        INC    R9
        DEC    R10
        CMPI   R10, 0x0000
        JNZ    n_send_byte
        CALL   enc_off
        LOADLO R1, 0x04                 ; ETXST, ETXND, first and last byte of the frame
        LOADLO R2, TX_START
        CALL   enc_write16
        LOADLO R1, 0x06
        LOADLO R2, TX_START
        ADD    R2, R2, R8
        CALL   enc_write16
        LOADLO R1, ECON1                ; TXRTS, send it
        LOADLO R2, 0x0008
        CALL   enc_set
        POP    R10
        POP    R9
        POP    R8
        RET

; enc_receive, next frame into NET_RECEIVED, out R1 = length without CRC, 0 if none
; R8 = start of the one after, R9 = length, R10 = pointer, R11 = count
enc_receive: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        LOADLO R1, 1                    ; bank 1, EPKTCNT, frames waiting
        CALL   enc_bank
        LOADLO R1, 0x19
        CALL   enc_read
        CMPI   R1, 0x0000
        JZ     n_receive_none
        LOADLO R1, 0                    ; bank 0, ERDPT = where it starts
        CALL   enc_bank
        LOADLO R1, 0x00
        LOAD   R2, [NET_NEXT]
        CALL   enc_write16
        CALL   enc_on                   ; RBM, 6 byte header, then the bytes
        LOADLO R1, 0x003A
        CALLF  spi_swap
        LOADLO R1, 0x00FF               ; next frames start, low then high
        CALLF  spi_swap
        MOV    R8, R1
        LOADLO R1, 0x00FF
        CALLF  spi_swap
        SHIFTI R1, R1, 0x08, 0b0000
        OR     R8, R8, R1
        LOADLO R1, 0x00FF               ; length with the CRC, low then high
        CALLF  spi_swap
        MOV    R9, R1
        LOADLO R1, 0x00FF
        CALLF  spi_swap
        SHIFTI R1, R1, 0x08, 0b0000
        OR     R9, R9, R1
        LOADLO R1, 0x00FF               ; status, 2 bytes, not used
        CALLF  spi_swap
        LOADLO R1, 0x00FF
        CALLF  spi_swap
        SUBI   R9, R9, 4                ; without the CRC
        CMPI   R9, 1519
        JNC    n_receive_size_ok        ; over 1518, cut
        LOADLO R9, 1518
n_receive_size_ok: LOADHI R10, NET_RECEIVED_HIGH
        MOV    R11, R9
n_receive_byte: CMPI R11, 0x0000
        JZ     n_receive_copied
        LOADLO R1, 0x00FF
        CALLF  spi_swap
        STOREB R1, [R10]
        INC    R10
        DEC    R11
        JUMP   n_receive_byte
n_receive_copied: CALL enc_off
        STORE  R8, [NET_NEXT]
        SUBI   R2, R8, 1                ; ERXRDPT, just before the next one, errata wants odd so 0 wraps to the end
        CMPI   R8, RX_START
        JNZ    n_receive_free
        LOADLO R2, RX_END
n_receive_free: LOADLO R1, 0x0C
        CALL   enc_write16
        LOADLO R1, ECON2                ; PKTDEC, one fewer waiting
        LOADLO R2, 0x0040
        CALL   enc_set
        MOV    R1, R9
        JUMP   n_receive_done
n_receive_none: LOADLO R1, 0
n_receive_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET
