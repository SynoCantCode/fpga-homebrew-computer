; HTTP, fetch a page with net_get, leave out its tags with net_page_letter

; net_page_letter, handle one letter of the servers answer, in R1 = letter, uses R1-R7
; status line shown, headers skipped, then the page with tags left out
; p, br, h1, li, div, tr tags give a new line, script and style are skipped
; runs of spaces become one, what is shown also goes into NET_PAGE
net_page_letter: LOAD R2, [NET_PHASE]
        CMPI   R2, 0x0000
        JZ     n_page_status
        CMPI   R2, 1
        JZ     n_page_header
        LOAD   R2, [NET_IN_TAG]         ; the page
        CMPI   R2, 0x0000
        JNZ    n_page_tag
        CMPI   R1, 0x003C               ; '<', a tag starts
        JNZ    n_page_text
        LOADLO R2, 1
        STORE  R2, [NET_IN_TAG]
        STORE  R0, [NET_TAG_LEN]
        STORE  R0, [NET_TAG_TEXT]
        RET
n_page_text: LOAD R2, [NET_SKIPPING]    ; inside script or style, not shown
        CMPI   R2, 0x0000
        JNZ    n_page_done
        CMPI   R1, 0x0021               ; space, tab or line end becomes one space
        JC     n_page_show
        LOAD   R2, [NET_LAST]
        CMPI   R2, 0x0020
        JZ     n_page_done
        CMPI   R2, 0x000A
        JZ     n_page_done
        LOADLO R1, 0x0020
        JUMP   n_page_show
n_page_tag: CMPI R1, 0x003E             ; '>', the tag ends
        JZ     n_page_tag_end
        LOAD   R2, [NET_TAG_LEN]        ; keep its first 4 letters, lowercase
        CMPI   R2, 4
        JNC    n_page_tag_keep
        RET
n_page_tag_keep: CMPI R1, 0x0041
        JNC    n_page_tag_small
        CMPI   R1, 0x005B
        JC     n_page_tag_small
        ORI    R1, R1, 0x0020
n_page_tag_small: LOADLO R3, NET_TAG_TEXT
        ADD    R3, R3, R2
        STOREB R1, [R3]
        INC    R2
        STORE  R2, [NET_TAG_LEN]
        RET
n_page_tag_end: STORE R0, [NET_IN_TAG]
        LOAD   R1, [NET_TAG_TEXT]       ; tags first letters as one word, lowest byte = the first
        LA     R2, tag_script           ; script or style, skip the inside, /script or /style, stop
        LOAD   R3, [R2]
        CMP    R1, R3
        JZ     n_page_skip_on
        LOAD   R3, [R2 + 4]
        CMP    R1, R3
        JZ     n_page_skip_on
        LOAD   R3, [R2 + 8]
        CMP    R1, R3
        JZ     n_page_skip_off
        LOAD   R3, [R2 + 12]
        CMP    R1, R3
        JZ     n_page_skip_off
        ANDI   R2, R1, 0x00FF           ; a tag that breaks the line? first letter, after a '/'
        CMPI   R2, 0x002F
        JNZ    n_page_break_letter
        SHIFTI R1, R1, 0x08, 0b1000
        ANDI   R2, R1, 0x00FF
n_page_break_letter: CMPI R2, 0x0070    ; p
        JZ     n_page_break
        CMPI   R2, 0x0068               ; h, h1-h6 and hr
        JZ     n_page_break
        CMPI   R2, 0x006C               ; l, li
        JZ     n_page_break
        CMPI   R2, 0x0064               ; d, div, dt, dd
        JZ     n_page_break
        CMPI   R2, 0x0074               ; t, tr, title
        JZ     n_page_break
        LOAD   R3, [NET_TAG_TEXT]       ; br
        ANDI   R3, R3, 0xFFFF
        CMPI   R3, 0x7262
        JZ     n_page_break
        RET
n_page_break: LOAD R2, [NET_SKIPPING]
        CMPI   R2, 0x0000
        JNZ    n_page_done
        LOAD   R2, [NET_LAST]
        CMPI   R2, 0x000A
        JZ     n_page_done              ; not two empty lines
        LOADLO R1, 0x000A
        JUMP   n_page_show
n_page_skip_on: LOADLO R1, 1
        STORE  R1, [NET_SKIPPING]
        RET
n_page_skip_off: STORE R0, [NET_SKIPPING]
        RET
n_page_status: CMPI R1, 0x000D          ; status line, shown up to its end
        JZ     n_page_done
        CMPI   R1, 0x000A
        JNZ    n_page_show
        LOADLO R2, 1
        STORE  R2, [NET_PHASE]
        STORE  R0, [NET_LINE_LEN]
        JUMP   n_page_show
n_page_header: CMPI R1, 0x000D          ; headers not shown, an empty line ends them
        JZ     n_page_done
        CMPI   R1, 0x000A
        JZ     n_page_header_end
        LOAD   R2, [NET_LINE_LEN]
        INC    R2
        STORE  R2, [NET_LINE_LEN]
        RET
n_page_header_end: LOAD R2, [NET_LINE_LEN]
        STORE  R0, [NET_LINE_LEN]
        CMPI   R2, 0x0000
        JNZ    n_page_done
        LOADLO R2, 2
        STORE  R2, [NET_PHASE]
        LOADLO R1, 0x000A
        STORE  R1, [NET_LAST]
        RET
n_page_show: STORE R1, [NET_LAST]       ; to the screen and into NET_PAGE, up to 64 KB
        LOAD   R2, [NET_PAGE_SIZE]
        LOADLO R3, 0xFFFF
        CMP    R2, R3
        JC     n_page_full
        LOADHI R3, NET_PAGE_HIGH
        ADD    R3, R3, R2
        STOREB R1, [R3]
        INC    R2
        STORE  R2, [NET_PAGE_SIZE]
n_page_full: JUMPF screen_char
n_page_done: RET

; net get HOST[/PATH], fetch http://HOST/PATH
; DNS, TCP to port 80 with SYN, SYN+ACK, ACK, then the GET request
; segments next in line are shown and ACKed, others get our last ACK again
; ends on FIN, RST, 10 seconds of nothing or Esc, then saves /web.txt
; R8 = pointer to the line, then the requests end, R9 = give up time
; R10 = SYN tries left, then a segments data length
net_get: LOAD R1, [NET_IP]
        CMPI   R1, 0x0000
        JNZ    n_get_ready
        LA     R1, net_listen_first_text
        CALLF  screen_line
        JUMP   net_end
n_get_ready: MOV R1, R8
        CALL   after_word
        CALL   net_take_name            ; the host
        LOADLO R2, NET_PATH             ; the path, "/" if none
        LOADLO R3, 0x002F
        STOREB R3, [R2]
        STOREB R0, [R2 + 1]
        LOADB  R3, [R1]
        CMPI   R3, 0x002F
        JNZ    n_get_path_done
        LOADLO R4, 95
n_get_path: LOADB R3, [R1]
        CMPI   R3, 0x0021
        JNC    n_get_path_end
        CMPI   R4, 0x0000
        JZ     n_get_path_end
        STOREB R3, [R2]
        INC    R1
        INC    R2
        DEC    R4
        JUMP   n_get_path
n_get_path_end: STOREB R0, [R2]
n_get_path_done: LOADB R1, [NET_NAME]
        CMPI   R1, 0x0000
        JNZ    n_get_named
        LA     R1, get_usage_text
        CALLF  screen_line
        JUMP   net_end
n_get_named: CALL net_resolve           ; its address
        CMPI   R1, 0x0000
        JNZ    n_get_found
        LA     R1, dns_none_text
        CALLF  screen_line
        JUMP   net_end
n_get_found: LA R1, get_connecting_text ; "connecting to "
        CALLF  screen_text
        LOADLO R1, NET_TARGET
        CALL   net_print_ip
        LOADLO R1, 0x000A
        CALLF  screen_char
        LOADLO R1, NET_TARGET           ; its MAC, or the routers
        CALL   net_route
        CMPI   R1, 0x0000
        JNZ    n_get_routed
        LA     R1, ping_no_arp_text
        CALLF  screen_line
        JUMP   net_end
n_get_routed: LOAD R1, [TIMER]          ; our port = 49152 + timer bits, first sequence number from the timer
        ANDI   R1, R1, 0x0FFF
        ORI    R1, R1, 0xC000
        STORE  R1, [NET_LOCAL_PORT]
        LOADLO R1, 80
        STORE  R1, [NET_REMOTE_PORT]
        LOAD   R1, [TIMER]
        MULI   R1, R1, 2654
        STORE  R1, [NET_SEQ]
        STORE  R0, [NET_ACK]
        LOADLO R10, 3
n_get_syn: LOADLO R1, 0x0002            ; SYN
        LOADLO R2, 0
        LOADLO R3, 0
        CALL   net_tcp_send
        LOAD   R9, [TIMER]
        ADDI   R9, R9, 200
n_get_syn_wait: CALLF get_char
        CMPI   R1, 0x001B
        JZ     n_get_stopped
        CALL   enc_receive
        CMPI   R1, 0x0000
        JZ     n_get_syn_time
        CALL   net_tcp_frame
        CMPI   R1, 0x0000
        JZ     n_get_syn_time
        ANDI   R5, R1, 0x0004           ; RST, refused
        JNZ    n_get_refused
        ANDI   R5, R1, 0x0012           ; SYN + ACK, their number + 1, ours + 1
        CMPI   R5, 0x0012
        JNZ    n_get_syn_time
        ADDI   R4, R4, 1
        STORE  R4, [NET_ACK]
        LOAD   R1, [NET_SEQ]
        INC    R1
        STORE  R1, [NET_SEQ]
        JUMP   n_get_connected
n_get_syn_time: LOAD R1, [TIMER]
        CMP    R1, R9
        JNC    n_get_syn_wait
        DEC    R10
        CMPI   R10, 0x0000
        JNZ    n_get_syn
        LA     R1, get_no_answer_text
        CALLF  screen_line
        JUMP   net_end
n_get_connected: LOADLO R1, 0x0010      ; ACK, connected
        LOADLO R2, 0
        LOADLO R3, 0
        CALL   net_tcp_send
        LOADHI R8, NET_SENDING_HIGH     ; build the request in NET_REQUEST
        ORI    R8, R8, NET_REQUEST_LOW
        LA     R1, http_get_text        ; "GET "
        MOV    R2, R8
        CALL   copy_text_net
        LOADLO R1, NET_PATH
        CALL   copy_text_net
        LA     R1, http_version_text    ; " HTTP/1.0\r\nHost: "
        CALL   copy_text_net
        LOADLO R1, NET_NAME
        CALL   copy_text_net
        LA     R1, http_end_text        ; "\r\nUser-Agent: ...\r\nConnection: close\r\n\r\n"
        CALL   copy_text_net
        MOV    R3, R2                   ; R3 = its length
        LOADHI R8, NET_SENDING_HIGH
        ORI    R8, R8, NET_REQUEST_LOW
        SUB    R3, R3, R8
        PUSH   R3
        LOADLO R1, 0x0018               ; PSH + ACK with the request
        MOV    R2, R8
        CALL   net_tcp_send
        POP    R3
        LOAD   R1, [NET_SEQ]
        ADD    R1, R1, R3
        STORE  R1, [NET_SEQ]
        STORE  R0, [NET_PHASE]          ; reset the page state for the answer
        STORE  R0, [NET_IN_TAG]
        STORE  R0, [NET_SKIPPING]
        STORE  R0, [NET_PAGE_SIZE]
        LOADLO R1, 0x000A
        STORE  R1, [NET_LAST]
n_get_more: LOAD R9, [TIMER]            ; 10 seconds with nothing, give up
        LOADLO R1, 1000
        ADD    R9, R9, R1
n_get_wait: CALLF get_char
        CMPI   R1, 0x001B
        JZ     n_get_stopped
        CALL   enc_receive
        CMPI   R1, 0x0000
        JZ     n_get_time
        CALL   net_tcp_frame
        CMPI   R1, 0x0000
        JZ     n_get_time
        ANDI   R5, R1, 0x0004
        JNZ    n_get_reset
        PUSH   R1
        LOAD   R5, [NET_ACK]            ; next in line?
        CMP    R4, R5
        JNZ    n_get_out_of_order
        MOV    R10, R3                  ; show its data, R10 = its length
        MOV    R5, R3
n_get_letters: CMPI R5, 0x0000
        JZ     n_get_letters_done
        LOADB  R1, [R2]
        PUSH   R2
        PUSH   R5
        CALL   net_page_letter
        POP    R5
        POP    R2
        INC    R2
        DEC    R5
        JUMP   n_get_letters
n_get_letters_done: LOAD R1, [NET_ACK]
        ADD    R1, R1, R10
        STORE  R1, [NET_ACK]
        POP    R1
        ANDI   R5, R1, 0x0001           ; FIN, they are done
        JNZ    n_get_fin
        LOADLO R1, 0x0010               ; ACK what we have
        LOADLO R2, 0
        LOADLO R3, 0
        CALL   net_tcp_send
        JUMP   n_get_more
n_get_out_of_order: POP R1              ; not next in line, our last ACK again
        LOADLO R1, 0x0010
        LOADLO R2, 0
        LOADLO R3, 0
        CALL   net_tcp_send
        JUMP   n_get_wait
n_get_fin: LOAD R1, [NET_ACK]           ; their FIN counts as one, ACK it and FIN ours
        INC    R1
        STORE  R1, [NET_ACK]
        LOADLO R1, 0x0011
        LOADLO R2, 0
        LOADLO R3, 0
        CALL   net_tcp_send
        LA     R1, get_done_text
        JUMP   n_get_save
n_get_time: LOAD R1, [TIMER]
        CMP    R1, R9
        JNC    n_get_wait
        LA     R1, get_quiet_text
        JUMP   n_get_save
n_get_reset: LA R1, get_reset_text
        JUMP   n_get_save
n_get_stopped: LOADLO R1, 0x0004        ; Esc, send RST
        LOADLO R2, 0
        LOADLO R3, 0
        CALL   net_tcp_send
        LA     R1, get_stopped_text
n_get_save: PUSH R1                     ; save the text so far as /web.txt
        LOADLO R1, 0x000A
        CALLF  screen_char
        POP    R1
        CALLF  screen_text
        LOADLO     R1, NET_FETCH_QUIET        ; called by net_fetch, not saved
        LOAD   R1, [R1]
        CMPI   R1, 0x0000
        JNZ    net_end
        LA     R1, web_file_name
        LOADHI R2, NET_PAGE_HIGH
        LOAD   R3, [NET_PAGE_SIZE]
        CALLF  FILE_WRITE
        LA     R1, get_saved_text
        CALLF  screen_line
        JUMP   net_end
n_get_refused: LA R1, get_refused_text
        CALLF  screen_line
        JUMP   net_end
; copy_text_net, copy a text, in R1 = from, R2 = to, out R2 = at its 0, uses R1-R3
copy_text_net: LOADB R3, [R1]
        STOREB R3, [R2]
        CMPI   R3, 0x0000
        JZ     n_copied
        INC    R1
        INC    R2
        JUMP   copy_text_net
n_copied: RET
