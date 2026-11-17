; ENC28J60 chip over SPI, registers, banks, PHY

;---- talking to the chip ----
; enc_on / enc_off, chip select low / high, uses R3
enc_on: LOADLO R3, 0x0002
        STORE  R3, [SPI_SELECT]
        RET
enc_off: STORE R0, [SPI_SELECT]
        RET
; enc_op, send a command byte and one more byte, in R1 = command, R2 = byte
; out R1 = the byte that came back, uses R1-R5
enc_op: PUSH R2
        CALL   enc_on
        CALLF  spi_swap
        POP    R1
        CALLF  spi_swap
        JUMP   enc_off
; enc_write, WCR, in R1 = register address, R2 = value, uses R1-R5
enc_write: ORI R1, R1, 0x0040
        JUMP   enc_op
; enc_set / enc_clear, BFS / BFC, in R1 = address, R2 = bits, uses R1-R5
enc_set: ORI R1, R1, 0x0080
        JUMP   enc_op
enc_clear: ORI R1, R1, 0x00A0
        JUMP   enc_op
; enc_read, RCR of an ETH register, in R1 = address, out R1 = value, uses R1-R5
enc_read: LOADLO R2, 0x00FF
        JUMP   enc_op
; enc_read_mii, RCR of a MAC / MII register, dummy byte first, in R1 = address, out R1 = value
enc_read_mii: CALL enc_on
        CALLF  spi_swap
        LOADLO R1, 0x00FF
        CALLF  spi_swap
        LOADLO R1, 0x00FF
        CALLF  spi_swap
        JUMP   enc_off
; enc_bank, pick the register bank, in R1 = 0-3, uses R1-R5
enc_bank: PUSH R1
        LOADLO R1, ECON1
        LOADLO R2, 0x0003
        CALL   enc_clear
        POP    R2
        LOADLO R1, ECON1
        JUMP   enc_set
; enc_write16, 16 bit value into a register pair, low byte first
; in R1 = low address, R2 = value, uses R1-R5
enc_write16: PUSH R1
        PUSH   R2
        CALL   enc_write
        POP    R2
        POP    R1
        INC    R1
        SHIFTI R2, R2, 0x08, 0b1000
        JUMP   enc_write
; enc_phy_write, MIREGADR, MIWRL, then MIWRH starts the write
; in R1 = PHY register, R2 = value, uses R1-R5
enc_phy_write: PUSH R2
        PUSH   R1
        LOADLO R1, 2
        CALL   enc_bank
        POP    R2
        LOADLO R1, 0x14                 ; MIREGADR
        CALL   enc_write
        POP    R2
        PUSH   R2
        LOADLO R1, 0x16                 ; MIWRL
        CALL   enc_write
        POP    R2
        SHIFTI R2, R2, 0x08, 0b1000
        LOADLO R1, 0x17                 ; MIWRH, the write starts
        CALL   enc_write
        JUMP   net_pause
; enc_phy_read, MIREGADR, MIIRD on, wait, off, then MIRDL / MIRDH
; in R1 = PHY register, out R1 = its 16 bits, uses R1-R5
enc_phy_read: PUSH R1
        LOADLO R1, 2
        CALL   enc_bank
        POP    R2
        LOADLO R1, 0x14                 ; MIREGADR
        CALL   enc_write
        LOADLO R1, 0x12                 ; MICMD, MIIRD on
        LOADLO R2, 0x0001
        CALL   enc_write
        CALL   net_pause
        LOADLO R1, 0x12                 ; MICMD, off
        LOADLO R2, 0x0000
        CALL   enc_write
        LOADLO R1, 0x19                 ; MIRDH
        CALL   enc_read_mii
        PUSH   R1
        LOADLO R1, 0x18                 ; MIRDL
        CALL   enc_read_mii
        POP    R2
        SHIFTI R2, R2, 0x08, 0b0000
        OR     R1, R1, R2
        RET
