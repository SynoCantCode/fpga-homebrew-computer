; 32 bit numbers in packets, routing, host names

;---- names, TCP and the web ----
; net_put32, 32 bit number big endian, in R1 = number, R2 = where
; net_get32, in R1 = where, out R1 = number, both use R4, R5
net_put32: SHIFTI R4, R1, 0x18, 0b1000
        STOREB R4, [R2]
        SHIFTI R4, R1, 0x10, 0b1000
        STOREB R4, [R2 + 1]
        SHIFTI R4, R1, 0x08, 0b1000
        STOREB R4, [R2 + 2]
        STOREB R1, [R2 + 3]
        RET
net_get32: LOADB R4, [R1]
        SHIFTI R4, R4, 0x18, 0b0000
        LOADB  R5, [R1 + 1]
        SHIFTI R5, R5, 0x10, 0b0000
        OR     R4, R4, R5
        LOADB  R5, [R1 + 2]
        SHIFTI R5, R5, 0x08, 0b0000
        OR     R4, R4, R5
        LOADB  R5, [R1 + 3]
        OR     R1, R4, R5
        RET

; net_route, pick the next hop and get its MAC by ARP into NET_HOP_MAC
; next hop = the address if on our network, else the router
; in R1 = pointer to the 4 byte address, out R1 = 1 ready, 0 no ARP answer, uses R1-R7
net_route: LOAD R1, [R1]
        LOAD   R2, [NET_MASK]
        AND    R3, R1, R2
        LOAD   R4, [NET_IP]
        AND    R4, R4, R2
        CMP    R3, R4
        JZ     n_route_hop
        LOAD   R1, [NET_GATEWAY]
n_route_hop: STORE R1, [NET_HOP]
        JUMP   net_arp_ask

; net_take_name, name from a typed line into NET_NAME, 63 letters max
; stops at a space, '/' or the end, in R1 = pointer, out R1 = where it stopped, uses R1-R4
net_take_name: LOADLO R2, NET_NAME
        LOADLO R3, 63
n_take_next: LOADB R4, [R1]
        CMPI   R4, 0x0021
        JNC    n_take_end               ; space or the end
        CMPI   R4, 0x002F
        JZ     n_take_end               ; '/', the path starts
        CMPI   R3, 0x0000
        JZ     n_take_end
        STOREB R4, [R2]
        INC    R1
        INC    R2
        DEC    R3
        JUMP   n_take_next
n_take_end: STOREB R0, [R2]
        RET
