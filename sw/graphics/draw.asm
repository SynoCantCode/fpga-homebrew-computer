; graphics routines, drawing on the pixel screen
; part of the boot ROM, jump table entries 27-35
; a page is 480 rows of 1 KB in the SDRAM, one byte per dot
; a byte is a colour number, the palette makes it red/green/blue
; dot (x, y) = page + (y << 10) + x
; 2 pages, PAGE_0 and PAGE_1
; DRAW_PAGE is drawn on, GRAPHICS_PAGE is shown
; DRAW_FLIP swaps them
; point = x | (y << 16), size = width | (height << 16)
; x >= 640 or y >= 480 is clipped
; R1-R7 may be wrecked, R8-R14 are kept

; graphics_init, start-up for the graphics card
; colour 0 = 16 greys, colours 1-14 = 16 shades each
; colour 15 = the 16 free colours
; pointer picture and colours from designs/pointer.asm
; page 0 shown and drawn on, mouse in the middle, text layer only
graphics_init: PUSH R8
        PUSH   R9
        LOADLO R8, 0                    ; R8 = colour number, greys first
init_greys: LOADHI R2, 0x0011
        ORI    R2, R2, 0x1111           ; 0x111111 x the shade
        MUL    R2, R2, R8
        MOV    R1, R8
        CALL   set_colour
        INC    R8
        CMPI   R8, 0x0010
        JNZ    init_greys
        LOADLO R9, palette_colours      ; R9 = pointer to colour 1's middle shade
init_shades: LOAD R1, [R9]
        ANDI   R2, R8, 0x000F           ; shade = bottom 4 bits
        CALL   shade_of                 ; R1 = that shade
        MOV    R2, R1
        MOV    R1, R8
        CALL   set_colour
        INC    R8
        TESTI  R8, 0x000F
        JNZ    init_shades              ; next shade
        ADDI   R9, R9, 4                ; next colour
        CMPI   R8, 0x00F0
        JNZ    init_shades
        LOADLO R9, palette_free         ; colour 15, the free colours
init_free: LOAD R2, [R9]
        MOV    R1, R8
        CALL   set_colour
        ADDI   R9, R9, 4
        INC    R8
        CMPI   R8, 0x0100
        JNZ    init_free
        LOADLO R9, pointer_picture      ; the pointer, 16 rows
        LOADHI R8, 0xFFFF
        ORI    R8, R8, 0x9100           ; R8 = POINTER_PICTURE row 0
init_pointer: LOAD R1, [R9]
        STORE  R1, [R8]
        ADDI   R9, R9, 4
        ADDI   R8, R8, 4
        TESTI  R8, 0x0040
        JZ     init_pointer             ; until 0xFFFF_9140
        LOADLO R9, pointer_colours
        LOAD   R1, [R9]
        STORE  R1, [POINTER_COLOUR_1]
        LOAD   R1, [R9 + 4]
        STORE  R1, [POINTER_COLOUR_2]
        LOAD   R1, [R9 + 8]
        STORE  R1, [POINTER_COLOUR_3]
        STORE  R0, [GRAPHICS_PAGE]      ; show page 0
        LOADHI R1, PAGE_0_HIGH
        STORE  R1, [DRAW_PAGE]          ; draw on page 0
        LOADLO R1, 320
        STORE  R1, [MOUSE_X]            ; mouse in the middle
        LOADLO R1, 240
        STORE  R1, [MOUSE_Y]
        STORE  R0, [MOUSE_BUTTONS]
        STORE  R0, [MOUSE_PACKET_COUNT]
        LOADLO R1, LAYER_TEXT
        STORE  R1, [GRAPHICS_CONTROL]   ; text layer only
        POP    R9
        POP    R8
        RET

; shade_of, one shade of a colour, each channel on its own
; shades 0-8 = channel x (shade + 1) / 9
; shades 9-15 = channel + (255 - channel) x (shade - 8) / 8
; in R1 = 0x00RRGGBB, R2 = shade 0-15, out R1 = 0x00RRGGBB, uses R1-R7
shade_of: LOADLO R3, 0                  ; R3 = the answer
        LOADLO R4, 16                   ; R4 = channel shift, 16 red, 8 green, 0 blue
shade_channel: SHIFT R5, R1, R4, 0b1000
        ANDI   R5, R5, 0x00FF           ; R5 = this channel
        CMPI   R2, 9
        JC     shade_lighter            ; shade 9 or more
        ADDI   R6, R2, 1
        MUL    R5, R5, R6
        DIVUI  R5, R5, 9
        JUMP   shade_put
shade_lighter: LOADLO R6, 255
        SUB    R6, R6, R5               ; room left to white
        SUBI   R7, R2, 8
        MUL    R6, R6, R7
        SHIFTI R6, R6, 0x03, 0b1000     ; / 8
        ADD    R5, R5, R6
shade_put: SHIFT R5, R5, R4, 0b0000     ; back in place
        OR     R3, R3, R5
        CMPI   R4, 0x0000
        JZ     shade_done
        SUBI   R4, R4, 8
        JUMP   shade_channel
shade_done: MOV R1, R3
        RET

; SET_COLOUR, in R1 = colour number 0-255, R2 = 0x00RRGGBB, uses R1, R3
set_colour: ANDI R1, R1, 0x00FF
        SHIFTI R1, R1, 0x02, 0b0000     ; x 4
        LOADHI R3, 0xFFFF
        ORI    R3, R3, 0x9400           ; PALETTE
        ADD    R3, R3, R1
        STORE  R2, [R3]
        RET

; GRAPHICS_MODE, in R1 = layers on, LAYER_PIXELS + LAYER_TEXT + LAYER_POINTER
graphics_mode: STORE R1, [GRAPHICS_CONTROL]
        RET

; DRAW_PIXEL, in R1 = point, R2 = colour, uses R1-R5
draw_pixel: MOV R5, R1
        CALL   blit_wait                ; blitter finishes first
        MOV    R1, R5
        ANDI   R3, R1, 0xFFFF           ; R3 = x
        SHIFTI R4, R1, 0x10, 0b1000     ; R4 = y
        CMPI   R3, PIXELS_ACROSS
        JC     pixel_done               ; off the right edge
        CMPI   R4, PIXELS_DOWN
        JC     pixel_done               ; off the bottom
        LOAD   R5, [DRAW_PAGE]
        SHIFTI R4, R4, 0x0A, 0b0000     ; y x 1024
        ADD    R5, R5, R4
        ADD    R5, R5, R3               ; R5 = pointer to the dot
        STOREB R2, [R5]
pixel_done: RET

; DRAW_RECT, a filled box, in R1 = top-left point, R2 = size, R3 = colour
; cut to the screen, then filled by the blitter
; returns before the fill is finished
; R4 = x0, R5 = y0, R6 = x1, R7 = y1, x1 and y1 just past the end
draw_rect: ANDI R4, R1, 0xFFFF
        SHIFTI R5, R1, 0x10, 0b1000
        ANDI   R6, R2, 0xFFFF
        ADD    R6, R4, R6
        SHIFTI R7, R2, 0x10, 0b1000
        ADD    R7, R5, R7
        CMPI   R6, PIXELS_ACROSS
        JNC    rect_right_ok
        LOADLO R6, PIXELS_ACROSS        ; cut at the right edge
rect_right_ok: CMPI R7, PIXELS_DOWN
        JNC    rect_bottom_ok
        LOADLO R7, PIXELS_DOWN          ; cut at the bottom
rect_bottom_ok: CMP R4, R6
        JC     rect_done                ; nothing left
        CMP    R5, R7
        JC     rect_done
        CALL   blit_wait                ; blitter finishes first
        LOAD   R1, [DRAW_PAGE]
        STORE  R1, [BLIT_DEST]
        SHIFTI R1, R5, 0x10, 0b0000
        OR     R1, R1, R4
        STORE  R1, [BLIT_DEST_POINT]    ; (x0, y0)
        SUB    R6, R6, R4               ; width
        SUB    R7, R7, R5               ; height
        SHIFTI R7, R7, 0x10, 0b0000
        OR     R6, R6, R7
        STORE  R6, [BLIT_SIZE]
        STORE  R3, [BLIT_COLOURS]
        LOADLO R1, BLIT_FILL
        STORE  R1, [BLIT_GO]
rect_done: RET

; blit_wait, waits until BLIT_GO bit 0 is 0, uses R1
blit_wait: LOAD R1, [BLIT_GO]
        TESTI  R1, 0x0001
        JNZ    blit_wait
        RET

; DRAW_WAIT, the same for programs
; call before reading or writing dots yourself
draw_wait: JUMP blit_wait

; DRAW_COPY, copies a box from a page shaped place to the drawing page
; in R1 = dest point, R2 = size
; R3 = source base, a multiple of 1 KB, R4 = source point
; DRAW_SPRITE, the same but one colour is skipped
; the colour is R3's bottom 8 bits, like 0x1010_0000 + 0xEE
; both cut at the right and bottom edges
; R8 = dest point, R9 = blitter job, R5, R6 = room, R1, R7 = width, height
draw_copy: PUSH R8
        PUSH   R9
        LOADLO R9, BLIT_COPY
        JUMP   copy_start
draw_sprite: PUSH R8
        PUSH   R9
        LOADLO R9, BLIT_COPY_SEE_THROUGH
copy_start: MOV R8, R1
        ANDI   R5, R1, 0xFFFF           ; x
        SHIFTI R6, R1, 0x10, 0b1000     ; y
        CMPI   R5, PIXELS_ACROSS
        JC     copy_done                ; starts off the screen
        CMPI   R6, PIXELS_DOWN
        JC     copy_done
        LOADLO R1, PIXELS_ACROSS
        SUB    R5, R1, R5               ; R5 = room to the right edge
        LOADLO R1, PIXELS_DOWN
        SUB    R6, R1, R6               ; R6 = room to the bottom
        ANDI   R1, R2, 0xFFFF           ; R1 = width
        CMP    R1, R5
        JNC    copy_width_ok
        MOV    R1, R5                   ; cut
copy_width_ok: SHIFTI R7, R2, 0x10, 0b1000 ; R7 = height
        CMP    R7, R6
        JNC    copy_height_ok
        MOV    R7, R6                   ; cut
copy_height_ok: SHIFTI R7, R7, 0x10, 0b0000
        OR     R2, R7, R1               ; R2 = the cut size
        CALL   blit_wait
        LOAD   R1, [DRAW_PAGE]
        STORE  R1, [BLIT_DEST]
        STORE  R8, [BLIT_DEST_POINT]
        STORE  R2, [BLIT_SIZE]
        STORE  R3, [BLIT_SOURCE]        ; the key bits dont matter here
        STORE  R4, [BLIT_SOURCE_POINT]
        SHIFTI R1, R3, 0x08, 0b0000
        STORE  R1, [BLIT_COLOURS]       ; the key goes in bits 15-8
        STORE  R9, [BLIT_GO]
copy_done: POP R9
        POP    R8
        RET

; DRAW_CLEAR, fills the drawing page, in R1 = colour
draw_clear: MOV R3, R1
        LOADLO R1, 0
        LOADHI R2, PIXELS_DOWN
        ORI    R2, R2, PIXELS_ACROSS
        JUMP   draw_rect                ; tail call

; DRAW_LINE, both ends included, in R1 = from, R2 = to, R3 = colour
; Bresenham, one dot at a time
; R8 = x, R9 = y, R10 = end point, R11 = colour, R12 = dx = |x_end - x|
; R13 = dy = -|y_end - y|, R14 = err, R6 = x step, R7 = y step
draw_line: PUSH R8
        MOV    R8, R1
        CALL   blit_wait                ; blitter finishes first
        MOV    R1, R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        PUSH   R13
        PUSH   R14
        ANDI   R8, R1, 0xFFFF
        SHIFTI R9, R1, 0x10, 0b1000
        MOV    R10, R2
        MOV    R11, R3
        ANDI   R2, R10, 0xFFFF          ; x_end
        SUB    R12, R2, R8
        LOADLO R6, 1
        CMPIS  R12, 0
        JGE    line_dx_ready
        NEG    R12, R12                 ; going left, step -1
        NOT    R6, R0
line_dx_ready: SHIFTI R3, R10, 0x10, 0b1000 ; y_end
        SUB    R13, R3, R9
        CMPIS  R13, 0
        JGE    line_going_down
        NOT    R7, R0                   ; going up, step -1
        JUMP   line_dy_ready
line_going_down: LOADLO R7, 1
        NEG    R13, R13
line_dy_ready: ADD R14, R12, R13        ; err = dx + dy
line_dot: CMPI R8, PIXELS_ACROSS
        JC     line_skip_dot
        CMPI   R9, PIXELS_DOWN
        JC     line_skip_dot
        LOAD   R1, [DRAW_PAGE]
        SHIFTI R2, R9, 0x0A, 0b0000
        ADD    R1, R1, R2
        ADD    R1, R1, R8
        STOREB R11, [R1]
line_skip_dot: SHIFTI R2, R9, 0x10, 0b0000
        ANDI   R3, R8, 0xFFFF
        OR     R2, R2, R3               ; this dot as a point
        CMP    R2, R10
        JZ     line_done                ; the end
        ADD    R1, R14, R14             ; e2 = 2 x err
        CMP    R1, R13
        JLT    line_no_across
        ADD    R14, R14, R13            ; e2 >= dy, step across
        ADD    R8, R8, R6
line_no_across: CMP R1, R12
        JGT    line_dot
        ADD    R14, R14, R12            ; e2 <= dx, step down or up
        ADD    R9, R9, R7
        JUMP   line_dot
line_done: POP R14
        POP    R13
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; DRAW_TEXT, letters as pixels, 8 x 16 dots each
; in R1 = top-left point, R2 = pointer to 0-ended text
; R3 = colour in bits 7-0, + TEXT_BACKGROUND (bit 16) = background in bits 15-8
; without it only the letters dots are drawn
; a letter that doesnt fit whole is left out
; R8 = x, R9 = y, R10 = text pointer, R11 = colours, R12 = blitter job
draw_text: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        ANDI   R8, R1, 0xFFFF
        SHIFTI R9, R1, 0x10, 0b1000
        MOV    R10, R2
        MOV    R11, R3
        LOADLO R12, BLIT_LETTER_SEE_THROUGH
        SHIFTI R1, R11, 0x10, 0b1000
        TESTI  R1, 0x0001
        JZ     text_letter
        LOADLO R12, BLIT_LETTER_JOB     ; letters on a background
text_letter: LOADB R2, [R10]
        CMPI   R2, 0x0000
        JZ     text_done
        ADDI   R1, R8, 8
        CMPI   R1, PIXELS_ACROSS + 1
        JC     text_next                ; past the right edge, left out
        ADDI   R1, R9, 16
        CMPI   R1, PIXELS_DOWN + 1
        JC     text_next                ; past the bottom
        CALL   blit_wait
        LOAD   R1, [DRAW_PAGE]
        STORE  R1, [BLIT_DEST]
        SHIFTI R1, R9, 0x10, 0b0000
        OR     R1, R1, R8
        STORE  R1, [BLIT_DEST_POINT]
        STORE  R11, [BLIT_COLOURS]
        STORE  R2, [BLIT_LETTER]
        STORE  R12, [BLIT_GO]
text_next: ADDI R8, R8, 8               ; next letter
        INC    R10
        JUMP   text_letter
text_done: POP R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; DRAW_FLIP, show the drawing page, then draw on the other one
; pages change at the top of a frame, so it waits for GRAPHICS_FRAME
; gives up after about 2 frames
; uses R1-R5
draw_flip: CALL blit_wait               ; blitter finishes first
        LOAD   R1, [DRAW_PAGE]
        LOADHI R2, PAGE_1_HIGH
        LOADLO R3, 0
        CMP    R1, R2
        JNZ    flip_show
        LOADLO R3, 1                    ; drawing page is page 1
flip_show: LOAD R4, [GRAPHICS_FRAME]
        STORE  R3, [GRAPHICS_PAGE]      ; shown from the next frame
        LOADHI R5, 0x0003               ; R5 = wait count
flip_wait: LOAD R1, [GRAPHICS_FRAME]
        CMP    R1, R4
        JNZ    flip_shown
        DEC    R5, 0b0100
        JNZ    flip_wait
flip_shown: LOADHI R1, PAGE_0_HIGH      ; draw on the other page
        CMPI   R3, 0x0001
        JZ     flip_draw_on
        LOADHI R1, PAGE_1_HIGH
flip_draw_on: STORE R1, [DRAW_PAGE]
        RET

; MOUSE_STATE, reads the waiting mouse packets and moves the pointer
; packet = buttons + sign bits (bit 3 always 1), x move, y move (up = +)
; MOUSE_PACKET_SIZE = 4 is a wheel mouse, a fourth byte goes to MOUSE_WHEEL
; the mouse must be woken first with mouse_start, 0xFA answers are skipped
; out R1 = pointer place, R2 = buttons, bit 0 left, 1 right, 2 middle, uses R1-R7
; R8 = the byte just read
mouse_state: PUSH R8
mouse_next: CALL get_mouse_byte
        CMPIS  R1, -1
        JZ     mouse_report             ; nothing more waiting
        MOV    R8, R1
        LOAD   R2, [MOUSE_PACKET_COUNT]
        CMPI   R2, 0x0000
        JNZ    mouse_not_first
        CMPI   R8, 0x00FA
        JZ     mouse_next               ; 0xFA, not part of a packet
        TESTI  R8, 0x0008
        JZ     mouse_next               ; bit 3 not set, out of step
        STORE  R8, [MOUSE_PACKET_FIRST]
        LOADLO R2, 1
        STORE  R2, [MOUSE_PACKET_COUNT]
        JUMP   mouse_next
mouse_not_first: CMPI R2, 0x0001
        JNZ    mouse_later
        STORE  R8, [MOUSE_PACKET_X]
        LOADLO R2, 2
        STORE  R2, [MOUSE_PACKET_COUNT]
        JUMP   mouse_next
mouse_later: CMPI R2, 0x0002
        JNZ    mouse_fourth
        LOAD   R3, [MOUSE_PACKET_SIZE]
        CMPI   R3, 4
        JNZ    mouse_third              ; plain mouse, third byte is the last
        STORE  R8, [MOUSE_PACKET_Y]     ; wheel mouse, keep the y move
        LOADLO R2, 3
        STORE  R2, [MOUSE_PACKET_COUNT]
        JUMP   mouse_next
mouse_fourth: ANDI R3, R8, 0x000F       ; fourth byte, wheel move, 4 bits, -8 to 7
        TESTI  R3, 0x0008
        JZ     mouse_wheel_ready
        LOADHI R4, 0xFFFF
        ORI    R4, R4, 0xFFF0
        OR     R3, R3, R4               ; bit 3 = negative, sign extend
mouse_wheel_ready: LOAD R4, [MOUSE_WHEEL]
        ADD    R4, R4, R3
        STORE  R4, [MOUSE_WHEEL]        ; added up for the program
        LOAD   R8, [MOUSE_PACKET_Y]     ; R8 = the y move
mouse_third: STORE R0, [MOUSE_PACKET_COUNT] ; packet complete
        LOAD   R3, [MOUSE_PACKET_FIRST]
        LOAD   R4, [MOUSE_PACKET_X]
        TESTI  R3, 0x0010
        JZ     mouse_x_ready
        LOADHI R5, 0xFFFF
        ORI    R5, R5, 0xFF00
        OR     R4, R4, R5               ; bit 4 = x move negative, sign extend
mouse_x_ready: LOAD R5, [MOUSE_X]
        ADD    R5, R5, R4
        CMPIS  R5, 0
        JGE    mouse_x_not_low
        LOADLO R5, 0                    ; keep x in 0-639
mouse_x_not_low: CMPI R5, PIXELS_ACROSS
        JLT    mouse_x_ok
        LOADLO R5, PIXELS_ACROSS - 1
mouse_x_ok: STORE R5, [MOUSE_X]
        MOV    R4, R8                   ; y move, sign is bit 5, subtracted
        TESTI  R3, 0x0020
        JZ     mouse_y_ready
        LOADHI R5, 0xFFFF
        ORI    R5, R5, 0xFF00
        OR     R4, R4, R5
mouse_y_ready: LOAD R5, [MOUSE_Y]
        SUB    R5, R5, R4
        CMPIS  R5, 0
        JGE    mouse_y_not_low
        LOADLO R5, 0
mouse_y_not_low: CMPI R5, PIXELS_DOWN
        JLT    mouse_y_ok
        LOADLO R5, PIXELS_DOWN - 1
mouse_y_ok: STORE R5, [MOUSE_Y]
        ANDI   R3, R3, 0x0007
        STORE  R3, [MOUSE_BUTTONS]
        JUMP   mouse_next
mouse_report: LOAD R1, [MOUSE_X]
        STORE  R1, [POINTER_X]          ; the pointer follows
        LOAD   R2, [MOUSE_Y]
        STORE  R2, [POINTER_Y]
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2               ; R1 = the point
        LOAD   R2, [MOUSE_BUTTONS]
        POP    R8
        RET

; the designs, data
.include "designs/palette.asm"
.include "designs/pointer.asm"
