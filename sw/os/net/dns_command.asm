; the shells net dns NAME

; net dns NAME, shows its address
net_dns_command: MOV R1, R8
        CALL   after_word
        CALL   net_take_name
        LOAD   R1, [NET_IP]
        CMPI   R1, 0x0000
        JNZ    n_dnsc_ready
        LA     R1, net_listen_first_text
        CALLF  screen_line
        JUMP   net_end
n_dnsc_ready: CALL net_resolve
        CMPI   R1, 0x0000
        JNZ    n_dnsc_found
        LA     R1, dns_none_text
        CALLF  screen_line
        JUMP   net_end
n_dnsc_found: LOADLO R1, NET_NAME
        CALLF  screen_text
        LA     R1, dns_is_text          ; " is at "
        CALLF  screen_text
        LOADLO R1, NET_TARGET
        CALL   net_print_ip
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   net_end
