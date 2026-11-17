; network, the Ethernet connection, uses only named pieces
; fills in the texts link, ip, router, mask and note
; init and Refresh, event 2, show net_link, NET_CALLS + 4
; and NET_IP, NET_GATEWAY, NET_MASK as text
; Connect, event 1, net_connect, NET_CALLS + 0, DHCP
; takes a few seconds, then Refresh
; KERNEL.BIN writes its network routines' addresses at NET_CALLS, 0x4A40
; LOAD R5, [NET_CALLS] then CALLR R5
; build and send with send_app.py network
.include "sw/apps/app_defs.asm"
.org APP_BASE
        JUMP   init
        JUMP   tick
        JUMP   key
        JUMP   click
        JUMP   paint
        JUMP   button
        JUMP   close
        .word  0                        ; no ticks

; my texts, the window shows them so they must stay
ip_text:     .word 0                    ; "255.255.255.255" + a 0, 16 bytes each
             .word 0
             .word 0
             .word 0
router_text: .word 0
             .word 0
             .word 0
             .word 0
mask_text:   .word 0
             .word 0
             .word 0
             .word 0

; init, in R1 = window
init:   JUMP   refresh

; button, event 1 Connect, event 2 Refresh. in R1 = window, R2 = event. R8 = window
button: PUSH   R8
        MOV    R8, R1
        CMPI   R2, 1
        JNZ    button_refresh
        LA     R2, note_name            ; "connecting..." while DHCP runs
        LA     R3, connecting_text
        CALLF  WM_SET_TEXT
        LOAD   R5, [NET_CALLS]          ; net_connect, R1 = 1 we have an IP
        CALLR  R5
        LA     R3, connected_text
        CMPI   R1, 0x0000
        JNZ    button_said
        LA     R3, no_router_text
button_said: MOV R1, R8
        LA     R2, note_name
        CALLF  WM_SET_TEXT
button_refresh: MOV R1, R8
        CALL   refresh
        POP    R8
        RET

; refresh, fill in every named text. in R1 = window. R8 = window
refresh: PUSH  R8
        MOV    R8, R1
        LOAD   R5, [NET_CALLS + 4]      ; net_link, R1 = 1 link is up
        CALLR  R5
        LA     R3, link_up_text
        CMPI   R1, 0x0000
        JNZ    refresh_link
        LA     R3, link_down_text
refresh_link: MOV R1, R8
        LA     R2, link_name
        CALLF  WM_SET_TEXT
        LOAD   R1, [NET_IP]             ; an IP yet?
        CMPI   R1, 0x0000
        JNZ    refresh_ip
        MOV    R1, R8
        LA     R2, ip_name
        LA     R3, none_text
        CALLF  WM_SET_TEXT
        JUMP   refresh_done
refresh_ip: LOADLO R1, NET_IP           ; the three addresses as text
        LA     R2, ip_text
        CALL   address_text
        MOV    R1, R8
        LA     R2, ip_name
        LA     R3, ip_text
        CALLF  WM_SET_TEXT
        LOADLO R1, NET_GATEWAY
        LA     R2, router_text
        CALL   address_text
        MOV    R1, R8
        LA     R2, router_name
        LA     R3, router_text
        CALLF  WM_SET_TEXT
        LOADLO R1, NET_MASK
        LA     R2, mask_text
        CALL   address_text
        MOV    R1, R8
        LA     R2, mask_name
        LA     R3, mask_text
        CALLF  WM_SET_TEXT
refresh_done: POP R8
        RET

; address_text, 4 bytes of an address as "10.0.0.5" + a 0
; in R1 = pointer to them, R2 = where. R6 = pointer to the bytes, R7 = bytes left
address_text: MOV R6, R1
        LOADLO R7, 4
address_byte: LOADB R1, [R6]            ; one byte in decimal, R2 = after it
        CALL   number_text
        INC    R6
        DEC    R7
        CMPI   R7, 0x0000
        JZ     address_done
        LOADLO R3, 0x002E               ; '.'
        STOREB R3, [R2]
        INC    R2
        JUMP   address_byte
address_done: RET

; nothing to do
tick:
key:
click:
paint:
close:  RET

link_name:       .string "link"
ip_name:         .string "ip"
router_name:     .string "router"
mask_name:       .string "mask"
note_name:       .string "note"
link_up_text:    .string "connected"
link_down_text:  .string "not connected"
none_text:       .string "none yet"
connecting_text: .string "connecting (a few seconds)..."
connected_text:  .string "connected: we have an IP"
no_router_text:  .string "no answer from the router"

.include "sw/apps/lib/text.asm"       ; number_text
