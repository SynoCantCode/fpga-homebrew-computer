; boot ROM, runs at reset, lives at 0x0000_0000
; will keep growing
; this file is the start-up, the other parts come in with .include
; the ROM is these parts, in this order
; devices.asm  names of every address and bit, makes no code
; jump_table.asm  kernel entry points, must be the first code, entry 0 = reset
; (start-up)   LEDs, kernel set up, banner, load /SYSTEM/KERNEL.BIN or the USB fallback
; loader.asm   kernel_arm, receive_program, run_program
; line.asm     line_key, read_line into LINE_BUFFER
; serial.asm   UART, send_byte, print_text, print_line, receive_byte, receive_word
; screen.asm   screen_char, screen_text, screen_line, screen_clear
; kernel.asm   interrupt handler and the queues
; sd.asm       SD card driver, 512 byte blocks over SPI
; fs.asm       file system reading half, mount, paths, FAT, reading files
; the shell, heap and file system writing half are in KERNEL.BIN on the card
; (banner text) at the bottom

.include "devices.asm"
.include "jump_table.asm"

; start-up, entry 0 of the jump table jumps here
start: DI                               ; interrupts off during set up
        LOADLO R15SP, STACK_TOP         ; stack at the top of the 32 KB block RAM
        LOADLO R1, 0x0001
        STORE  R1, [LEDS]               ; LED 0 on, boot started
        STORE  R0, [LAST_PROGRAM]       ; no program uploaded yet
        STORE  R0, [SD_STATE]           ; SD card not awake yet
        STORE  R0, [FS_STATE]           ; file system not mounted yet
        STOREB R0, [FS_PATH]            ; current folder path = "", the root

; empty queues
        CALL   queues_clear

; screen white on blue, blank, cursor top-left
        LOADLO R1, WHITE_ON_BLUE
        STORE  R1, [SCREEN_COLOUR]
        CALL   screen_clear

; graphics card, palette and pointer, page 0, text layer only
        CALL   graphics_init

; banner over the UART, then on the screen
; print_line may wreck R1-R7, so R1 is loaded again
        LOADLO R1, blank
        CALL   print_line
        LOADLO R1, title
        CALL   print_line
        LOADLO R1, title
        CALL   screen_line
        LOADLO R1, details
        CALL   print_line
        LOADLO R1, details
        CALL   screen_line
        LOADLO R1, ready
        CALL   print_line
        LOADLO R1, ready
        CALL   screen_line

        LOADLO R1, 0x0003
        STORE  R1, [LEDS]               ; LEDs 0 and 1, booted

; ---- load /SYSTEM/KERNEL.BIN from the card into the SDRAM ----
; copied to KERNEL_START (0x1000_0000) and started there
; it fills KERNEL_TABLE with its routines addresses
; until then ALLOCATE gives 0, the file routines give error 28
        LOADLO R1, no_kernel
        STORE  R1, [KERNEL_TABLE]
        LOADLO R1, kernel_missing_zero
        STORE  R1, [KERNEL_TABLE + 4]
        STORE  R1, [KERNEL_TABLE + 8]
        LOADLO R1, kernel_missing
        STORE  R1, [KERNEL_TABLE + 12]
        STORE  R1, [KERNEL_TABLE + 16]
        STORE  R1, [KERNEL_TABLE + 20]
        STORE  R1, [KERNEL_TABLE + 24]
        STORE  R1, [KERNEL_TABLE + 28]
        CALL   kernel_arm               ; doorbells on, keyboard and upload work even if loading fails
        LOADLO R1, kernel_path
        CALL   file_size                ; R1 = 0 or an error, R2 = size
        CMPI   R1, 0x0000
        JNZ    no_kernel_error
        LOADHI R5, KERNEL_MAX_HIGH
        CMP    R5, R2
        JNC    no_kernel_too_big        ; bigger than 1 MB, not a kernel
        LOADLO R1, kernel_path
        LOADHI R2, KERNEL_START_HIGH
        CALL   file_read                ; whole file into the SDRAM at 0x1000_0000
        CMPI   R1, 0x0000
        JNZ    no_kernel_error
        LOADLO R1, 0x0007
        STORE  R1, [LEDS]               ; LEDs 0-2, kernel loaded
        LOADHI R1, KERNEL_START_HIGH
        JUMPR  R1                       ; start it, never comes back
no_kernel_too_big: LOADLO R1, 18
no_kernel_error: MOV R8, R1             ; R8 = error number
        LOADLO R1, no_kernel_text
        CALL   screen_text
        MOV    R1, R8
        CALL   screen_hex_word
        LOADLO R1, 0x000A
        CALL   screen_char
        LOADLO R1, no_kernel_text
        CALL   print_line               ; and to the PC

; no_kernel, no KERNEL.BIN so wait for a program from the PC and run it
; KERNEL.BIN itself can be sent this way with send.sh
; then mkdir system, sdwrite.file system/kernel.bin 10000000 SIZE
no_kernel: LOADLO R15SP, STACK_TOP      ; empty stack, a crash without a kernel also comes back here
        CALL   kernel_arm
        LOADLO R1, waiting
        CALL   print_line
        LOADLO R1, upload_text
        CALL   screen_line
no_kernel_wait: LOAD R1, [UART_QUEUE + QUEUE_HEAD]
        LOAD   R2, [UART_QUEUE + QUEUE_TAIL]
        CMP    R1, R2
        JZ     no_kernel_wait           ; nothing from the PC yet
        CALL   receive_program          ; R1 = where it went, or -1 if refused
        CMPIS  R1, -1
        JZ     no_kernel
        STORE  R1, [LAST_PROGRAM]
        LOADLO R2, blank                ; no arguments
        CALL   run_program
        JUMP   no_kernel

; ---- the bridge, jump table entries for KERNEL.BIN routines jump on through KERNEL_TABLE
; R5 is scratch, R1-R4 untouched
to_restart: LOAD R5, [KERNEL_TABLE]
        JUMPR  R5
to_allocate: LOAD R5, [KERNEL_TABLE + 4]
        JUMPR  R5
to_free: LOAD R5, [KERNEL_TABLE + 8]
        JUMPR  R5
to_file_write: LOAD R5, [KERNEL_TABLE + 12]
        JUMPR  R5
to_file_delete: LOAD R5, [KERNEL_TABLE + 16]
        JUMPR  R5
to_folder_make: LOAD R5, [KERNEL_TABLE + 20]
        JUMPR  R5
to_file_move: LOAD R5, [KERNEL_TABLE + 24]
        JUMPR  R5
to_file_copy: LOAD R5, [KERNEL_TABLE + 28]
        JUMPR  R5
; answers before KERNEL.BIN is there
kernel_missing_zero: LOADLO R1, 0       ; ALLOCATE no room, FREE nothing to do
        RET
kernel_missing: LOADLO R1, 28           ; file routines, error 28, kernel not loaded
        RET

; parts the start-up and the shell use
.include "loader.asm"
.include "line.asm"
.include "serial.asm"
.include "screen.asm"
.include "kernel.asm"
.include "remote.asm"
.include "sd.asm"
.include "fs.asm"
.include "keymap.asm"
.include "../graphics/draw.asm"
.include "i2c.asm"

; banner text
blank: .string ""
title: .string "NAME shell"
details: .string "32-bit CPU, 32 KB block RAM, 8 MB SDRAM, SD card"
ready: .string "ready. (help lists the commands)"
waiting: .string "waiting for a program..."
refused: .string "refused: programs go at 0x5000 or above"
kernel_path: .string "/system/kernel.bin"
no_kernel_text: .string "no kernel: /SYSTEM/KERNEL.BIN could not be loaded, error 0x"
upload_text: .string "waiting for a program from the PC (send.sh), e.g. sw/os/kernel_main.asm"

; last, so nothing above moves, mouse wheel dispatch and junk rule
.include "remote_pixels.asm"
