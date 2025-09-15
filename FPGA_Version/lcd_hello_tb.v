`timescale 1ns/1ps

module tb_lcd_hello;

    // Clock signal
    reg clk = 0;
    always #41.67 clk = ~clk; // Create a 12MHz clock

    // Wires to connect to the LCD module's outputs
    wire lcd_rs;
    wire lcd_e;
    wire [3:0] lcd_d;

    // Instantiate the lcd module
    lcd uut (
        .clk(clk),
        .rs_out(lcd_rs),
        .enable_out(lcd_e),
        .data_out(lcd_d)
    );

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_lcd_hello);
    end

    // Stop the simulation after some time
    initial begin
        #500000; // Let it run for 500us
        $finish;
    end

endmodule