; WINLIB, the window library shared by wm.asm and studio.asm
; include winlib_defs.asm at the top
; and this file at the end of the program
; drawing a window: draw_window, nine_slice, title_bar
;   cells: window_size, clear_cells, put_text, wrap_box, draw_cells
;   pages: load_page, page_line, new_element, page_into_cells, page_images, find_app
;   styles: init_styles, find_style, style_line, blend, from_edge, close_place, full_place
; files and text: load_text, load_picture, build_path / make_path, text_copy, text_length, cut_word,
; skip_spaces, read_word, read_number, read_signed, read_hex, word_is, text_same
;   drawing helpers: box, text, bevel_box, field_box, copy_piece, tile, align_1k, window_record
; real apps: load_app, app_call, app_ticks, app_dirty
; services: api_box, api_text, api_size, api_redraw, api_number, WM and Studio add the rest

; window drawing, cells, pages, styles, files

.include "sw/graphics/winlib/title_bar.asm"                    ; a window's header
.include "sw/graphics/winlib/scroll.asm"                       ; scrolling, the scroll bar
.include "sw/graphics/winlib/window_parts.asm"                 ; where a window's parts are
.include "sw/graphics/winlib/draw_window.asm"                  ; draw_window, cells, wrapping
.include "sw/graphics/winlib/pictures.asm"                     ; window records, .PIC files
.include "sw/graphics/winlib/pages.asm"                        ; PAGE.TXT read into a window
.include "sw/graphics/winlib/files.asm"                        ; files and paths, sprites
.include "sw/graphics/winlib/app_host.asm"                     ; the app host, APP.BIN loaded, called, ticked
.include "sw/graphics/winlib/text_utils.asm"                   ; small text tools
.include "sw/graphics/winlib/text_builder.asm"                 ; the text builder
.include "sw/graphics/winlib/styles.asm"                       ; STYLE.TXT read, nine-slice frames
.include "sw/graphics/winlib/drawing.asm"                      ; drawing helpers
.include "sw/graphics/winlib/mouse.asm"                        ; the mouse woken up, its wheel turned on
.include "sw/graphics/winlib/data.asm"                         ; the default style and the library's texts
