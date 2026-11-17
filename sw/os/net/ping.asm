; ping, ARP for the next hop and ICMP echo

;---- ping: "are you there?" ----
; net_parse_ip, text like "10.0.0.1" into 4 bytes
; in R1 = pointer to the text, R2 = where the bytes go, out R1 = 1 ok, 0 not
; R8 = text pointer, R9 = where, R10 = number so far, R11 = parts done
net_parse_ip: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R8, R1
        MOV    R9, R2
        LOADLO R11, 0
n_parse_part: LOADLO R10, 0
        LOADLO R6, 0                    ; R6 = digits in this part
n_parse_digit: LOADB R1, [R8]
        SUBI   R1, R1, 0x0030           ; '0'-'9' to 0-9, anything else is huge
        CMPI   R1, 10
        JC     n_parse_end_part
        MULI   R10, R10, 10
        ADD    R10, R10, R1
        INC    R8
        INC    R6
        JUMP   n_parse_digit
n_parse_end_part: CMPI R6, 0x0000
        JZ     n_parse_no               ; no digits
        CMPI   R10, 256
        JC     n_parse_no               ; more than 255
        STOREB R10, [R9]
        INC    R9
        INC    R11
        CMPI   R11, 4
        JZ     n_parse_last
        LOADB  R1, [R8]                 ; '.' between the parts
        CMPI   R1, 0x002E
        JNZ    n_parse_no
        INC    R8
        JUMP   n_parse_part
n_parse_last: LOADB R1, [R8]            ; after the 4th, the word must end
        CMPI   R1, 0x0021
        JC     n_parse_no
        LOADLO R1, 1
        JUMP   n_parse_done
n_parse_no: LOADLO R1, 0
n_parse_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; net_arp_ask, find the MAC of NET_HOP with an ARP request to everyone
; waits up to 1 second for the reply, its MAC goes into NET_HOP_MAC
; out R1 = 1 found, 0 not, R8 = give up time, R9 = frame sent
net_arp_ask: PUSH R8
        PUSH   R9
        LA     R1, net_broadcast        ; Ethernet to everyone, ARP inside
        LOADLO R2, 0x0806
        CALL   net_eth_header
        LOADHI R9, NET_SENDING_HIGH
        ORI    R9, R9, NET_SENDING_LOW
        LOADLO R1, 1                    ; ARP, Ethernet 1, IP 0x0800, MAC is 6, IP is 4, op 1 request
        ADDI   R2, R9, 14
        CALL   net_put16
        LOADLO R1, 0x0800
        ADDI   R2, R9, 16
        CALL   net_put16
        LOADLO R1, 6
        STOREB R1, [R9 + 18]
        LOADLO R1, 4
        STOREB R1, [R9 + 19]
        LOADLO R1, 1
        ADDI   R2, R9, 20
        CALL   net_put16
        LA     R1, net_mac              ; sender = us
        ADDI   R2, R9, 22
        LOADLO R3, 6
        CALL   net_copy
        LOADLO R1, NET_IP
        ADDI   R2, R9, 28
        LOADLO R3, 4
        CALL   net_copy
        LA     R1, net_zeros            ; target, MAC unknown so zeros, then its IP
        ADDI   R2, R9, 32
        LOADLO R3, 6
        CALL   net_copy
        LOADLO R1, NET_HOP
        ADDI   R2, R9, 38
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R1, 60
        CALL   enc_send
        LOAD   R8, [TIMER]              ; wait a second for the reply
        ADDI   R8, R8, 100
n_arp_wait: CALL enc_receive
        CMPI   R1, 0x0000
        JZ     n_arp_time
        CALL   net_arp_reply_check      ; R1 = 1 if it is the reply
        CMPI   R1, 0x0000
        JNZ    n_arp_found
n_arp_time: LOAD R1, [TIMER]
        CMP    R1, R8
        JNC    n_arp_wait
        LOADLO R1, 0
        JUMP   n_arp_end
n_arp_found: LOADLO R1, 1
n_arp_end: POP R9
        POP    R8
        RET
; net_arp_reply_check, is the frame received the ARP reply from NET_HOP? MAC into NET_HOP_MAC
; other frames go to net_answer, in R1 = length, out R1 = 1 it was the reply, R8 = frame
net_arp_reply_check: PUSH R8
        PUSH   R1
        LOADHI R8, NET_RECEIVED_HIGH
        ADDI   R1, R8, 12
        CALL   net_get16
        CMPI   R1, 0x0806
        JNZ    n_reply_other
        ADDI   R1, R8, 20               ; op 2, a reply
        CALL   net_get16
        CMPI   R1, 2
        JNZ    n_reply_other
        ADDI   R1, R8, 28               ; from NET_HOP?
        LOADLO R2, NET_HOP
        LOADLO R3, 4
        CALL   net_same
        CMPI   R1, 0x0000
        JZ     n_reply_other
        ADDI   R1, R8, 22               ; its MAC
        LOADLO R2, NET_HOP_MAC
        LOADLO R3, 6
        CALL   net_copy
        POP    R1
        LOADLO R1, 1
        JUMP   n_reply_end
n_reply_other: POP R1                   ; not it, answer as usual
        CALL   net_answer
        LOADLO R1, 0
n_reply_end: POP R8
        RET

; net_ping_one, one ICMP echo request to NET_TARGET, waits a second for the reply
; shows "reply from A.B.C.D: time=N ms" or "no reply", in R1 = sequence number
; R8 = frame, R9 = time sent, R10 = give up time
net_ping_one: PUSH R8
        PUSH   R9
        PUSH   R10
        STORE  R1, [NET_SEQUENCE]
        LOADLO R1, NET_HOP_MAC          ; Ethernet to the next hops MAC, IP inside
        LOADLO R2, 0x0800
        CALL   net_eth_header
        LOADLO R1, 60                   ; IP, 20 + ICMP 8 + 32 data bytes, protocol 1
        LOADLO R2, 1
        LOADLO R3, NET_TARGET
        CALL   net_ip_header
        LOADHI R8, NET_SENDING_HIGH     ; ICMP at 34, type 8 echo request, code 0, checksum, id, number
        ORI    R8, R8, NET_SENDING_LOW
        LOADLO R1, 8
        STOREB R1, [R8 + 34]
        STOREB R0, [R8 + 35]
        STOREB R0, [R8 + 36]
        STOREB R0, [R8 + 37]
        LOADLO R1, 0x4650               ; the id, "FP"
        ADDI   R2, R8, 38
        CALL   net_put16
        LOAD   R1, [NET_SEQUENCE]
        ADDI   R2, R8, 40
        CALL   net_put16
        LOADLO R1, 0x0061               ; 32 data bytes, a to w repeating
        ADDI   R2, R8, 42
        LOADLO R3, 32
n_ping_data: STOREB R1, [R2]
        INC    R1
        CMPI   R1, 0x0078
        JNZ    n_ping_letter
        LOADLO R1, 0x0061
n_ping_letter: INC R2
        DEC    R3
        CMPI   R3, 0x0000
        JNZ    n_ping_data
        ADDI   R1, R8, 34               ; checksum over the 40 ICMP bytes
        LOADLO R2, 40
        CALL   net_checksum
        ADDI   R2, R8, 36
        CALL   net_put16
        LOAD   R9, [TIMER]              ; time sent
        LOADLO R1, 74
        CALL   enc_send
        ADDI   R10, R9, 100             ; wait a second for the reply
n_ping_wait: CALL enc_receive
        CMPI   R1, 0x0000
        JZ     n_ping_time
        CALL   net_ping_reply_check     ; R1 = 1 if it is our reply
        CMPI   R1, 0x0000
        JNZ    n_ping_got
n_ping_time: LOAD R1, [TIMER]
        CMP    R1, R10
        JNC    n_ping_wait
        LA     R1, ping_none_text       ; "no reply (1 second)"
        CALLF  screen_line
        JUMP   n_ping_end
n_ping_got: LOAD R10, [TIMER]           ; time taken, ticks x 10 = ms
        SUB    R10, R10, R9
        MULI   R10, R10, 10
        LA     R1, ping_reply_text      ; "reply from "
        CALLF  screen_text
        LOADLO R1, NET_TARGET
        CALL   net_print_ip
        LA     R1, ping_time_text       ; ": time="
        CALLF  screen_text
        MOV    R1, R10
        CALL   screen_decimal
        LA     R1, ping_ms_text         ; " ms"
        CALLF  screen_line
n_ping_end: POP R10
        POP    R9
        POP    R8
        RET
; net_ping_reply_check, is the frame received our echo reply?
; other frames go to net_answer, in R1 = length, out R1 = 1 it is ours, R8 = frame
net_ping_reply_check: PUSH R8
        PUSH   R1
        LOADHI R8, NET_RECEIVED_HIGH
        ADDI   R1, R8, 12
        CALL   net_get16
        CMPI   R1, 0x0800
        JNZ    n_ping_other
        LOADB  R1, [R8 + 23]            ; ICMP?
        CMPI   R1, 1
        JNZ    n_ping_other
        LOADB  R1, [R8 + 34]            ; type 0, an echo reply
        CMPI   R1, 0x0000
        JNZ    n_ping_other
        ADDI   R1, R8, 26               ; from the target?
        LOADLO R2, NET_TARGET
        LOADLO R3, 4
        CALL   net_same
        CMPI   R1, 0x0000
        JZ     n_ping_other
        ADDI   R1, R8, 40               ; our number?
        CALL   net_get16
        LOAD   R2, [NET_SEQUENCE]
        CMP    R1, R2
        JNZ    n_ping_other
        POP    R1
        LOADLO R1, 1
        JUMP   n_ping_check_end
n_ping_other: POP R1
        CALL   net_answer
        LOADLO R1, 0
n_ping_check_end: POP R8
        RET

; net ping NAME or A.B.C.D, resolve it, ARP for the next hop, then 4 echo requests
; next hop = the target if on our network, else the router
; R8 = pointer to the address typed, R9 = request count
net_ping: LOAD R1, [NET_IP]
        CMPI   R1, 0x0000
        JNZ    n_ping_ready
        LA     R1, net_listen_first_text ; "no IP yet: net up first"
        CALLF  screen_line
        JUMP   net_end
n_ping_ready: MOV R1, R8
        CALL   after_word               ; the address or name after "ping"
        CALL   net_take_name
        LOADB  R1, [NET_NAME]
        CMPI   R1, 0x0000
        JNZ    n_ping_named
        LA     R1, ping_usage_text
        CALLF  screen_line
        JUMP   net_end
n_ping_named: CALL net_resolve
        CMPI   R1, 0x0000
        JNZ    n_ping_parsed
        LA     R1, dns_none_text
        CALLF  screen_line
        JUMP   net_end
n_ping_parsed: LOAD R1, [NET_TARGET]    ; on our network? target AND mask = our IP AND mask
        LOAD   R2, [NET_MASK]
        AND    R1, R1, R2
        LOAD   R3, [NET_IP]
        AND    R3, R3, R2
        LOAD   R4, [NET_TARGET]         ; yes, straight to the target
        CMP    R1, R3
        JZ     n_ping_hop
        LOAD   R4, [NET_GATEWAY]        ; no, to the router
n_ping_hop: STORE R4, [NET_HOP]
        LA     R1, ping_arp_text        ; "ARP: who has "
        CALLF  screen_text
        LOADLO R1, NET_HOP
        CALL   net_print_ip
        LOADLO R1, 0x003F               ; '?'
        CALLF  screen_char
        LOADLO R1, 0x000A
        CALLF  screen_char
        CALL   net_arp_ask
        CMPI   R1, 0x0000
        JNZ    n_ping_send
        LA     R1, ping_no_arp_text
        CALLF  screen_line
        JUMP   net_end
n_ping_send: LOADLO R9, 1
n_ping_next: MOV R1, R9
        CALL   net_ping_one
        INC    R9
        CMPI   R9, 5
        JNZ    n_ping_next
        JUMP   net_end
