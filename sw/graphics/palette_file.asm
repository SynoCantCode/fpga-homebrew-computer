; the palette file and the colour command
; part of KERNEL.BIN
; /SYSTEM/DESIGN/PALETTE.TXT, plain text, read at every start-up
; each line replaces colours from the ROM palette
; numbers in hex without 0x
; family N RRGGBB     family N (1-E), 16 shades around RRGGBB as shade 8
; NN RRGGBB           colour number NN (00-FF) is exactly RRGGBB
; empty lines and lines starting with ; are skipped, words after the colour too
; family 4 3C8CE6 sky blue
; the shell's colour command takes the same lines, lost at reset
; colour 48 FF8800          colour family 4 3C8CE6          colour load
; the text screen's 16 colours are separate

; palette_line, one line of the palette file
; in R1 = pointer to the 0-ended line, out R1 = 0 set colours, 1 not a palette line
; R8 = pointer, then the colour number, R9 = 0x00RRGGBB
palette_line: PUSH R8
        PUSH   R9
        CALL   skip_spaces
        MOV    R8, R1
        LA     R2, family_word
        CALL   word_is
        CMPI   R1, 0x0000
        JZ     palette_single
        MOV    R1, R8
        CALL   after_word
        CALL   parse_hex                ; R1 = family number
        CMPI   R2, 0x0000
        JZ     palette_not
        CMPI   R1, 0x0001
        JNC    palette_not              ; 0 is the greys
        CMPI   R1, 0x000F
        JC     palette_not              ; F is the free colours
        SHIFTI R8, R1, 0x04, 0b0000     ; R8 = family's first colour number
        MOV    R1, R2
        CALL   parse_hex                ; R1 = middle shade
        CMPI   R2, 0x0000
        JZ     palette_not
        MOV    R9, R1
family_shade: MOV R1, R9
        ANDI   R2, R8, 0x000F           ; which shade
        CALLF  shade_of                 ; the ROM's shade_of
        MOV    R2, R1
        MOV    R1, R8
        CALLF  set_colour
        INC    R8
        TESTI  R8, 0x000F
        JNZ    family_shade             ; all 16 shades
        JUMP   palette_set
palette_single: MOV R1, R8
        CALL   parse_hex                ; R1 = colour number
        CMPI   R2, 0x0000
        JZ     palette_not
        CMPI   R1, 0x0100
        JC     palette_not              ; past FF
        MOV    R8, R1
        MOV    R1, R2
        CALL   parse_hex                ; R1 = its colour
        CMPI   R2, 0x0000
        JZ     palette_not
        MOV    R2, R1
        MOV    R1, R8
        CALLF  set_colour
palette_set: LOADLO R1, 0x0000
        JUMP   palette_line_done
palette_not: LOADLO R1, 0x0001
palette_line_done: POP R9
        POP    R8
        RET

; palette_load, reads /SYSTEM/DESIGN/PALETTE.TXT
; out R1 = 0 or an error number, 13 = no such file, R2 = lines used
; the file is read whole into heap memory and cut into lines
; 0x0A and 0x0D become the line's ending 0
; R8 = file size, R9 = the memory, R10 = this line, R11 = next line
; R12 = lines used
palette_load: PUSH R8
        PUSH   R9
        PUSH   R10
        PUSH   R11
        PUSH   R12
        LOADLO R12, 0
        LA     R1, palette_path
        CALLF  file_size                ; R1 = 0 or an error, R2 = size
        CMPI   R1, 0x0000
        JNZ    palette_load_done
        MOV    R8, R2
        LOADLO R1, 0x4000
        CMP    R8, R1
        JNC    palette_size_ok
        LOADLO R1, 18                   ; more than 16 KB, too big
        JUMP   palette_load_done
palette_size_ok: ADDI R1, R8, 1
        CALL   allocate                 ; room for it + an ending 0
        CMPI   R1, 0x0000
        JNZ    palette_have_room
        LOADLO R1, 18
        JUMP   palette_load_done
palette_have_room: MOV R9, R1
        LA     R1, palette_path
        MOV    R2, R9
        CALLF  file_read
        CMPI   R1, 0x0000
        JNZ    palette_load_free
        ADD    R1, R9, R8
        STOREB R0, [R1]                 ; ending 0 after the last line
        MOV    R10, R9
palette_next_line: LOADB R1, [R10]
        CMPI   R1, 0x0000
        JZ     palette_load_end         ; end of the file
        MOV    R11, R10                 ; find the end of this line
palette_find_end: LOADB R1, [R11]
        CMPI   R1, 0x0000
        JZ     palette_line_ready       ; last line
        CMPI   R1, 0x000A
        JZ     palette_line_cut
        CMPI   R1, 0x000D
        JZ     palette_line_cut
        INC    R11
        JUMP   palette_find_end
palette_line_cut: STOREB R0, [R11]      ; the line ends here
        INC    R11                      ; next line starts after it
palette_line_ready: MOV R1, R10
        CALL   palette_line
        CMPI   R1, 0x0000
        JNZ    palette_line_skipped
        INC    R12
palette_line_skipped: MOV R10, R11
        JUMP   palette_next_line
palette_load_end: LOADLO R1, 0x0000
palette_load_free: MOV R10, R1          ; the answer
        MOV    R1, R9
        CALL   free
        MOV    R1, R10
palette_load_done: MOV R2, R12
        POP    R12
        POP    R11
        POP    R10
        POP    R9
        POP    R8
        RET

; colour (or color), the shell command
; colour NN RRGGBB, colour family N RRGGBB, see palette_line
; colour load, reads /SYSTEM/DESIGN/PALETTE.TXT again
; in R1 = pointer to the words after the command, R8 = that pointer
command_colour: PUSH R8
        MOV    R8, R1
        LA     R2, load_word
        CALL   word_is
        CMPI   R1, 0x0000
        JZ     colour_set
        CALL   palette_load
        CMPI   R1, 0x0000
        JNZ    colour_load_failed
        MOV    R8, R2                   ; lines used
        LA     R1, palette_loaded_text  ; "palette.txt: d'5 lines used"
        CALLF  screen_text
        MOV    R1, R8
        CALL   screen_decimal
        LA     R1, palette_lines_text
        CALLF  screen_line
        JUMP   colour_done
colour_load_failed: CALL show_fs_error
        JUMP   colour_done
colour_set: MOV R1, R8
        CALL   palette_line
        CMPI   R1, 0x0000
        JZ     colour_done
        LA     R1, colour_usage_text
        CALLF  screen_line
colour_done: POP R8
        RET

family_word: .string "family"
load_word: .string "load"
palette_path: .string "/system/design/palette.txt"
palette_loaded_text: .string "palette.txt: d'"
palette_lines_text: .string " lines used"
colour_usage_text: .string "use: colour NN RRGGBB, colour family N RRGGBB, or colour load (hex)"
