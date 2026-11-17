; jump table, the kernels entry points
; must be the first code in the ROM so the addresses never move
; programs CALL an entry, the entry JUMPs to the routine
; entries 18, 19 and 21-25 are in KERNEL.BIN
; they go through a bridge in the ROM and KERNEL_TABLE
; never reorder or remove an entry, add at the end
; in R1-R4, out R1, may change R1-R7, keeps R8-R14

        JUMP   start                    ; entry 0, 0x0000, reset starts here
        JUMP   get_key_byte             ; entry 1, 0x0004, GET_KEY_BYTE, out R1 = raw keyboard byte or -1
        JUMP   get_mouse_byte           ; entry 2, 0x0008, GET_MOUSE_BYTE, out R1 = raw mouse byte or -1
        JUMP   get_serial_byte          ; entry 3, 0x000C, GET_SERIAL_BYTE, out R1 = byte from the PC or -1
        JUMP   get_char                 ; entry 4, 0x0010, GET_CHAR, out R1 = character typed or -1
        JUMP   send_byte                ; entry 5, 0x0014, SEND_BYTE, in R1 = byte to the PC
        JUMP   print_text               ; entry 6, 0x0018, PRINT_TEXT, in R1 = text, 0 ended, to the PC
        JUMP   print_line               ; entry 7, 0x001C, PRINT_LINE, in R1 = text, then a new line
        JUMP   print_byte_hex           ; entry 8, 0x0020, PRINT_BYTE_HEX, in R1 = byte, sent as 2 hex digits
        JUMP   screen_char              ; entry 9, 0x0024, SCREEN_CHAR, in R1 = character, at the cursor
        JUMP   screen_text              ; entry 10, 0x0028, SCREEN_TEXT, in R1 = text, onto the screen
        JUMP   screen_line              ; entry 11, 0x002C, SCREEN_LINE, in R1 = text, then a new line
        JUMP   screen_clear             ; entry 12, 0x0030, SCREEN_CLEAR, blank screen, cursor top left
        JUMP   screen_hex_word          ; entry 13, 0x0034, SCREEN_HEX_WORD, in R1 = number, as 8 hex digits
        JUMP   read_line                ; entry 14, 0x0038, READ_LINE, waits for a line, out R1 = pointer to it
        JUMP   sd_init                  ; entry 15, 0x003C, SD_INIT, out R1 = 0 or error
        JUMP   sd_read_block            ; entry 16, 0x0040, SD_READ_BLOCK, in R1 = block, R2 = 512 bytes, out R1 = 0 or error
        JUMP   sd_write_checked         ; entry 17, 0x0044, SD_WRITE_BLOCK, in R1 = block, R2 = 512 bytes, out R1 = 0 or error
                            ; refuses the file systems blocks with 16
        JUMP   to_allocate              ; entry 18, 0x0048, ALLOCATE, in R1 = bytes wanted, out R1 = pointer or 0
        JUMP   to_free                  ; entry 19, 0x004C, FREE, in R1 = pointer from ALLOCATE
        JUMP   file_read                ; entry 20, 0x0050, FILE_READ, in R1 = file name, R2 = where to, out R1 = 0 or error, R2 = size
        JUMP   to_file_write            ; entry 21, 0x0054, FILE_WRITE, in R1 = file name, R2 = bytes, R3 = count, out R1 = 0 or error
        JUMP   to_file_delete           ; entry 22, 0x0058, FILE_DELETE, in R1 = path, out R1 = 0 or error
        JUMP   to_folder_make           ; entry 23, 0x005C, FOLDER_MAKE, in R1 = path, out R1 = 0 or error
        JUMP   to_file_move             ; entry 24, 0x0060, FILE_MOVE, in R1 = old path, R2 = new path, out R1 = 0 or error
        JUMP   to_file_copy             ; entry 25, 0x0064, FILE_COPY, in R1 = old path, R2 = new path, out R1 = 0 or error
        JUMP   file_size                ; entry 26, 0x0068, FILE_SIZE, in R1 = path, out R1 = 0 or error, R2 = size
; graphics, point = x | (y << 16), size = width | (height << 16), colours 0-255
        JUMP   graphics_mode            ; entry 27, 0x006C, GRAPHICS_MODE, in R1 = layers on
        JUMP   draw_clear               ; entry 28, 0x0070, DRAW_CLEAR, in R1 = colour
        JUMP   draw_pixel               ; entry 29, 0x0074, DRAW_PIXEL, in R1 = point, R2 = colour
        JUMP   draw_line                ; entry 30, 0x0078, DRAW_LINE, in R1 = from, R2 = to, R3 = colour
        JUMP   draw_rect                ; entry 31, 0x007C, DRAW_RECT, in R1 = top left, R2 = size, R3 = colour
        JUMP   draw_text                ; entry 32, 0x0080, DRAW_TEXT, in R1 = top left, R2 = text, R3 = colours
        JUMP   draw_flip                ; entry 33, 0x0084, DRAW_FLIP, show the drawing page, draw on the other
        JUMP   set_colour               ; entry 34, 0x0088, SET_COLOUR, in R1 = colour number, R2 = 0x00RRGGBB
        JUMP   mouse_state              ; entry 35, 0x008C, MOUSE_STATE, out R1 = pointer position, R2 = buttons
        JUMP   draw_copy                ; entry 36, 0x0090, DRAW_COPY, in R1 = where, R2 = size, R3 = source base, R4 = where in it
        JUMP   draw_sprite              ; entry 37, 0x0094, DRAW_SPRITE, same, skips the colour in R3 low 8 bits
        JUMP   draw_wait                ; entry 38, 0x0098, DRAW_WAIT, waits for the blitter
; I2C, DS3231 clock at 0x68, MCP23017 pins at 0x20
        JUMP   i2c_read                 ; entry 39, 0x009C, I2C_READ, in R1 = chip, R2 = register, R3 = count, R4 = where to, out R1 = 0/1
        JUMP   i2c_write                ; entry 40, 0x00A0, I2C_WRITE, in R1 = chip, R2 = register, R3 = count, R4 = bytes, out R1 = 0/1
