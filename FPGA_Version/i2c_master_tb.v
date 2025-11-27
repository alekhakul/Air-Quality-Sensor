`timescale 1ns/1ns

module i2c_tb;
    reg clk;
    reg reset;
    reg start;
    reg [6:0] addr;
    reg [7:0] data;
    wire sda;
    wire scl;
    wire busy;
    wire ack_error;

    i2c_master uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .addr(addr),
        .data(data),
        .sda(sda),
        .scl(scl),
        .busy(busy),
        .ack_error(ack_error)
    );

    initial begin
        clk = 0;
        forever #41.66 clk = ~clk;
    end

    pullup(sda);
    pullup(scl);

    reg slave_drive_ack;

    assign sda = (slave_drive_ack) ? 1'b0 : 1'bz;

    
    initial begin
        // Init: Sensor asleep
        slave_drive_ack = 0;
        // Wait until master
        wait(start == 1);
        
        // Address ack
        #90000;
        // Wait for falling edge
        @(negedge scl);
        slave_drive_ack = 1;
        // Hold one clk cycle
        @(negedge scl);
        slave_drive_ack = 0;

        // Data ack
        #90000;
        @(negedge scl);
        slave_drive_ack = 1;
        @(negedge scl)
        slave_drive_ack = 0;
    end

    initial begin
        $dumpfile("i2c_tb.vcd");
        $dumpvars(0, i2c_tb);

        // Init inputs
        rst = 1;
        start = 0;
        addr = 7'h59;   // Address of SGP40 sensor
        data = 8'h6A;   // Random test data

        // Sequence
        #200 rst = 0;       // Release reset
        #1000 start = 1;    // Press start
        #100 start = 0;     // Release start

        // Wait for master to finish
        wait(busy == 0);

        #5000;
        $finish;
    end
endmodule