; building and checking packets, checksums, Ethernet and IP headers

;---- building and checking packets ----
; net_checksum, internet checksum, in R1 = pointer, R2 = bytes, out R1 = 16 bit checksum
; 16 bit big endian sum, carries added back in, bits flipped, uses R1-R5
; net_sum adds to a running total in R3, net_fold finishes it
net_checksum: LOADLO R3, 0
        CALL   net_sum
        JUMP   net_fold
net_sum: CMPI R2, 2
        JNC    n_checksum_last
        JUMP   n_checksum_add
n_checksum_pair: CMPI R2, 2
        JNC    n_checksum_last          ; fewer than 2 left
n_checksum_add: LOADB R4, [R1]
        SHIFTI R4, R4, 0x08, 0b0000
        LOADB  R5, [R1 + 1]
        OR     R4, R4, R5
        ADD    R3, R3, R4
        ADDI   R1, R1, 2
        SUBI   R2, R2, 2
        JUMP   n_checksum_pair
n_checksum_last: CMPI R2, 0x0000
        JZ     n_checksum_summed
        LOADB  R4, [R1]
        SHIFTI R4, R4, 0x08, 0b0000
        ADD    R3, R3, R4
n_checksum_summed: RET
net_fold: SHIFTI R4, R3, 0x10, 0b1000   ; add the carries above 16 bits back in, twice
        ANDI   R3, R3, 0xFFFF
        ADD    R3, R3, R4
        SHIFTI R4, R3, 0x10, 0b1000
        ANDI   R3, R3, 0xFFFF
        ADD    R3, R3, R4
        NOT    R3, R3
        ANDI   R1, R3, 0xFFFF
        RET
; net_put16, 16 bit number big endian, in R1 = number, R2 = where, uses R4
net_put16: SHIFTI R4, R1, 0x08, 0b1000
        STOREB R4, [R2]
        STOREB R1, [R2 + 1]
        RET
; net_get16, 16 bit big endian number, in R1 = where, out R1 = number, uses R4
net_get16: LOADB R4, [R1]
        LOADB  R1, [R1 + 1]
        SHIFTI R4, R4, 0x08, 0b0000
        OR     R1, R1, R4
        RET
; net_copy, copy bytes, in R1 = from, R2 = to, R3 = how many, uses R1-R4
net_copy: CMPI R3, 0x0000
        JZ     n_net_copy_done
        LOADB  R4, [R1]
        STOREB R4, [R2]
        INC    R1
        INC    R2
        DEC    R3
        JUMP   net_copy
n_net_copy_done: RET
; net_same, compare bytes, in R1, R2 = pointers, R3 = how many, out R1 = 1 same, 0 not, uses R1-R5
net_same: CMPI R3, 0x0000
        JZ     n_net_same_yes
        LOADB  R4, [R1]
        LOADB  R5, [R2]
        CMP    R4, R5
        JNZ    n_net_same_no
        INC    R1
        INC    R2
        DEC    R3
        JUMP   net_same
n_net_same_yes: LOADLO R1, 1
        RET
n_net_same_no: LOADLO R1, 0
        RET
; net_ip_header, IP header at NET_SENDING + 14
; 0x45, total length, TTL 64, protocol, from NET_IP, to the address, checksum
; in R1 = total length, R2 = protocol, R3 = pointer to the address it goes to, R8 kept
net_ip_header: PUSH R8
        LOADHI R8, NET_SENDING_HIGH
        ORI    R8, R8, NET_SENDING_LOW + 14
        PUSH   R3
        PUSH   R2
        ADDI   R2, R8, 2                ; total length
        CALL   net_put16
        LOADLO R1, 0x0045               ; version 4, 5 words
        STOREB R1, [R8]
        STOREB R0, [R8 + 1]             ; TOS
        STOREB R0, [R8 + 4]             ; the id
        STOREB R0, [R8 + 5]
        STOREB R0, [R8 + 6]             ; flags, fragment
        STOREB R0, [R8 + 7]
        LOADLO R1, 64                   ; TTL
        STOREB R1, [R8 + 8]
        POP    R2
        STOREB R2, [R8 + 9]             ; protocol
        STOREB R0, [R8 + 10]            ; checksum, 0 while it is worked out
        STOREB R0, [R8 + 11]
        LOADLO R1, NET_IP               ; from us
        ADDI   R2, R8, 12
        LOADLO R3, 4
        CALL   net_copy
        POP    R1                       ; to
        ADDI   R2, R8, 16
        LOADLO R3, 4
        CALL   net_copy
        MOV    R1, R8
        LOADLO R2, 20
        CALL   net_checksum
        ADDI   R2, R8, 10
        CALL   net_put16
        POP    R8
        RET
; net_eth_header, Ethernet header at NET_SENDING, to, from our MAC, type
; in R1 = pointer to the MAC it goes to, R2 = type, 0x0800 IP, 0x0806 ARP, uses R1-R6
net_eth_header: PUSH R2
        LOADHI R6, NET_SENDING_HIGH
        ORI    R6, R6, NET_SENDING_LOW
        MOV    R2, R6
        LOADLO R3, 6
        CALL   net_copy
        LA     R1, net_mac
        ADDI   R2, R6, 6
        LOADLO R3, 6
        CALL   net_copy
        POP    R1
        ADDI   R2, R6, 12
        JUMP   net_put16
; net_print_ip, prints an IP like "10.0.0.5", in R1 = pointer to its 4 bytes
net_print_ip: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOADLO R9, 4
n_print_ip_byte: LOADB R1, [R8]
        CALL   net_print_decimal
        INC    R8
        DEC    R9
        CMPI   R9, 0x0000
        JZ     n_print_ip_done
        LOADLO R1, 0x002E               ; '.'
        CALLF  screen_char
        JUMP   n_print_ip_byte
n_print_ip_done: POP R9
        POP    R8
        RET
; net_print_decimal, print 0-255 without leading zeros, in R1 = number, uses R7, R8 kept
net_print_decimal: MOV R7, R1
        CMPI   R7, 100
        JNC    n_decimal_tens           ; under 100
        DIVUI  R1, R7, 100
        ADDI   R1, R1, 0x0030
        PUSH   R7
        CALLF  screen_char
        POP    R7
n_decimal_tens: CMPI R7, 10
        JNC    n_decimal_ones
        DIVUI  R1, R7, 10
        MODUI  R1, R1, 10
        ADDI   R1, R1, 0x0030
        PUSH   R7
        CALLF  screen_char
        POP    R7
n_decimal_ones: MODUI R1, R7, 10
        ADDI   R1, R1, 0x0030
        JUMPF  screen_char
