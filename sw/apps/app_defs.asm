; app_defs, what an app needs to run in a window of WM.BIN
; an app is a folder /APPS/NAME/ with PAGE.TXT and APP.BIN
; APP.BIN is built from app.asm with make_app.py
; the window manager loads it into the heap and calls it
; the code must start with these 7 jumps and the rate
; +0  JUMP init, once at the start, R1 = window
; +4  JUMP tick, RATE times a second while open, R1 = window
; +8  JUMP key, a key while at the front, R1 = window, R2 = key
; +12 JUMP click, a click in the content, R1 = window, R2 = x, R3 = y
; +16 JUMP paint, draw the window, R1 = window
; +20 JUMP button, page button event N, R1 = window, R2 = N
; +24 JUMP close, the window was closed, R1 = window
; +28 .word RATE, ticks a second, 0 = none, 100 at most
; handlers keep R8-R14, R1-R7 are free
; a handler with nothing to do is just RET
; to change what is shown, CALLF WM_REDRAW with R1 = window
; variables are words inside the app, my_x: .word 0
; not PROGRAM_DATA, that belongs to the window manager
; the heap and kernel calls work as in any program
; window manager services, CALLF them, each keeps R8-R14, uses R1-R7
.include "sw/os/devices.asm"
; painting is from the content's top-left
; page row N is y = N x 16, it moves with the scroll
; anything outside the content isn't drawn
.equ WM_BOX,       PROGRAM_SDRAM + 4    ; in paint, a filled box, R1 = x, R2 = y
                                        ; R3 = width, R4 = height, R5 = colour
.equ WM_TEXT,      PROGRAM_SDRAM + 8    ; in paint, a text, 8 x 16 letters, R1 = x, R2 = y
                                        ; R3 = pointer to the text, R4 = colour
.equ WM_SIZE,      PROGRAM_SDRAM + 12   ; content size, in R1 = window, out R1 = width, R2 = height
.equ WM_REDRAW,    PROGRAM_SDRAM + 16   ; draw the window again soon, in R1 = window
.equ WM_WALLPAPER, PROGRAM_SDRAM + 20   ; new wallpaper, in R1 = pointer to a .PIC path or 0 for teal
                                        ; out R1 = its width, 0 = couldn't read it
.equ WM_NUMBER,    PROGRAM_SDRAM + 24   ; number to decimal, in R1 = number, R2 = where, 11 bytes
                                        ; out R2 = the 0 after the digits
.equ WM_APP_INFO,  PROGRAM_SDRAM + 28   ; an installed app, in R1 = its number 0-31
                                        ; out R1 = pointer to its name or 0, R2 = title
                                        ; R3 = icon file name or 0, R4 = icon label colour
                                        ; R5 = 1 on the desktop, 0 only in the search
                                        ; R6 = 0 app, 1 text, 2 program, 3 folder, 4 other file
.equ WM_SET_ICON,  PROGRAM_SDRAM + 32   ; set an app's desktop icon, in R1 = window
                                        ; R2 = pointer to a picture name that stays, or 0 for default
.equ WM_SET_LABEL, PROGRAM_SDRAM + 36   ; set an app's icon label colour, in R1 = window, R2 = colour
.equ WM_ICON,      PROGRAM_SDRAM + 40   ; in paint, an app's desktop icon, 32 x 32
                                        ; in R1 = window whose icon, R2 = x, R3 = y
.equ WM_OPEN,      PROGRAM_SDRAM + 44   ; open an app's window, in R1 = pointer to the app's name
                                        ; out R1 = 1, or 0 if no such app on the desktop
; named pieces, a page line can name its element, input #city 0 2 20 1
; the app reads and changes them by name
.equ WM_GET_TEXT,  PROGRAM_SDRAM + 48   ; a named element's text
                                        ; in R1 = window, R2 = pointer to the name, no #
                                        ; out R1 = pointer to the text, or 0
.equ WM_SET_DESKTOP, PROGRAM_SDRAM + 56  ; put an app's icon on or off the desktop, saved in APPS.TXT
                                        ; in R1 = its number, R2 = 1 on, 0 off
                                        ; out R1 = 1 done, 0 refused, Settings always stays
.equ WM_SET_TEXT,  PROGRAM_SDRAM + 52   ; a named element shows a new text
                                        ; in R1 = window, R2 = pointer to the name, R3 = pointer to the text
                                        ; an input copies it, anything else shows it so it must stay
                                        ; out R1 = 1, or 0 for no such name
; decorations, pictures on the desktop under the windows
; kept in /SYSTEM/DESIGN/DECOR.TXT
; looked up in BIGSPRTS first, then SPRITES
.equ WM_DECORATE,  PROGRAM_SDRAM + 60   ; add a decoration in the middle of the screen, saved
                                        ; in R1 = pointer to its picture name, out R1 = 1 added, 0 not
.equ WM_UNDECORATE, PROGRAM_SDRAM + 64  ; remove every decoration, saved, out R1 = 1
.equ WM_PICTURE,   PROGRAM_SDRAM + 68   ; in paint, a picture's first frame, see-through
                                        ; in R1 = x, R2 = y, R3 = pointer to its name
                                        ; out R1 = width in bits 15-0, height in 31-16, 0 = no picture
; Enter in a one row input goes to the key handler, R2 = 0x0A

; keys are letters as they are, Enter 0x0A, Backspace 0x08, Space 0x20
; arrows KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, 0x80-0x83
