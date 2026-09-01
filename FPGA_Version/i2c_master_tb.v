`timescale 1ns/1ns

module i2c_tb;
    reg clk;
    reg reset;
    reg start;
    reg rw;
    reg [6:0] addr;
    reg [2:0] num_bytes;
    reg [7:0] wr_data;

    wire sda;
    wire scl;
    wire [2:0] byte_index;
    wire [7:0] rd_data;
    wire byte_ready;
    wire busy;
    wire ack_error;

    i2c_master uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .rw(rw),
        .addr(addr),
        .num_bytes(num_bytes),
        .wr_data(wr_data),
        .sda(sda),
        .scl(scl),
        .byte_index(byte_index),
        .rd_data(rd_data),
        .byte_ready(byte_ready),
        .busy(busy),
        .ack_error(ack_error)
    );

    initial begin
        clk = 0;
        forever #41.66 clk = ~clk;
    end

    pullup(sda);
    pullup(scl);

    // Mirror the DUT's state encoding so the mock slave can react to
    // *what the master is doing* instead of guessing SCL edge counts.
    localparam TB_WAIT_ACK_ADDR = 3, TB_WAIT_ACK_WR = 5, TB_READ_DATA = 6;

    // Bytes the mock slave will play back during a read, indexed by
    // the master's own byte_index.
    reg [7:0] tx_bytes [0:6];

    // Single-driver mock slave: pulls SDA low to ACK, or to send a
    // data-bit of value 0 during a read; floats otherwise so the
    // pull-up (or the master's own ACK/NACK drive) wins.
    reg slave_drive_low;
    always @(*) begin
        if (uut.state == TB_WAIT_ACK_ADDR || uut.state == TB_WAIT_ACK_WR)
            slave_drive_low = 1; // always ACK in these tests
        else if (uut.state == TB_READ_DATA)
            slave_drive_low = (tx_bytes[uut.byte_index][uut.bit_count] == 1'b0);
        else
            slave_drive_low = 0;
    end
    assign sda = slave_drive_low ? 1'b0 : 1'bz;

    integer errors;

    // Latch each byte the master reports as received during the read test
    reg [7:0] captured_byte0, captured_byte1;
    always @(posedge byte_ready) begin
        if (byte_index == 0) captured_byte0 <= rd_data;
        else if (byte_index == 1) captured_byte1 <= rd_data;
    end

    // ---- Test 1: WRITE transaction (master -> slave) ----
    initial begin
        errors = 0;

        reset = 1;
        start = 0;
        rw = 0;
        addr = 7'h59;      // SGP40 address
        num_bytes = 1;
        wr_data = 8'h6A;   // test byte

        #200 reset = 0;
        #1000 start = 1;
        #5000 start = 0;

        wait (busy == 1);
        wait (busy == 0);

        if (ack_error) begin
            $display("FAIL: write test saw unexpected ack_error");
            errors = errors + 1;
        end else begin
            $display("PASS: write test completed with no ack_error");
        end

        #5000;

        // ---- Test 2: READ transaction (slave -> master), 2 bytes ----
        rw = 1;
        num_bytes = 2;
        tx_bytes[0] = 8'hAB;
        tx_bytes[1] = 8'hCD;
        captured_byte0 = 8'h00;
        captured_byte1 = 8'h00;

        #1000 start = 1;
        #5000 start = 0;

        wait (busy == 1);
        wait (busy == 0);

        if (ack_error) begin
            $display("FAIL: read test saw unexpected ack_error");
            errors = errors + 1;
        end
        if (captured_byte0 !== 8'hAB) begin
            $display("FAIL: expected byte0=0xAB, got 0x%02h", captured_byte0);
            errors = errors + 1;
        end
        if (captured_byte1 !== 8'hCD) begin
            $display("FAIL: expected byte1=0xCD, got 0x%02h", captured_byte1);
            errors = errors + 1;
        end
        if (errors == 0) $display("PASS: read test received 0xAB 0xCD with correct ACK/NACK");

        #5000;
        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

    initial begin
        $dumpfile("i2c_tb.vcd");
        $dumpvars(0, i2c_tb);
    end

    // Watchdog: fail loudly instead of hanging forever on a deadlock
    initial begin
        #2_000_000;
        $display("TIMEOUT: simulation did not finish (state=%0d busy=%b)", uut.state, busy);
        $finish;
    end
endmodule
