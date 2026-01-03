`timescale 1ns / 1ps

module tb_apb_uart;

    // 1. Signals
    reg         pclk;
    reg         presetn;
    reg  [31:0] paddr;
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready;
    wire        pslverr;

    wire        tx_line;
    wire        rx_line = tx_line; // Loopback

    localparam CLK_PERIOD = 20; 
    localparam [19:0] BAUD_DIV = 20'd325; 

    // 2. DUT
    apb_uart dut (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .tx_o(tx_line),
        .rx_i(rx_line) 
    );

    // 3. Clock
    initial pclk = 0;
    always #(CLK_PERIOD/2) pclk = ~pclk;

    // 4. Tasks
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge pclk);
            paddr   <= addr;
            pwrite  <= 1;
            psel    <= 1;
            pwdata  <= data;
            @(posedge pclk);
            penable <= 1;
            wait(pready);
            @(posedge pclk);
            psel    <= 0;
            penable <= 0;
            pwrite  <= 0;
        end
    endtask

    task apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge pclk);
            paddr   <= addr;
            pwrite  <= 0;
            psel    <= 1;
            @(posedge pclk);
            penable <= 1;
            wait(pready);
            data    = prdata;
            @(posedge pclk);
            psel    <= 0;
            penable <= 0;
        end
    endtask

    task wait_for_rx_ready;
        reg [31:0] status;
        begin
            status = 32'hFFFF; 
            while (status[1] == 1'b1) begin // Bit 1 is RX_EMPTY
                apb_read(32'h04, status);
                #1000; 
            end
        end
    endtask

    // 5. Simulation
    reg [31:0] read_data;

    initial begin
        presetn = 0;
        psel = 0; penable = 0; pwrite = 0;
        #100;
        presetn = 1;
        #100;

        $display("\n--- SIMULATION START ---");

        // Config Baud
        apb_write(32'h08, {12'b0, BAUD_DIV});
        
        // Send Data 0xAB
        $display("Sending 0xAB...");
        apb_write(32'h00, 32'hAB);

        // Wait & Read
        wait_for_rx_ready();
        apb_read(32'h00, read_data);
        
        if (read_data[7:0] === 8'hAB) 
            $display("[PASS] Received 0xAB correctly.");
        else 
            $display("[FAIL] Expected 0xAB, got 0x%h", read_data[7:0]);

        $display("--- SIMULATION END ---");
        $stop;
    end
endmodule
