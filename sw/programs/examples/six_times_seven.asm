; multiply 6x7 by adding 6, seven times. Answer in R3

        LOADLO R1, 6
        LOADLO R2, 7
        LOADLO R3, 0
loop:   ADD R3, R3, R1
        DEC R2, 0b0100
        JNZ loop
        HALT