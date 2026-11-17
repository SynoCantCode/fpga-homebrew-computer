; devices.asm, a name for every address, area and bit in the computer
; put at the top of a program, .include "sw/os/devices.asm"
; only .equ names, no instructions, no memory

; ---- memory areas (block RAM) ----
; _START = first address, _END = first address after it
.equ ROM_START,          0x0000_0000    ; boot ROM, read-only, the bus ignores writes
.equ ROM_END,            0x0000_4000    ; 16 KB
.equ RAM_START,          0x0000_4000    ; RAM, kernel variables first, then programs
.equ RAM_END,            0x0000_8000    ; block RAM is 32 KB, 0x0000-0x7FFF
.equ PROGRAM_START,      0x0000_5000    ; uploaded programs go here (their .org), the loader refuses lower
.equ KERNEL_VARIABLES,   0x0000_4000    ; kernel variables, 0x4000-0x4FFF
.equ KERNEL_VARIABLES_END, 0x0000_5000  ; 4 KB
.equ STACK_LIMIT,        0x0000_7000    ; lowest address the stack may reach, 4 KB stack 0x7000-0x7FFF
.equ STACK_RESERVE,      0x0010         ; SLIM = STACK_LIMIT + this, 16 bytes kept for the crash handler
.equ STACK_TOP,          0x0000_8000    ; R15SP, stack grows down, first PUSH at 0x7FFC
                                         ; the CPU resets it to 0x0001_0000
; programs in the SDRAM, code and texts at PROGRAM_SDRAM, run NAME loads a .BIN there
; small variables in block RAM at PROGRAM_DATA, 8 KB below the stack
; a small program uploaded with send.sh may sit at 0x5000 instead
.equ PROGRAM_SDRAM,      0x1018_0000    ; 0x1018_0000-0x101F_FFFF, 512 KB
.equ PROGRAM_SDRAM_HIGH, 0x1018         ; top half, for LOADHI
.equ PROGRAM_SDRAM_SIZE_HIGH, 0x0008    ; 0x0008_0000 = 512 KB
.equ PROGRAM_DATA,       0x0000_5000    ; 0x5000-0x6FFF, a programs variables, 8 KB of block RAM

; ---- kernel entry points, the jump table at the start of the ROM ----
; CALL these by name, CALL GET_KEY_BYTE
; inputs R1-R4, answer in R1, may wreck R1-R7, keep R8-R14
.equ GET_KEY_BYTE,       0x0000_0004    ; out R1 = next raw keyboard byte (scan code, F0, E0), or -1
.equ GET_MOUSE_BYTE,     0x0000_0008    ; out R1 = next raw mouse packet byte, or -1
.equ GET_SERIAL_BYTE,    0x0000_000C    ; out R1 = next byte from the PC, or -1
.equ GET_CHAR,           0x0000_0010    ; out R1 = next character typed (ASCII, Shift handled), or -1
.equ SEND_BYTE,          0x0000_0014    ; in R1 = byte, sent to the PC, waits for the UART
.equ PRINT_TEXT,         0x0000_0018    ; in R1 = pointer to a text ending with 0, sent to the PC
.equ PRINT_LINE,         0x0000_001C    ; in R1 = pointer to a text, sent to the PC, then CR LF
.equ PRINT_BYTE_HEX,     0x0000_0020    ; in R1 = byte, sent to the PC as 2 hex digits
.equ SCREEN_CHAR,        0x0000_0024    ; in R1 = character, onto the screen at the cursor
.equ SCREEN_TEXT,        0x0000_0028    ; in R1 = pointer to a text, onto the screen at the cursor
.equ SCREEN_LINE,        0x0000_002C    ; in R1 = pointer to a text, onto the screen, then a new line
.equ SCREEN_CLEAR,       0x0000_0030    ; whole screen blank, cursor top-left
.equ SCREEN_HEX_WORD,    0x0000_0034    ; in R1 = number, onto the screen as 8 hex digits
.equ READ_LINE,          0x0000_0038    ; waits for a typed line, out R1 = pointer to it
.equ SD_INIT,            0x0000_003C    ; wakes the SD card, out R1 = 0 or an error number
.equ SD_READ_BLOCK,      0x0000_0040    ; in R1 = block number, R2 = pointer to 512 bytes, out R1 = 0 or an error
.equ SD_WRITE_BLOCK,     0x0000_0044    ; in R1 = block number, R2 = pointer to 512 bytes, out R1 = 0 or an error
                                         ; 16 = refused, on a FAT32 card only the gap before the FAT32 part may be written
.equ ALLOCATE,           0x0000_0048    ; in R1 = bytes, out R1 = pointer into the heap, or 0 if no room
.equ FREE,               0x0000_004C    ; in R1 = pointer from ALLOCATE, back to the heap
.equ FILE_MOVE,          0x0000_0060    ; in R1 = old path, R2 = new path, out R1 = 0 or an error, renames or moves
.equ FILE_COPY,          0x0000_0064    ; in R1 = old path, R2 = new path, out R1 = 0 or an error, copies a file
.equ FILE_SIZE,          0x0000_0068    ; in R1 = path, out R1 = 0 or an error (14 = a folder)
                                         ; R2 = size in bytes, nothing is read
.equ FILE_DELETE,        0x0000_0058    ; in R1 = path, out R1 = 0 or an error, deletes the file
.equ FOLDER_MAKE,        0x0000_005C    ; in R1 = path, out R1 = 0 or an error, makes an empty folder
.equ FILE_WRITE,         0x0000_0054    ; in R1 = file name, R2 = pointer to the bytes, R3 = how many, out R1 = 0 or an error
                                         ; saves or replaces the file
.equ FILE_READ,          0x0000_0050    ; in R1 = file name or path, R2 = where to put it, out R1 = 0 or an error
                                         ; R2 = size in bytes
; graphics card (sw/graphics/draw.asm), a point is x | (y << 16), (100, 40) = 0x0028_0064
; a size is width | (height << 16), colours are 0-255
; palette, top 4 bits = colour, bottom 4 = shade
; drawn on the drawing page, DRAW_FLIP swaps pages, dots off the screen are left out
.equ GRAPHICS_MODE,      0x0000_006C    ; in R1 = layers on, LAYER_PIXELS + LAYER_TEXT + LAYER_POINTER
.equ DRAW_CLEAR,         0x0000_0070    ; in R1 = colour, fills the drawing page
.equ DRAW_PIXEL,         0x0000_0074    ; in R1 = point, R2 = colour
.equ DRAW_LINE,          0x0000_0078    ; in R1 = from, R2 = to, R3 = colour
.equ DRAW_RECT,          0x0000_007C    ; in R1 = top-left, R2 = size, R3 = colour, a filled box
.equ DRAW_TEXT,          0x0000_0080    ; in R1 = top-left, R2 = pointer to a text, R3 = letter colour
                                         ; + TEXT_BACKGROUND + background colour x 0x100 for boxes too
.equ DRAW_FLIP,          0x0000_0084    ; show the drawing page, then draw on the other
.equ SET_COLOUR,         0x0000_0088    ; in R1 = colour number 0-255, R2 = 0x00RRGGBB
.equ MOUSE_STATE,        0x0000_008C    ; reads mouse packets, moves the pointer, out R1 = where it is (a point)
                                         ; R2 = buttons, bit 0 left, bit 1 right, bit 2 middle
.equ DRAW_COPY,          0x0000_0090    ; in R1 = where, R2 = size, R3 = source base address, R4 = where in the source
                                         ; base is a multiple of 1 KB, a page or a picture
.equ DRAW_SPRITE,        0x0000_0094    ; same, but one colour is skipped, R3 = base + that colour
.equ DRAW_WAIT,          0x0000_0098    ; waits for the blitter, before LOADB / STOREB on a page
.equ I2C_READ,           0x0000_009C    ; in R1 = chip I2C address, R2 = first register, R3 = how many bytes, R4 = where to put them
                                         ; out R1 = 0, or 1 if no answer
.equ I2C_WRITE,          0x0000_00A0    ; in R1 = chip, R2 = first register, R3 = how many, R4 = where they are
                                         ; out R1 = 0, or 1 if no answer
.equ CLOCK_CHIP,         0x68           ; DS3231 I2C address, registers 0-6 = seconds, minutes, hours, weekday, date, month, year
                                         ; each 2 BCD digits in a byte
.equ PINS_CHIP,          0x20           ; MCP23017 I2C address, A0-A2 to ground
; GET_CHAR codes for keys with no ASCII letter
.equ KEY_UP,             0x0080         ; arrow keys
.equ KEY_DOWN,           0x0081
.equ KEY_LEFT,           0x0082
.equ KEY_RIGHT,          0x0083
.equ KEY_HOME,           0x0084
.equ KEY_END,            0x0085
.equ KEY_DELETE,         0x0086
.equ KEY_PAGE_UP,        0x0087
.equ KEY_PAGE_DOWN,      0x0088
.equ NOTHING,            0xFFFF_FFFF    ; answer when a routine has nothing to give back (-1)

; ---- kernel variables, 0x4000-0x4FFF ----
; queues, ring buffers the interrupt handler fills and programs empty
; +0 head, where the next byte goes in, only the handler writes it
; +4 tail, where the next byte comes out, +8 the 64 byte slots
.equ KEY_QUEUE,          0x0000_4000    ; keyboard raw bytes, 0x4000-0x4047
.equ MOUSE_QUEUE,        0x0000_4080    ; mouse raw packet bytes, 0x4080-0x40C7
.equ UART_QUEUE,         0x0000_4100    ; bytes from the PC, 0x4100-0x4147
.equ KEYBOARD_SHIFT,     0x0000_4180    ; get_char, 1 while Shift is held
.equ KEYBOARD_NOTES,     0x0000_4184    ; get_char, about the next byte, bit 0 = release (F0), bit 1 = extended (E0)
.equ SCREEN_CURSOR,      0x0000_4188    ; pointer to the cell where the next character goes
.equ SCREEN_ROW_START,   0x0000_418C    ; pointer to the first cell of the cursor row
.equ SCREEN_COLOUR,      0x0000_4190    ; colours for new characters, bits 15-12 back, 11-8 letter
.equ LINE_LENGTH,        0x0000_4194    ; characters in the line being typed
.equ LAST_PROGRAM,       0x0000_4198    ; pointer to the last program uploaded, 0 = none
.equ SD_STATE,           0x0000_419C    ; SD card, 0 = not awake, 1 = awake (old small card), 2 = awake (high capacity)
.equ FS_STATE,           0x0000_41A0    ; file system, 0 = not mounted, 1 = mounted
.equ FS_PARTITION_START, 0x0000_41A4    ; block where the FAT32 part starts
.equ FS_SECTORS_PER_CLUSTER, 0x0000_41A8 ; blocks per cluster
.equ FS_FAT_START,       0x0000_41AC    ; block where the FAT starts
.equ FS_DATA_START,      0x0000_41B0    ; block where the data area starts, cluster 2
.equ FS_ROOT_CLUSTER,    0x0000_41B4    ; first cluster of the root folder
; the file being read, set by file_open, moved along by file_next_block
.equ FS_FILE_CLUSTER,    0x0000_41B8    ; cluster being read
.equ FS_FILE_LEFT,       0x0000_41BC    ; bytes of the file still to come
.equ FS_FILE_BLOCK,      0x0000_41C0    ; next block to read
.equ FS_FILE_BLOCKS,     0x0000_41C4    ; blocks left in this cluster, 0 = ask the FAT
.equ FS_FILE_SIZE,       0x0000_41C8    ; file size in bytes
.equ FS_FAT_SIZE,        0x0000_41CC    ; blocks in one copy of the FAT
.equ FS_NAME,            0x0000_41D0    ; 11 bytes, the name looked for, in the card form "TEXT    TXT" (0x41D0-0x41DA)
.equ FS_FAT_COUNT,       0x0000_41DC    ; how many copies of the FAT, usually 2
.equ FS_LAST_CLUSTER,    0x0000_41E0    ; last cluster on the card, they go from 2 to this
.equ FS_LINE_BLOCK,      0x0000_41E4    ; block holding the line of the file fs_find found
.equ FS_LINE_OFFSET,     0x0000_41E8    ; offset of that line in its block, 0x00 to 0x1E0
.equ FS_FREE_BLOCK,      0x0000_41EC    ; block of the first free line fs_find passed, or NOTHING
.equ FS_FREE_OFFSET,     0x0000_41F0    ; offset of that free line in its block
.equ FS_WRITE_ADDR,      0x0000_41F4    ; address of the bytes being saved
.equ FS_WRITE_SIZE,      0x0000_41F8    ; how many bytes are being saved
.equ FS_OLD_CLUSTER,     0x0000_41FC    ; first cluster of the replaced file, freed once the new one is safe
.equ LINE_BUFFER,        0x0000_4200    ; the line being typed, one byte per character, then a 0
.equ LINE_BUFFER_SIZE,   256            ; up to 255 characters + the 0
                                         ; 0x4200-0x43FF is kept free for it, up to 512
.equ FS_CURRENT_CLUSTER, 0x0000_4600    ; cluster of the current folder
.equ FS_FOLDER_CLUSTER,  0x0000_4604    ; cluster of the folder fs_find looked in last
.equ FS_FOLDER_LAST,     0x0000_4608    ; last cluster of that folder
.equ FS_PATH,            0x0000_4610    ; text, path of the current folder, "/GAMES/LEVELS", "" = the root
                                         ; 0x4610-0x468F, up to 0x7F characters, then a 0
.equ FS_MOVE_LINE,       0x0000_4690    ; 32 bytes, copy of the line being moved, 0x4690-0x46AF
.equ FS_MOVE_BLOCK,      0x0000_46B0    ; block where that line was
.equ FS_MOVE_OFFSET,     0x0000_46B4    ; offset of that line in its block
.equ FS_MOVE_CLUSTER,    0x0000_46B8    ; first cluster of the moved file or folder
.equ FS_MOVE_PATH,       0x0000_46C0    ; text, a path built by the kernel or shell, 0x46C0-0x473F
.equ REMOTE_KEY,         0x0000_4760    ; remote control, a key the PC pressed, waiting for GET_CHAR, 0 = none
; graphics routines (sw/graphics/draw.asm)
.equ DRAW_PAGE,          0x0000_4764    ; address of the page being drawn on, PAGE_0 or PAGE_1
.equ MOUSE_X,            0x0000_4768    ; pointer x in dots, 0-639
.equ MOUSE_Y,            0x0000_476C    ; pointer y, 0-479
.equ MOUSE_BUTTONS,      0x0000_4770    ; buttons in the last packet, bit 0 left, 1 right, 2 middle
.equ MOUSE_PACKET_COUNT, 0x0000_4774    ; bytes of the packet so far, 0-2
.equ MOUSE_PACKET_FIRST, 0x0000_4778    ; first packet byte, buttons + sign bits
.equ MOUSE_PACKET_X,     0x0000_477C    ; second byte, the x move
.equ MOUSE_PACKET_SIZE,  0x0000_47A0    ; 4 = wheel mouse with 4 byte packets, else 3
.equ MOUSE_PACKET_Y,     0x0000_47A4    ; wheel mouse, third byte (the y move), kept for the fourth
.equ MOUSE_WHEEL,        0x0000_47A8    ; wheel notches since a program last took them, + = down, - = up
                                         ; MOUSE_STATE adds to it, the program reads it and stores 0
.equ TIME_BYTES,         0x0000_4790    ; 8 bytes, DS3231 registers 0-6
.equ TIMER_JOB,          0x0000_4780    ; address of a routine called on every timer tick (100 a second), 0 = none
                                         ; kernel_arm sets it back to 0
                                         ; it runs inside the interrupt, keep it short
                                         ; plain loads and stores only, no blitter, no kernel calls
                                         ; keeps R8-R14, may use R1-R7
; the shell note, commands left by a program that is ending
; text, one command a line ending with 0x0A, then a 0
; each time the shell starts it takes the first line out and runs it
; a 0 first = nothing left
.equ NEXT_COMMANDS,      0x0000_4800    ; 0x4800-0x48FF
; networking (net.asm), our addresses, 4 bytes each
.equ NET_IP,             0x0000_4900    ; our IP address, 0 = none yet
.equ NET_MASK,           0x0000_4904    ; network mask
.equ NET_GATEWAY,        0x0000_4908    ; the router
.equ NET_DNS,            0x0000_490C    ; the name server
.equ NET_SERVER,         0x0000_4910    ; DHCP, the server that offered
.equ NET_OFFER,          0x0000_4914    ; DHCP, the address offered
.equ NET_XID,            0x0000_4918    ; DHCP, our number for the exchange
.equ NET_NEXT,           0x0000_491C    ; ENC28J60, where the next received frame starts in its buffer
.equ NET_STARTED,        0x0000_4920    ; 1 = chip started (enc_start)
.equ NET_TARGET,         0x0000_4924    ; ping, the address being pinged
.equ NET_HOP,            0x0000_4928    ; who gets the packets, the target if on our network, else the router
.equ NET_HOP_MAC,        0x0000_492C    ; MAC of that one, 6 bytes, 0x492C-0x4931
.equ NET_SEQUENCE,       0x0000_4934    ; ping, echo request number
.equ NET_LOCAL_PORT,     0x0000_4938    ; TCP, our port
.equ NET_REMOTE_PORT,    0x0000_493C    ; TCP, their port, 80 for a web server
.equ NET_SEQ,            0x0000_4940    ; TCP, number of our next byte
.equ NET_ACK,            0x0000_4944    ; TCP, number of their next byte we wait for
.equ NET_PAGE_SIZE,      0x0000_4948    ; net get, size of the page text so far
.equ NET_PHASE,          0x0000_494C    ; net get, 0 status line, 1 headers, 2 page
.equ NET_LINE_LEN,       0x0000_4950    ; net get, letters in this header line, 0 = the blank line
.equ NET_IN_TAG,         0x0000_4954    ; net get, 1 = inside <...>
.equ NET_TAG_LEN,        0x0000_4958    ; net get, letters of the tag name kept so far
.equ NET_TAG_TEXT,       0x0000_495C    ; first 4 letters of the tag, 0x495C-0x495F
.equ NET_SKIPPING,       0x0000_4A00    ; net get, 1 = inside <script> or <style>, not shown
.equ NET_LAST,           0x0000_4A04    ; net get, last letter shown
.equ NET_NAME,           0x0000_4960    ; host name as typed, up to 63 letters + a 0, 0x4960-0x499F
.equ NET_PATH,           0x0000_49A0    ; net get, the page path, up to 95 letters + a 0, 0x49A0-0x49FF
.equ TIME_ZONE,          0x0000_4A80    ; DS3231 register 7, the time zone + 32, 4 bytes
.equ NET_FETCH_QUIET,    0x0000_4A84    ; 1 while net_fetch runs net get, page not saved as /web.txt
.equ KERNEL_SUM,         0x0000_4A88    ; KERNEL.BIN fingerprint, all its words added up at start
.equ KERNEL_WARNED,      0x0000_4A8C    ; 1 once the shell has said the kernel is damaged
.equ UPLOADS_WELCOME,    0x0000_4B10    ; 1 only while the shell waits at its prompt, a byte from the PC starts an upload
                                         ; 0 anywhere else, such a byte is junk and gets thrown away
.equ NET_FETCH_LINE,     0x0000_4A90    ; net_fetch, "get HOST/PATH" for net get, 128 bytes, 0x4A90-0x4B0F
; KERNEL.BIN keeps no variables of its own, all of them are here in RAM
; so kernel_check can tell if something wrote over it
.equ KERNEL_CALLS,       0x0000_4A60    ; KERNEL.BIN routines for programs, addresses filled in at start
                                         ; +0 folder_list, in R1 = path, R2 = where entries go, R3 = room
                                         ; out R1 = how many, -1 not a folder
                                         ; +4 mouse_start, wakes the mouse, wheel on if it has one
                                         ; out R1 = 4 wheel, 3 plain
                                         ; call with LOAD R5, [KERNEL_CALLS] then CALLR R5
.equ NET_CALLS,          0x0000_4A40    ; network routines for programs, 8 words, 0x4A40-0x4A5F
                                         ; +0 net_connect (R1 = 1, we have an IP), +4 net_link (R1 = 1 up)
                                         ; +8 net_time, clock set from the internet, R1 = 1 done
                                         ; +12 clock_shift, in R1 = hours +1 / -1, out R1 = 1 done
                                         ; +16 net_fetch, in R1 = "HOST/PATH", out R1 = page bytes or 0, R2 = NET_PAGE
; frames wait in the SDRAM, near the top of the 1 MB for KERNEL.BIN
.equ NET_RECEIVED,       0x100F_0000    ; frame just received, up to 1518 bytes
.equ NET_RECEIVED_HIGH,  0x100F
.equ NET_SENDING,        0x100F_0800    ; frame being sent
.equ NET_SENDING_HIGH,   0x100F
.equ NET_SENDING_LOW,    0x0800
.equ NET_REQUEST,        0x100F_1000    ; net get, the HTTP request being sent
.equ NET_REQUEST_LOW,    0x1000
.equ NET_PSEUDO_LOW,     0x1800         ; TCP, checksum pseudo header at NET_SENDING_HIGH : this
.equ NET_PAGE,           0x100E_0000    ; net get, the page text, saved as /web.txt, up to 64 KB
.equ NET_PAGE_HIGH,      0x100E
.equ NEXT_COMMANDS_SIZE, 256            ; most a note may hold, with its 0
.equ KERNEL_TABLE,       0x0000_4740    ; 8 words filled in by KERNEL.BIN, 0x4740-0x475F, +0 shell restart, +4 ALLOCATE, +8 FREE
                                         ; +12 FILE_WRITE, +16 FILE_DELETE, +20 FOLDER_MAKE, +24 FILE_MOVE, +28 FILE_COPY
.equ DISK_BUFFER,        0x0000_4400    ; kernel 512 bytes for card settings, folders and FAT, 0x4400-0x45FF
.equ QUEUE_HEAD,         0              ; offsets inside a queue block, [R6 + QUEUE_HEAD]
.equ QUEUE_TAIL,         4
.equ QUEUE_SLOTS,        8
.equ QUEUE_SIZE,         64             ; slots per queue, a power of 2
.equ QUEUE_MASK,         63             ; QUEUE_SIZE - 1, (position + 1) AND QUEUE_MASK wraps 64 to 0

; ---- the text screen (a separate block RAM) ----
.equ TEXT_SCREEN,        0x2000_0000    ; cell 0, top-left, cell N is at TEXT_SCREEN + N x 4
.equ TEXT_SCREEN_END,    0x2000_2580    ; just past the last cell, 2400 cells x 4 bytes
.equ SCREEN_COLUMNS,     80
.equ SCREEN_ROWS,        30
.equ SCREEN_CELLS,       2400           ; 80 x 30
.equ ROW_BYTES,          320            ; one row = 80 cells x 4 bytes
.equ CELL_BYTES,         4              ; one cell = one word
; a cell, bits 15-12 background colour, 11-8 letter colour, 7-0 character
.equ BLUE_SPACE,         0x1F20         ; a space, white on blue
.equ WHITE_ON_BLUE,      0x1F00         ; background blue (1), letter white (F)
.equ TEXT_SCREEN_HIGH,   0x2000         ; top half of TEXT_SCREEN, for LOADHI

; ---- the 16 colours, bits 15-12 background, 11-8 letter ----
.equ BLACK,              0x0
.equ BLUE,               0x1
.equ GREEN,              0x2
.equ CYAN,               0x3
.equ RED,                0x4
.equ MAGENTA,            0x5
.equ BROWN,              0x6
.equ LIGHT_GREY,         0x7
.equ DARK_GREY,          0x8
.equ LIGHT_BLUE,         0x9
.equ LIGHT_GREEN,        0xA
.equ LIGHT_CYAN,         0xB
.equ LIGHT_RED,          0xC
.equ LIGHT_MAGENTA,      0xD
.equ YELLOW,             0xE
.equ WHITE,              0xF

; ---- the SDRAM, 8 MB, slower, the CPU waits for it ----
.equ SDRAM_START,        0x1000_0000
.equ SDRAM_END,          0x1080_0000    ; 8 MB
.equ SDRAM_RESERVED,     0x1000_0000    ; 3 MB kept back for things that need a fixed address
.equ SDRAM_RESERVED_END, 0x1030_0000
.equ HEAP_START,         0x1030_0000    ; heap, 5 MB handed out with ALLOCATE / FREE
.equ HEAP_END,           0x1080_0000
; KERNEL.BIN, loaded at boot from /SYSTEM/KERNEL.BIN
.equ KERNEL_START,       0x1000_0000    ; where KERNEL.BIN is loaded and started (its .org)
.equ KERNEL_START_HIGH,  0x1000         ; top half, for LOADHI
.equ KERNEL_MAX_HIGH,    0x0010         ; up to 0x0010_0000 bytes, 1 MB
.equ HEAP_START_HIGH,    0x1030         ; top halves, for LOADHI
.equ HEAP_END_HIGH,      0x1080
.equ HEAP_SIZE_HIGH,     0x0050         ; 0x0050_0000 = 5 MB

; ---- the pixel screen, 2 pages in the SDRAM ----
; a page = 480 rows of 1 KB, row y starts at page + y x 1024
; its first 640 bytes are the dots, one byte = a colour number, 384 spare
.equ PAGE_0,             0x1020_0000    ; 0x1020_0000 - 0x1027_7FFF
.equ PAGE_1,             0x1028_0000    ; 0x1028_0000 - 0x102F_7FFF
.equ PAGE_0_HIGH,        0x1020         ; top halves, for LOADHI
.equ PAGE_1_HIGH,        0x1028
.equ PAGE_ROW_BYTES,     1024           ; next row down is + 1024
.equ PICTURE_STORE,      0x1010_0000    ; page-shaped place for a picture, 0x1010_0000-0x1017_7FFF
.equ PICTURE_STORE_HIGH, 0x1010
.equ PIXELS_ACROSS,      640
.equ PIXELS_DOWN,        480

; ---- I/O, the device addresses, LOAD R4, [KEYBOARD_STATUS] ----
.equ IO_START,           0xFFFF_8000    ; first device address
.equ IO_HIGH,            0xFFFF         ; top half of IO_START, for LOADHI, then ORI with 0x8000
.equ LEDS,               0xFFFF_8000    ; write bits 5-0 = LEDs on (1 = on), read the same bits back
.equ UART_DATA,          0xFFFF_8004    ; write sends a byte to the PC, read takes the byte from the PC
.equ UART_STATUS,        0xFFFF_8008    ; read, bit 0 = busy sending, bit 1 = a byte is waiting
.equ KEYBOARD_DATA,      0xFFFF_800C    ; write sends a command byte, read takes the scan code byte
.equ KEYBOARD_STATUS,    0xFFFF_8010    ; read, bit 0 = sending, bit 1 = a byte is waiting
.equ MOUSE_DATA,         0xFFFF_8014    ; write sends a command byte (0xF4 = start), read takes a packet byte
.equ MOUSE_STATUS,       0xFFFF_8018    ; read, bit 0 = sending, bit 1 = a byte is waiting
.equ INTERRUPTS_PENDING, 0xFFFF_801C    ; read, which doorbells are ringing (INTERRUPT_ bits)
.equ INTERRUPTS_ENABLED, 0xFFFF_8020    ; write/read, which doorbells may ring the CPU, all 0 after reset
.equ TIMER,              0xFFFF_8024    ; read ticks, hundredths of a second since reset, write anything = acknowledge
.equ SPI_DATA,           0xFFFF_8028    ; write swaps this byte with the selected device, read the byte that came back
.equ SPI_STATUS,         0xFFFF_802C    ; read, bit 0 = busy swapping, bit 1 = the Ethernet chip INT is low
                                         ; a packet arrived
.equ SPI_SELECT,         0xFFFF_8030    ; write/read, bit 0 = 1 selects the SD card
                                         ; bit 1 = 1 selects the ENC28J60 (pins 56, 54, 51, 48)
                                         ; bit 7 = 1 holds the ENC28J60 in reset (pin 49 low)
.equ SPI_SPEED,          0xFFFF_8034    ; write/read, system clock ticks per half SPI tick, 34 = 397 kHz, 3 = 4.5 MHz
.equ I2C_PINS,           0xFFFF_8038    ; write bit 0 = SCL, bit 1 = SDA, 1 = let go (pulled high), 0 = pull low
                                         ; read the two wires as they are
; graphics card, 0xFFFF_9000 - 0xFFFF_9FFF
.equ GRAPHICS_CONTROL,   0xFFFF_9000    ; write/read, which layers are on (LAYER_ bits), text only after reset
.equ GRAPHICS_PAGE,      0xFFFF_9004    ; write the page to show (0 or 1), from the next frame
                                         ; read, bit 0 = wanted, bit 8 = shown now
.equ GRAPHICS_FRAME,     0xFFFF_9008    ; read, frames since reset, 60 a second
.equ POINTER_X,          0xFFFF_900C    ; write/read, pointer top-left dot, 0-639
.equ POINTER_Y,          0xFFFF_9010    ; 0-479
.equ POINTER_COLOUR_1,   0xFFFF_9014    ; write/read, 0x00RRGGBB for pointer dots of value 1
.equ POINTER_COLOUR_2,   0xFFFF_9018    ; value 2
.equ POINTER_COLOUR_3,   0xFFFF_901C    ; value 3
.equ POINTER_PICTURE,    0xFFFF_9100    ; write 16 words, pointer rows 0-15, dot c = bits 2c+1..2c, 0 = see-through
.equ PALETTE,            0xFFFF_9400    ; write 256 words, colour 0-255 = 0x00RRGGBB
; the blitter
.equ BLIT_DEST,          0xFFFF_9200    ; destination base address, a multiple of 1 KB, like PAGE_0
.equ BLIT_DEST_POINT,    0xFFFF_9204    ; where in it, x | (y << 16)
.equ BLIT_SIZE,          0xFFFF_9208    ; width | (height << 16)
.equ BLIT_SOURCE,        0xFFFF_920C    ; source base address, for copies
.equ BLIT_SOURCE_POINT,  0xFFFF_9210    ; where in the source, x | (y << 16)
.equ BLIT_COLOURS,       0xFFFF_9214    ; bits 7-0 = colour, bits 15-8 = background for letters, or the skipped colour
.equ BLIT_LETTER,        0xFFFF_9218    ; which letter, 0-255
.equ BLIT_GO,            0xFFFF_921C    ; write a job to start it, read bit 0 = busy

; ---- bits in the status words, ANDI R4, R4, BYTE_WAITING ----
.equ UART_BUSY,          0x0001         ; UART_STATUS bit 0, still sending
.equ SENDING,            0x0001         ; KEYBOARD_STATUS / MOUSE_STATUS bit 0, command still going out
.equ BYTE_WAITING,       0x0002         ; bit 1 of all three status words, a byte has arrived
.equ SPI_BUSY,           0x0001         ; SPI_STATUS bit 0, swap still going on
.equ SELECT_SD_CARD,     0x0001         ; SPI_SELECT bit 0, the SD card
.equ SPI_SLOW,           34             ; SPI_SPEED for waking an SD card, 397 kHz
.equ SPI_FAST,           3              ; SPI_SPEED once the SD card is awake, 4.5 MHz
.equ LAYER_PIXELS,       0x0001         ; GRAPHICS_CONTROL bit 0, the pixel screen
.equ LAYER_TEXT,         0x0002         ; bit 1, the text screen, background colour 0 is see-through
.equ LAYER_POINTER,      0x0004         ; bit 2, the mouse pointer
.equ BLIT_FILL,          1              ; blitter jobs, write one to BLIT_GO
.equ BLIT_COPY,          2
.equ BLIT_COPY_SEE_THROUGH, 3
.equ BLIT_LETTER_JOB,    4              ; a letter on its background
.equ BLIT_LETTER_SEE_THROUGH, 5         ; a letter's dots only
.equ TEXT_BACKGROUND,    0x0001_0000    ; DRAW_TEXT, add to the colour to fill around the letters
                                         ; with the colour in bits 15-8, 0x0001_0700 + 0x0F

; ---- the doorbell bits (INTERRUPTS_PENDING and INTERRUPTS_ENABLED) ----
.equ INTERRUPT_TIMER,    0x0001         ; bit 0
.equ INTERRUPT_KEYBOARD, 0x0002         ; bit 1
.equ INTERRUPT_MOUSE,    0x0004         ; bit 2
.equ INTERRUPT_UART,     0x0008         ; bit 3

; ---- CAUSE values (GETCAUSE, in the handler) ----
.equ CAUSE_DOORBELL,     0x0000_0000    ; a device rang, read INTERRUPTS_PENDING
.equ CAUSE_DIVIDE_BY_ZERO,  0x0001_0000
.equ CAUSE_ROM_WRITE,    0x0001_0001    ; not wired yet, the bus ignores the write
.equ CAUSE_MISALIGNED,   0x0001_0002    ; LOAD/STORE at an address not a multiple of 4
.equ CAUSE_STACK_OVERFLOW, 0x0001_0003  ; PUSH/CALL would take R15SP below SLIM

; ---- the timer ----
.equ TICKS_PER_SECOND,   100            ; timer rings every 1/100 of a second
