module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] dout, // Wire = Show-Ahead (Combinational)
    output wire                  full,
    output wire                  empty
);

    localparam PTR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH:0]    count;
    reg [PTR_WIDTH-1:0]  wr_ptr, rd_ptr;

    // Show-Ahead: Data is always valid at rd_ptr
    assign dout  = mem[rd_ptr];
    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count  <= 0;
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: begin // Write Only
                    mem[wr_ptr] <= din;
                    wr_ptr      <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
                    count       <= count + 1;
                end
                2'b01: begin // Read Only
                    rd_ptr      <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                    count       <= count - 1;
                end
                2'b11: begin // Simultaneous
                    mem[wr_ptr] <= din;
                    wr_ptr      <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
                    rd_ptr      <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                    // Count unchanged
                end
                default: ; 
            endcase
        end
    end
endmodule
