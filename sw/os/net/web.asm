; names, TCP and the web

.include "sw/os/net/addresses.asm"                             ; 32 bit numbers, routing, host names
.include "sw/os/net/dns.asm"                                   ; DNS, a name to its address
.include "sw/os/net/tcp.asm"                                   ; TCP, send and check a segment
.include "sw/os/net/http.asm"                                  ; HTTP, fetch a page, leave out its tags
.include "sw/os/net/dns_command.asm"                           ; the shells net dns NAME
