; app library, the line reader
; a text file read whole, then taken a line at a time
; include text.asm then lines.asm at the end of app.asm
; file_text   R1 = path              -> R1 = text in the heap, R2 = its end
; line_first  R1 = place, R2 = end   -> R1 = first real line or 0
; line_next   R1 = line, R2 = end    -> R1 = next real line or 0
; first_word  R1 = line              -> R2 = first word, R1 = the rest
; call line_next before first_word and keep it
; first_word writes a 0 into the line, it would look like its end

; file_text, a text file into the heap, CR and LF made 0, a 0 at the end
; in R1 = pointer to its path, out R1 = text or 0, R2 = its end. uses R1-R7
file_text: PUSH R8
        PUSH   R9
        MOV    R8, R1
        CALLF  FILE_SIZE                ; R2 = its size
        CMPI   R1, 0x0000
        JNZ    file_text_none
        MOV    R9, R2
        ADDI   R1, R9, 1
        CALLF  ALLOCATE
        CMPI   R1, 0x0000
        JZ     file_text_none
        MOV    R2, R1
        MOV    R1, R8
        MOV    R8, R2
        CALLF  FILE_READ
        CMPI   R1, 0x0000
        JNZ    file_text_none
        ADD    R9, R8, R9               ; R9 = its end, a 0 there
        STOREB R0, [R9]
        MOV    R1, R8
file_text_ends: CMP R1, R9               ; each CR and LF made a 0
        JC     file_text_done
        LOADB  R2, [R1]
        CMPI   R2, 0x000D
        JZ     file_text_end
        CMPI   R2, 0x000A
        JNZ    file_text_next
file_text_end: STOREB R0, [R1]
file_text_next: INC R1
        JUMP   file_text_ends
file_text_done: MOV R1, R8
        MOV    R2, R9
        POP    R9
        POP    R8
        RET
file_text_none: LOADLO R1, 0
        POP    R9
        POP    R8
        RET

; line_first, first real line from a place, skips blank lines and ; notes
; in R1 = place in the text, R2 = its end, out R1 = line or 0. uses R3
line_first: CMP R1, R2
        JC     line_none
        LOADB  R3, [R1]
        CMPI   R3, 0x0021
        JNC    line_blank               ; a 0 or a space
        CMPI   R3, 0x003B
        JZ     line_note
        RET
line_blank: INC R1
        JUMP   line_first
line_note: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     line_blank
        INC    R1
        JUMP   line_note
line_none: LOADLO R1, 0
        RET

; line_next, the next real line after this one
; in R1 = line, R2 = text end, out as line_first. uses R3
line_next: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     line_blank
        INC    R1
        JUMP   line_next

; first_word, cut off a line's first word with a 0
; in R1 = line, out R2 = word, R1 = rest of the line. uses R3, R4
first_word: LOADB R3, [R1]              ; skip spaces before it
        CMPI   R3, 0x0020
        JNZ    first_word_start
        INC    R1
        JUMP   first_word
first_word_start: MOV R2, R1
first_word_next: LOADB R3, [R1]
        CMPI   R3, 0x0000
        JZ     first_word_done
        CMPI   R3, 0x0020
        JZ     first_word_cut
        INC    R1
        JUMP   first_word_next
first_word_cut: STOREB R0, [R1]
        INC    R1
first_word_done: RET

