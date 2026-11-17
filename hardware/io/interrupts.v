//Interrupt Controller
//every device 1 bit

//bit 0 timer
//bit 1 keyboard byte
//bit 2 mouse byte
//bit 3 uart byte

module interrupts (

    input wire clk,
    input wire rst,

    //doorbells
    input wire timer_ringing,
    input wire keyboard_ringing,
    input wire mouse_ringing,
    input wire uart_ringing,

    //from bus
    input wire enabled_write,
    input wire [3:0] write_data,
    
    output wire [3:0] pending,
    output reg [3:0] enabled,
    output wire irq
    
    );

    //all doorbells side by side bit 0 on right
    assign pending = {uart_ringing, mouse_ringing, keyboard_ringing, timer_ringing};
    
    //switches, remember what CPU wrote, all off after reset
    always @(posedge clk) begin
        if (rst)
            enabled <= 4'b0000;
        else if (enabled_write)
            enabled <= write_data;
    end

    //ring the cpu when any line is ringing and enabled

    assign irq = |(pending & enabled);

endmodule