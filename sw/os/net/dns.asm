; DNS, a name to its address

; net_resolve, address of the name in NET_NAME into NET_TARGET
; numbers like "10.0.0.5" are read directly, else DNS, out R1 = 1 found, 0 not
net_resolve: LOADLO R1, NET_NAME
        LOADLO R2, NET_TARGET
        CALL   net_parse_ip
        CMPI   R1, 0x0000
        JNZ    n_resolve_done
        JUMP   net_dns
n_resolve_done: RET

; net_dns, ask the name server for the A record of NET_NAME
; UDP from port 53000 to port 53 of NET_DNS, Googles if DHCP gave none
; question = header with id 0x4650, the name as labels, type 1, class 1
; labels are a length then letters, 7 example 3 com 0
; 2 tries of 2 seconds, out R1 = 1 found and NET_TARGET set, 0 not
; R8 = frame sent, R9 = label pointer, R10 = question length, R11 = tries left, R12 = give up time
net_dns: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        LOAD   R1, [NET_DNS]            ; a name server? else Googles
        CMPI   R1, 0x0000
        JNZ    n_dns_server
        LA     R1, net_google_dns
        LOAD   R1, [R1]
        STORE  R1, [NET_DNS]
n_dns_server: LOADLO R1, NET_DNS        ; its MAC, or the routers
        CALL   net_route
        CMPI   R1, 0x0000
        JZ     n_dns_fail
        LOADLO R11, 2
n_dns_try: LOADHI R8, NET_SENDING_HIGH
        ORI    R8, R8, NET_SENDING_LOW
        LOADLO R1, 0x4650               ; DNS header at 42, id, flags recursion desired, 1 question
        ADDI   R2, R8, 42
        CALL   net_put16
        LOADLO R1, 0x0100
        ADDI   R2, R8, 44
        CALL   net_put16
        LOADLO R1, 1
        ADDI   R2, R8, 46
        CALL   net_put16
        STOREB R0, [R8 + 48]
        STOREB R0, [R8 + 49]
        STOREB R0, [R8 + 50]
        STOREB R0, [R8 + 51]
        STOREB R0, [R8 + 52]
        STOREB R0, [R8 + 53]
        ADDI   R9, R8, 54               ; the name as labels
        LOADLO R1, NET_NAME
n_dns_label: ADDI R2, R9, 1             ; R2 = where the letters go, R3 = how many
        LOADLO R3, 0
n_dns_letter: LOADB R4, [R1]
        CMPI   R4, 0x0000
        JZ     n_dns_label_end
        CMPI   R4, 0x002E
        JZ     n_dns_label_end
        STOREB R4, [R2]
        INC    R1
        INC    R2
        INC    R3
        JUMP   n_dns_letter
n_dns_label_end: STOREB R3, [R9]        ; length in front
        MOV    R9, R2
        CMPI   R4, 0x0000
        JZ     n_dns_name_done
        INC    R1                       ; past the '.'
        JUMP   n_dns_label
n_dns_name_done: STOREB R0, [R9]        ; end of the name, then type 1, class 1
        LOADLO R1, 1
        ADDI   R2, R9, 1
        CALL   net_put16
        LOADLO R1, 1
        ADDI   R2, R9, 3
        CALL   net_put16
        ADDI   R9, R9, 5
        SUB    R10, R9, R8              ; R10 = frame length
        SUBI   R10, R10, 42             ; minus 42 = the DNS part
        LOADLO R1, NET_HOP_MAC          ; Ethernet, IP, UDP 53000 -> 53
        LOADLO R2, 0x0800
        CALL   net_eth_header
        ADDI   R1, R10, 28
        LOADLO R2, 17
        LOADLO R3, NET_DNS
        CALL   net_ip_header
        LOADLO R1, 53000
        ADDI   R2, R8, 34
        CALL   net_put16
        LOADLO R1, 53
        ADDI   R2, R8, 36
        CALL   net_put16
        ADDI   R1, R10, 8
        ADDI   R2, R8, 38
        CALL   net_put16
        STOREB R0, [R8 + 40]            ; no UDP checksum
        STOREB R0, [R8 + 41]
        ADDI   R1, R10, 42
        CALL   enc_send
        LOAD   R12, [TIMER]             ; wait 2 seconds for the answer
        ADDI   R12, R12, 200
n_dns_wait: CALL enc_receive
        CMPI   R1, 0x0000
        JZ     n_dns_time
        CALL   net_dns_answer           ; R1 = 1 if it was the answer
        CMPI   R1, 0x0000
        JNZ    n_dns_found
n_dns_time: LOAD R1, [TIMER]
        CMP    R1, R12
        JNC    n_dns_wait
        DEC    R11
        CMPI   R11, 0x0000
        JNZ    n_dns_try
n_dns_fail: LOADLO R1, 0
        JUMP   n_dns_end
n_dns_found: LOADLO R1, 1
n_dns_end: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET
; net_dns_answer, is the frame received the DNS answer? first A record into NET_TARGET
; other frames go to net_answer, in R1 = length, out R1 = 1 address found
; R8 = frame, R9 = pointer through it, R10 = answers left
net_dns_answer: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R1
        LOADHI R8, NET_RECEIVED_HIGH
        ADDI   R1, R8, 12
        CALL   net_get16
        CMPI   R1, 0x0800
        JNZ    n_dnsa_other
        LOADB  R1, [R8 + 23]
        CMPI   R1, 17
        JNZ    n_dnsa_other
        ADDI   R1, R8, 34               ; from port 53
        CALL   net_get16
        CMPI   R1, 53
        JNZ    n_dnsa_other
        ADDI   R1, R8, 36               ; to our port
        CALL   net_get16
        LOADLO R2, 53000
        CMP    R1, R2
        JNZ    n_dnsa_other
        ADDI   R1, R8, 42               ; our id?
        CALL   net_get16
        CMPI   R1, 0x4650
        JNZ    n_dnsa_other
        POP    R1
        LOADB  R1, [R8 + 45]            ; no error? low 4 bits of the flags
        ANDI   R1, R1, 0x000F
        JNZ    n_dnsa_none
        ADDI   R1, R8, 48               ; R10 = number of answers
        CALL   net_get16
        MOV    R10, R1
        ADDI   R1, R8, 54               ; skip the question, its name, type and class
        CALL   net_skip_name
        ADDI   R9, R1, 4
n_dnsa_record: CMPI R10, 0x0000
        JZ     n_dnsa_none
        MOV    R1, R9                   ; record = name, type 2, class 2, TTL 4, length 2, data
        CALL   net_skip_name
        MOV    R9, R1
        CALL   net_get16                ; type
        PUSH   R1
        ADDI   R1, R9, 8                ; length
        CALL   net_get16
        POP    R2
        CMPI   R2, 1
        JNZ    n_dnsa_skip
        CMPI   R1, 4
        JNZ    n_dnsa_skip
        ADDI   R1, R9, 10               ; A record, copy the address
        LOADLO R2, NET_TARGET
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R1, 1
        JUMP   n_dnsa_end
n_dnsa_skip: ADD R9, R9, R1             ; another kind like CNAME, next record
        ADDI   R9, R9, 10
        DEC    R10
        JUMP   n_dnsa_record
n_dnsa_other: POP R1
        CALL   net_answer
n_dnsa_none: LOADLO R1, 0
n_dnsa_end: POP R10
        POP    R9
        POP    R8
        RET
; net_skip_name, skip a name in a DNS message, in R1 = start, out R1 = just after it
; labels up to a 0, or a 2 byte pointer with the top 2 bits set, uses R1, R4
net_skip_name: LOADB R4, [R1]
        CMPI   R4, 0x0000
        JZ     n_skip_zero
        ANDI   R4, R4, 0x00C0
        CMPI   R4, 0x00C0
        JZ     n_skip_pointer
        LOADB  R4, [R1]
        ADD    R1, R1, R4
        INC    R1
        JUMP   net_skip_name
n_skip_zero: INC R1
        RET
n_skip_pointer: ADDI R1, R1, 2
        RET
