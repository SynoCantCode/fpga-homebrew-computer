//CPU:
//Plugs in the register file, talks to memory
//Runs Fetch, Fetch_Wait, Decode, Execute, Writeback


module cpu (
    input wire clk,
    input wire rst,

    //Memory pins
    output wire [31:0] mem_address,
    output wire [31:0] mem_write_data,
    output wire mem_we,
    output wire [3:0] mem_byte_enable, //which bytes to write, 1111 = all
    input wire [31:0] mem_read_data,
    //SDRAM is slow, CPU stays in the step while mem_wait = 1
    input wire mem_wait, //1 = not ready, stay in this step
    output wire mem_valid, //1 = CPU is asking memory (FETCH or MEMORY)
    output wire mem_is_fetch, //1 = instruction fetch
    output wire flush_cache, //1 for one tick, FLUSH empties the instruction cache

    //Interrupts
    input wire irq, //1 = a device wants attention, stays 1 until handled

    //Status
    output wire halted

);

//state is a 4 bit reg which says the step the CPU is on

localparam STATE_FETCH = 4'h0; //Send PC to memory
localparam STATE_FETCH_WAIT = 4'h1; //Memory answers, catch the instruction into IR
localparam STATE_DECODE = 4'h2; //Read registers into A and B
localparam STATE_EXECUTE = 4'h3; //ALU does work
localparam STATE_DIVIDE = 4'h4;
localparam STATE_MEMORY = 4'h5; //LOAD & STORE
localparam STATE_MEMORY2 = 4'h6; //RETI's second pop
localparam STATE_WAIT = 4'h7; //WAIT instruction
localparam STATE_WRITEBACK = 4'h8; //save answer, move PC
localparam STATE_INT_FLAGS = 4'h9;
localparam STATE_INT_RETURN = 4'hA;
localparam STATE_HALT = 4'hB; //HALT : only reset to get out

`include "cpu_defines.vh"


//hidden registers

reg [3:0] state;

reg [31:0] pc;

reg [31:0] ir;

reg [31:0] a;
reg [31:0] b;

reg [31:0] result; //answer from EXECUTE, saved in WRITEBACK

//Interrupt registers
reg [31:0] ivec; //interrupt handler's address
reg [31:0] cause; //why the handler was entered
reg        ie; //interrupts enabled, traps ignore it
reg [31:0] stack_limit; //lowest address the stack can reach, 0 = no limit
reg        trap_pending; //go to the handler when this instruction ends
reg [31:0] trap_cause; //CAUSE for the pending trap
reg [31:0] data; //RETI's first pop, the return address

reg flag_n;
reg flag_z;
reg flag_c;
reg flag_v;


//Split IR into fields
//consistent for all of them (im goated)

//R format: opcode [31:24], rd [23:20], rs1 [19:16], NZCV [15:12], rs2 [11:8], zeros [7:0]
//F format: opcode [31:24], rd [23:20], rs1 [19:16], NZCV [15:12], imm12 [11:0]
//I format: opcode [31:24], rd [23:20], rs1 [19:16], imm16 [15:0]
//S format: opcode [31:24], rd [23:20], rs1 [19:16], NZCV [15:12], amount [11:4], type [3:0]
//SHIFT and ROT use rs2 [11:8] for the amount

//opcode = which instruction
//rd = register that gets the answer
//rs1 = first input register
//NZCV = which flags to save
//rs2 = second input register
//imm12 = 12 bit number
//imm16 = 16 bit number
//amount = how far to shift, bottom 5 bits
//type = D00V, D = direction (0 left, 1 right), V = variant

wire [7:0] opcode;
wire [3:0] rd;
wire [3:0] rs1;
wire [3:0] rs2;
wire [3:0] flag_switches;
wire [15:0] imm16;
wire [11:0] imm12;

assign opcode        = ir[31:24];
assign rd            = ir[23:20];
assign rs1           = ir[19:16];
assign rs2           = ir[11:8];
assign flag_switches = ir[15:12];
assign imm16         = ir[15:0];
assign imm12         = ir[11:0];

//LOAD and STORE, use the MEMORY step
wire is_memory_op;
assign is_memory_op = (opcode == OPCODE_LOAD)  || (opcode == OPCODE_STORE)
                   || (opcode == OPCODE_LOADB) || (opcode == OPCODE_STOREB);

//the two stores
wire is_store;
assign is_store = (opcode == OPCODE_STORE) || (opcode == OPCODE_STOREB);

//16 bit offset sign extended to 32
wire [31:0] offset_sext;
assign offset_sext = {{16{imm16[15]}}, imm16};

//arithmetic group, 0x20 INC to 0x2C NEG
wire is_arith;
assign is_arith = (opcode >= OPCODE_INC) && (opcode <= OPCODE_NEG);

//wide add and sub, 0x30 ADDIW to 0x35 ADCISW
//16 bit number, flags never change
wire is_wide;
assign is_wide = (opcode >= OPCODE_ADDIW) && (opcode <= OPCODE_ADCISW);

//stack group, 0xA0 CALL to 0xA6 POPF, uses R15SP
wire is_stack;
assign is_stack = (opcode >= OPCODE_CALL) && (opcode <= OPCODE_POPF);
//pushes R15SP - 4 and write, pops read and R15SP + 4
wire is_push;
assign is_push = (opcode == OPCODE_PUSH) || (opcode == OPCODE_PUSHF)
              || (opcode == OPCODE_CALL) || (opcode == OPCODE_CALLR);
wire is_pop;
assign is_pop = (opcode == OPCODE_POP) || (opcode == OPCODE_POPF) || (opcode == OPCODE_RET);

//RETI pops two words, return address then flags
wire is_reti;
assign is_reti = (opcode == OPCODE_RETI);

//system group, 0xB0 EI to 0xB9 GETSLIM
wire is_system;
assign is_system = (opcode >= OPCODE_EI) && (opcode <= OPCODE_GETSLIM);

//trap always, irq only if IE = 1
wire is_entering_handler;
assign is_entering_handler = trap_pending || (irq && ie);

//multiply and divide, 0x40 to 0x4B, wide ones 0x36 to 0x3A
wire is_muldiv;
assign is_muldiv = (opcode >= OPCODE_MUL) && (opcode <= OPCODE_MODUI);
wire is_wide_muldiv;
assign is_wide_muldiv = (opcode >= OPCODE_MULIW) && (opcode <= OPCODE_MODUIW);
//multiplies take 1 tick, divides 32
wire is_multiply;
assign is_multiply = (opcode == OPCODE_MUL) || (opcode == OPCODE_MULI) || (opcode == OPCODE_MULH)
                  || (opcode == OPCODE_MULHU) || (opcode == OPCODE_MULIW);
wire is_divide;
assign is_divide = (is_muldiv || is_wide_muldiv) && !is_multiply;
//signed divides, and the ones that want the remainder
wire is_signed_divide;
assign is_signed_divide = (opcode == OPCODE_DIV) || (opcode == OPCODE_DIVI) || (opcode == OPCODE_MOD)
                       || (opcode == OPCODE_MODI) || (opcode == OPCODE_DIVIW) || (opcode == OPCODE_MODIW);
wire is_modulo;
assign is_modulo = (opcode == OPCODE_MOD) || (opcode == OPCODE_MODI) || (opcode == OPCODE_MODU)
                || (opcode == OPCODE_MODUI) || (opcode == OPCODE_MODIW) || (opcode == OPCODE_MODUIW);

//the ones that subtract
wire is_subtract;
assign is_subtract = (opcode == OPCODE_SUB)  || (opcode == OPCODE_SBC)
                  || (opcode == OPCODE_SUBI) || (opcode == OPCODE_SBCI)
                  || (opcode == OPCODE_DEC)  || (opcode == OPCODE_NEG)
                  || (opcode == OPCODE_CMP)  || (opcode == OPCODE_CMPI) || (opcode == OPCODE_CMPIS)
                  || (opcode == OPCODE_SUBIW) || (opcode == OPCODE_SBCIW)
                  || is_push; //pushes do R15SP - 4

//the ones that read the carry flag
wire is_carry_used;
assign is_carry_used = (opcode == OPCODE_ADC)  || (opcode == OPCODE_ADCI) || (opcode == OPCODE_ADCIS)
                    || (opcode == OPCODE_SBC)  || (opcode == OPCODE_SBCI)
                    || (opcode == OPCODE_ADCIW) || (opcode == OPCODE_SBCIW) || (opcode == OPCODE_ADCISW);

//logic group, 0x50 AND to 0x5C XNORI
//always saves N and Z, never C and V
wire is_logic;
assign is_logic = (opcode >= OPCODE_AND) && (opcode <= OPCODE_XNORI);

//compare group, 0x70 CMP to 0x74 TESTI
//only flags, answer thrown away
wire is_compare;
assign is_compare = (opcode >= OPCODE_CMP) && (opcode <= OPCODE_TESTI);

//shift group, 0x60 SHIFT, 0x61 SHIFTI, 0x62 ROT, 0x63 ROTI
wire is_shift_group;
assign is_shift_group = (opcode >= OPCODE_SHIFT) && (opcode <= OPCODE_ROTI);
wire is_rotate;
assign is_rotate = (opcode == OPCODE_ROT) || (opcode == OPCODE_ROTI);
wire [3:0] shift_type;
assign shift_type = ir[3:0];
//shifts allow 0000, 1000, 1001, rotates also 0001, others halt
wire is_shift_type_ok;
assign is_shift_type_ok = (shift_type == 4'b0000) || (shift_type == 4'b1000) || (shift_type == 4'b1001)
                       || (is_rotate && (shift_type == 4'b0001));
//SHIFTI/ROTI amount from the instruction, SHIFT/ROT from B, bottom 5 bits
wire [4:0] shift_amount;
assign shift_amount = ((opcode == OPCODE_SHIFTI) || (opcode == OPCODE_ROTI)) ? ir[8:4] : b[4:0];

//moves and flags group, 0xC0 MOV to 0xC5 PUTF
wire is_move_or_flags;
assign is_move_or_flags = (opcode >= OPCODE_MOV) && (opcode <= OPCODE_PUTF);

//INC and DEC read rd instead of rs1
wire is_rd_read;
assign is_rd_read = (opcode == OPCODE_INC) || (opcode == OPCODE_DEC);

//jumps, first hex digit = group, second = condition
//0x8F and 0x9F are free, they halt
wire is_jump_rel;
assign is_jump_rel = (opcode[7:4] == GROUP_JUMP_REL) && (opcode[3:0] != 4'hF);
wire is_jump_reg;
assign is_jump_reg = (opcode[7:4] == GROUP_JUMP_REG) && (opcode[3:0] != 4'hF);

//is the jump condition true
reg is_condition_met;
always @(*) begin
    case (opcode[3:0])
        COND_ALWAYS: is_condition_met = 1'b1;
        COND_Z:      is_condition_met = flag_z;
        COND_NZ:     is_condition_met = !flag_z;
        COND_C:      is_condition_met = flag_c;
        COND_NC:     is_condition_met = !flag_c;
        COND_N:      is_condition_met = flag_n;
        COND_NN:     is_condition_met = !flag_n;
        COND_V:      is_condition_met = flag_v;
        COND_NV:     is_condition_met = !flag_v;
        COND_GTU:    is_condition_met = flag_c && !flag_z;
        COND_LEU:    is_condition_met = !flag_c || flag_z;
        COND_LT:     is_condition_met = (flag_n != flag_v);
        COND_GE:     is_condition_met = (flag_n == flag_v);
        COND_GT:     is_condition_met = !flag_z && (flag_n == flag_v);
        COND_LE:     is_condition_met = flag_z || (flag_n != flag_v);
        default:     is_condition_met = 1'b0;
    endcase
end

//unknown opcodes halt
wire is_known_opcode;
assign is_known_opcode = (opcode == OPCODE_HALT)   || (opcode == OPCODE_NOP)
                      || (opcode == OPCODE_LOADLO) || (opcode == OPCODE_LOADHI)
                      || (opcode == OPCODE_LOAD)   || (opcode == OPCODE_STORE)
                      || (opcode == OPCODE_LOADB)  || (opcode == OPCODE_STOREB)
                      || (opcode == OPCODE_LOADLOK) || (opcode == OPCODE_LOADHIK)
                      || is_arith
                      || is_wide
                      || is_logic
                      || is_compare
                      || is_jump_rel || is_jump_reg
                      || is_move_or_flags
                      || is_stack
                      || is_system
                      || is_muldiv || is_wide_muldiv
                      || (is_shift_group && is_shift_type_ok)
                      || (opcode == OPCODE_RAND)   || (opcode == OPCODE_FLUSH);

//PC adder, separate from the ALU
wire [31:0] pc_plus_4;
assign pc_plus_4 = pc + 32'h0000_0004;

//where a jump goes
//register jumps: rs1 (in A), bottom 2 bits 0
//relative jumps: PC + offset x 4
wire [31:0] jump_target;
assign jump_target = is_jump_reg ? {a[31:2], 2'b00} : (pc + {offset_sext[29:0], 2'b00});

//jump only if its condition is true
wire is_jump_taken;
assign is_jump_taken = (is_jump_rel || is_jump_reg) && is_condition_met;

//next PC, WRITEBACK copies it into pc
//RET: popped address, bottom 2 bits 0
//CALL: PC + offset x 4
//CALLR: rs1 (in B)
//jumps: jump target if condition is true
//everyone else: next instruction
reg [31:0] next_pc;
always @(*) begin
    if (trap_pending)
        next_pc = pc_plus_4; //traps never jump
    else if (opcode == OPCODE_RET)
        next_pc = {mem_read_data[31:2], 2'b00};
    else if (is_reti)
        next_pc = {data[31:2], 2'b00}; //return address from the first pop
    else if (opcode == OPCODE_CALL)
        next_pc = pc + {offset_sext[29:0], 2'b00};
    else if (opcode == OPCODE_CALLR)
        next_pc = {b[31:2], 2'b00};
    else if (is_jump_taken)
        next_pc = jump_target;
    else
        next_pc = pc_plus_4;
end

//Plugging in the register file

wire [31:0] reg_read_data1;
wire [31:0] reg_read_data2;

wire is_rd_write;
assign is_rd_write = (opcode == OPCODE_LOADLO) || (opcode == OPCODE_LOADHI)
                || is_arith
                || is_wide
                || is_logic
                || (opcode == OPCODE_LOAD) || (opcode == OPCODE_LOADB)
                || (opcode == OPCODE_LOADLOK) || (opcode == OPCODE_LOADHIK)
                || (opcode == OPCODE_MOV) || (opcode == OPCODE_GETPC) || (opcode == OPCODE_GETF)
                || (opcode == OPCODE_RAND)
                || is_shift_group
                || (opcode == OPCODE_POP)
                || (opcode == OPCODE_GETIVEC) || (opcode == OPCODE_GETCAUSE) || (opcode == OPCODE_GETSLIM)
                || is_muldiv || is_wide_muldiv;

wire reg_we1;
//not on a trap, divide by zero leaves rd alone
assign reg_we1 = (state == STATE_WRITEBACK) && is_rd_write && !trap_pending;

//Read port 1: stack group reads R15SP, INC and DEC read rd, else rs1
wire [3:0] reg_read_addr1;
//RETI and handler entry need R15SP too
wire is_in_entry;
assign is_in_entry = (state == STATE_INT_FLAGS) || (state == STATE_INT_RETURN);
assign reg_read_addr1 = (is_stack || is_reti || is_in_entry) ? 4'hF : (is_rd_read ? rd : rs1);

//R15SP - 4 and - 8, the two handler entry pushes
wire [31:0] sp_minus_4;
assign sp_minus_4 = reg_read_data1 - 32'h0000_0004;
wire [31:0] sp_minus_8;
assign sp_minus_8 = reg_read_data1 - 32'h0000_0008;

//Read port 2: STORE reads rd, else rs2
wire [3:0] reg_read_addr2;
//PUSH reads rd, CALLR reads rs1
assign reg_read_addr2 = (is_store || (opcode == OPCODE_PUSH)) ? rd
                      : ((opcode == OPCODE_CALLR) ? rs1 : rs2);

//Write port 2: new R15SP in WRITEBACK
//POP uses both ports, port 1 = rd, port 2 = R15SP
wire reg_we2;
//RETI R15SP + 8, handler entry R15SP - 8
//not on a trap, R15SP stays
assign reg_we2 = ((state == STATE_WRITEBACK) && (is_stack || is_reti) && !trap_pending) || (state == STATE_INT_RETURN);
wire [31:0] reg_write_data2;
assign reg_write_data2 = (state == STATE_INT_RETURN) ? sp_minus_8 : result;

//LOADB picks one byte from the word
//address bottom 2 bits say which, little-endian
reg [7:0] loaded_byte;
always @(*) begin
    case (result[1:0])
        2'b00: loaded_byte = mem_read_data[7:0];
        2'b01: loaded_byte = mem_read_data[15:8];
        2'b10: loaded_byte = mem_read_data[23:16];
        2'b11: loaded_byte = mem_read_data[31:24];
    endcase
end

//what goes into rd
//LOAD whole word, LOADB one byte with zeros on top, else result
reg [31:0] reg_write_data1;
always @(*) begin
    case (opcode)
        OPCODE_LOAD:  reg_write_data1 = mem_read_data;
        OPCODE_LOADB: reg_write_data1 = {24'h00_0000, loaded_byte};
        OPCODE_POP:   reg_write_data1 = mem_read_data;
        default:      reg_write_data1 = result;
    endcase
end


regfile registers (
    .clk(clk),
    .rst(rst),

    .read_addr1(reg_read_addr1),
    .read_data1(reg_read_data1),
    .read_addr2(reg_read_addr2),
    .read_data2(reg_read_data2),

    .we1(reg_we1),
    .write_addr1(rd),
    .write_data1(reg_write_data1),

    .we2(reg_we2),
    .write_addr2(4'hF), //always R15SP
    .write_data2(reg_write_data2) //new stack pointer

);

//Plugging in the random number generator
//RAND copies whatever it has
wire [31:0] random_value;

random randomizer (
    .clk(clk),
    .rst(rst),
    .random_number(random_value)
);

//Plugging in the shifter
wire [31:0] shifter_result;
wire        shifter_carry;

shifter bit_mover (
    .value(a),
    .amount(shift_amount),
    .type(shift_type),
    .is_rotate(is_rotate),
    .carry_in(flag_c),
    .result(shifter_result),
    .carry_out(shifter_carry)
);

//Plugging in the multiplier
wire [63:0] product_unsigned;
wire [63:0] product_signed;

multiplier times (
    .a(a),
    .b(b),
    .product_unsigned(product_unsigned),
    .product_signed(product_signed)
);

//MULH signed high half, MULHU unsigned high half
//MUL, MULI, MULIW low half
wire [31:0] multiply_answer;
assign multiply_answer = (opcode == OPCODE_MULH)  ? product_signed[63:32]
                       : (opcode == OPCODE_MULHU) ? product_unsigned[63:32]
                       : product_unsigned[31:0];
//C = unsigned product didn't fit in 32 bits, V = signed didn't fit
wire multiply_flag_c;
assign multiply_flag_c = (product_unsigned[63:32] != 32'h0000_0000);
wire multiply_flag_v;
assign multiply_flag_v = (product_signed[63:32] != {32{product_signed[31]}});

//Plugging in the divider, EXECUTE starts it, DIVIDE waits 32 ticks
wire        divider_busy;
wire [31:0] divider_quotient;
wire [31:0] divider_remainder;
wire        divider_start;
assign divider_start = (state == STATE_EXECUTE) && is_divide && (b != 32'h0000_0000);

divider long_division (
    .clk(clk),
    .rst(rst),
    .start(divider_start),
    .is_signed(is_signed_divide),
    .dividend(a),
    .divisor(b),
    .busy(divider_busy),
    .quotient(divider_quotient),
    .remainder(divider_remainder)
);

//which job the ALU does
reg [3:0] alu_operation;
always @(*) begin
    case (opcode)
        OPCODE_AND,  OPCODE_ANDI,
        OPCODE_TEST, OPCODE_TESTI: alu_operation = OP_AND;
        OPCODE_OR,   OPCODE_ORI:   alu_operation = OP_OR;
        OPCODE_XOR,  OPCODE_XORI:  alu_operation = OP_XOR;
        OPCODE_NOT:                alu_operation = OP_NOT;
        OPCODE_NAND, OPCODE_NANDI: alu_operation = OP_NAND;
        OPCODE_NOR,  OPCODE_NORI:  alu_operation = OP_NOR;
        OPCODE_XNOR, OPCODE_XNORI: alu_operation = OP_XNOR;
        //everything else adds or subtracts
        default:                   alu_operation = is_subtract ? OP_SUB : OP_ADD;
    endcase
end

//ALU carry in
//with carry ones use C, plain sub 1, plain add 0
wire alu_carry_in;
assign alu_carry_in = is_carry_used ? flag_c : is_subtract;

wire [31:0] alu_result;

//word LOAD or STORE, address not a multiple of 4
//LOADB and STOREB can use any address
wire is_misaligned;
assign is_misaligned = ((opcode == OPCODE_LOAD) || (opcode == OPCODE_STORE)) && (alu_result[1:0] != 2'b00);

wire alu_flag_n;
wire alu_flag_z;
wire alu_flag_c;
wire alu_flag_v;

//ALU second input: offset for LOAD/STORE, else B
wire [31:0] alu_b;
//stack group uses 4
//RETI uses 8, pops two words
assign alu_b = is_memory_op ? offset_sext
             : (is_stack ? 32'h0000_0004
             : (is_reti  ? 32'h0000_0008 : b));

alu calculator (
    .a(a),
    .b(alu_b),
    .operation(alu_operation),
    .carry_in(alu_carry_in),
    .result(alu_result),
    .flag_n(alu_flag_n),
    .flag_z(alu_flag_z),
    .flag_c(alu_flag_c),
    .flag_v(alu_flag_v)
);

//stack limit: a push below SLIM traps, CAUSE 0x0001_0003
//nothing written, R15SP stays
//SLIM = 0 at reset so it never fires
wire is_stack_overflow;
assign is_stack_overflow = is_push && (alu_result < stack_limit);

//memory pins

//address: PC for FETCH, calculated address in MEMORY
//pops read at old R15SP (A), pushes write at the new one (result)
//RETI second pop at A + 4, handler entry at R15SP - 4 and - 8
reg [31:0] mem_address_choice;
always @(*) begin
    case (state)
        STATE_MEMORY:     mem_address_choice = (is_pop || is_reti) ? a : result;
        STATE_MEMORY2:    mem_address_choice = a + 32'h0000_0004;
        STATE_INT_FLAGS:  mem_address_choice = sp_minus_4;
        STATE_INT_RETURN: mem_address_choice = sp_minus_8;
        default:          mem_address_choice = pc;
    endcase
end
assign mem_address = mem_address_choice;
//what to write: B (rd's value)
//STOREB copies the low byte into all 4 spots
//PUSHF writes flags, CALL and CALLR write the return address
reg [31:0] mem_write_data_choice;
always @(*) begin
    //handler entry: flags first, then the return address
    if (state == STATE_INT_FLAGS)
        mem_write_data_choice = {28'h000_0000, flag_n, flag_z, flag_c, flag_v};
    else if (state == STATE_INT_RETURN)
        mem_write_data_choice = pc;
    else case (opcode)
        OPCODE_STOREB:              mem_write_data_choice = {4{b[7:0]}};
        OPCODE_PUSHF:               mem_write_data_choice = {28'h000_0000, flag_n, flag_z, flag_c, flag_v};
        OPCODE_CALL, OPCODE_CALLR:  mem_write_data_choice = pc_plus_4;
        default:                    mem_write_data_choice = b;
    endcase
end
assign mem_write_data = mem_write_data_choice;
//only write in MEMORY for stores and pushes, and handler entry
assign mem_we = ((state == STATE_MEMORY) && (is_store || is_push)) || is_in_entry;
//byte enable: all 4, STOREB a single 1 shifted by address bottom 2 bits
assign mem_byte_enable = ((state == STATE_MEMORY) && (opcode == OPCODE_STOREB)) ? (4'b0001 << result[1:0]) : 4'b1111;

assign halted = (state == STATE_HALT);

//CPU asks memory in FETCH and MEMORY
//MEMORY2 and handler entry don't wait, stack must be in block RAM
assign mem_valid = (state == STATE_FETCH) || (state == STATE_MEMORY);
assign mem_is_fetch = (state == STATE_FETCH);
assign flush_cache = (state == STATE_EXECUTE) && (opcode == OPCODE_FLUSH);

//Step machine

always @(posedge clk) begin
    if (rst) begin
        state <= STATE_FETCH;
        pc <= 32'h0000_0000; //programs start at address 0
        ir <= 32'h0000_0000;
        a <= 32'h0000_0000;
        b <= 32'h0000_0000;
        result <= 32'h0000_0000;
        flag_n <= 1'b0;
        flag_z <= 1'b0;
        flag_c <= 1'b0;
        flag_v <= 1'b0;
        ivec <= 32'h0000_0000;
        cause <= 32'h0000_0000;
        stack_limit <= 32'h0000_0000; //no stack limit yet
        ie <= 1'b0; //interrupts off at reset
        trap_pending <= 1'b0;
        trap_cause <= 32'h0000_0000;
        data <= 32'h0000_0000;

    end else begin
        case (state)

        STATE_FETCH: begin
            //memory is reading mem[pc], stay here while it waits
            if (!mem_wait)
                state <= STATE_FETCH_WAIT;
        end

        STATE_FETCH_WAIT: begin
            ir <= mem_read_data; //catch instruction
            state <= STATE_DECODE;
        end

        STATE_DECODE: begin
            //A = read port 1, 0 for NEG
            if (opcode == OPCODE_NEG)
                a <= 32'h0000_0000;
            else
                a <= reg_read_data1;

            //B depends on the instruction
            case (opcode)
                //12 bit number, zeros on top
                OPCODE_ADDI, OPCODE_ADCI, OPCODE_SUBI, OPCODE_SBCI: b <= {20'h0_0000, imm12};
                //12 bit number, sign extended
                OPCODE_ADDIS, OPCODE_ADCIS: b <= {{20{imm12[11]}}, imm12};
                //logic: 16 bit number, zeros on top
                OPCODE_ANDI, OPCODE_ORI, OPCODE_XORI, OPCODE_NANDI, OPCODE_NORI, OPCODE_XNORI:
                    b <= {16'h0000, imm16};
                //wide: 16 bit, zeros on top, sign extended for the S ones
                OPCODE_ADDIW, OPCODE_ADCIW, OPCODE_SUBIW, OPCODE_SBCIW: b <= {16'h0000, imm16};
                OPCODE_ADDISW, OPCODE_ADCISW: b <= offset_sext;
                //compares: zeros on top, CMPIS sign extended
                OPCODE_CMPI, OPCODE_TESTI: b <= {16'h0000, imm16};
                OPCODE_CMPIS: b <= offset_sext;
                //multiply and divide: 12 bits, 16 for the wide ones
                OPCODE_MULI, OPCODE_DIVI, OPCODE_DIVUI, OPCODE_MODI, OPCODE_MODUI: b <= {20'h0_0000, imm12};
                OPCODE_MULIW, OPCODE_DIVIW, OPCODE_DIVUIW, OPCODE_MODIW, OPCODE_MODUIW: b <= {16'h0000, imm16};
                //INC and DEC: always 1
                OPCODE_INC, OPCODE_DEC: b <= 32'h0000_0001;
                //NEG: rs1
                OPCODE_NEG: b <= reg_read_data1;
                //everyone else: second register
                default: b <= reg_read_data2;
            endcase

            //HALT or unknown opcode stops
            if ((opcode == OPCODE_HALT) || !is_known_opcode)
                state <= STATE_HALT;
            else
                state<= STATE_EXECUTE;
        end

        STATE_EXECUTE: begin
        //work out the answer
            if (is_arith) begin
                //arithmetic group, save the answer
                result <= alu_result;
                //flags only if their switch is on
                if (flag_switches[3]) flag_n <= alu_flag_n;
                if (flag_switches[2]) flag_z <= alu_flag_z;
                if (flag_switches[1]) flag_c <= alu_flag_c;
                if (flag_switches[0]) flag_v <= alu_flag_v;
            end else if (is_wide) begin
                //wide group, flags not touched
                result <= alu_result;
            end else if (is_shift_group) begin
                //shifts and rotates, V never changes
                result <= shifter_result;
                if (flag_switches[3]) flag_n <= shifter_result[31];
                if (flag_switches[2]) flag_z <= (shifter_result == 32'h0000_0000);
                if (flag_switches[1]) flag_c <= shifter_carry;
            end else if (is_stack) begin
                //stack group, result = new R15SP
                result <= alu_result;
                //push below the stack limit traps
                if (is_stack_overflow) begin
                    trap_pending <= 1'b1;
                    trap_cause <= 32'h0001_0003;
                end
            end else if (is_reti) begin
                //RETI: result = R15SP + 8
                result <= alu_result;
            end else if (is_multiply) begin
                //multiplies, answer is ready right away
                result <= multiply_answer;
                //MULIW never changes flags
                if (opcode != OPCODE_MULIW) begin
                    if (flag_switches[3]) flag_n <= multiply_answer[31];
                    if (flag_switches[2]) flag_z <= (multiply_answer == 32'h0000_0000);
                    if (flag_switches[1]) flag_c <= multiply_flag_c;
                    if (flag_switches[0]) flag_v <= multiply_flag_v;
                end
            end else if (is_divide) begin
                //divide by zero traps, CAUSE 0x0001_0000
                //else the divider starts and DIVIDE waits
                if (b == 32'h0000_0000) begin
                    trap_pending <= 1'b1;
                    trap_cause <= 32'h0001_0000;
                end
            end else if (is_misaligned) begin
                //misaligned LOAD or STORE traps, CAUSE 0x0001_0002
                trap_pending <= 1'b1;
                trap_cause <= 32'h0001_0002;
            end else if (is_logic) begin
                //logic group, N and Z always
                result <= alu_result;
                flag_n <= alu_flag_n;
                flag_z <= alu_flag_z;
            end else if (is_compare) begin
                //compares, only flags
                flag_n <= alu_flag_n;
                flag_z <= alu_flag_z;
                //TEST and TESTI only N and Z, CMPs also C and V
                if ((opcode != OPCODE_TEST) && (opcode != OPCODE_TESTI)) begin
                    flag_c <= alu_flag_c;
                    flag_v <= alu_flag_v;
                end
            end else begin
                case (opcode)
                    OPCODE_LOADLO: result <= {16'h0000, imm16}; //low half, top wiped
                    OPCODE_LOADHI: result <= {imm16, 16'h0000}; //high half, bottom wiped
                    //keep one half of rd (in A)
                    OPCODE_LOADLOK: result <= {a[31:16], imm16}; //set low half
                    OPCODE_LOADHIK: result <= {imm16, a[15:0]}; //set high half
                    OPCODE_LOAD, OPCODE_STORE, OPCODE_LOADB, OPCODE_STOREB: begin
                        result <= alu_result; //the address, rs1 + offset
                    end
                    //Moves and flags
                    OPCODE_MOV:   result <= a; //copy of rs1
                    OPCODE_GETPC: result <= pc; //this instruction's address
                    OPCODE_GETF:  result <= {28'h000_0000, flag_n, flag_z, flag_c, flag_v}; //flags in bits [3:0]
                    OPCODE_SETF: begin
                        //mask in bits [3:0] (N Z C V), 1 = set that flag
                        if (imm16[3]) flag_n <= 1'b1;
                        if (imm16[2]) flag_z <= 1'b1;
                        if (imm16[1]) flag_c <= 1'b1;
                        if (imm16[0]) flag_v <= 1'b1;
                    end
                    OPCODE_CLRF: begin
                        //same mask, 1 = clear that flag
                        if (imm16[3]) flag_n <= 1'b0;
                        if (imm16[2]) flag_z <= 1'b0;
                        if (imm16[1]) flag_c <= 1'b0;
                        if (imm16[0]) flag_v <= 1'b0;
                    end
                    OPCODE_PUTF: begin
                        //flags from rs1 bits [3:0]
                        flag_n <= a[3];
                        flag_z <= a[2];
                        flag_c <= a[1];
                        flag_v <= a[0];
                    end
                    //System
                    OPCODE_EI:       ie <= 1'b1;
                    OPCODE_DI:       ie <= 1'b0;
                    OPCODE_SETIVEC:  ivec <= a; //rs1
                    OPCODE_GETIVEC:  result <= ivec;
                    OPCODE_GETCAUSE: result <= cause;
                    OPCODE_SETSLIM:  stack_limit <= a; //rs1
                    OPCODE_GETSLIM:  result <= stack_limit;
                    OPCODE_TRAP: begin
                        //handler after this instruction, CAUSE = TRAP's number
                        trap_pending <= 1'b1;
                        trap_cause <= {16'h0000, imm16};
                    end
                    //Misc
                    OPCODE_RAND:  result <= random_value; //whatever the generator has
                    //FLUSH is done by flush_cache
                    default: result <= 32'h0000_0000; //no answer
                endcase
            end
            //memory ops go to MEMORY, else WRITEBACK
            if (is_misaligned || is_stack_overflow)
                state <= STATE_WRITEBACK; //trap, skip MEMORY
            else if (is_memory_op || is_stack || is_reti)
                state <= STATE_MEMORY;
            else if (opcode == OPCODE_WAIT)
                state <= STATE_WAIT;
            else if (is_divide && (b != 32'h0000_0000))
                state <= STATE_DIVIDE;
            else
                state <= STATE_WRITEBACK;
        end

        STATE_MEMORY: begin
            //memory pins do the work
            //STORE writes at this tick
            //LOAD answer is ready in WRITEBACK
            //RETI goes to MEMORY2 for its second pop
            //stay here while memory waits
            if (mem_wait)
                state <= STATE_MEMORY;
            else if (is_reti)
                state <= STATE_MEMORY2;
            else
                state <= STATE_WRITEBACK;
        end

        STATE_MEMORY2: begin
            //RETI's second pop, reads flags at A + 4
            //first pop is ready, keep it in data
            data <= mem_read_data;
            state <= STATE_WRITEBACK;
        end

        STATE_DIVIDE: begin
            //wait for the divider, then take the answer
            if (!divider_busy) begin
                result <= is_modulo ? divider_remainder : divider_quotient;
                //N and Z by the switches, not for wide, C and V never
                if (!is_wide_muldiv) begin
                    if (flag_switches[3]) flag_n <= is_modulo ? divider_remainder[31] : divider_quotient[31];
                    if (flag_switches[2]) flag_z <= ((is_modulo ? divider_remainder : divider_quotient) == 32'h0000_0000);
                end
                state <= STATE_WRITEBACK;
            end
        end

        STATE_WAIT: begin
            //do nothing until irq
            //WRITEBACK enters the handler if IE = 1
            if (irq)
                state <= STATE_WRITEBACK;
        end

        STATE_WRITEBACK: begin
            pc <= next_pc; //+ 4 or the jump target
            //POPF: flags from the memory answer
            //RETI too, its second pop
            if ((opcode == OPCODE_POPF) || is_reti) begin
                flag_n <= mem_read_data[3];
                flag_z <= mem_read_data[2];
                flag_c <= mem_read_data[1];
                flag_v <= mem_read_data[0];
            end
            if (is_reti)
                ie <= 1'b1; //RETI turns interrupts back on

            //interrupt check between instructions
            if (is_entering_handler) begin
                //trap wins over irq, irq CAUSE is 0
                cause <= trap_pending ? trap_cause : 32'h0000_0000;
                //stack overflow: SLIM = 0 so the handler can push
                //kernel sets it again
                if (trap_pending && (trap_cause == 32'h0001_0003))
                    stack_limit <= 32'h0000_0000;
                trap_pending <= 1'b0;
                state <= STATE_INT_FLAGS;
            end else begin
                state <= STATE_FETCH;
            end
        end

        STATE_INT_FLAGS: begin
            //push flags at R15SP - 4
            state <= STATE_INT_RETURN;
        end

        STATE_INT_RETURN: begin
            //push return address at R15SP - 8, R15SP = R15SP - 8, go to handler
            ie <= 1'b0; //no interrupts while the handler runs
            pc <= ivec;
            state <= STATE_FETCH;
        end

        STATE_HALT: begin
            state<= STATE_HALT; //Stay
        end

        default: begin
            state <= STATE_HALT; //stop safely if broken or not working properly
        end

        endcase

    end
end

endmodule

