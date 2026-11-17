; STUDIO, the window editor.   run studio.bin NAME   an app in /APPS/NAME/, or a new one
; no NAME = the start screen, the apps in APPS.TXT, numbered
; a number edits that one, N names a new one, Esc goes back
; a white workspace with the app's window in the middle, drawn with winlib.asm
; the toolbar along the top
; Text / Box / Input / Button   add one, under the others
; Sprite                        a picture selected = its next sprite in SPRITES.TXT
; anything else = the first sprite is added
; Canvas                        where a real app draws, sized like a box
; type into it the program that runs there
; nothing typed = the app's own APP.BIN
; Style                         the window's next style, from STYLES.TXT
; Colour                        the selected element's next colour
; title selected = its icon's label colour (`label NN`)
; Action                        the selected button's next action, nothing, close,
; open APP (from APPS.TXT), event 1-3
; Save                          writes /APPS/NAME/PAGE.TXT
; Desktop                       puts NAME in /APPS/APPS.TXT
; Icon                          the app's desktop icon, the next sprite in SPRITES.TXT
; 32 x 32, after the last = none, shown top right
; Delete removes the selected element, Esc goes back to the shell
; a page can be up to 64 rows, longer than its window
; Page Up / Page Down or the scroll bar scroll it
; click selects an element, drag moves it a cell at a time, typing changes its text
; drag the bottom-right corner to resize, click the header to select the title
; drag the header to move the window
; a move or resize that makes something not fit is refused
; the page's other lines are written back as they were
; runs in the SDRAM, LA for own labels, CALLF for the jump table
; variables in block RAM at PROGRAM_DATA, after the library's
.include "sw/os/devices.asm"
.include "sw/graphics/programs/winlib_defs.asm"   ; the shared names

; Studio's own variables, after VARIABLES_END
.equ selected,       PROGRAM_DATA + 0xA40   ; pointer to the selected element, 0 = none
.equ holding,        PROGRAM_DATA + 0xA44   ; what is dragged, 0 nothing, 1 the element, 2 the corner
.equ grab_column,    PROGRAM_DATA + 0xA48   ; where in the element it was grabbed, in cells
.equ grab_row,       PROGRAM_DATA + 0xA4C
.equ status,         PROGRAM_DATA + 0xA50   ; pointer to the status line's text
.equ app_name,       PROGRAM_DATA + 0xA70   ; the app's name, up to 8 letters + a 0
.equ number_buffer,    PROGRAM_DATA + 0xA80   ; put_number's digits
.equ title_selected, PROGRAM_DATA + 0xA90   ; 1 = the window's title is selected
.equ title_own,      PROGRAM_DATA + 0xA94   ; 1 = the title is Studio's own copy
.equ style_list,     PROGRAM_DATA + 0xA98   ; STYLES.TXT, a name a line, 0 = no list
.equ style_list_end, PROGRAM_DATA + 0xA9C   ; its end
.equ style_pick,     PROGRAM_DATA + 0xAA0   ; the style's name in that list, 0 = the default
.equ app_list,       PROGRAM_DATA + 0xAA4   ; APPS.TXT, the apps a button can open
.equ app_list_end,   PROGRAM_DATA + 0xAA8   ; its end
.equ sprite_table,   PROGRAM_DATA + 0xAAC   ; SPRITES.TXT as a table in the heap, 16 bytes a sprite
.equ sprite_count,   PROGRAM_DATA + 0xAB0   ; how many sprites
.equ status_text,    PROGRAM_DATA + 0xAC0   ; a status line being built, up to 0x3F letters + a 0
.equ sprite_cache,   PROGRAM_DATA + 0xB00   ; sprites read so far, 16 x 16 bytes, name, base, width, height
.equ old_element,    PROGRAM_DATA + 0xC00   ; next_sprite, an element's 32 bytes to put back
.equ choose_names,   PROGRAM_DATA + 0xC20   ; start screen, a pointer to each app's name, 8 words
.equ name_for,       PROGRAM_DATA + 0xC40   ; the element whose name typing goes to, 0 = typing goes to texts
.equ STUDIO_END,     PROGRAM_DATA + 0xC50

.equ TOOLBAR_H,  28                         ; toolbar height
.equ STATUS_Y,   460                        ; status line's top
.equ OUTLINE,    0x3A                       ; selected element's outline, blue
.equ STUDIO_Y,   48                         ; a new window's top
.equ TITLE_MAX,  40                         ; most letters in a title, its copy is 0x40 bytes
.equ COLOURS,    12                         ; colours the Colour button goes through
.equ MAX_ROWS,   24                         ; tallest window in the workspace, in rows
.equ MAX_SPRITES, 64                        ; most lines in SPRITES.TXT
.equ OWN_TEXT,   20                         ; element byte 20, 1 = its text is Studio's own copy
.equ OWN_NAME,   21                         ; element byte 21, 1 = its name is Studio's own copy
.equ NAME_MOST,  11                         ; longest name

.org PROGRAM_SDRAM

; first word = where `run studio.bin` starts, then the same services table as WM.BIN
; so an app's program runs in Studio too
        JUMP   start                    ; PROGRAM_SDRAM + 0
        JUMP   api_box                  ;              + 4   WM_BOX
        JUMP   api_text                 ;              + 8   WM_TEXT
        JUMP   api_size                 ;              + 12  WM_SIZE
        JUMP   api_redraw               ;              + 16  WM_REDRAW
        JUMP   studio_no_wallpaper      ; + 20  WM_WALLPAPER, not in Studio
        JUMP   api_number               ;              + 24  WM_NUMBER
        JUMP   studio_app_info          ; + 28  WM_APP_INFO, window 0
        JUMP   studio_ignore            ; + 32  WM_SET_ICON, not in Studio
        JUMP   studio_ignore            ; + 36  WM_SET_LABEL, not in Studio
        JUMP   studio_ignore            ; + 40  WM_ICON, not in Studio
        JUMP   studio_no_wallpaper      ; + 44  WM_OPEN, not in Studio, answers 0
        JUMP   api_get_text             ;              + 48  WM_GET_TEXT
        JUMP   studio_ignore            ; + 52  WM_SET_TEXT, not in Studio
        JUMP   studio_no_wallpaper      ; + 56  WM_SET_DESKTOP, not in Studio, answers 0
        JUMP   studio_no_wallpaper      ; + 60  WM_DECORATE, not in Studio, answers 0
        JUMP   studio_no_wallpaper      ; + 64  WM_UNDECORATE, not in Studio, answers 0
        JUMP   studio_no_wallpaper      ; + 68  WM_PICTURE, not in Studio, answers 0

.include "sw/graphics/studio/start.asm"                        ; starting up, the main loop, quitting
.include "sw/graphics/studio/services.asm"                     ; the services Studio gives differently from WM
.include "sw/graphics/studio/open.asm"                         ; opening the app, its page into window 0, its program
.include "sw/graphics/studio/start_screen.asm"                 ; the start screen, choose an app or a new one
.include "sw/graphics/studio/screen.asm"                       ; the window, the toolbar, the outline
.include "sw/graphics/studio/mouse.asm"                        ; the mouse, clicks, dragging and resizing
.include "sw/graphics/studio/elements.asm"                     ; elements, adding, making room, deleting
.include "sw/graphics/studio/keys.asm"                         ; keys, typing, moving with the arrows
.include "sw/graphics/studio/choosers.asm"                     ; sprite, icon, style, colour, action, name buttons
.include "sw/graphics/studio/save.asm"                         ; saving PAGE.TXT, adding to APPS.TXT
.include "sw/graphics/studio/out_text.asm"                     ; writing the page's text a piece at a time
.include "sw/graphics/studio/texts.asm"                        ; Studio's texts

; the shared window library
.include "sw/graphics/programs/winlib.asm"
