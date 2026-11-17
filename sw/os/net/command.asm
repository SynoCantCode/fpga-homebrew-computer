; the shells net command and the network texts

;---- the shell's command ----
; command_net, picks the net subcommand, R8 = pointer to what was typed after "net"
command_net: PUSH R8
        MOV    R8, R1
        LOADB  R1, [R8]
        CMPI   R1, 0x0000
        JZ     net_status
        MOV    R1, R8
        LA     R2, net_up_name
        CALL   word_is
        CMPI   R1, 0x0000
        JNZ    net_up
        MOV    R1, R8
        LA     R2, net_listen_name
        CALL   word_is
        CMPI   R1, 0x0000
        JNZ    net_listen
        MOV    R1, R8
        LA     R2, net_ping_name
        CALL   word_is
        CMPI   R1, 0x0000
        JNZ    net_ping
        MOV    R1, R8
        LA     R2, net_get_name
        CALL   word_is
        CMPI   R1, 0x0000
        JNZ    net_get
        MOV    R1, R8
        LA     R2, net_dns_name
        CALL   word_is
        CMPI   R1, 0x0000
        JNZ    net_dns_command
        MOV    R1, R8
        LA     R2, net_time_name
        CALL   word_is
        CMPI   R1, 0x0000
        JNZ    net_time_command
        LA     R1, net_usage_text
        POP    R8
        JUMPF  screen_line

; net, shows the link and our addresses
net_status: CALL net_awake
        CMPI   R1, 0x0000
        JZ     net_end
        LOADLO R1, 0x11                 ; PHSTAT2
        CALL   enc_phy_read
        PUSH   R1
        LA     R1, net_link_text
        CALLF  screen_text
        POP    R1
        ANDI   R1, R1, 0x0400           ; LSTAT, bit 10
        JZ     net_link_down
        LA     R1, net_up_text
        CALLF  screen_line
        JUMP   net_addresses
net_link_down: LA R1, net_down_text
        CALLF  screen_line
net_addresses: LOAD R1, [NET_IP]
        CMPI   R1, 0x0000
        JZ     net_no_ip
        LA     R1, net_ip_text          ; "our IP: "
        CALLF  screen_text
        LOADLO R1, NET_IP
        CALL   net_print_ip
        LA     R1, net_gateway_text     ; "  router: "
        CALLF  screen_text
        LOADLO R1, NET_GATEWAY
        CALL   net_print_ip
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   net_end
net_no_ip: LA R1, net_no_ip_text
        CALLF  screen_line
net_end: POP R8
        RET

; net_awake, check the chip answers and show its revision, bank 3 EREVID 0x12
; first time pulses its RESET low, out R1 = 1 answered, 0 not
net_awake: LOAD R1, [NET_STARTED]
        CMPI   R1, 0x0000
        JNZ    n_awake_ask
        LOADLO R1, 0x0080               ; SPI_SELECT bit 7, hold its RESET low
        STORE  R1, [SPI_SELECT]
        CALL   net_pause
        STORE  R0, [SPI_SELECT]         ; let go, it starts
        CALL   net_pause
n_awake_ask: LOADLO R1, 3               ; bank 3, EREVID
        CALL   enc_bank
        LOADLO R1, 0x12
        CALL   enc_read
        PUSH   R1
        LA     R1, net_text             ; "ENC28J60 revision: 0x"
        CALLF  screen_text
        POP    R1
        PUSH   R1
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        POP    R1
        CMPI   R1, 0x0000
        JZ     n_awake_no
        CMPI   R1, 0x00FF
        JZ     n_awake_no
        LOADLO R1, 1
        RET
n_awake_no: LA R1, net_nothing_text
        CALLF  screen_line
        LOADLO R1, 0
        RET

; net up, start the chip then DHCP
net_up: CALL net_awake
        CMPI   R1, 0x0000
        JZ     net_end
        STORE  R0, [NET_IP]             ; no address until the router gives one
        CALL   enc_start
        LA     R1, net_mac_text         ; "our MAC: 02:46:50:47:41:01"
        CALLF  screen_line
        CALL   net_dhcp
        CMPI   R1, 0x0000
        JZ     net_up_failed
        LA     R1, net_got_text         ; "we have an IP: "
        CALLF  screen_text
        LOADLO R1, NET_IP
        CALL   net_print_ip
        LA     R1, net_mask_text        ; "  mask: "
        CALLF  screen_text
        LOADLO R1, NET_MASK
        CALL   net_print_ip
        LA     R1, net_gateway_text     ; "  router: "
        CALLF  screen_text
        LOADLO R1, NET_GATEWAY
        CALL   net_print_ip
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   net_end
net_up_failed: LA R1, net_no_dhcp_text
        CALLF  screen_line
        JUMP   net_end

; net listen, answer ARP and pings until Esc
net_listen: LOAD R1, [NET_IP]
        CMPI   R1, 0x0000
        JNZ    n_listen_ready
        LA     R1, net_listen_first_text
        CALLF  screen_line
        JUMP   net_end
n_listen_ready: LA R1, net_listening_text
        CALLF  screen_text
        LOADLO R1, NET_IP
        CALL   net_print_ip
        LOADLO R1, 0x000A
        CALLF  screen_char
n_listen_next: CALLF get_char
        CMPI   R1, 0x001B
        JZ     net_end
        CALL   enc_receive
        CMPI   R1, 0x0000
        JZ     n_listen_next
        CALL   net_answer
        JUMP   n_listen_next

net_mac: .byte 0x02, 0x46, 0x50, 0x47, 0x41, 0x01 ; our MAC, 02 = made by hand, 46 50 47 41 = "FPGA"
net_broadcast: .byte 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00 ; everyone, a MAC, or an IP in its first 4
net_up_name: .string "up"
net_listen_name: .string "listen"
net_ping_name: .string "ping"
net_get_name: .string "get"
net_dns_name: .string "dns"
net_google_dns: .byte 8, 8, 8, 8
tag_script: .byte 0x73, 0x63, 0x72, 0x69, 0x73, 0x74, 0x79, 0x6C, 0x2F, 0x73, 0x63, 0x72, 0x2F, 0x73, 0x74, 0x79
dns_none_text: .string "no address for that name (or no answer from the name server)"
dns_is_text: .string " is at "
get_usage_text: .string "use: net get HOST[/PATH]   e.g. net get example.com   (http only, not https)"
get_connecting_text: .string "connecting to "
get_no_answer_text: .string "no answer (port 80): is it an http site?"
get_refused_text: .string "refused (nothing on port 80 there)"
get_done_text: .string "(the end of the page)"
get_quiet_text: .string "(nothing more for 10 seconds)"
get_reset_text: .string "(the server ended the connection: RST)"
get_stopped_text: .string "(stopped)"
get_saved_text: .string "  saved as /web.txt"
web_file_name: .string "/web.txt"
http_get_text: .string "GET "
http_version_text: .string " HTTP/1.0\r\nHost: "
http_end_text: .string "\r\nUser-Agent: FPGA-computer/1 (homemade)\r\nConnection: close\r\n\r\n"
net_zeros: .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
ping_usage_text: .string "use: net ping A.B.C.D   (e.g. net ping 10.0.0.1)"
ping_arp_text: .string "ARP: who has "
ping_no_arp_text: .string "no ARP answer: nobody at that address (or the router) on our network"
ping_reply_text: .string "reply from "
ping_time_text: .string ": time="
ping_ms_text: .string " ms"
ping_none_text: .string "no reply (1 second)"
net_usage_text: .string "use: net   net up   net listen   net ping NAME   net dns NAME   net get HOST[/PATH]   net time"
net_text: .string "ENC28J60 revision: 0x"
net_nothing_text: .string "  (no answer: the Ethernet module wired? powered? pins 56 SCK, 54 SI, 51 SO, 48 CS, 49 RESET)"
net_link_text: .string "link: "
net_up_text: .string "up (the cable is connected at the other end)"
net_down_text: .string "down (no cable, or nothing at its other end)"
net_ip_text: .string "our IP: "
net_gateway_text: .string "  router: "
net_mask_text: .string "  mask: "
net_no_ip_text: .string "no IP yet: net up asks the router for one"
net_mac_text: .string "our MAC: 02:46:50:47:41:01"
dhcp_discover_text: .string "DHCP: DISCOVER (anyone have an address for us?)"
dhcp_offer_text: .string "DHCP: offered "
net_got_text: .string "we have an IP: "
net_no_dhcp_text: .string "no answer from a DHCP server (the router): is the cable in its LAN port?"
net_listen_first_text: .string "no IP yet: net up first"
net_listening_text: .string "listening (Esc stops) as "
arp_text: .string "ARP: told "
arp_text_2: .string " where we are"
ping_text: .string "ping from "
ping_text_2: .string ": answered"
