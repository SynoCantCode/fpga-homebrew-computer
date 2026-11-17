; NET_CALLS for programs, net_connect, net_link, net_fetch

;---- for programs (apps): NET_CALLS ----
; net_connect, start the chip and run DHCP, out R1 = 1 we have an IP
; net_link, out R1 = 1 link is up, 0 down or no chip
net_connect: PUSH R8
        STORE  R0, [NET_IP]
        CALL   net_awake
        CMPI   R1, 0x0000
        JZ     n_connect_end
        CALL   enc_start
        CALL   net_dhcp
n_connect_end: POP R8
        RET
net_link: LOADLO R1, 3                  ; chip there? EREVID
        CALL   enc_bank
        LOADLO R1, 0x12
        CALL   enc_read
        CMPI   R1, 0x0000
        JZ     n_link_no
        CMPI   R1, 0x00FF
        JZ     n_link_no
        LOADLO R1, 0x11
        CALL   enc_phy_read
        ANDI   R1, R1, 0x0400
        JZ     n_link_no
        LOADLO R1, 1
        RET
n_link_no: LOADLO R1, 0
        RET

; net_fetch, NET_CALLS + 16, fetch a web page for a program
; in R1 = pointer to "HOST/PATH", out R1 = bytes of text or 0, R2 = NET_PAGE
; text without tags lands in NET_PAGE, up to 64 KB, not saved as /web.txt
; runs net_connect first if there is no IP
; R8-R13 kept, R9 = the address asked for
net_fetch: PUSH R8                      ; net get uses R8-R12 freely, keep them
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        MOV    R9, R1
        STORE  R0, [NET_PAGE_SIZE]      ; 0 so a failed fetch does not give the last size
        LOAD   R1, [NET_IP]             ; have an IP? else ask the router
        CMPI   R1, 0x0000
        JNZ    n_fetch_ready
        CALL   net_connect
n_fetch_ready: LA R1, n_fetch_word       ; build the line net get expects, "get " then the address
        LOADLO     R2, NET_FETCH_LINE
        CALL   copy_text_net
        MOV    R1, R9
        CALL   copy_text_net
        LOADLO     R1, NET_FETCH_QUIET        ; tell net get not to save /web.txt
        LOADLO R2, 1
        STORE  R2, [R1]
        LOADLO     R1, NET_FETCH_LINE
        CALL   n_fetch_get
        LOADLO     R1, NET_FETCH_QUIET
        STORE  R0, [R1]
        LOAD   R1, [NET_PAGE_SIZE]
        LOADHI R2, NET_PAGE_HIGH
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET
n_fetch_get: PUSH R8                    ; net get ends with net_end, POP R8 and RET
        MOV    R8, R1
        JUMP   net_get
n_fetch_word: .string "get "
; NET_FETCH_LINE and NET_FETCH_QUIET are in RAM
