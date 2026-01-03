module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,         // Synchronized in Top Level
    input  wire       s_tick,
    output reg  [7:0] dout,
    output reg        rx_done_tick
);
    
    localparam [1:0] IDLE=0, START=1, DATA=2, STOP=3;
    reg [1:0] state, next_state;
    reg [3:0] s_count;
    reg [2:0] n_count;
    reg [7:0] rx_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            s_count <= 0;
            n_count <= 0;
            rx_reg  <= 0;
            dout    <= 0;
            rx_done_tick <= 0;
        end else begin
            state <= next_state;
            rx_done_tick <= 1'b0;

            case (state)
                IDLE: if (~rx) s_count <= 0;
                START: if (s_tick) s_count <= (s_count == 7) ? 0 : s_count + 1;
                DATA: if (s_tick) begin
                    if (s_count == 15) begin
                        s_count <= 0;
                        // RIGHT SHIFT: UART sends LSB first.
                        // New bit enters at MSB and shifts right to LSB.
                        rx_reg <= {rx, rx_reg[7:1]};
                        if (n_count < 7) n_count <= n_count + 1;
                    end else s_count <= s_count + 1;
                end
                STOP: if (s_tick) begin
                    if (s_count == 15) begin
                         rx_done_tick <= 1'b1;
                         dout <= rx_reg;
                         s_count <= 0;
                    end else s_count <= s_count + 1;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:  if (~rx) next_state = START;
            START: if (s_tick && s_count == 7) next_state = (~rx) ? DATA : IDLE;
            DATA:  if (s_tick && s_count == 15 && n_count == 7) next_state = STOP;
            STOP:  if (s_tick && s_count == 15) next_state = IDLE;
        endcase
    end
endmodule
