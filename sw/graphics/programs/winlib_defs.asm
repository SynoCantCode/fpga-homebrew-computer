; WINLIB_DEFS, the window library's names
; shared by wm.asm and studio.asm, include it before .org

; the variables, in block RAM at PROGRAM_DATA
.equ last_buttons,   PROGRAM_DATA + 0       ; the left button at the last look
.equ dragging,       PROGRAM_DATA + 4       ; 1 while a title bar is held
.equ drag_dx,        PROGRAM_DATA + 8       ; where the window was grabbed, from its top-left
.equ drag_dy,        PROGRAM_DATA + 12
.equ mouse_point,    PROGRAM_DATA + 16      ; where the pointer is, a point
.equ wall_width,     PROGRAM_DATA + 20      ; the wallpaper's size, 0 = none
.equ wall_height,    PROGRAM_DATA + 24
.equ icons,          PROGRAM_DATA + 28      ; the icons' picture, base address in the SDRAM
.equ redraw,         PROGRAM_DATA + 36      ; 1 = something changed, draw the screen again
.equ saved_page,     PROGRAM_DATA + 40      ; DRAW_PAGE, kept while drawing into a window's picture
.equ file_memory,    PROGRAM_DATA + 44      ; the wallpaper file's heap memory
.equ resizing,       PROGRAM_DATA + 48      ; 1 while a window's grip is held
.equ one_letter,     PROGRAM_DATA + 52      ; a cell's letter + a 0, for DRAW_TEXT
.equ text_colour,    PROGRAM_DATA + 56      ; colour for a page's next text lines
.equ apps_text,      PROGRAM_DATA + 60      ; APPS.TXT's memory
.equ style_count,    PROGRAM_DATA + 80      ; styles loaded, style 0 = the default
.equ head_width,     PROGRAM_DATA + 84      ; title_bar, the header's width in dots
.equ box_left,       PROGRAM_DATA + 88      ; wrap_box, the box's left column
.equ box_width,      PROGRAM_DATA + 92      ; its width in cells
.equ wall_name,      PROGRAM_DATA + 96      ; the wallpaper's file name, up to 0x3F letters + a 0
.equ path,           PROGRAM_DATA + 0xA0    ; a path being built, "/apps/" NAME "/" FILE, up to 0x5F letters + a 0
.equ order,          PROGRAM_DATA + 0x100   ; stacking order, 8 window numbers, back to front
.equ ORDER_FRONT,    PROGRAM_DATA + 0x11C   ; its last place, the front window
.equ label_colours,  PROGRAM_DATA + 0x600   ; each app's icon label colour, 8 words, 0x5600-0x561F
                                            ; from `label NN` or DESKTOP.TXT's `label APP NN`, else white
.equ scroll_rows,    PROGRAM_DATA + 0x620   ; each window's scroll, the page's row at its top, 8 words
.equ page_rows_tab,  PROGRAM_DATA + 0x640   ; each page's height in rows, 8 words
.equ scroll_now,     PROGRAM_DATA + 0x660   ; the scroll of the window being drawn
.equ PAGE_MAX,       64                     ; a page is at most 64 rows
.equ menu_open,      PROGRAM_DATA + 0x670   ; WM right-click menu, 1 while one is showing
.equ menu_x,         PROGRAM_DATA + 0x674   ; its top-left
.equ menu_y,         PROGRAM_DATA + 0x678
.equ menu_count,     PROGRAM_DATA + 0x67C   ; how many items, up to MENU_MAX, 0x680-0x6AF is free
.equ menu_items,     PROGRAM_DATA + 0x700   ; 12 bytes each, text, action (MENU_...), window / app name
                                            ; 6 x 12 = 72 bytes, 0x700-0x747
.equ MENU_MAX, 6
.equ picture_rows,   PROGRAM_DATA + 0x750   ; WM, rows each window's picture has room for, 8 words
.equ picture_raw,    PROGRAM_DATA + 0x770   ; the address ALLOCATE gave, before align_1k, 8 words
.equ apps,           PROGRAM_DATA + 0x790   ; WM, pointer to the app records, APPS_MAX x 128 bytes in the heap
.equ app_count,      PROGRAM_DATA + 0x794   ; how many apps
.equ app_raw,        PROGRAM_DATA + 0x7A0   ; each window's app code, the address ALLOCATE gave, 8 words
.equ tray_net,       PROGRAM_DATA + 0x7C0   ; WM tray, network shown, 0 no cable
                                            ; 1 cable only, 2 connected
.equ tray_time,      PROGRAM_DATA + 0x7C4   ; time shown, hours x 256 + minutes, 2 BCD digits each
                                            ; 0xFFFF = the DS3231 didnt answer
.equ tray_second,    PROGRAM_DATA + 0x7C8   ; the second (TIMER / 100) it last looked
.equ tray_chip,      PROGRAM_DATA + 0x7CC   ; the chip's minutes and hours, 2 bytes
.equ tray_text,      PROGRAM_DATA + 0x7D0   ; the time as text, "HH:MM" + a 0, 8 bytes
.equ search_open,    PROGRAM_DATA + 0x800   ; WM search, 1 while its list is open
.equ search_choice,  PROGRAM_DATA + 0x804   ; the row chosen
.equ search_count,   PROGRAM_DATA + 0x808   ; how many apps were found
.equ search_text,    PROGRAM_DATA + 0x810   ; what's typed, up to SEARCH_LETTERS + a 0, 16 bytes
.equ search_found,   PROGRAM_DATA + 0x820   ; the apps found, SEARCH_MAX words, to 0x84F
.equ SEARCH_LETTERS, 15
.equ SEARCH_MAX, 12
.equ SEARCH_LIST_WIDTH, 200                 ; the list above the search box, 200 dots wide, rows 18 dots tall
.equ tray_widths,    PROGRAM_DATA + 0x7F0   ; tray, each picture's width, 4 words
                                            ; wider than 16 = a strip of 16 x 16 frames, it animates
.equ icon_drag,      PROGRAM_DATA + 0x860   ; WM, the icon being dragged, its record + 1, 0 = none
.equ icon_moved,     PROGRAM_DATA + 0x864   ; 1 once it moved more than 4 dots
.equ icon_drag_from, PROGRAM_DATA + 0x868   ; where the button was pressed, a point
.equ icon_drag_last, PROGRAM_DATA + 0x86C   ; the pointer the last time round
.equ tb_base,        PROGRAM_DATA + 0x878   ; text builder, the text being made
.equ tb_at,          PROGRAM_DATA + 0x87C   ; where its next letter goes, 0 = no text being made
.equ tb_digits,      PROGRAM_DATA + 0x884   ; tb_number's digits, 12 bytes, 0x884-0x88F
.equ tb_end,         PROGRAM_DATA + 0x880   ; the end of its room, nothing is written past it
.equ decor,          PROGRAM_DATA + 0x890   ; WM decorations, pointer to their records in the heap
.equ decor_count,    PROGRAM_DATA + 0x894   ; how many
.equ decor_drag,     PROGRAM_DATA + 0x898   ; the one being dragged, its number + 1, 0 = none
.equ decor_moved,    PROGRAM_DATA + 0x89C   ; 1 once it moved more than 4 dots
.equ decor_grab_x,   PROGRAM_DATA + 0x8A0   ; where in it the pointer took it, dots from its top-left
.equ decor_grab_y,   PROGRAM_DATA + 0x8A4
.equ picture_got,    PROGRAM_DATA + 0x8A8   ; load_picture, the address ALLOCATE gave for the last picture
                                            ; the room itself starts at the next 1 KB
.equ preview_base,   PROGRAM_DATA + 0x8AC   ; WM_PICTURE, where the picture last shown is
.equ preview_raw,    PROGRAM_DATA + 0x8B0   ; the address ALLOCATE gave, 0 = none loaded
.equ preview_width,  PROGRAM_DATA + 0x8B4   ; its first frame's size
.equ preview_height, PROGRAM_DATA + 0x8B8
.equ decor_path,     PROGRAM_DATA + 0x8C0   ; a decoration picture's path, 48 bytes, 0x8C0-0x8EF
.equ preview_name,   PROGRAM_DATA + 0x8F0   ; WM_PICTURE, its name, 32 bytes, 0x8F0-0x90F
.equ DECOR_MAX, 16                          ; most decorations
.equ DECOR_BYTES, 48                        ; a decoration's record
.equ D_PICTURE, 0                           ; its picture, rows 1 KB apart
.equ D_RAW, 4                               ; the address ALLOCATE gave
.equ D_FRAME_W, 8                           ; a frame's width and height
.equ D_HEIGHT, 12
.equ D_FRAMES, 16                           ; how many frames, 1 = a still picture
.equ D_FRAME, 20                            ; the frame shown
.equ D_X, 24                                ; its top-left on the screen
.equ D_Y, 28
.equ D_NAME, 32                             ; its file name, up to 15 letters + a 0
.equ paint_top,      PROGRAM_DATA + 0x870   ; an app's paint, the window's content top and bottom, in dots
.equ paint_bottom,   PROGRAM_DATA + 0x874   ; only what fits between them is drawn
.equ tray_frame,     PROGRAM_DATA + 0x850   ; tray, the frame shown, 10 a second
.equ tray_sprites,   PROGRAM_DATA + 0x7E0   ; tray, the 16 x 16 pictures, 4 words, NETOFF, NETCABLE, NETOK, SEARCH .PIC
                                            ; 0 = not on the card, a plain drawing instead
.equ APPS_MAX, 32                           ; most apps installed, APPS.TXT's lines
; an app record is shaped like a window's, 128 bytes
; W_NAME = folder name, W_TITLE = title, W_ICON 1 = on the desktop, 0 = off
; W_ICON_NAME / W_ICON_STRIP / W_ICON_FRAMES / W_ICON_FRAME = its icon, and its own
.equ A_WINDOW, 0                            ; the window it's open in + 1, 0 = not open
.equ A_LABEL, 4                             ; its icon label's colour
.equ A_HIDDEN, 8                            ; 1 = its page says `hidden`
.equ A_FULL, 12                             ; 1 = a full-screen app, its page has `shell` lines
.equ A_KIND, 16                             ; 0 = an app, else a file on the desktop
.equ ITEM_TEXT, 1                           ; a text, .TXT .ASM .MD
.equ ITEM_PROGRAM, 2                        ; a program, .BIN
.equ ITEM_FOLDER, 3                         ; a folder
.equ ITEM_FILE, 4                           ; anything else
.equ A_PLACE, 24                            ; its icon's place on the grid, column x 5 + row
                                            ; 0-39, -1 = none yet, not 20, that's W_TITLE
                                            ; app records use 0-24, 52, 56, 88-96, 104
; a window's record, W_ICON = its app's number + 1
.equ last_right,     PROGRAM_DATA + 0x6B0   ; the right button at the last look
.equ hover_task,     PROGRAM_DATA + 0x6B4   ; WM, the taskbar button under the pointer, -1 = none
.equ hover_title,    PROGRAM_DATA + 0x6B8   ; a title button, window x 4 + 1 close, 2 full, 3 minimise, -1 = none
.equ hover_button,   PROGRAM_DATA + 0x6BC   ; a page's button, pointer to its element, 0 = none
.equ hover_button_win, PROGRAM_DATA + 0x6C0 ; its window
.equ quit_now,       PROGRAM_DATA + 0x6C4   ; WM, 1 = a note for the shell is written, WM ends
.equ hg_strip,       PROGRAM_DATA + 0x6CC   ; hourglass, its strip's memory, 0 = not showing
.equ hg_frame,       PROGRAM_DATA + 0x6D0   ; the frame shown, 0-15
.equ hg_ticks,       PROGRAM_DATA + 0x6D4   ; timer ticks since that frame, a frame every 10
.equ HG_DOTS_HIGH, 0x1023                   ; its top-left dot on PAGE_0, 0x1020_0000 + 224 x 1 KB + 304 = 0x1023_8130
.equ HG_DOTS_LOW, 0x8130
.equ HG_X, 304                              ; middle of the screen, text cells 38-41
.equ HG_Y, 224                              ; rows 14-15, 4 x 2 cells = 32 x 32 dots
.equ HG_CELLS, 0x1218                       ; cell 14 x 80 + 38, x 4 bytes, from TEXT_SCREEN
.equ HG_BLUE, 0x18                          ; the pixel colour like the text screen's blue (0x5044C8)
.equ sprite_place,   PROGRAM_DATA + 0x6D8   ; load_sprite, where the next sprite goes, 0 = new room from the heap
                                            ; an address = reuse that memory
.equ element_name,   PROGRAM_DATA + 0x6C8   ; page_line, the #name read on this line, 0 = none
                                            ; new_element puts it in E_NAME, then empties this
.equ MENU_OPEN, 1                           ; menu actions, show a window at the front
.equ MENU_CLOSE, 2                          ; close it
.equ MENU_MIN, 3                            ; minimise it
.equ MENU_FULL, 4                           ; full screen and back
.equ MENU_APP, 5                            ; open the app with this name
.equ MENU_EDIT, 6                           ; edit this window's page in Studio
.equ MENU_CODE, 7                           ; edit /apps/NAME/app.asm in the text editor
.equ MENU_REMOVE, 9                         ; take an app's icon off the desktop
.equ MENU_UNDECORATE, 10                    ; take a decoration off the desktop
.equ MENU_BUILD, 8                          ; build it with build.bin
.equ MENU_WIDTH, 112
.equ MENU_ROW, 18
.equ windows,        PROGRAM_DATA + 0x200   ; 8 windows x 128 bytes, 0x5200-0x55FF
.equ W_X,       0                           ; its top-left dot
.equ W_Y,       4
.equ W_WIDTH,   8                           ; its size in dots, from window_size
.equ W_HEIGHT,  12
.equ W_PICTURE, 16                          ; its picture's base address, a multiple of 1 KB
.equ ELEMENT_BYTES, 32                      ; a page element's size
.equ W_TITLE,   20                          ; pointer to its title
.equ W_VISIBLE, 24                          ; 1 = shown, 0 = closed
.equ W_KIND,    28                          ; KIND_PAGE or KIND_NONE
.equ W_COLUMNS, 32                          ; cells across
.equ W_ROWS,    36                          ; cells down
.equ W_CELLS,   40                          ; pointer to its cells, 2 bytes each, a letter and its colour
.equ W_ELEMENTS, 44                         ; pointer to its elements, 32 bytes each
.equ W_ELEMENT_COUNT, 48                    ; how many elements
.equ W_NAME,    52                          ; pointer to its folder's name
.equ W_ICON,    56                          ; 1 = it has a desktop icon
.equ W_STYLE,   60                          ; pointer to its style in `styles`
.equ W_FULL,    64                          ; 1 = full screen
.equ W_SAVED_X, 68                          ; where it was and how big, to go back to
.equ W_SAVED_Y, 72
.equ W_SAVED_COLUMNS, 76
.equ W_SAVED_ROWS, 80
.equ W_NO_FULL, 84                          ; 1 = its page said "fullscreen no"
.equ W_ICON_STRIP, 88                       ; an animated icon's strip, frames side by side
.equ W_ICON_FRAMES, 92                      ; how many frames, 0 or 1 = not animated
.equ W_ICON_FRAME, 96                       ; the frame shown
.equ W_ANIMATES, 100                        ; 1 = its page has an `animate`
.equ W_ICON_NAME, 104                       ; pointer to its icon's file name, 0 = ICON.PIC
.equ W_HIDDEN, 108                          ; 1 = its page said `hidden`
.equ W_APP, 112                             ; where its APP.BIN code is, 0 = none
.equ W_APP_TICK, 116                        ; timer ticks between its tick calls, 0 = never
.equ W_APP_NEXT, 120                        ; the timer's count when it's due next
.equ W_DIRTY, 124                           ; 1 = it asked to be drawn again, WM_REDRAW
.equ WINDOW_BYTES, 128
.equ WINDOW_COUNT, 8
.equ WHEEL_ROWS, 3                          ; rows scrolled per wheel notch
.equ APP_SLOTS, 8                           ; windows 0-7 are apps
.equ KIND_PAGE, 4
.equ KIND_NONE, 0x00FF                      ; an empty slot
; a page element, 32 bytes, byte 0 kind, 1 column, 2 row, 3 colour, then 3 words
; +16 = pointer to a picture's / animation's file name, 20-31 spare
; text / wrap = pointer to the text, button = label, action, app to open
; image = the picture's base, width, height
.equ E_NAME, 24                              ; word 24, pointer to the element's name (`input #city ...`)
                                            ; 0 = unnamed, used by WM_GET_TEXT, WM_SET_TEXT
.equ E_TEXT_LINE, 1
.equ E_WRAP, 2
.equ E_BUTTON, 3
.equ E_IMAGE, 4
.equ E_BOX, 5                               ; width and height in the 2nd and 3rd words
.equ E_INPUT, 6                             ; like a box, its text is a heap buffer
.equ E_CANVAS, 8                            ; where a real app draws, sized like a box
.equ E_SHELL, 9                             ; a `shell` line, its text in the 1st word, not drawn
.equ E_ANIM, 7                              ; byte 3 = speed, then strip base, frame width
                                            ; frames (low half) and height (high half)
.equ ANIM_TICKS, 10                         ; an animation step every 10 timer ticks
.equ INPUT_MAX, 250                         ; most letters in an input, its buffer is 0x104 bytes
.equ MAX_ELEMENTS, 32
.equ ACTION_CLOSE, 1
.equ ACTION_OPEN, 2
.equ ACTION_EVENT, 3                        ; button ... event N, the app's button handler gets N
; a real app's code starts with 7 jumps and a number
.equ APP_INIT, 0
.equ APP_TICK, 4
.equ APP_KEY, 8
.equ APP_CLICK, 12
.equ APP_PAINT, 16
.equ APP_BUTTON, 20
.equ APP_CLOSE, 24
.equ APP_RATE, 28                           ; a word, ticks a second it wants
; a style, 224 bytes, up to MAX_STYLES in `styles`, style 0 = the default
; in dots from the window's top-left, below 0 = from the right / bottom edge
.equ S_CONTENT_L, 0                         ; the cells' margins, left, top, right, bottom
.equ S_CONTENT_T, 4
.equ S_CONTENT_R, 8
.equ S_CONTENT_B, 12
.equ S_FRAME_FILL, 16                       ; the frame, its colour, light edge, dark edge
.equ S_FRAME_LIGHT, 20
.equ S_FRAME_DARK, 24
.equ S_PANEL_L, 28                          ; the panel behind the cells, its margins
.equ S_PANEL_T, 32
.equ S_PANEL_R, 36
.equ S_PANEL_B, 40
.equ S_PANEL_COLOUR, 44
.equ S_PANEL_EDGE, 48
.equ S_HEAD_L, 52                           ; the header, left and right margins, top, height
.equ S_HEAD_T, 56
.equ S_HEAD_R, 60
.equ S_HEAD_H, 64
.equ S_HEAD_FROM, 68
.equ S_HEAD_TO, 72
.equ S_HEAD_BACK_FROM, 76                   ; header colours behind
.equ S_HEAD_BACK_TO, 80
.equ S_TITLE_X, 84                          ; the title, where in the header, colour at the front, behind
.equ S_TITLE_Y, 88
.equ S_TITLE_FRONT, 92
.equ S_TITLE_BACK, 96
.equ S_CLOSE_X, 100                         ; the close box, 16 x 16, where in the window
.equ S_CLOSE_Y, 104
.equ S_DECO_COUNT, 108                      ; decorations, how many, 0-2
.equ S_DECO, 112                            ; 20 bytes each, picture base, width, height, x, y
.equ S_NAME, 152                            ; pointer to its name
.equ S_PICTURE, 156                         ; a drawn style's picture, 0 = none
.equ S_PIC_W, 160                           ; its width and height
.equ S_PIC_H, 164
.equ S_SLICE_L, 168                         ; the 4 slice lines, corners stay, strips repeat (nine_slice)
.equ S_SLICE_T, 172
.equ S_SLICE_R, 176
.equ S_SLICE_B, 180
.equ S_CLOSE_DRAW, 184                      ; 1 = draw the close box, 0 = the picture has its own
.equ S_FULL_X, 188                          ; the full-screen button, 16 x 16, where in the window
.equ S_FULL_Y, 192
.equ S_FULL_DRAW, 196
.equ S_MIN_X, 200                           ; the minimise button, 16 x 16, where in the window
.equ S_MIN_Y, 204
.equ S_MIN_DRAW, 208
.equ STYLE_BYTES, 224                       ; 212-223 spare
.equ MAX_STYLES, 12
.equ styles,         PROGRAM_DATA + 0x1000  ; the styles, 12 x 224 bytes, 0x6000-0x6A7F, 0x5910-0x597F is free
; nine_slice, for the 3 columns and 3 rows of pieces
; source (sx, sy), size (pw, ph), dest (dx, dy), fill (dw, dh)
.equ slice_sx,       PROGRAM_DATA + 0x980
.equ slice_pw,       PROGRAM_DATA + 0x98C
.equ slice_dx,       PROGRAM_DATA + 0x998
.equ slice_dw,       PROGRAM_DATA + 0x9A4
.equ slice_sy,       PROGRAM_DATA + 0x9B0
.equ slice_ph,       PROGRAM_DATA + 0x9BC
.equ slice_dy,       PROGRAM_DATA + 0x9C8
.equ slice_dh,       PROGRAM_DATA + 0x9D4
.equ t_sx,           PROGRAM_DATA + 0x9E0   ; tile, one piece from (t_sx, t_sy), t_pw x t_ph, in picture t_src
.equ t_sy,           PROGRAM_DATA + 0x9E4   ; fills t_dw x t_dh from (t_dx, t_dy) in t_self
.equ t_pw,           PROGRAM_DATA + 0x9E8
.equ t_ph,           PROGRAM_DATA + 0x9EC
.equ t_dx,           PROGRAM_DATA + 0x9F0
.equ t_dy,           PROGRAM_DATA + 0x9F4
.equ t_dw,           PROGRAM_DATA + 0x9F8
.equ t_dh,           PROGRAM_DATA + 0x9FC
.equ t_src,          PROGRAM_DATA + 0xA00
.equ t_self,         PROGRAM_DATA + 0xA04
.equ focus_window,   PROGRAM_DATA + 0xA10   ; the window whose input takes the typing, -1 = none
.equ focus_element,  PROGRAM_DATA + 0xA14   ; pointer to that input's element
.equ last_anim,      PROGRAM_DATA + 0xA18   ; the timer's count / ANIM_TICKS at the last animation step
.equ task_step,      PROGRAM_DATA + 0xA1C   ; taskbar, a button's width + the gap, in dots
.equ task_text,      PROGRAM_DATA + 0xA20   ; taskbar, a title cut to fit, up to 14 letters + a 0
.equ paint_x,        PROGRAM_DATA + 0xA30   ; an app's paint, its content's top-left in the window's picture
.equ paint_y,        PROGRAM_DATA + 0xA34
.equ pressed,        PROGRAM_DATA + 0xA38   ; press_button, 1 = the click hit an input or a button
.equ hover_place,    PROGRAM_DATA + 0xA3C   ; WM, the desktop icon under the pointer, its place, or -1
.equ VARIABLES_END, PROGRAM_DATA + 0xA40

; colours and sizes
.equ TEAL,      0x28                        ; colour 2 shade 8, the desktop without a wallpaper
.equ BUTTON_HOVER, 0xF2                     ; a button's face under the pointer
.equ ICON_SHADOW, 0x02                      ; almost black, the shadow under a desktop icon that pops out
.equ SILVER,    0xF0
.equ SHADOW,    0xF1
.equ WHITE_DOT, 0x0F
.equ BLACK_DOT, 0x00
.equ NAVY,      0x30                        ; colour 3, the front window's title bar, shades 8-15
.equ GREY,      0x00                        ; colour 0, the other title bars, shades 6-13
.equ KEY,       0xFE                        ; the icons' see-through colour, pure magenta
.equ TASKBAR_Y, 452
.equ SEARCH_X, 4                            ; taskbar, the search box, 4-163
.equ SEARCH_WIDTH, 160
.equ TASK_LEFT, 168                         ; the windows' buttons, from 168
.equ TRAY_X, 540                            ; the tray, network light and clock, 540-635
.equ TITLE_BOTTOM, 21                       ; the title bar, the window's rows 3-20
.equ CELLS_X,   8                           ; where the cells start in a window, dots from its top-left
.equ CELLS_Y,   28
