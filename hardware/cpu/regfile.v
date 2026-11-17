//CPU's register file: R0-R15, 32 bits
//2 read ports, 2 write ports
//Read ports always read
//Write only at the clock tick
//R0 always reads 0 and ignored writes
//Port 1 priority

module regfile (
    //Clock and reset
    input  wire        clk, //writes on rising edge
    input  wire        rst, //1 = all registers back to start values

    //Read port 1, always on
    input  wire [3:0]  read_addr1, //which register, 0x0-0xF = R0-R15
    output wire [31:0] read_data1, //value inside, instant

    //Read port 2, always on
    input  wire [3:0]  read_addr2,
    output wire [31:0] read_data2,

    //Write port 1, wins if both write the same register
    input  wire        we1, //1 = write at next tick
    input  wire [3:0]  write_addr1, //which register to write
    input  wire [31:0] write_data1, //value to put in

    //Write port 2
    input  wire        we2, //write enable 2
    input  wire [3:0]  write_addr2,
    input  wire [31:0] write_data2 //last one, no comma
);

    //16 boxes, each 32 bits
    //[31:0] = width, [0:15] = how many
    reg [31:0] regs [0:15];

    integer i; //for loop counter, not hardware

    always @(posedge clk) begin
        if (rst) begin
            //reset clears all 16
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 32'h0000_0000;
            //R15SP starts at top of block RAM, after the loop so it wins
            regs[15] <= 32'h0001_0000;
        end else begin
            //only writes if we = 1 and not R0
            if (we2 && write_addr2 != 4'h0) regs[write_addr2] <= write_data2;
            //port 1 last so it wins
            if (we1 && write_addr1 != 4'h0) regs[write_addr1] <= write_data1;
        end
    end

    assign read_data1 = (read_addr1 == 4'h0) ? 32'h0000_0000 : regs[read_addr1];
    assign read_data2 = (read_addr2 == 4'h0) ? 32'h0000_0000 : regs[read_addr2];

endmodule
