; String length: counts the letters in a text that ends with a 0 byte (puzzle 2)
; At the end R2 = how many letters (3 for "HI!")

        LOADLO R1, message          ; R1 = the address of the text (a pointer)
        LOADLO R2, 0x0000           ; R2 = 0, the counter
loop:   LOADB  R3, [R1 + 0x0000]    ; R3 = the letter R1 points at
        CMPI   R3, 0x0000           ; is it the 0 at the end?
        JZ     done                 ; yes: finished
        INC    R1                   ; next letter
        INC    R2                   ; count it
        JUMP   loop
done:   HALT

message: .string "HI!"
