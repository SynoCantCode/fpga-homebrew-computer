//Line fetcher, keeps the line buffer one row ahead of the screen, 27MHz system clock
//screen draws row y from one half while this fills the other half with row y + 1
//one burst from the SDRAM second door
//screen side flips line_toggle at the start of every row, line_number = next row
//flip is caught with 2 flip-flops
//line_number holds still for a whole row (~857 ticks) so it can just be read
//two pages in the SDRAM, page 0 at 0x1020_0000, page 1 at 0x1028_0000
//row y starts at page + y x 1024, one row of pixels = one SDRAM row (160 of 256 words used)
//SDRAM address: bit 21 = 1, bit 19 = page, bits 18-10 = y
//page only changes at the top of a frame, no tearing

module line_fetcher (
    input wire clk, //27MHz system clock
    input wire rst,

    //from the screen side (pixel clock)
    input wire line_toggle,
    input wire [8:0] line_number,

    //from the card registers
    input wire pixels_on, //0 = pixel layer off, nothing fetched
    input wire page_wanted, //page the CPU wants, taken at the top of the next frame
    output reg page_shown, //page being shown
    output reg [31:0] frame_count, //frames since reset, counts with pixels off too

    //SDRAM second door
    output reg video_request,
    output wire [22:0] video_address,
    input wire video_word_valid,
    input wire [7:0] video_word_index,
    input wire [31:0] video_word,
    input wire video_done,

    //into the line buffer, half = row's lowest bit, then word number
    output wire buffer_write,
    output wire [8:0] buffer_address,
    output wire [31:0] buffer_data
);

//catch the flip, 2 flip-flops then a third to compare
reg toggle_caught, toggle_safe, toggle_last;
always @(posedge clk) begin
    toggle_caught <= line_toggle;
    toggle_safe <= toggle_caught;
    toggle_last <= toggle_safe;
end
wire is_new_row = toggle_safe ^ toggle_last;

reg [8:0] row; //row being fetched, lowest bit picks the half
reg row_page; //page it comes from

assign video_address = {2'b01, 1'b0, row_page, row, 10'b00_0000_0000};
assign buffer_write = video_word_valid;
assign buffer_address = {row[0], video_word_index};
assign buffer_data = video_word;

always @(posedge clk) begin
    if (rst) begin
        page_shown <= 1'b0;
        frame_count <= 32'd0;
        video_request <= 1'b0;
        row <= 9'd0;
        row_page <= 1'b0;
    end else begin
        if (video_done)
            video_request <= 1'b0; //row is in, let go this tick so no second burst
        if (is_new_row && !video_request) begin
            row <= line_number;
            if (line_number == 9'd0) begin //top of a new frame, wanted page becomes shown
                page_shown <= page_wanted;
                row_page <= page_wanted;
                frame_count <= frame_count + 32'd1;
            end else begin
                row_page <= page_shown;
            end
            if (pixels_on)
                video_request <= 1'b1;
        end
    end
end

endmodule
