; TCP, send a segment with net_tcp_send, check one with net_tcp_frame

; net_tcp_send, one TCP segment to NET_TARGET, NET_LOCAL_PORT to NET_REMOTE_PORT
; flags 0x02 SYN, 0x10 ACK, 0x01 FIN, 0x08 PSH, 0x04 RST, window 2 KB
; checksum over a pseudo header and the segment, a SYN adds MSS 1000
; in R1 = flags, R2 = pointer to the data, R3 = its length or 0
; R8 = frame, R9 = TCP header length, R10 = TCP length, R11 = flags
net_tcp_send: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R11, R1
        LOADHI R8, NET_SENDING_HIGH
        ORI    R8, R8, NET_SENDING_LOW
        LOADLO R9, 20
        ANDI   R1, R11, 0x0002
        JZ     n_tcp_header
        LOADLO R9, 24                   ; a SYN, add the MSS option
n_tcp_header: ADD R10, R9, R3
        PUSH   R3
        ADD    R1, R8, R9               ; copy the data after the header first
        ADDI   R1, R1, 34
        MOV    R4, R2
        MOV    R2, R1
        MOV    R1, R4
        CALL   net_copy
        LOADLO R1, NET_HOP_MAC
        LOADLO R2, 0x0800
        CALL   net_eth_header
        ADDI   R1, R10, 20
        LOADLO R2, 6
        LOADLO R3, NET_TARGET
        CALL   net_ip_header
        LOAD   R1, [NET_LOCAL_PORT]     ; TCP header at 34
        ADDI   R2, R8, 34
        CALL   net_put16
        LOAD   R1, [NET_REMOTE_PORT]
        ADDI   R2, R8, 36
        CALL   net_put16
        LOAD   R1, [NET_SEQ]
        ADDI   R2, R8, 38
        CALL   net_put32
        LOAD   R1, [NET_ACK]
        ADDI   R2, R8, 42
        CALL   net_put32
        SHIFTI R1, R9, 0x02, 0b0000     ; header length in words, top 4 bits
        STOREB R1, [R8 + 46]
        STOREB R11, [R8 + 47]
        LOADLO R1, 2048                 ; the window
        ADDI   R2, R8, 48
        CALL   net_put16
        STOREB R0, [R8 + 50]            ; checksum 0 while it is worked out, urgent 0
        STOREB R0, [R8 + 51]
        STOREB R0, [R8 + 52]
        STOREB R0, [R8 + 53]
        CMPI   R9, 24
        JNZ    n_tcp_sum
        LOADLO R1, 0x0204               ; MSS option, kind 2, length 4, 1000
        ADDI   R2, R8, 54
        CALL   net_put16
        LOADLO R1, 1000
        ADDI   R2, R8, 56
        CALL   net_put16
n_tcp_sum: LOADHI R2, NET_SENDING_HIGH  ; pseudo header, our address, theirs, 0, 6, TCP length
        ORI    R2, R2, NET_PSEUDO_LOW
        LOADLO R1, NET_IP
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R1, NET_TARGET
        LOADLO R3, 4
        CALL   net_copy
        STOREB R0, [R2]
        LOADLO R1, 6
        STOREB R1, [R2 + 1]
        MOV    R1, R10
        ADDI   R2, R2, 2
        CALL   net_put16
        LOADHI R1, NET_SENDING_HIGH
        ORI    R1, R1, NET_PSEUDO_LOW
        LOADLO R2, 12
        LOADLO R3, 0
        CALL   net_sum
        ADDI   R1, R8, 34
        MOV    R2, R10
        CALL   net_sum
        CALL   net_fold
        ADDI   R2, R8, 50
        CALL   net_put16
        POP    R3
        ADDI   R1, R10, 34
        CALL   enc_send
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; net_tcp_frame, is the frame received a TCP segment of our connection?
; out R1 = flags + 0x100, or 0 if not ours and net_answer gets it
; R2 = data start, R3 = data length, R4 = sequence number, R8 = frame
net_tcp_frame: PUSH R8
        PUSH   R1
        LOADHI R8, NET_RECEIVED_HIGH
        ADDI   R1, R8, 12
        CALL   net_get16
        CMPI   R1, 0x0800
        JNZ    n_frame_other
        LOADB  R1, [R8 + 23]
        CMPI   R1, 6
        JNZ    n_frame_other
        ADDI   R1, R8, 26               ; from them?
        LOADLO R2, NET_TARGET
        LOADLO R3, 4
        CALL   net_same
        CMPI   R1, 0x0000
        JZ     n_frame_other
        ADDI   R1, R8, 34               ; their port
        CALL   net_get16
        LOAD   R2, [NET_REMOTE_PORT]
        CMP    R1, R2
        JNZ    n_frame_other
        ADDI   R1, R8, 36               ; to our port
        CALL   net_get16
        LOAD   R2, [NET_LOCAL_PORT]
        CMP    R1, R2
        JNZ    n_frame_other
        POP    R1
        LOADB  R6, [R8 + 46]            ; R6 = TCP header length, top 4 bits x 4
        SHIFTI R6, R6, 0x04, 0b1000
        SHIFTI R6, R6, 0x02, 0b0000
        ADDI   R1, R8, 16               ; R3 = data length, IP total - 20 - TCP header
        CALL   net_get16
        SUBI   R3, R1, 20
        SUB    R3, R3, R6
        ADDI   R2, R8, 34               ; R2 = the data
        ADD    R2, R2, R6
        PUSH   R2
        PUSH   R3
        ADDI   R1, R8, 38               ; R4 = its sequence number
        CALL   net_get32
        MOV    R4, R1
        POP    R3
        POP    R2
        LOADB  R1, [R8 + 47]            ; its flags
        ORI    R1, R1, 0x0100
        JUMP   n_frame_end
n_frame_other: POP R1
        CALL   net_answer
        LOADLO R1, 0
n_frame_end: POP R8
        RET
