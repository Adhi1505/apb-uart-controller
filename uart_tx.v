module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,    // 1-cycle pulse
    input  wire [7:0] din,         // Latched data
    input  wire       s_tick,
    output reg        tx_busy,     
    output reg        tx
);

    localparam [1:0] IDLE=0, START=1, DATA=2, STOP=3;
    reg [1:0] state, next_state;
    reg [3:0] s_count;
    reg [2:0] n_count;
    reg [7:0] tx_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            s_count <= 0;
            n_count <= 0;
            tx_reg  <= 0;
            tx      <= 1'b1;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        tx_reg  <= din;
                        s_count <= 0;
                        // n_count reset is handled in state transition below
                    end
                end

                START: begin
                    tx <= 1'b0;
                    // Fix: Ensure bit counter is clean before DATA state
                    n_count <= 0; 
                    
                    if (s_tick) s_count <= (s_count == 15) ? 0 : s_count + 1;
                end

                DATA: begin
                    tx <= tx_reg[0]; // LSB First
                    if (s_tick) begin
                        if (s_count == 15) begin
                            s_count <= 0;
                            tx_reg  <= tx_reg >> 1;
                            if (n_count < 7) n_count <= n_count + 1;
                        end else s_count <= s_count + 1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (s_tick) begin
                        if (s_count == 15) s_count <= 0;
                        else s_count <= s_count + 1;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        tx_busy    = 1'b1; 

        case (state)
            IDLE: begin
                tx_busy = 1'b0; 
                if (tx_start) next_state = START;
            end
            START: if (s_tick && s_count == 15) next_state = DATA;
            DATA:  if (s_tick && s_count == 15 && n_count == 7) next_state = STOP;
            STOP:  if (s_tick && s_count == 15) next_state = IDLE;
        endcase
    end
endmodule
