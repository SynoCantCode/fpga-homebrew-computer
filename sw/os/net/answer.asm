; answering others, ARP requests and pings

;---- answering: ARP and ping ----
; net_answer, answer an ARP request or a ping for our IP, shows what it answered
; in R1 = length of the frame received, out R1 = 1 if answered
; R8 = frame received, R9 = frame sent, R10 = length
net_answer: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R10, R1
        LOADHI R8, NET_RECEIVED_HIGH
        LOADHI R9, NET_SENDING_HIGH
        ORI    R9, R9, NET_SENDING_LOW
        ADDI   R1, R8, 12
        CALL   net_get16
        CMPI   R1, 0x0806
        JZ     n_answer_arp
        CMPI   R1, 0x0800
        JZ     n_answer_ip
        JUMP   n_answer_none
n_answer_arp: ADDI R1, R8, 20           ; ARP op 1, a request?
        CALL   net_get16
        CMPI   R1, 1
        JNZ    n_answer_none
        ADDI   R1, R8, 38               ; for our IP?
        LOADLO R2, NET_IP
        LOADLO R3, 4
        CALL   net_same
        CMPI   R1, 0x0000
        JZ     n_answer_none
        ADDI   R1, R8, 22               ; reply goes back to the askers MAC, ARP inside
        LOADLO R2, 0x0806
        CALL   net_eth_header
        ADDI   R1, R8, 14               ; same first 6 ARP bytes
        ADDI   R2, R9, 14
        LOADLO R3, 6
        CALL   net_copy
        LOADLO R1, 2                    ; op 2, a reply
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
        ADDI   R1, R8, 22               ; target = the asker, MAC and IP
        ADDI   R2, R9, 32
        LOADLO R3, 10
        CALL   net_copy
        LOADLO R1, 60                   ; shortest frame, 60
        CALL   enc_send
        LA     R1, arp_text             ; "ARP: told "
        CALLF  screen_text
        ADDI   R1, R8, 28
        CALL   net_print_ip
        LA     R1, arp_text_2           ; " where we are"
        CALLF  screen_line
        JUMP   n_answer_yes
n_answer_ip: LOADB R1, [R8 + 14]        ; IP with a 20 byte header, ICMP, to us, type 8 echo request?
        CMPI   R1, 0x0045
        JNZ    n_answer_none
        LOADB  R1, [R8 + 23]
        CMPI   R1, 1
        JNZ    n_answer_none
        ADDI   R1, R8, 30
        LOADLO R2, NET_IP
        LOADLO R3, 4
        CALL   net_same
        CMPI   R1, 0x0000
        JZ     n_answer_none
        LOADB  R1, [R8 + 34]
        CMPI   R1, 8
        JNZ    n_answer_none
        MOV    R1, R8                   ; reply is the same frame
        MOV    R2, R9
        MOV    R3, R10
        CALL   net_copy
        ADDI   R1, R8, 6                ; Ethernet, back to the sender, from us
        MOV    R2, R9
        LOADLO R3, 6
        CALL   net_copy
        LA     R1, net_mac
        ADDI   R2, R9, 6
        LOADLO R3, 6
        CALL   net_copy
        ADDI   R1, R8, 26               ; IP, to the sender, from us, TTL 64, new checksum
        ADDI   R2, R9, 30
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R1, NET_IP
        ADDI   R2, R9, 26
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R1, 64
        STOREB R1, [R9 + 22]
        STOREB R0, [R9 + 24]
        STOREB R0, [R9 + 25]
        ADDI   R1, R9, 14
        LOADLO R2, 20
        CALL   net_checksum
        ADDI   R2, R9, 24
        CALL   net_put16
        STOREB R0, [R9 + 34]            ; ICMP type 0 reply, new checksum
        STOREB R0, [R9 + 36]
        STOREB R0, [R9 + 37]
        ADDI   R1, R9, 16               ; ICMP length = IP total - 20
        CALL   net_get16
        SUBI   R2, R1, 20
        ADDI   R1, R9, 34
        CALL   net_checksum
        ADDI   R2, R9, 36
        CALL   net_put16
        MOV    R1, R10
        CALL   enc_send
        LA     R1, ping_text            ; "ping from "
        CALLF  screen_text
        ADDI   R1, R8, 26
        CALL   net_print_ip
        LA     R1, ping_text_2          ; ": answered"
        CALLF  screen_line
n_answer_yes: LOADLO R1, 1
        JUMP   n_answer_end
n_answer_none: LOADLO R1, 0
n_answer_end: POP R10
        POP    R9
        POP    R8
        RET
