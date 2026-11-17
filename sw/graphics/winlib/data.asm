; default style and the librarys texts
; included by winlib.asm

; style 0, grey Windows 95 look, 160 bytes in S_ order
default_style:
        .word 8                         ; content margins left, top, right, bottom
        .word 28
        .word 8
        .word 6
        .word 0xF0                      ; frame silver, white edge, grey edge
        .word 0x0F
        .word 0xF1
        .word 3                         ; panel margins left, top, right, bottom
        .word 24
        .word 3
        .word 3
        .word 0x0F                      ; white, grey line above
        .word 0xF1
        .word 3                         ; header left, top, right, height
        .word 3
        .word 3
        .word 18
        .word 0x38                      ; navy shades 8 to 15 at the front
        .word 0x3F
        .word 0x06                      ; grey shades 6 to 13 behind
        .word 0x0D
        .word 3                         ; title 3 in, 1 down, white / silver
        .word 1
        .word 0x0F
        .word 0xF0
        .word 0xFFFFFFEB                ; close box -21 from the right, 4 down
        .word 4
        .word 0                         ; no decorations
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0                         ; no name
        .word 0                         ; no picture, made of the parts
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 1                         ; close box drawn
        .word 0xFFFFFFDA                ; full screen button -38 from the right, 4 down, drawn
        .word 4
        .word 1
        .word 0xFFFFFFC9                ; minimise button -55 from the right, 4 down, drawn
        .word 4
        .word 1
        .word 0
        .word 0
        .word 0

close_text:      .string "x"
default_wallpaper: .string "/system/design/wallpapr/bliss.pic"
apps_list_path:  .string "/apps/apps.txt"
apps_prefix:     .string "/apps/"
page_name:       .string "page.txt"
icon_name:       .string "icon.pic"
default_icon_name: .string "gear.pic"
word_title:      .string "title"
word_size:       .string "size"
word_place:      .string "place"
word_hidden:     .string "hidden"
word_colour:     .string "colour"
word_text:       .string "text"
word_wrap:       .string "wrap"
word_button:     .string "button"
word_image:      .string "image"
word_close:      .string "close"
word_open:       .string "open"
word_event:      .string "event"
app_bin_name:    .string "app.bin"
word_box:        .string "box"
word_canvas:     .string "canvas"
bar_up_text:     .string "^"
bar_down_text:   .string "v"
word_style:      .string "style"
word_input:      .string "input"
word_fullscreen: .string "fullscreen"
word_animate:    .string "animate"
word_label:      .string "label"
word_shell:      .string "shell"
hourglass_name:  .string "hourglas.pic"
nothing_name:    .string ""
word_no:         .string "no"
word_full:       .string "full"
word_min:        .string "min"
word_content:    .string "content"
word_frame:      .string "frame"
word_panel:      .string "panel"
word_header:     .string "header"
word_close_box:  .string "close"
word_decoration: .string "decoration"
word_picture:    .string "picture"
styles_prefix:   .string "/system/design/windows/"
style_file:      .string "style.txt"
design_prefix:   .string "/system/design/"
sprites_name:    .string "sprites"
bigsprts_name:   .string "bigsprts"
word_icon:       .string "icon"
