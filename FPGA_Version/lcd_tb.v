`timescale 1ns/1ns

module lcd_tb;

    reg clk;
    reg rst;
    reg rs_in;
    reg start;
    reg [7:0] data_in;

    wire [3:0] data_out;
    wire rs_out;
    wire enable_out;
    wire busy;

    lcd uut (.*);

    parameter CLK_PERIOD = 83; // ~12MHz
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Task to send a full 8-bit command and wait
    task send_cmd;
        input [7:0] cmd;
        begin
            wait (busy == 0);
            @(posedge clk);
            start = 1; rs_in = 0; data_in = cmd;
            @(posedge clk);
            start = 0;
        end
    endtask

    // Task to send a full 8-bit character and wait
    task send_char;
        input [7:0] char;
        begin
            wait (busy == 0);
            @(posedge clk);
            start = 1; rs_in = 1; data_in = char;
            @(posedge clk);
            start = 0;
            $display("Time %t: Sent character '%c'", $time, char);
        end
    endtask

    initial begin
        $dumpfile("lcd_tb.vcd");
        $dumpvars(0, lcd_tb);

        // Reset the controller
        rst = 1; start = 0;
        #200;
        rst = 0;
        wait (busy == 0);

        // Wait for LCD power-on
        $display("Time %t: Waiting for LCD power-on...", $time);
        #40_000_000; // 40ms

        // Magic initialization sequence
        send_cmd(8'h30); #5_000_000;   // Wait 5ms
        send_cmd(8'h30); #100_000;    // Wait 100us
        send_cmd(8'h30); #100_000;    // Wait 100us
        send_cmd(8'h20);             // Set 4-bit mode
        
        $display("Time %t: Magic sequence complete.", $time);

        // Send initialization commands
        send_cmd(8'h28); // Function Set: 4-bit, 2-line
        send_cmd(8'h0C); // Display On, Cursor Off
        send_cmd(8'h01); // Clear Display
        wait (busy == 0); #2_000_000; // Wait after clear display
        send_cmd(8'h06); // Entry Mode Set
        
        $display("Time %t: Standard initialization complete.", $time);

        // Send test characters
        send_char("H");
        send_char("e");
        send_char("l");
        send_char("l");
        send_char("o");

        wait(busy==0);
        #5_000_000;
        $finish;
    end
endmodule