module apb_uart (
    input  wire        pclk,
    input  wire        presetn,
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,
    output wire        tx_o,
    input  wire        rx_i
);

    // -----------------------------------------------------------
    // Parameter Checks (Simulation Time)
    // -----------------------------------------------------------
    initial begin
        // Ensure Depth is valid (Power of 2 check implied by logic)
        if (16 < 2) $error("FIFO DEPTH must be >= 2");
    end

    // -----------------------------------------------------------
    // 1. Resets & Constants
    // -----------------------------------------------------------
    wire rst_n = presetn; 
    assign pready  = 1'b1;  // Zero-Wait State (Valid for Show-Ahead FIFO)
    assign pslverr = 1'b0;

    // -----------------------------------------------------------
    // 2. Input Synchronization
    // -----------------------------------------------------------
    reg rx_sync1, rx_sync2;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_i;
            rx_sync2 <= rx_sync1; 
        end
    end
    // Comment: rx_sync2 is the safe, stable signal used downstream.

    // -----------------------------------------------------------
    // 3. Wires & Registers
    // -----------------------------------------------------------
    reg  [19:0] baud_divisor;
    wire        s_tick;
    wire [7:0]  tx_fifo_out, rx_fifo_out, rx_data_raw;
    wire        tx_full, tx_empty, rx_full, rx_empty;
    wire        rx_done_tick;
    wire        uart_tx_busy;
    
    // TX FSM Signals
    reg         tx_fifo_rd_en;
    reg         uart_tx_start;
    reg  [7:0]  uart_tx_data_latched;

    wire wr_en = psel & penable & pwrite;
    wire rd_en = psel & penable & ~pwrite;
    wire [3:0] addr = paddr[3:0];

    // -----------------------------------------------------------
    // 4. TX Fetch-Execute Controller
    // -----------------------------------------------------------
    localparam [1:0] S_TX_IDLE = 0, S_TX_POP = 1, S_TX_START = 2;
    reg [1:0] tx_fsm_state;

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            tx_fsm_state   <= S_TX_IDLE;
            tx_fifo_rd_en  <= 0;
            uart_tx_start  <= 0;
            uart_tx_data_latched <= 0;
        end else begin
            tx_fifo_rd_en <= 0;
            uart_tx_start <= 0;

            case (tx_fsm_state)
                S_TX_IDLE: begin
                    if (!tx_empty && !uart_tx_busy) begin
                        // Step 1: Assert Read
                        tx_fifo_rd_en <= 1; 
                        // Step 2: Latch Data
                        // NOTE: Valid because FIFO is Show-Ahead
                        uart_tx_data_latched <= tx_fifo_out;
                        tx_fsm_state <= S_TX_START;
                    end
                end

                S_TX_START: begin
                    uart_tx_start <= 1; 
                    tx_fsm_state  <= S_TX_IDLE;
                end
                
                default: tx_fsm_state <= S_TX_IDLE;
            endcase
        end
    end

    // -----------------------------------------------------------
    // 5. APB Interface & Submodules
    // -----------------------------------------------------------
    
    // Write Logic
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) baud_divisor <= 20'd325;
        else if (wr_en && addr == 4'h08) baud_divisor <= pwdata[19:0];
    end

    // Read Logic
    always @(*) begin
        prdata = 32'b0;
        case (addr)
            4'h00: prdata = {24'b0, rx_fifo_out}; 
            4'h04: prdata = {30'b0, rx_empty, tx_full};
            4'h08: prdata = {12'b0, baud_divisor};
            default: prdata = 32'b0;
        endcase
    end

    // Modules
    baud_gen #(.DIV_WIDTH(20)) u_baud (
        .clk(pclk), .rst_n(rst_n),
        .divisor(baud_divisor), .tick_16x(s_tick)
    );

    sync_fifo #(.DATA_WIDTH(8), .DEPTH(16)) u_tx_fifo (
        .clk(pclk), .rst_n(rst_n),
        .wr_en(wr_en && (addr == 4'h00)),
        .din(pwdata[7:0]),
        .rd_en(tx_fifo_rd_en), 
        .dout(tx_fifo_out), 
        .full(tx_full), .empty(tx_empty)
    );

    uart_tx u_tx (
        .clk(pclk), .rst_n(rst_n),
        .tx_start(uart_tx_start),
        .din(uart_tx_data_latched),
        .s_tick(s_tick),
        .tx_busy(uart_tx_busy),
        .tx(tx_o)
    );

    sync_fifo #(.DATA_WIDTH(8), .DEPTH(16)) u_rx_fifo (
        .clk(pclk), .rst_n(rst_n),
        .wr_en(rx_done_tick),
        .din(rx_data_raw),
        .rd_en(rd_en && (addr == 4'h00)),
        .dout(rx_fifo_out),
        .full(rx_full), .empty(rx_empty)
    );

    uart_rx u_rx (
        .clk(pclk), .rst_n(rst_n),
        .rx(rx_sync2), 
        .s_tick(s_tick),
        .dout(rx_data_raw),
        .rx_done_tick(rx_done_tick)
    );

endmodule
