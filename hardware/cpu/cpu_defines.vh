//Shared nicknames for the CPU

//ALU jobs
localparam OP_ADD = 4'h0;
localparam OP_SUB = 4'h1;
localparam OP_AND  = 4'h2;
localparam OP_OR   = 4'h3;
localparam OP_XOR  = 4'h4;
localparam OP_NOT  = 4'h5;
localparam OP_NAND = 4'h6;
localparam OP_NOR  = 4'h7;
localparam OP_XNOR = 4'h8;

//Opcodes, grouped by first hex digit
//CPU only runs the ones in is_known_opcode, others halt

//0x0_ loads
localparam OPCODE_HALT     = 8'h00;
localparam OPCODE_LOADLO   = 8'h01;
localparam OPCODE_LOADHI   = 8'h02;
localparam OPCODE_LOAD     = 8'h03;
localparam OPCODE_LOADB    = 8'h04;
localparam OPCODE_LOADLOK  = 8'h05;
localparam OPCODE_LOADHIK  = 8'h06;

//0x1_ stores
localparam OPCODE_STORE    = 8'h10;
localparam OPCODE_STOREB   = 8'h11;

//0x2_ arithmetic (flag switches, 12 bit numbers)
localparam OPCODE_INC      = 8'h20;
localparam OPCODE_DEC      = 8'h21;
localparam OPCODE_ADD      = 8'h22;
localparam OPCODE_ADC      = 8'h23;
localparam OPCODE_ADDI     = 8'h24;
localparam OPCODE_ADCI     = 8'h25;
localparam OPCODE_SUB      = 8'h26;
localparam OPCODE_SBC      = 8'h27;
localparam OPCODE_SUBI     = 8'h28;
localparam OPCODE_SBCI     = 8'h29;
localparam OPCODE_ADDIS    = 8'h2A;
localparam OPCODE_ADCIS    = 8'h2B;
localparam OPCODE_NEG      = 8'h2C;

//0x3_ wide arithmetic (16 bit numbers, flags never change)
localparam OPCODE_ADDIW    = 8'h30;
localparam OPCODE_ADCIW    = 8'h31;
localparam OPCODE_SUBIW    = 8'h32;
localparam OPCODE_SBCIW    = 8'h33;
localparam OPCODE_ADDISW   = 8'h34;
localparam OPCODE_ADCISW   = 8'h35;
localparam OPCODE_MULIW    = 8'h36;
localparam OPCODE_DIVIW    = 8'h37;
localparam OPCODE_DIVUIW   = 8'h38;
localparam OPCODE_MODIW    = 8'h39;
localparam OPCODE_MODUIW   = 8'h3A;

//0x4_ multiply and divide
localparam OPCODE_MUL      = 8'h40;
localparam OPCODE_MULI     = 8'h41;
localparam OPCODE_MULH     = 8'h42;
localparam OPCODE_MULHU    = 8'h43;
localparam OPCODE_DIV      = 8'h44;
localparam OPCODE_DIVI     = 8'h45;
localparam OPCODE_DIVU     = 8'h46;
localparam OPCODE_DIVUI    = 8'h47;
localparam OPCODE_MOD      = 8'h48;
localparam OPCODE_MODI     = 8'h49;
localparam OPCODE_MODU     = 8'h4A;
localparam OPCODE_MODUI    = 8'h4B;

//0x5_ logic (always N and Z)
localparam OPCODE_AND      = 8'h50;
localparam OPCODE_ANDI     = 8'h51;
localparam OPCODE_OR       = 8'h52;
localparam OPCODE_ORI      = 8'h53;
localparam OPCODE_XOR      = 8'h54;
localparam OPCODE_XORI     = 8'h55;
localparam OPCODE_NOT      = 8'h56;
localparam OPCODE_NAND     = 8'h57;
localparam OPCODE_NANDI    = 8'h58;
localparam OPCODE_NOR      = 8'h59;
localparam OPCODE_NORI     = 8'h5A;
localparam OPCODE_XNOR     = 8'h5B;
localparam OPCODE_XNORI    = 8'h5C;

//0x6_ shifts and rotates
localparam OPCODE_SHIFT    = 8'h60;
localparam OPCODE_SHIFTI   = 8'h61;
localparam OPCODE_ROT      = 8'h62;
localparam OPCODE_ROTI     = 8'h63;

//0x7_ compare and test (only set flags)
localparam OPCODE_CMP      = 8'h70;
localparam OPCODE_CMPI     = 8'h71;
localparam OPCODE_CMPIS    = 8'h72;
localparam OPCODE_TEST     = 8'h73;
localparam OPCODE_TESTI    = 8'h74;

//0x8_ relative jumps (PC = this address + offset x 4)
localparam OPCODE_JUMP     = 8'h80;
localparam OPCODE_JZ       = 8'h81;
localparam OPCODE_JNZ      = 8'h82;
localparam OPCODE_JC       = 8'h83;
localparam OPCODE_JNC      = 8'h84;
localparam OPCODE_JN       = 8'h85;
localparam OPCODE_JNN      = 8'h86;
localparam OPCODE_JV       = 8'h87;
localparam OPCODE_JNV      = 8'h88;
localparam OPCODE_JGTU     = 8'h89;
localparam OPCODE_JLEU     = 8'h8A;
localparam OPCODE_JLT      = 8'h8B;
localparam OPCODE_JGE      = 8'h8C;
localparam OPCODE_JGT      = 8'h8D;
localparam OPCODE_JLE      = 8'h8E;

//0x9_ register jumps (PC = rs1)
localparam OPCODE_JUMPR    = 8'h90;
localparam OPCODE_JZR      = 8'h91;
localparam OPCODE_JNZR     = 8'h92;
localparam OPCODE_JCR      = 8'h93;
localparam OPCODE_JNCR     = 8'h94;
localparam OPCODE_JNR      = 8'h95;
localparam OPCODE_JNNR     = 8'h96;
localparam OPCODE_JVR      = 8'h97;
localparam OPCODE_JNVR     = 8'h98;
localparam OPCODE_JGTUR    = 8'h99;
localparam OPCODE_JLEUR    = 8'h9A;
localparam OPCODE_JLTR     = 8'h9B;
localparam OPCODE_JGER     = 8'h9C;
localparam OPCODE_JGTR     = 8'h9D;
localparam OPCODE_JLER     = 8'h9E;

//0xA_ stack and subroutines
localparam OPCODE_CALL     = 8'hA0;
localparam OPCODE_CALLR    = 8'hA1;
localparam OPCODE_RET      = 8'hA2;
localparam OPCODE_PUSH     = 8'hA3;
localparam OPCODE_POP      = 8'hA4;
localparam OPCODE_PUSHF    = 8'hA5;
localparam OPCODE_POPF     = 8'hA6;

//0xB_ system and interrupts
localparam OPCODE_EI       = 8'hB0;
localparam OPCODE_DI       = 8'hB1;
localparam OPCODE_RETI     = 8'hB2;
localparam OPCODE_TRAP     = 8'hB3;
localparam OPCODE_WAIT     = 8'hB4;
localparam OPCODE_SETIVEC  = 8'hB5;
localparam OPCODE_GETIVEC  = 8'hB6;
localparam OPCODE_GETCAUSE = 8'hB7;
localparam OPCODE_SETSLIM  = 8'hB8; //SLIM = rs1, the stack limit
localparam OPCODE_GETSLIM  = 8'hB9; //rd = SLIM

//0xC_ moves and flags
localparam OPCODE_MOV      = 8'hC0;
localparam OPCODE_SETF     = 8'hC1;
localparam OPCODE_CLRF     = 8'hC2;
localparam OPCODE_GETPC    = 8'hC3;
localparam OPCODE_GETF     = 8'hC4;
localparam OPCODE_PUTF     = 8'hC5;

//0xF_ miscellaneous
localparam OPCODE_RAND     = 8'hF0;
localparam OPCODE_FLUSH    = 8'hF1;
localparam OPCODE_NOP      = 8'hFF;

//first hex digit = group, second = condition
//0x8F and 0x9F are free
localparam GROUP_JUMP_REL = 4'h8; //PC = this address + offset x 4
localparam GROUP_JUMP_REG = 4'h9; //PC = rs1

//Jump conditions, opcode's second hex digit
localparam COND_ALWAYS = 4'h0; //JUMP, always
localparam COND_Z      = 4'h1; //JZ, Z = 1, equal
localparam COND_NZ     = 4'h2; //JNZ, Z = 0, not equal
localparam COND_C      = 4'h3; //JC, C = 1, unsigned >=
localparam COND_NC     = 4'h4; //JNC, C = 0, unsigned <
localparam COND_N      = 4'h5; //JN, N = 1, negative
localparam COND_NN     = 4'h6; //JNN, N = 0, not negative
localparam COND_V      = 4'h7; //JV, V = 1, signed overflow
localparam COND_NV     = 4'h8; //JNV, V = 0, no signed overflow
localparam COND_GTU    = 4'h9; //JGTU, C = 1 and Z = 0, unsigned >
localparam COND_LEU    = 4'hA; //JLEU, C = 0 or Z = 1, unsigned <=
localparam COND_LT     = 4'hB; //JLT, N != V, signed <
localparam COND_GE     = 4'hC; //JGE, N = V, signed >=
localparam COND_GT     = 4'hD; //JGT, Z = 0 and N = V, signed >
localparam COND_LE     = 4'hE; //JLE, Z = 1 or N != V, signed <=
