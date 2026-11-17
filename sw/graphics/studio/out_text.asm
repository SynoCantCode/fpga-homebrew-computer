; out_text, writes the pages text a piece at a time
; included by studio.asm

; short names for the text builder, tb_start, tb_text, tb_char,
; tb_number, tb_hex2, tb_line, saved with tb_save

; out_open, a new page text, 8 KB
out_open: LOADLO R1, 0x2000
        JUMP   tb_start

; put_text_out, a text up to its 0, in R1 = pointer, uses R1-R3
put_text_out: JUMP tb_text

; put_line_end_after, a text then CR LF, in R1 = pointer
put_line_end_after: CALL tb_text
put_newline: JUMP tb_line

; put_space, one space
put_space: LOADLO R1, 0x0020
        JUMP   tb_char

; put_number, decimal, in R1 = number, uses R1-R5
put_number: JUMP tb_number

; put_hex2, a byte as 2 hex digits, in R1 = byte
put_hex2: JUMP tb_hex2

; put_column_row, COLUMN ROW of the element at R9
put_column_row: CALL put_name          ; its #name first
        LOADB  R1, [R9 + 1]
        CALL   put_number
        CALL   put_space
        LOADB  R1, [R9 + 2]
        CALL   put_number
        JUMP   put_space

; put_name, #NAME if the element at R9 has one
put_name: LOAD R1, [R9 + E_NAME]
        CMPI   R1, 0x0000
        JZ     put_name_done
        LOADB  R2, [R1]
        CMPI   R2, 0x0000
        JZ     put_name_done            ; empty name
        LA     R1, w_hash
        CALL   put_text_out
        LOAD   R1, [R9 + E_NAME]
        CALL   put_text_out
        JUMP   put_space
put_name_done: RET

; put_size, WIDTH HEIGHT of the element at R9
put_size: LOAD R1, [R9 + 8]
        CALL   put_number
        CALL   put_space
        LOAD   R1, [R9 + 12]
        JUMP   put_number
