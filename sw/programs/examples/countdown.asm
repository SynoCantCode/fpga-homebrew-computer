; Countdown: Stores 10 down to 1 at 0x0000_0100, then halts

        LOADLO R1, 0x000A  ; counter = 10
        LOADLO R2, 0x0001 ; step = 1
        LOADLO R3, 0x0100 ; pointer = 0x0000_0100
loop:   STORE R1, [R3 + 0x0000] ; save the counter at the pointer
        ADDI R3, R3, 0x004 ; pointer + 4, no flags
        SUB R1, R1, R2, 0b1111 ; counter - 1 all flags
        JNZ loop ; not zero? again
        HALT