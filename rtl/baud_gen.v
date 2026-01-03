module baud_gen #(
    parameter DIV_WIDTH = 20
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [DIV_WIDTH-1:0] divisor,
    output reg                  tick_16x
);

    reg [DIV_WIDTH-1:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter  <= 0;
            tick_16x <= 0;
        end else begin
            // 1. Disable if divisor is 0 or 1
            if (divisor <= 1) begin
                tick_16x <= 1'b0;
                counter  <= 0;
            end
            // 2. Exact match using simple subtraction
            else if (counter == divisor - 1) begin
                tick_16x <= 1'b1;
                counter  <= 0;
            end 
            else begin
                tick_16x <= 1'b0;
                counter  <= counter + 1;
            end
        end
    end
endmodule
