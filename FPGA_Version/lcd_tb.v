`timescale 1ns/1ns

module lcd_tb;

    // Testbench signals
    reg clk;
    reg rst;
    reg rs_in;
    reg start;
    reg [7:0] data_in;

    // Wires to connect to the module's outputs
    wire [3:0] data_out;
    wire rs_out;
    wire enable_out;
    wire busy;

    // Instantiate your lcd module
    lcd uut (
        .clk(clk),
        .rst(rst),
        .rs_in(rs_in),
        .start(start),
        .data_in(data_in),
        .rs_out(rs_out),
        .enable_out(enable_out),
        .busy(busy),
        .data_out(data_out)
    );

    // Clock generation (12 MHz for iCEBreaker)
    // 1 / 12MHz = ~83.33 ns period
    initial clk = 0;
    always #41.67 clk = ~clk;

    // Test sequence
    initial begin
        // Setup waveform dumping
        $dumpfile("lcd_tb.vcd");
        $dumpvars(0, lcd_tb);

        // Start with a reset pulse
        rst = 1;
        start = 0;
        rs_in = 0;
        data_in = 8'h00;
        #100; // Hold reset for 100ns
        rst = 0;

        // Wait for init to finish
        wait (busy == 0);
        $display("Time %t: LCD initialization complete. Controller is idle.", $time);

        // 3. Send a character: 'A' (ASCII code is 0x41)
        #100;
        start = 1;      // Pulse start high to begin the write
        rs_in = 1;      // rs_in = 1 for character data
        data_in = 8'h41; // ASCII for 'A'
        #100;           // Hold the inputs stable
        start = 0;      // De-assert start
        
        // 4. Wait for the write to finish
        wait (busy == 0);
        $display("Time %t: Character 'A' has been sent.", $time);

        // End the simulation
        #2000;
        $finish;
    end
endmodule