; net.asm, networking, part of KERNEL.BIN
; ENC28J60 Ethernet chip on SPI_SELECT bit 1
; net          chip revision, link, our addresses
; net up       start the chip, then DHCP
; net listen   answer ARP and ping until Esc
; net ping NAME      4 echo requests, timed
; net dns NAME       its address
; net get HOST/PATH  a web page, http only, on the screen and in /web.txt
;
; the layers, every number is big-endian
; Ethernet  14 bytes, to MAC (6), from MAC (6), type (2), 0x0800 IP, 0x0806 ARP
; IP        20 bytes, 0x45, TOS, total length (2), id (2), flags (2), TTL,
; protocol (1 ICMP, 17 UDP), header checksum (2), from IP (4), to IP (4)
; UDP       8 bytes, from port, to port, length, checksum (0 = none)
; ICMP      type 8 request, 0 reply, code, checksum, then the echoed data
; ARP       28 bytes, 1 = who has IP x, 2 = IP x is at MAC z
; DHCP      in UDP, port 68 to 67, our MAC, xid, options
;
; the chip has 8 KB of buffer, 0x0000-0x19FF receives, 0x1A00-0x1FFF sends
; each received frame has a 6 byte header, next frame, length, status
; registers are in 4 banks, ECON1 bits 1-0 pick one, 0x1B-0x1F are in every bank
; RCR 000a_aaaa read a register, MAC/MII ones send a dummy byte first, WCR 010a_aaaa write one
; BFS 100a_aaaa set bits, BFC 101a_aaaa clear bits, RBM 0x3A read buffer, WBM 0x7A write buffer
; SRC 0xFF soft reset, PHY registers go through the MII registers
; frames are in the SDRAM, NET_RECEIVED and NET_SENDING, addresses in RAM, NET_MAC...
; uses R1-R7, some routines keep R8-R12

.equ RX_START, 0x0000                   ; receive buffer 0x0000-0x19FF
.equ RX_END, 0x19FF
.equ TX_START, 0x1A00                   ; send buffer from 0x1A00, one control byte then the frame
.equ ECON1, 0x1F                        ; bits 1-0 bank, bit 2 RXEN, bit 3 TXRTS, bit 7 TXRST
.equ ECON2, 0x1E                        ; bit 6 PKTDEC, a frame was taken
.equ ESTAT, 0x1D                        ; bit 0 CLKRDY, clock started
.equ DHCP_SIZE, 342                     ; DHCP message, 14 + 20 + 8 + 300

.include "sw/os/net/enc28j60.asm"       ; ENC28J60 over SPI, registers, banks, PHY
.include "sw/os/net/driver.asm"         ; start the chip, send and receive frames
.include "sw/os/net/packets.asm"        ; checksums, Ethernet and IP headers
.include "sw/os/net/dhcp.asm"           ; DHCP, get an IP address
.include "sw/os/net/answer.asm"         ; answer ARP and ping
.include "sw/os/net/ping.asm"           ; ping, ARP for the next hop, ICMP echo
.include "sw/os/net/web.asm"            ; DNS, TCP and HTTP
.include "sw/os/net/calls.asm"          ; NET_CALLS for programs
.include "sw/os/net/command.asm"        ; the net command and its texts
