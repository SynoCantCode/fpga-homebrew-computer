; WM, the window manager.   run wm.bin [WALLPAPER.PIC]   Esc goes to the shell
; compositing, every window has its own picture in the SDRAM, rows 1 KB apart
; drawn again only when the window changes
; the blitter copies everything to the hidden page, back to front, then DRAW_FLIP
; 1. the wallpaper, or plain teal
; 2. the desktop icons, key colour 0xFE is see-through
; 3. each visible window's picture in stacking order, then its title bar
; 4. the taskbar, a button for each window
; cells, each window is a grid of cells like the text screen
; a cell is a letter and its colour, 2 bytes, kept in the heap
; the window's size in dots follows from its cells, text is wrapped
; apps, /APPS/APPS.TXT lists them, one folder name a line
; each app is a folder /APPS/NAME/ with PAGE.TXT, one line each
; title TEXT                  the title bar's text, else the folder's name
; size COLUMNS ROWS           its cells, else 30 x 6
; place X Y                   where it starts, else one below another
; hidden                      it starts closed
; colour NN                   hex colour of the text lines after it, else 00
; text COLUMN ROW TEXT        a text from that cell, not wrapped
; wrap ROW TEXT               a paragraph wrapped to the window's width
; box COLUMN ROW WIDTH HEIGHT TEXT   a paragraph wrapped inside that box
; animate COLUMN ROW FILE.PIC FRAMEWIDTH FRAMES SPEED   a picture strip played there
; SPEED frames a second, up to 10
; input COLUMN ROW WIDTH HEIGHT     a box you can type into
; emptied when the window closes
; style NAME                  /SYSTEM/DESIGN/WINDOWS/NAME/STYLE.TXT, else the default
; button COLUMN ROW LABEL ACTION   ACTION is close, or open NAME
; image COLUMN ROW FILE.PIC   a picture from the app's folder, 0xFE is see-through
; shell COMMAND               a full-screen app, its shell lines go to NEXT_COMMANDS
; and WM ends, the shell runs them
; `shell run /wm.bin` as the last brings the desktop back
; ICON.PIC (32 x 32, 0xFE see-through) is its desktop icon, wider than 32 animates
; lines starting with ; are notes
; styles, where every part of a window goes and its colours
; frame, panel, margins, header, title, close box, decoration pictures
; numbers below 0 count from the right / bottom edge
; the default style is grey Windows 95
; mouse, click a window to bring it to the front, drag its title bar to move it
; drag the bottom-right grip to resize, x closes, _ minimises, box = full screen
; a taskbar button shows or hides its window, a desktop icon opens its window
; runs in the SDRAM, LA for own labels, CALLF for the jump table
; variables in block RAM at PROGRAM_DATA, set at the start
.include "sw/os/devices.asm"
.include "sw/graphics/programs/winlib_defs.asm"   ; the shared names

.org PROGRAM_SDRAM

; first word = where `run wm.bin` starts, then the services apps call
; these addresses never move
        JUMP   start                    ; PROGRAM_SDRAM + 0
        JUMP   api_box                  ;              + 4   WM_BOX
        JUMP   api_text                 ;              + 8   WM_TEXT
        JUMP   api_size                 ;              + 12  WM_SIZE
        JUMP   api_redraw               ;              + 16  WM_REDRAW
        JUMP   api_wallpaper            ;              + 20  WM_WALLPAPER
        JUMP   api_number               ;              + 24  WM_NUMBER
        JUMP   api_app_info             ;              + 28  WM_APP_INFO
        JUMP   api_set_icon             ;              + 32  WM_SET_ICON
        JUMP   api_set_label            ;              + 36  WM_SET_LABEL
        JUMP   api_icon                 ;              + 40  WM_ICON
        JUMP   api_open                 ;              + 44  WM_OPEN
        JUMP   api_get_text             ;              + 48  WM_GET_TEXT
        JUMP   api_set_text             ;              + 52  WM_SET_TEXT
        JUMP   api_set_desktop          ;              + 56  WM_SET_DESKTOP
        JUMP   api_decorate             ;              + 60  WM_DECORATE
        JUMP   api_undecorate           ;              + 64  WM_UNDECORATE
        JUMP   api_picture              ;              + 68  WM_PICTURE

.include "sw/graphics/wm/start.asm"                            ; starting up, the main loop, quitting
.include "sw/graphics/wm/compose.asm"                          ; the whole screen drawn on the hidden page, then shown
.include "sw/graphics/wm/menus.asm"                            ; right-click menus, the shell's note
.include "sw/graphics/wm/hover.asm"                            ; what's under the pointer, full screen, animation
.include "sw/graphics/wm/taskbar.asm"                          ; the taskbar, window buttons, tray, search box
.include "sw/graphics/wm/windows.asm"                          ; window slots, each window's picture
.include "sw/graphics/wm/click.asm"                            ; clicks, dragging, resizing, raising
.include "sw/graphics/wm/icons.asm"                            ; the wallpaper's name, the desktop icons' picture
.include "sw/graphics/wm/apps.asm"                             ; APPS.TXT read, records, opening, closing, saving
.include "sw/graphics/wm/desktop_files.asm"                    ; /DESKTOP's files and folders as icons
.include "sw/graphics/wm/decor.asm"                            ; pictures on the desktop, DECOR.TXT
.include "sw/graphics/wm/icon_places.asm"                     ; where icons sit, ICONS.TXT, dragging them
.include "sw/graphics/wm/input.asm"                            ; page buttons, typing into inputs, closing a window, keys
.include "sw/graphics/wm/pointer.asm"                          ; the mouse pointer's picture, POINTER.PTR
.include "sw/graphics/wm/services.asm"                         ; services only WM gives apps
.include "sw/graphics/wm/texts.asm"                            ; WM's texts

; the shared window library
.include "sw/graphics/programs/winlib.asm"
