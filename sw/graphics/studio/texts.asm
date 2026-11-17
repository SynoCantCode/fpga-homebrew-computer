; texts, the toolbar, the start screen, page words
; included by studio.asm

; the texts
toolbar_labels:
        .word t_text
        .word t_box
        .word t_input
        .word t_button
        .word t_sprite
        .word t_canvas
        .word t_style
        .word t_colour
        .word t_action
        .word t_save
        .word t_desktop
        .word t_icon
        .word 0
t_text:          .string "Text"
t_box:           .string "Box"
t_input:         .string "Input"
t_button:        .string "Button"
t_sprite:        .string "Sprite"
t_canvas:        .string "Canvas"
t_icon:          .string "Icon"
t_style:         .string "Style"
t_colour:        .string "Colour"
t_action:        .string "Action"
t_save:          .string "Save"
t_desktop:       .string "Desktop"
choose_title:    .string "STUDIO: which app's window do you want to edit?\n"
choose_new:      .string "  N  a new app (type its name)"
choose_esc:      .string "  Esc  back\n"
choose_ask:      .string "the new app's name (up to 8 letters, Enter): "
hello_text:      .string "Studio: click a thing to select it, drag it, type to change it; the header: the title. Esc: quit"
title_text:      .string "the title: type to change it; drag the header to move the window"
title_full_text: .string "the title is as long as it can be (a wider window takes more)"
too_small_text:  .string "something inside wouldn't fit: make it smaller or move it first"
style_said:      .string "style: "
default_said:    .string "the default"
colour_said:     .string "its colour changed (Colour again: the next one)"
pick_text_text:  .string "select a text, a paragraph, a box or an input first"
pick_button_text: .string "select a button first"
does_nothing_text: .string "this button does nothing (Action: change it)"
does_close_text: .string "this button closes the window (Action: change it)"
does_open_text:  .string "this button opens "
icon_said:       .string "its desktop icon: "
icon_none_text:  .string "its desktop icon: none (the little computer)"
does_event_text: .string "this button sends its program event "
styles_list_path: .string "/system/design/windows/styles.txt"
sprites_list_path: .string "/system/design/sprites/sprites.txt"
big_list_path:    .string "/system/design/bigsprts/bigsprts.txt"
no_sprites_text: .string "no sprites listed: put their names in /system/design/sprites/sprites.txt"
not_read_text:   .string "couldn't read "
sprite_said:     .string "sprite: "
no_room_text:    .string "no room for it: make the window wider, or take something out"
; Colour button colours, black, navy, blue-violet, sky blue, green, red,
; orange, magenta, purple, brown, grey, white
colour_list:     .byte 0x00, 0x38, 0x18, 0x48, 0x64, 0xA8, 0x98, 0xC8, 0xD8, 0xE6, 0xF1, 0x0F
new_text:        .string "a new app: add things with the toolbar, then Save"
selected_text:   .string "selected: drag it, type to change it, Tab: its #name (Delete removes it)"
name_status_text: .string "Tab: back to its text.  its name: #"
name_back_text:  .string "typing changes its text again"
sizing_text:     .string "drag the corner to change its size"
fits_text:       .string "it's full: make it bigger first (drag its corner)"
added_text:      .string "added: type its text, drag it where you want it"
full_text:       .string "the page is full (32 things at most)"
deleted_text:    .string "removed"
saved_text:      .string "saved its page.txt (the window manager shows it: run wm.bin)"
not_saved_text:  .string "couldn't save it (is the card in?)"
desktop_text:    .string "added to /apps/apps.txt: the window manager shows it now"
there_text:      .string "it's on the desktop already"
sample_text:     .string "Text"
sample_box:      .string "A box of text: it wraps inside the box"
sample_button:   .string "OK"
empty_text:      .string ""
w_comment:       .string "; "
w_made:          .string ": made with Studio"
w_title:         .string "title "
w_style:         .string "style "
w_size:          .string "size "
w_place:         .string "place "
w_hidden:        .string "hidden"
w_fullscreen_no: .string "fullscreen no"
w_icon:          .string "icon "
w_label:         .string "label "
w_colour:        .string "colour "
w_text:          .string "text "
w_wrap:          .string "wrap "
w_box:           .string "box "
w_input:         .string "input "
w_button:        .string "button "
w_close:         .string " close"
w_open:          .string " open "
w_event:         .string " event "
w_canvas:        .string "canvas "
w_shell:         .string "shell "
w_hash:          .string "#"
w_image:         .string "image "
w_animate:       .string "animate "
