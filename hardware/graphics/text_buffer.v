//Text buffer, 80 x 30 = 2400 letters, dual-port block RAM
//Door A is the CPU, reads and writes on the CPU clock
//Door B is the screen, only reads on the pixel clock
//cell = 16 bits: 15-12 background colour, 11-8 letter colour, 7-0 letter (ASCII)
//cell number = row x 80 + column, 4096 cells, 2400 used

module text_buffer (
    //door A, CPU
    input wire cpu_clk,
    input wire [11:0] cpu_cell, //which cell, 0-4095
    input wire cpu_we, //1 = write
    input wire [15:0] cpu_write_data,
    output reg [15:0] cpu_read_data, //the cell, one tick later

    //door B, screen
    input wire pixel_clk,
    input wire [11:0] screen_cell,
    output reg [15:0] screen_read_data //the cell, one tick later
);

reg [15:0] cells [0:4095];

//every cell starts 0, blank on black
//4 cells per step, Gowin refuses loops over 2000 steps
integer i;
initial begin
    for (i = 0; i < 1024; i = i + 1) begin
        cells[i] = 16'h0000;
        cells[i + 1024] = 16'h0000;
        cells[i + 2048] = 16'h0000;
        cells[i + 3072] = 16'h0000;
    end
end

//door A: write if asked, otherwise read
//never both in one tick, block RAM limit
always @(posedge cpu_clk) begin
    if (cpu_we)
        cells[cpu_cell] <= cpu_write_data;
    else
        cpu_read_data <= cells[cpu_cell];
end

//door B only reads
always @(posedge pixel_clk) begin
    screen_read_data <= cells[screen_cell];
end

endmodule
