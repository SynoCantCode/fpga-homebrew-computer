; kernel_main.asm, KERNEL.BIN, the kernel part on the SD card, /SYSTEM/KERNEL.BIN
; the boot ROM loads it at KERNEL_START (0x1000_0000) and jumps to it
; holds the shell, the heap and the file system writing half
; the ROM keeps start-up, interrupts, queues, screen, UART, SD
; and the file system reading half
; ROM routines are called with CALLF / JUMPF, CALL / JUMP reach +-128 KB
; names come from rom_symbols.asm, made by make_rom_symbols.py
; build with sh project/tools/scripts/assemble_os.sh
; a new kernel needs no FPGA rebuild, only ROM changes do
.include "devices.asm"
.include "rom_symbols.asm"
.org KERNEL_START

; kernel_start, fills KERNEL_TABLE, then starts the shell
; never comes back
kernel_start: LA R5, shell_restart
        STORE  R5, [KERNEL_TABLE]
        LA     R5, allocate
        STORE  R5, [KERNEL_TABLE + 4]
        LA     R5, free
        STORE  R5, [KERNEL_TABLE + 8]
        LA     R5, file_write
        STORE  R5, [KERNEL_TABLE + 12]
        LA     R5, file_delete
        STORE  R5, [KERNEL_TABLE + 16]
        LA     R5, folder_make
        STORE  R5, [KERNEL_TABLE + 20]
        LA     R5, file_move
        STORE  R5, [KERNEL_TABLE + 24]
        LA     R5, file_copy
        STORE  R5, [KERNEL_TABLE + 28]
        STORE  R0, [NET_STARTED]        ; network not started, no IP yet
        STORE  R0, [NET_IP]
        STORE  R0, [NET_DNS]
        LA     R5, net_connect          ; NET_CALLS, network routines for programs
        STORE  R5, [NET_CALLS]
        LA     R5, net_link
        STORE  R5, [NET_CALLS + 4]
        LA     R5, net_time             ; set the clock from the internet
        STORE  R5, [NET_CALLS + 8]
        LA     R5, clock_shift          ; move the clock an hour
        STORE  R5, [NET_CALLS + 12]
        LA     R5, net_fetch            ; fetch a web page
        STORE  R5, [NET_CALLS + 16]
        LA     R5, folder_list          ; KERNEL_CALLS, a folders entries
        STORE  R5, [KERNEL_CALLS]
        LA     R5, mouse_start          ; + 4, mouse_start
        STORE  R5, [KERNEL_CALLS + 4]
        STOREB R0, [NEXT_COMMANDS]      ; empty the shells note, RAM keeps it over a reset
        CALL   heap_init                ; palette_load uses heap memory
        CALL   palette_load             ; colours from /SYSTEM/DESIGN/PALETTE.TXT, if its there
        CALL   kernel_sum               ; sum of the kernel, for kernel_check
        STORE  R1, [KERNEL_SUM]
        STORE  R0, [KERNEL_WARNED]
        JUMP   shell_restart

.include "shell.asm"
.include "heap.asm"
.include "fs_write.asm"
.include "net.asm"
.include "time.asm"
.include "folder_list.asm"
.include "kernel_check.asm"
.include "mouse_start.asm"
.include "../graphics/palette_file.asm"

kernel_end:                             ; end of KERNEL.BIN, kernel_sum adds up to here
