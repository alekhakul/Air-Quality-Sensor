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

    // Task to send a command and wait for it to finish
    task send_cmd;
        input [7:0] cmd;
        begin
            @(posedge clk);
            start = 1; rs_in = 0; data_in = cmd;
            @(posedge clk);
            start = 0;
            wait (busy == 0);
            $display("Time %t: Sent command 0x%h", $time, cmd);
        end
    endtask

    // Task to send a character and wait for it to finish
    task send_char;
        input [7:0] char;
        begin
            @(posedge clk);
            start = 1; rs_in = 1; data_in = char;
            @(posedge clk);
            start = 0;
            wait (busy == 0);
            $display("Time %t: Sent character '%c'", $time, char);
        end
    endtask

    initial begin
        $dumpfile("lcd_tb.vcd");
        $dumpvars(0, lcd_tb);

        // 1. Reset the controller
        rst = 1; start = 0; rs_in = 0; data_in = 0;
        #200;
        rst = 0;
        
        // 2. Wait for the full, automatic initialization to complete
        wait (busy == 0);
        $display("Time %t: LCD initialization complete.", $time);

        // 3. Send some test characters
        #1000;
        send_char("H");
        send_char("e");
        send_char("l");
        send_char("l");
        send_char("o");

        #5_000_000;
        $finish;
    end
endmodule