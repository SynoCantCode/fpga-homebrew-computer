; ticks, peek, poke, dump, sdread.block, heap
; included by shell.asm

; ticks, hundredths of a second since reset
command_ticks: LA R1, ticks_text
        CALLF  screen_text
        LOAD   R1, [TIMER]
        CALLF  screen_hex_word
        LA     R1, ticks_unit
        JUMPF  screen_line

; peek ADDR, shows the word at ADDR
command_peek: CALL parse_hex            ; R1 = address, R2 = 0 if not hex
        CMPI   R2, 0x0000
        JZ     peek_usage
        ANDI   R5, R1, 0x0003           ; bottom 2 bits, 0 for a multiple of 4
        JNZ    not_aligned
        JUMP   show_word
peek_usage: LA R1, peek_text
        JUMPF  screen_line
not_aligned: LA R1, aligned_text
        JUMPF  screen_line

; poke ADDR VALUE, stores VALUE at ADDR then shows it, R8 = address
command_poke: PUSH R8
        CALL   parse_hex
        CMPI   R2, 0x0000
        JZ     poke_usage
        ANDI   R5, R1, 0x0003
        JNZ    poke_not_aligned
        MOV    R8, R1                   ; R8 = address
        MOV    R1, R2
        CALL   parse_hex                ; R1 = value
        CMPI   R2, 0x0000
        JZ     poke_usage
        STORE  R1, [R8]
        MOV    R1, R8
        CALL   show_word                ; show what is there
        JUMP   poke_done
poke_usage: LA R1, poke_text
        CALLF  screen_line
        JUMP   poke_done
poke_not_aligned: LA R1, aligned_text
        CALLF  screen_line
poke_done: POP R8
        RET

; dump ADDR [COUNT], shows COUNT words from ADDR, one per line
; ADDR in hex, COUNT in decimal, 16 if left out
; R8 = address, R9 = words left
command_dump: PUSH R8
        PUSH   R9
        CALL   parse_hex
        CMPI   R2, 0x0000
        JZ     dump_usage
        ANDI   R5, R1, 0x0003
        JNZ    dump_not_aligned
        MOV    R8, R1                   ; R8 = address
        LOADLO R9, 16                   ; 16 words unless a count follows
        LOADB  R5, [R2]
        CMPI   R5, 0x0000
        JZ     dump_next                ; no count
        MOV    R1, R2
        CALL   parse_decimal            ; count is decimal
        CMPI   R2, 0x0000
        JZ     dump_usage
        MOV    R9, R1
        CMPI   R9, 0x0000
        JZ     dump_done                ; 0 words, nothing to show
dump_next: MOV R1, R8
        CALL   show_word
        ADDI   R8, R8, 4
        DEC    R9, 0b0100
        JNZ    dump_next
        JUMP   dump_done
dump_usage: LA R1, dump_text
        CALLF  screen_line
        JUMP   dump_done
dump_not_aligned: LA R1, aligned_text
        CALLF  screen_line
dump_done: POP R9
        POP    R8
        RET

; sdread.block BLOCK ADDR, reads a 512 byte block into memory at ADDR, hex
; wakes the card the first time, R8 = block number, R9 = address
command_sdread: PUSH R8
        PUSH   R9
        CALL   parse_hex                ; R1 = block number
        CMPI   R2, 0x0000
        JZ     sdread_usage
        MOV    R8, R1
        MOV    R1, R2
        CALL   parse_hex                ; R1 = address
        CMPI   R2, 0x0000
        JZ     sdread_usage
        MOV    R9, R1
        LOAD   R5, [SD_STATE]
        CMPI   R5, 0x0000
        JNZ    sdread_go                ; already awake
        CALLF  sd_init
        CMPI   R1, 0x0000
        JNZ    sdread_error
sdread_go: MOV R1, R8
        MOV    R2, R9
        CALLF  sd_read_block
        CMPI   R1, 0x0000
        JNZ    sdread_error
        LA     R1, sdread_text
        CALLF  screen_text
        MOV    R1, R8
        CALLF  screen_hex_word
        LA     R1, sdread_into
        CALLF  screen_text
        MOV    R1, R9
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   sdread_done
sdread_error: MOV R8, R1                ; error number
        LA     R1, sd_error_text
        CALLF  screen_text
        MOV    R1, R8
        CALLF  screen_hex_word
        LOADLO R1, 0x000A
        CALLF  screen_char
        JUMP   sdread_done
sdread_usage: LA R1, sdread_usage_text
        CALLF  screen_line
sdread_done: POP R9
        POP    R8
        RET

; heap, lists every piece, pointer, size, taken or free
; R8 = pointer to the label, R9 = end of the heap
command_heap: PUSH R8
        PUSH   R9
        LOADHI R8, HEAP_START_HIGH
        LOADHI R9, HEAP_END_HIGH
heap_next: CMP R8, R9
        JC     heap_done                ; past the last piece
        LOAD   R5, [R8]
        CMPI   R5, 0x0000
        JZ     heap_damaged             ; size 0 = damaged labels
        ADDI   R1, R8, 8
        CALLF  screen_hex_word          ; the pointer
        LA     R1, heap_size_text
        CALLF  screen_text
        LOAD   R1, [R8]
        SUBI   R1, R1, 8                ; usable bytes, without the label
        CALLF  screen_hex_word
        LA     R1, heap_taken_text
        LOAD   R5, [R8 + 4]
        CMPI   R5, 0x0000
        JNZ    heap_show
        LA     R1, heap_free_text
heap_show: CALLF screen_line
        LOAD   R5, [R8]
        ADD    R8, R8, R5               ; next label
        JUMP   heap_next
heap_damaged: LA R1, heap_damaged_text
        CALLF  screen_line
heap_done: POP R9
        POP    R8
        RET
