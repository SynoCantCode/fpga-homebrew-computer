; DHCP, get an IP address from the router

;---- DHCP: an IP address from the router ----
; dhcp_build, build a DHCP message in NET_SENDING, sent to everyone
; UDP from 0.0.0.0 port 68 to port 67
; options 53 type, 50 address offered, 54 server, 55 what we want, 255 end
; in R1 = type, 1 DISCOVER, 3 REQUEST
; R8 = type, R9 = message at NET_SENDING + 42, R10 = pointer into the options
dhcp_build: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R8, R1
        LOADHI R9, NET_SENDING_HIGH     ; clear everything first
        ORI    R9, R9, NET_SENDING_LOW
        LOADLO R10, DHCP_SIZE
n_dhcp_clear: STOREB R0, [R9]
        INC    R9
        DEC    R10
        CMPI   R10, 0x0000
        JNZ    n_dhcp_clear
        LA     R1, net_broadcast        ; Ethernet to everyone, IP inside
        LOADLO R2, 0x0800
        CALL   net_eth_header
        LOADLO R1, DHCP_SIZE - 14       ; IP with UDP inside, to 255.255.255.255 from 0.0.0.0
        LOADLO R2, 17
        LA     R3, net_broadcast
        CALL   net_ip_header
        LOADHI R9, NET_SENDING_HIGH     ; UDP 68 -> 67 and its length
        ORI    R9, R9, NET_SENDING_LOW + 34
        LOADLO R1, 68
        MOV    R2, R9
        CALL   net_put16
        LOADLO R1, 67
        ADDI   R2, R9, 2
        CALL   net_put16
        LOADLO R1, DHCP_SIZE - 34
        ADDI   R2, R9, 4
        CALL   net_put16
        ADDI   R9, R9, 8                ; the DHCP message
        LOADLO R1, 1                    ; op 1 request, htype 1 Ethernet, hlen 6
        STOREB R1, [R9]
        STOREB R1, [R9 + 1]
        LOADLO R1, 6
        STOREB R1, [R9 + 2]
        LOADLO R1, NET_XID              ; xid, our number for this exchange
        ADDI   R2, R9, 4
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R1, 0x0080               ; flags, broadcast your answer
        STOREB R1, [R9 + 10]
        LA     R1, net_mac              ; chaddr, our MAC
        ADDI   R2, R9, 28
        LOADLO R3, 6
        CALL   net_copy
        LOADLO R1, 0x0063               ; magic cookie 63 82 53 63
        STOREB R1, [R9 + 236]
        LOADLO R1, 0x0082
        STOREB R1, [R9 + 237]
        LOADLO R1, 0x0053
        STOREB R1, [R9 + 238]
        LOADLO R1, 0x0063
        STOREB R1, [R9 + 239]
        ADDI   R10, R9, 240             ; the options
        LOADLO R1, 53                   ; 53, the message type
        STOREB R1, [R10]
        LOADLO R1, 1
        STOREB R1, [R10 + 1]
        STOREB R8, [R10 + 2]
        ADDI   R10, R10, 3
        CMPI   R8, 3
        JNZ    n_dhcp_wishes
        LOADLO R1, 50                   ; REQUEST only, 50 = the address offered
        STOREB R1, [R10]
        LOADLO R1, 4
        STOREB R1, [R10 + 1]
        LOADLO R1, NET_OFFER
        ADDI   R2, R10, 2
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R1, 54                   ; 54 = the server that offered it
        STOREB R1, [R10 + 6]
        LOADLO R1, 4
        STOREB R1, [R10 + 7]
        LOADLO R1, NET_SERVER
        ADDI   R2, R10, 8
        LOADLO R3, 4
        CALL   net_copy
        ADDI   R10, R10, 12
n_dhcp_wishes: LOADLO R1, 55            ; 55, ask for 1 mask, 3 router, 6 DNS
        STOREB R1, [R10]
        LOADLO R1, 3
        STOREB R1, [R10 + 1]
        LOADLO R1, 1
        STOREB R1, [R10 + 2]
        LOADLO R1, 3
        STOREB R1, [R10 + 3]
        LOADLO R1, 6
        STOREB R1, [R10 + 4]
        LOADLO R1, 255                  ; the end
        STOREB R1, [R10 + 5]
        POP    R10
        POP    R9
        POP    R8
        RET

; dhcp_check, is the frame in NET_RECEIVED the DHCP answer we wait for?
; needs IP, 20 byte header, UDP, port 68, op 2, our xid, option 53 = type wanted
; keeps 54 in NET_SERVER, 1 mask, 3 router, 6 DNS, yiaddr in NET_OFFER
; in R1 = length, R2 = type wanted, 2 OFFER, 5 ACK, out R1 = 1 yes, 0 no
; R8 = frame, R9 = type wanted, R10 = options pointer, R11 = frame end, R12 = type found
dhcp_check: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        LOADHI R8, NET_RECEIVED_HIGH
        MOV    R9, R2
        ADD    R11, R8, R1
        CMPI   R1, 282
        JNC    n_check_no               ; too short
        ADDI   R1, R8, 12               ; Ethernet type 0x0800?
        CALL   net_get16
        CMPI   R1, 0x0800
        JNZ    n_check_no
        LOADB  R1, [R8 + 14]            ; IP, 20 byte header?
        CMPI   R1, 0x0045
        JNZ    n_check_no
        LOADB  R1, [R8 + 23]            ; UDP?
        CMPI   R1, 17
        JNZ    n_check_no
        ADDI   R1, R8, 36               ; to port 68?
        CALL   net_get16
        CMPI   R1, 68
        JNZ    n_check_no
        LOADB  R1, [R8 + 42]            ; op 2, a reply
        CMPI   R1, 2
        JNZ    n_check_no
        ADDI   R1, R8, 46               ; our xid?
        LOADLO R2, NET_XID
        LOADLO R3, 4
        CALL   net_same
        CMPI   R1, 0x0000
        JZ     n_check_no
        ADDI   R1, R8, 58               ; yiaddr, the address offered
        LOADLO R2, NET_OFFER
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R12, 0
        ADDI   R10, R8, 282             ; options start after the cookie
n_check_option: CMP R10, R11
        JC     n_check_options_done     ; end of the frame
        LOADB  R1, [R10]
        CMPI   R1, 255
        JZ     n_check_options_done
        CMPI   R1, 0x0000               ; 0 = padding, one byte
        JNZ    n_check_option_real
        INC    R10
        JUMP   n_check_option
n_check_option_real: LOADB R2, [R10 + 1] ; R1 = code, R2 = length, value at R10 + 2
        CMPI   R1, 53
        JNZ    n_check_not_type
        LOADB  R12, [R10 + 2]
n_check_not_type: LOADLO R3, NET_SERVER
        CMPI   R1, 54
        JZ     n_check_keep
        LOADLO R3, NET_MASK
        CMPI   R1, 1
        JZ     n_check_keep
        LOADLO R3, NET_GATEWAY
        CMPI   R1, 3
        JZ     n_check_keep
        LOADLO R3, NET_DNS
        CMPI   R1, 6
        JNZ    n_check_next
n_check_keep: PUSH R2                   ; its first 4 bytes
        ADDI   R1, R10, 2
        MOV    R2, R3
        LOADLO R3, 4
        CALL   net_copy
        POP    R2
n_check_next: ADD R10, R10, R2
        ADDI   R10, R10, 2
        JUMP   n_check_option
n_check_options_done: CMP R12, R9
        JNZ    n_check_no
        LOADLO R1, 1
        JUMP   n_check_end
n_check_no: LOADLO R1, 0
n_check_end: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; dhcp_wait, receive frames for up to 2 seconds until the wanted DHCP answer
; in R1 = type wanted, out R1 = 1 got it, 0 not, R8 = type, R9 = give up time
dhcp_wait: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOAD   R9, [TIMER]
        ADDI   R9, R9, 200
n_wait_frame: CALL enc_receive
        CMPI   R1, 0x0000
        JZ     n_wait_time
        MOV    R2, R8
        CALL   dhcp_check
        CMPI   R1, 0x0000
        JNZ    n_wait_end
n_wait_time: LOAD R1, [TIMER]
        CMP    R1, R9
        JNC    n_wait_frame             ; time left
        LOADLO R1, 0
n_wait_end: POP R9
        POP    R8
        RET

; net_dhcp, DISCOVER, OFFER, REQUEST, ACK, then NET_IP is ours, 4 tries
; out R1 = 1 we have an address, 0 no answer, R8 = tries left
net_dhcp: PUSH R8
        LOADLO R8, 4
        LOAD   R1, [TIMER]              ; xid from the timer, mixed
        LOADLO R2, 0x4650
        MUL    R1, R1, R2
        STORE  R1, [NET_XID]
n_dhcp_try: LA R1, dhcp_discover_text
        CALLF  screen_line
        LOADLO R1, 1                    ; DISCOVER
        CALL   dhcp_build
        LOADLO R1, DHCP_SIZE
        CALL   enc_send
        LOADLO R1, 2                    ; an OFFER?
        CALL   dhcp_wait
        CMPI   R1, 0x0000
        JZ     n_dhcp_again
        LA     R1, dhcp_offer_text
        CALLF  screen_text
        LOADLO R1, NET_OFFER
        CALL   net_print_ip
        LOADLO R1, 0x000A
        CALLF  screen_char
        LOADLO R1, 3                    ; REQUEST it
        CALL   dhcp_build
        LOADLO R1, DHCP_SIZE
        CALL   enc_send
        LOADLO R1, 5                    ; the ACK?
        CALL   dhcp_wait
        CMPI   R1, 0x0000
        JZ     n_dhcp_again
        LOADLO R1, NET_OFFER            ; the address is ours
        LOADLO R2, NET_IP
        LOADLO R3, 4
        CALL   net_copy
        LOADLO R1, 1
        JUMP   n_dhcp_end
n_dhcp_again: DEC R8
        CMPI   R8, 0x0000
        JNZ    n_dhcp_try
        LOADLO R1, 0
n_dhcp_end: POP R8
        RET
