`timescale 1ns/1ns

module lcd_ctrl_tb;

    reg clk, rst, rs, rw, start;
    reg [7:0] datain;

    wire [3:0] dataout;
    wire rs_out, rw_out, enable;

    // Instantiate the FSM
    lcd_ctrl uut (
        .clk(clk),
        .rst(rst),
        .rs_in(rs),
        .rw_in(rw),
        .data_in(datain),
        .start(start),
        .rs_out(rs_out),
        .rw_out(rw_out),
        .enable_out(enable),
        .data_out(dataout)
    );

    // Clock generation: 10ns period
    initial clk = 1;
    always #50 clk = ~clk;

    initial begin
        // Dump the waveform to a vcd file for GTKWave
        $dumpfile("lcd_ctrl_tb.vcd");
        $dumpvars(0, lcd_ctrl_tb);
        // Display headers
        $display("Time\tReset\tRS\tRW\tStart\tDatain\tRS_out\tRW_out\tEnable\tDataout");
        $monitor("%g\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b", $time, rst, rs, rw, start, datain, rs_out, rw_out, enable, dataout);

        // Initialize signals
        rst = 0; 
        rs = 0; 
        rw = 0; 
        start = 0; 
        datain = 0;

        // Reset pulse
        #010 {rst, rs, rw, start, datain} = 12'b1_0_0_0_00000000;
        #190 {rst, rs, rw, start, datain} = 12'b0_0_0_0_00000000; // #200

        // Write (1) Data (1) register with A0 
        #100 {rst, rs, rw, start, datain} = 12'b0_1_1_1_00110011;
        #100 {rst, rs, rw, start, datain} = 12'b0_x_x_0_xxxxxxxx;

        #10000 $finish;
    end

endmodule

