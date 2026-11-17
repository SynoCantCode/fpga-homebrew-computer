; wm decorations, pictures that sit on the desktop
; included by programs/wm.asm
; drawn after the wallpaper, before the icons and windows
; picture is a sprite from /SYSTEM/DESIGN/BIGSPRTS/ or /SYSTEM/DESIGN/SPRITES/
; a strip of square frames animates, 10 frames a second
; kept in /SYSTEM/DESIGN/DECOR.TXT, a line each, NAME.PIC X Y, last on top
; apps use WM_DECORATE, WM_UNDECORATE, WM_PICTURE
; a record is DECOR_BYTES, D_PICTURE = its picture, D_RAW = address from ALLOCATE
; D_FRAME_W, D_HEIGHT = frame size, D_FRAMES = how many, D_FRAME = the one shown
; D_X, D_Y = top left, D_NAME = file name, up to 15 letters + a 0

; decor_load, reads DECOR.TXT, loads and places each picture
; R8 = line, R9 = text end, R10 = name, R11 = text
decor_load: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        STORE  R0, [decor_count]
        STORE  R0, [decor_drag]
        STORE  R0, [decor_moved]
        STORE  R0, [preview_name]
        STORE  R0, [preview_raw]
        LOADLO R1, 768                   ; DECOR_MAX x DECOR_BYTES, 16 x 48
        CALLF  ALLOCATE
        STORE  R1, [decor]
        CMPI   R1, 0x0000
        JZ     decor_load_done
        LA     R1, decor_file           ; "/system/design/decor.txt"
        CALL   load_text                ; line ends are 0s
        CMPI   R1, 0x0000
        JZ     decor_load_done
        MOV    R11, R1
        MOV    R9, R2
        CALL   line_first               ; R1 = first line or 0
        MOV    R8, R1
decor_load_line: CMPI R8, 0x0000
        JZ     decor_load_end
        MOV    R1, R8                   ; find the next line first, first_word writes a 0 into this one
        MOV    R2, R9
        CALL   line_next
        PUSH   R1
        MOV    R1, R8
        CALL   first_word               ; R2 = name, R1 = rest
        MOV    R10, R2
        CALL   read_number              ; R2 = x
        PUSH   R2
        CALL   read_number              ; R2 = y
        MOV    R3, R2
        POP    R2
        MOV    R1, R10
        CALL   decor_add_at
        POP    R8
        JUMP   decor_load_line
decor_load_end: MOV R1, R11             ; free the text, names were copied
        CALLF  FREE
decor_load_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; decor_add_at, adds a decoration
; in R1 = pointer to picture name, R2 = x, R3 = y, out R1 = 1 added, 0 not
; R8 = its record, R9 = name, R10 = x, R11 = y
decor_add_at: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        MOV    R9, R1
        MOV    R10, R2
        MOV    R11, R3
        LOAD   R8, [decor]
        CMPI   R8, 0x0000
        JZ     decor_add_no
        LOAD   R1, [decor_count]
        CMPI   R1, DECOR_MAX
        JZ     decor_add_no             ; full
        MULI   R1, R1, DECOR_BYTES
        ADD    R8, R8, R1
        MOV    R1, R9                   ; same picture on the desktop already? share it
        CALL   decor_same_picture       ; R1 = 0 if not, R2-R4 as decor_picture, R4 = 0
        CMPI   R1, 0x0000
        JNZ    decor_add_have
        MOV    R1, R9
        CALL   decor_picture            ; R1 = width or 0, R2 = height, R3 = where, R4 = raw address
        CMPI   R1, 0x0000
        JZ     decor_add_no
decor_add_have: STORE R3, [R8 + D_PICTURE]
        STORE  R4, [R8 + D_RAW]
        STORE  R2, [R8 + D_HEIGHT]
        CALL   frames_of                ; R1 = frame width, R2 = how many
        STORE  R1, [R8 + D_FRAME_W]
        STORE  R2, [R8 + D_FRAMES]
        LOAD   R1, [decor_count]        ; first frame, 7 on from the one before
        MULI   R1, R1, 7
        MODU   R1, R1, R2
        STORE  R1, [R8 + D_FRAME]
        STORE  R10, [R8 + D_X]
        STORE  R11, [R8 + D_Y]
        MOV    R1, R9                   ; its name, up to 15 letters
        ADDI   R2, R8, D_NAME
        LOADLO R3, 15
decor_add_name: LOADB R4, [R1]
        CMPI   R4, 0x0000
        JZ     decor_add_named
        CMPI   R3, 0x0000
        JZ     decor_add_named
        STOREB R4, [R2]
        INC    R1
        INC    R2
        DEC    R3
        JUMP   decor_add_name
decor_add_named: STOREB R0, [R2]
        LOAD   R1, [decor_count]
        INC    R1
        STORE  R1, [decor_count]
        LOADLO R1, 1
        STORE  R1, [redraw]
        JUMP   decor_add_done
decor_add_no: LOADLO R1, 0
decor_add_done: POP R11
        POP    R10
        POP    R9
        POP    R8
        RET

; decor_same_picture, shares a loaded picture, the owner has D_RAW not 0
; in R1 = pointer to name, out R1 = width or 0, R2 = height, R3 = where, R4 = 0
; R8 = name, R9 = decoration number
decor_same_picture: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOAD   R9, [decor_count]
decor_same_next: CMPI R9, 0x0000
        JZ     decor_same_none
        DEC    R9
        MOV    R1, R9
        CALL   decor_record
        PUSH   R1
        ADDI   R2, R1, D_NAME
        MOV    R1, R8
        CALL   text_same                ; R3 = 1 if the same
        POP    R1
        CMPI   R3, 1
        JNZ    decor_same_next
        LOAD   R3, [R1 + D_PICTURE]
        LOAD   R2, [R1 + D_HEIGHT]
        LOAD   R4, [R1 + D_FRAMES]      ; whole width = frames x frame width
        LOAD   R5, [R1 + D_FRAME_W]
        MUL    R1, R4, R5
        LOADLO R4, 0
        JUMP   decor_same_done
decor_same_none: LOADLO R1, 0
decor_same_done: POP R9
        POP    R8
        RET

; decor_free, frees a picture, or hands it to a decoration sharing it
; in R1 = its record, uses R1-R6
decor_free: LOAD R5, [R1 + D_RAW]
        CMPI   R5, 0x0000
        JZ     decor_free_done          ; not the owner
        LOAD   R6, [R1 + D_PICTURE]
        STORE  R0, [R1 + D_RAW]
        MOV    R4, R1
        LOAD   R3, [decor_count]
decor_free_next: CMPI R3, 0x0000
        JZ     decor_free_now
        DEC    R3
        MOV    R1, R3
        CALL   decor_record
        CMP    R1, R4
        JZ     decor_free_next          ; itself
        LOAD   R2, [R1 + D_PICTURE]
        CMP    R2, R6
        JNZ    decor_free_next
        STORE  R5, [R1 + D_RAW]         ; another shares it, it owns the memory
        RET
decor_free_now: MOV R1, R5
        CALLF  FREE
decor_free_done: RET

; frames_of, a strip wider than tall is square frames side by side
; 1024 x 64 = 16 frames of 64 x 64, anything else is one frame
; in R1 = width, R2 = height, out R1 = frame width, R2 = frames, uses R3
frames_of: CMP R2, R1
        JC     frames_one               ; as tall as wide or taller, one frame
        MODU   R3, R1, R2
        CMPI   R3, 0x0000
        JNZ    frames_one
        DIVU   R3, R1, R2
        MOV    R1, R2
        MOV    R2, R3
        RET
frames_one: LOADLO R2, 1
        RET

; decor_picture, loads a picture by name, big sprites first, then sprites
; in R1 = pointer to name, out R1 = width or 0, R2 = height
; R3 = where, R4 = raw address for FREE. R8 = name
decor_picture: PUSH R8
        MOV    R8, R1
        LA     R1, big_sprites_folder   ; "/system/design/bigsprts/" + the name
        CALL   decor_path_of
        LOADLO R2, 0
        CALL   load_picture
        CMPI   R1, 0x0000
        JNZ    decor_picture_got
        LA     R1, sprites_folder       ; "/system/design/sprites/" + the name
        CALL   decor_path_of
        LOADLO R2, 0
        CALL   load_picture
        CMPI   R1, 0x0000
        JZ     decor_picture_done
decor_picture_got: LOAD R4, [picture_got]
decor_picture_done: POP R8
        RET

; decor_path_of, decor_path = folder + name
; in R1 = pointer to folder, R8 = name, out R1 = decor_path, uses R1-R4
decor_path_of: LOADLO R2, decor_path
        CALL   text_copy                ; R2 = where its 0 went, the name goes there
        MOV    R1, R8
        LOADLO R3, decor_path + 47
        SUB    R3, R3, R2               ; room left, a long name is cut
decor_path_name: LOADB R4, [R1]
        STOREB R4, [R2]
        CMPI   R4, 0x0000
        JZ     decor_path_done
        CMPI   R3, 0x0000
        JZ     decor_path_cut
        INC    R1
        INC    R2
        DEC    R3
        JUMP   decor_path_name
decor_path_cut: STOREB R0, [R2]
decor_path_done: LOADLO R1, decor_path
        RET

; decor_record, in R1 = decoration number, out R1 = pointer to its record, uses R2
decor_record: MULI R1, R1, DECOR_BYTES
        LOAD   R2, [decor]
        ADD    R1, R1, R2
        RET

; decor_draw, draws every decoration see-through, last on top
; R8 = its record, R9 = its number
decor_draw: PUSH R8
        PUSH   R9
        LOADLO R9, 0
decor_draw_next: LOAD R1, [decor_count]
        CMP    R9, R1
        JC     decor_draw_done
        MOV    R1, R9
        CALL   decor_record
        MOV    R8, R1
        LOAD   R1, [R8 + D_Y]           ; where, as a point
        SHIFTI R1, R1, 0x10, 0b0000
        LOAD   R2, [R8 + D_X]
        OR     R1, R1, R2
        LOAD   R2, [R8 + D_HEIGHT]      ; frame size
        SHIFTI R2, R2, 0x10, 0b0000
        LOAD   R3, [R8 + D_FRAME_W]
        OR     R2, R2, R3
        LOAD   R4, [R8 + D_FRAME]       ; from (frame x width, 0) in its strip
        MUL    R4, R4, R3
        LOAD   R3, [R8 + D_PICTURE]
        ORI    R3, R3, KEY
        CALLF  DRAW_SPRITE
        INC    R9
        JUMP   decor_draw_next
decor_draw_done: POP R9
        POP    R8
        RET

; decor_anim, next frame of each strip, 10 a second, uses R1-R4
decor_anim: LOADLO R4, 0
decor_anim_next: LOAD R1, [decor_count]
        CMP    R4, R1
        JC     decor_anim_done
        MOV    R1, R4
        CALL   decor_record
        LOAD   R2, [R1 + D_FRAMES]
        CMPI   R2, 2
        JNC    decor_anim_skip          ; one frame, still
        LOAD   R3, [R1 + D_FRAME]
        INC    R3
        CMP    R3, R2
        JNC    decor_anim_set
        LOADLO R3, 0
decor_anim_set: STORE R3, [R1 + D_FRAME]
        LOADLO R2, 1
        STORE  R2, [redraw]
decor_anim_skip: INC R4
        JUMP   decor_anim_next
decor_anim_done: RET

; decor_at, top decoration under the pointer
; in R8 = x, R9 = y, out R1 = its number or -1, uses R1-R6
decor_at: LOAD R6, [decor_count]
decor_at_next: CMPI R6, 0x0000
        JZ     decor_at_none
        DEC    R6
        MOV    R1, R6
        CALL   decor_record
        LOAD   R2, [R1 + D_X]
        CMP    R8, R2
        JNC    decor_at_next            ; left of it
        LOAD   R3, [R1 + D_FRAME_W]
        ADD    R2, R2, R3
        CMP    R8, R2
        JC     decor_at_next            ; right of it
        LOAD   R2, [R1 + D_Y]
        CMP    R9, R2
        JNC    decor_at_next            ; above it
        LOAD   R3, [R1 + D_HEIGHT]
        ADD    R2, R2, R3
        CMP    R9, R2
        JC     decor_at_next            ; below it
        MOV    R1, R6
        RET
decor_at_none: NOT R1, R0
        RET

; decor_save, writes DECOR.TXT from the records, NAME X Y a line
decor_save: PUSH R8
        PUSH   R9
        LOADLO R1, 512                   ; DECOR_MAX lines of up to 32 letters
        CALL   tb_start
        CMPI   R1, 0x0000
        JZ     decor_save_done
        LOADLO R9, 0
decor_save_next: LOAD R1, [decor_count]
        CMP    R9, R1
        JC     decor_save_write
        MOV    R1, R9
        CALL   decor_record
        MOV    R8, R1
        ADDI   R1, R8, D_NAME
        CALL   tb_text
        LOADLO R1, 0x0020
        CALL   tb_char
        LOAD   R1, [R8 + D_X]
        CALL   tb_number
        LOADLO R1, 0x0020
        CALL   tb_char
        LOAD   R1, [R8 + D_Y]
        CALL   tb_number
        CALL   tb_line
        INC    R9
        JUMP   decor_save_next
decor_save_write: LA R1, decor_file
        CALL   tb_save
decor_save_done: POP R9
        POP    R8
        RET

; decor_remove, removes a decoration, frees it, saves DECOR.TXT
; in R1 = its number. R8 = it, R9 = the record after it
decor_remove: PUSH R8
        PUSH   R9
        MOV    R8, R1
        LOAD   R2, [decor_count]
        CMP    R8, R2
        JC     decor_remove_done        ; no such one
        CALL   decor_record
        CALL   decor_free               ; free its picture or hand it on
decor_remove_shift: LOAD R2, [decor_count]
        ADDI   R1, R8, 1
        CMP    R1, R2
        JC     decor_remove_last
        CALL   decor_record             ; copy the next record over this one
        MOV    R9, R1
        MOV    R1, R8
        CALL   decor_record
        LOADLO R3, DECOR_BYTES
decor_remove_copy: LOAD R4, [R9]
        STORE  R4, [R1]
        ADDI   R9, R9, 4
        ADDI   R1, R1, 4
        SUBI   R3, R3, 4
        CMPI   R3, 0x0000
        JNZ    decor_remove_copy
        INC    R8
        JUMP   decor_remove_shift
decor_remove_last: LOAD R1, [decor_count]
        DEC    R1
        STORE  R1, [decor_count]
        LOADLO R1, 1
        STORE  R1, [redraw]
        CALL   decor_save
decor_remove_done: POP R9
        POP    R8
        RET

; decor_drag_start, right button pressed on a decoration not under a window
; decor_drag = its number + 1, decor_grab = where in it
; out R1 = 1 taken, 0 none, uses R1-R7
decor_drag_start: PUSH R8
        PUSH   R9
        LOAD   R1, [mouse_point]
        ANDI   R8, R1, 0xFFFF
        SHIFTI R9, R1, 0x10, 0b1000
        CMPI   R9, TASKBAR_Y
        JC     decor_drag_none          ; on the taskbar
        CALL   window_under             ; a window is over it
        CMPIS  R1, -1
        JNZ    decor_drag_none
        CALL   decor_at
        CMPIS  R1, -1
        JZ     decor_drag_none
        PUSH   R1
        INC    R1
        STORE  R1, [decor_drag]
        STORE  R0, [decor_moved]
        POP    R1
        CALL   decor_record
        LOAD   R2, [R1 + D_X]           ; where in it the pointer took it
        SUB    R2, R8, R2
        STORE  R2, [decor_grab_x]
        LOAD   R2, [R1 + D_Y]
        SUB    R2, R9, R2
        STORE  R2, [decor_grab_y]
        LOAD   R1, [mouse_point]
        STORE  R1, [icon_drag_from]     ; shared with icon dragging
        LOADLO R1, 1
        JUMP   decor_drag_end
decor_drag_none: LOADLO R1, 0
decor_drag_end: POP R9
        POP    R8
        RET

; decor_drag_move, right button held, follows after 4 dots of movement
; top left = pointer - grab, not past the top or left, uses R1-R7
decor_drag_move: LOAD R1, [mouse_point]
        LOAD   R2, [decor_moved]
        CMPI   R2, 0x0000
        JNZ    decor_drag_follow
        LOAD   R2, [icon_drag_from]     ; far enough yet?
        ANDI   R3, R1, 0xFFFF
        ANDI   R4, R2, 0xFFFF
        SUB    R3, R3, R4
        CALL   right_far
        CMPI   R3, 0x0000
        JNZ    decor_drag_far
        SHIFTI R3, R1, 0x10, 0b1000
        SHIFTI R4, R2, 0x10, 0b1000
        SUB    R3, R3, R4
        CALL   right_far
        CMPI   R3, 0x0000
        JZ     decor_drag_still
decor_drag_far: LOADLO R2, 1
        STORE  R2, [decor_moved]
decor_drag_follow: ANDI R5, R1, 0xFFFF
        SHIFTI R6, R1, 0x10, 0b1000
        LOAD   R2, [decor_grab_x]
        SUB    R5, R5, R2
        CMPIS  R5, 0
        JGE    decor_follow_x
        LOADLO R5, 0
decor_follow_x: LOAD R2, [decor_grab_y]
        SUB    R6, R6, R2
        CMPIS  R6, 0
        JGE    decor_follow_y
        LOADLO R6, 0
decor_follow_y: LOAD R1, [decor_drag]
        DEC    R1
        CALL   decor_record
        LOAD   R2, [R1 + D_X]           ; moved at all? redraw
        LOAD   R3, [R1 + D_Y]
        CMP    R2, R5
        JNZ    decor_follow_set
        CMP    R3, R6
        JZ     decor_drag_still
decor_follow_set: STORE R5, [R1 + D_X]
        STORE  R6, [R1 + D_Y]
        LOADLO R1, 1
        STORE  R1, [redraw]
decor_drag_still: RET

; decor_drag_stop, right button let go, moved = save DECOR.TXT
; not moved = its menu, uses R1-R7
decor_drag_stop: LOAD R1, [decor_drag]
        STORE  R0, [decor_drag]
        LOAD   R2, [decor_moved]
        STORE  R0, [decor_moved]
        CMPI   R2, 0x0000
        JNZ    decor_save               ; tail call
        DEC    R1                       ; its menu at the pointer
        PUSH   R8
        PUSH   R9
        MOV    R3, R1
        STORE  R0, [menu_count]
        LA     R1, menu_undecorate_text ; "Remove decoration"
        LOADLO R2, MENU_UNDECORATE
        CALL   menu_add
        LOAD   R1, [mouse_point]
        ANDI   R8, R1, 0xFFFF
        SHIFTI R9, R1, 0x10, 0b1000
        PUSH   R10
        JUMP   right_show               ; places the menu, pops R10, R9, R8

; ---- services for apps ----

; api_decorate, WM_DECORATE, adds a decoration near the middle and saves
; in R1 = pointer to picture name, like "crt64.pic"
; out R1 = 1 added, 0 not
api_decorate: PUSH R8
        LOADLO R2, 0
        LOADLO R3, 0
        CALL   decor_add_at
        CMPI   R1, 0x0000
        JZ     api_decorate_done
        LOAD   R1, [decor_count]
        DEC    R1
        CALL   decor_record
        MOV    R8, R1
        LOAD   R2, [R8 + D_FRAME_W]     ; x = (640 - width) / 2 + 16 x (count mod 8)
        LOADLO R1, PIXELS_ACROSS
        SUB    R1, R1, R2
        SHIFTI R1, R1, 0x01, 0b1000
        LOAD   R3, [decor_count]
        ANDI   R3, R3, 0x0007
        SHIFTI R3, R3, 0x04, 0b0000
        ADD    R1, R1, R3
        STORE  R1, [R8 + D_X]
        LOAD   R2, [R8 + D_HEIGHT]      ; y = (taskbar top - height) / 2 + the same
        LOADLO R1, TASKBAR_Y
        SUB    R1, R1, R2
        SHIFTI R1, R1, 0x01, 0b1000
        ADD    R1, R1, R3
        CMPIS  R1, 0
        JGE    api_decorate_y
        LOADLO R1, 0
api_decorate_y: STORE R1, [R8 + D_Y]
        CALL   decor_save
        LOADLO R1, 1
api_decorate_done: POP R8
        RET

; api_undecorate, WM_UNDECORATE, removes every decoration and saves, out R1 = 1
api_undecorate: LOAD R1, [decor_count]
        CMPI   R1, 0x0000
        JZ     api_undecorate_saved
        DEC    R1                       ; the last one
        CALL   decor_record
        CALL   decor_free
        LOAD   R1, [decor_count]
        DEC    R1
        STORE  R1, [decor_count]
        JUMP   api_undecorate
api_undecorate_saved: LOADLO R1, 1
        STORE  R1, [redraw]
        CALL   decor_save
        LOADLO R1, 1
        RET

; api_picture, WM_PICTURE, draws the first frame of a picture in the app window
; the last one asked for stays loaded in preview_
; in R1 = x, R2 = y, R3 = pointer to name
; out R1 = width in bits 15-0, height in 31-16, 0 = no such picture
api_picture: PUSH R8
        PUSH   R9
        PUSH   R10
        MOV    R9, R1
        MOV    R10, R2
        MOV    R8, R3
        MOV    R1, R8                   ; same one as last time?
        LOADLO R2, preview_name
        CALL   text_same
        CMPI   R3, 1
        JZ     api_picture_have
        LOAD   R1, [preview_raw]        ; free the old one first
        CMPI   R1, 0x0000
        JZ     api_picture_load
        CALLF  FREE
        STORE  R0, [preview_raw]
api_picture_load: STORE R0, [preview_name]
        MOV    R1, R8
        CALL   decor_picture            ; R1 = width, R2 = height, R3 = where, R4 = raw
        CMPI   R1, 0x0000
        JZ     api_picture_none
        STORE  R3, [preview_base]
        STORE  R4, [preview_raw]
        STORE  R2, [preview_height]
        CALL   frames_of                ; only its first frame
        STORE  R1, [preview_width]
        MOV    R1, R8                   ; note its name, up to 31 letters
        LOADLO R2, preview_name
        LOADLO R3, 31
api_picture_name: LOADB R4, [R1]
        STOREB R4, [R2]
        CMPI   R4, 0x0000
        JZ     api_picture_have
        CMPI   R3, 0x0000
        JZ     api_picture_cut
        INC    R1
        INC    R2
        DEC    R3
        JUMP   api_picture_name
api_picture_cut: STOREB R0, [R2]
api_picture_have: MOV R1, R9            ; where it goes in the window picture
        MOV    R2, R10
        LOAD   R7, [preview_height]
        CALL   paint_spot
        CMPI   R7, 0x0000
        JZ     api_picture_size
        SHIFTI R2, R2, 0x10, 0b0000
        OR     R1, R1, R2
        LOAD   R2, [preview_height]
        SHIFTI R2, R2, 0x10, 0b0000
        LOAD   R3, [preview_width]
        OR     R2, R2, R3
        LOAD   R3, [preview_base]
        ORI    R3, R3, KEY
        LOADLO R4, 0
        CALLF  DRAW_SPRITE
api_picture_size: LOAD R1, [preview_height]
        SHIFTI R1, R1, 0x10, 0b0000
        LOAD   R2, [preview_width]
        OR     R1, R1, R2
        JUMP   api_picture_done
api_picture_none: LOADLO R1, 0
api_picture_done: POP R10
        POP    R9
        POP    R8
        RET
