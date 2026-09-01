`timescale 1ns/1ns

// Top-level: bridges the I2C master (reading a SGP40 VOC sensor at 0x59)
// to the LCD controller, displaying the raw VOC reading in hex.
//
// Boot sequence: wait for LCD power-on -> run the HD44780 magic init
// sequence -> print a static "VOC RAW:" label on line 1. Then forever:
// write the SGP40 "measure raw" command -> wait out the conversion time
// -> read back 3 bytes (2 data + CRC) -> print the 2 data bytes as hex
// on line 2 -> wait ~1s -> repeat.
module top (
    input  wire clk,
    input  wire rst,

    inout  wire sda,
    output wire scl,

    output wire rs_out,
    output wire enable_out,
    output wire [3:0] data_out
);

    // ---------------- LCD instance ----------------
    reg lcd_start;
    reg lcd_rs;
    reg [7:0] lcd_data;
    wire lcd_busy;

    lcd lcd_inst (
        .clk(clk),
        .rst(rst),
        .rs_in(lcd_rs),
        .start(lcd_start),
        .data_in(lcd_data),
        .rs_out(rs_out),
        .enable_out(enable_out),
        .busy(lcd_busy),
        .data_out(data_out)
    );

    // ---------------- I2C master instance ----------------
    reg i2c_start;
    reg i2c_rw;
    reg [2:0] i2c_num_bytes;
    wire [2:0] i2c_byte_index;
    wire [7:0] i2c_rd_data;
    wire i2c_byte_ready;
    wire i2c_busy;
    wire i2c_ack_error;

    // SGP40 "measure raw" command with default (mid-point) RH/T compensation
    wire [7:0] i2c_wr_data = (i2c_byte_index == 3'd0) ? 8'h26 : 8'h0F;

    i2c_master i2c_inst (
        .clk(clk),
        .reset(rst),
        .start(i2c_start),
        .rw(i2c_rw),
        .addr(7'h59),
        .num_bytes(i2c_num_bytes),
        .wr_data(i2c_wr_data),
        .sda(sda),
        .scl(scl),
        .byte_index(i2c_byte_index),
        .rd_data(i2c_rd_data),
        .byte_ready(i2c_byte_ready),
        .busy(i2c_busy),
        .ack_error(i2c_ack_error)
    );

    // Latch every byte the master pulls off the bus during a read.
    // ack_error is left unused for now (see README caveats) - a future
    // revision should re-trigger the read or flag a fault on the LCD
    // instead of silently displaying stale data.
    reg [7:0] rx_bytes [0:2];
    always @(posedge clk) begin
        if (i2c_byte_ready) rx_bytes[i2c_byte_index] <= i2c_rd_data;
    end

    function [7:0] hex_ascii;
        input [3:0] nibble;
        begin
            hex_ascii = (nibble < 10) ? (8'h30 + nibble) : (8'h41 + (nibble - 4'd10));
        end
    endfunction

    // ---------------- Main orchestration FSM ----------------
    localparam S_POWERON        = 0,
               S_LCD_STEP        = 1,
               S_LCD_PULSE       = 2,
               S_LCD_WAIT        = 3,
               S_LCD_EXTRA_DELAY = 4,
               S_I2C_WRITE_START = 5,
               S_I2C_WRITE_WAIT  = 6,
               S_CONV_DELAY      = 7,
               S_I2C_READ_START  = 8,
               S_I2C_READ_WAIT   = 9,
               S_LOOP_DELAY      = 10;

    reg [3:0] state;
    reg [26:0] delay_cnt;
    reg [26:0] delay_target;

    reg lcd_phase;          // 0 = one-time init/label, 1 = per-cycle status update
    reg [4:0] lcd_step;
    reg lcd_step_is_last;
    reg [26:0] lcd_extra_delay;

    // Advances the LCD sub-FSM once the current command/char has been
    // accepted (and any extra post-command delay has elapsed).
    task finish_lcd_step;
        begin
            if (lcd_step_is_last) begin
                if (lcd_phase == 0) begin
                    state <= S_I2C_WRITE_START;
                end else begin
                    delay_cnt <= 0;
                    delay_target <= 27'd12_000_000; // ~1s between readings
                    state <= S_LOOP_DELAY;
                end
            end else begin
                lcd_step <= lcd_step + 1;
                state <= S_LCD_STEP;
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state <= S_POWERON;
            delay_cnt <= 0;
            delay_target <= 27'd480_000; // ~40ms LCD power-on wait @12MHz
            lcd_start <= 0;
            i2c_start <= 0;
            lcd_phase <= 0;
            lcd_step <= 0;
        end else begin
            case (state)

                S_POWERON: begin
                    if (delay_cnt >= delay_target) begin
                        delay_cnt <= 0;
                        lcd_phase <= 0;
                        lcd_step <= 0;
                        state <= S_LCD_STEP;
                    end else delay_cnt <= delay_cnt + 1;
                end

                // Look up the next LCD command/character byte to send.
                S_LCD_STEP: begin
                    lcd_extra_delay <= 0;
                    lcd_step_is_last <= 0;
                    if (lcd_phase == 0) begin
                        // One-time HD44780 magic init + "VOC RAW:" label (line 1)
                        case (lcd_step)
                            5'd0:  begin lcd_rs <= 0; lcd_data <= 8'h30; lcd_extra_delay <= 27'd60_000; end // 5ms
                            5'd1:  begin lcd_rs <= 0; lcd_data <= 8'h30; lcd_extra_delay <= 27'd1_200;  end // 100us
                            5'd2:  begin lcd_rs <= 0; lcd_data <= 8'h30; lcd_extra_delay <= 27'd1_200;  end // 100us
                            5'd3:  begin lcd_rs <= 0; lcd_data <= 8'h20; end                                 // 4-bit mode
                            5'd4:  begin lcd_rs <= 0; lcd_data <= 8'h28; end                                 // function set
                            5'd5:  begin lcd_rs <= 0; lcd_data <= 8'h0C; end                                 // display on
                            5'd6:  begin lcd_rs <= 0; lcd_data <= 8'h01; lcd_extra_delay <= 27'd24_000; end  // clear, 2ms
                            5'd7:  begin lcd_rs <= 0; lcd_data <= 8'h06; end                                 // entry mode
                            5'd8:  begin lcd_rs <= 0; lcd_data <= 8'h80; end                                 // line 1, pos 0
                            5'd9:  begin lcd_rs <= 1; lcd_data <= "V"; end
                            5'd10: begin lcd_rs <= 1; lcd_data <= "O"; end
                            5'd11: begin lcd_rs <= 1; lcd_data <= "C"; end
                            5'd12: begin lcd_rs <= 1; lcd_data <= " "; end
                            5'd13: begin lcd_rs <= 1; lcd_data <= "R"; end
                            5'd14: begin lcd_rs <= 1; lcd_data <= "A"; end
                            5'd15: begin lcd_rs <= 1; lcd_data <= "W"; end
                            5'd16: begin lcd_rs <= 1; lcd_data <= ":"; lcd_step_is_last <= 1; end
                            default: lcd_step_is_last <= 1;
                        endcase
                    end else begin
                        // Per-cycle status update: line 2, "0x" + 4 hex digits
                        case (lcd_step)
                            5'd0: begin lcd_rs <= 0; lcd_data <= 8'hC0; end // line 2, pos 0
                            5'd1: begin lcd_rs <= 1; lcd_data <= "0"; end
                            5'd2: begin lcd_rs <= 1; lcd_data <= "x"; end
                            5'd3: begin lcd_rs <= 1; lcd_data <= hex_ascii(rx_bytes[0][7:4]); end
                            5'd4: begin lcd_rs <= 1; lcd_data <= hex_ascii(rx_bytes[0][3:0]); end
                            5'd5: begin lcd_rs <= 1; lcd_data <= hex_ascii(rx_bytes[1][7:4]); end
                            5'd6: begin lcd_rs <= 1; lcd_data <= hex_ascii(rx_bytes[1][3:0]); lcd_step_is_last <= 1; end
                            default: lcd_step_is_last <= 1;
                        endcase
                    end
                    state <= S_LCD_PULSE;
                end

                S_LCD_PULSE: begin
                    lcd_start <= 1;
                    state <= S_LCD_WAIT;
                end

                S_LCD_WAIT: begin
                    lcd_start <= 0;
                    if (!lcd_busy) begin
                        if (lcd_extra_delay != 0) begin
                            delay_cnt <= 0;
                            delay_target <= lcd_extra_delay;
                            state <= S_LCD_EXTRA_DELAY;
                        end else begin
                            finish_lcd_step;
                        end
                    end
                end

                S_LCD_EXTRA_DELAY: begin
                    if (delay_cnt >= delay_target) finish_lcd_step;
                    else delay_cnt <= delay_cnt + 1;
                end

                S_I2C_WRITE_START: begin
                    i2c_rw <= 0;
                    i2c_num_bytes <= 3'd2;    // command bytes 0x26, 0x0F
                    i2c_start <= 1;
                    state <= S_I2C_WRITE_WAIT;
                end

                S_I2C_WRITE_WAIT: begin
                    i2c_start <= 0;
                    if (!i2c_busy) begin
                        delay_cnt <= 0;
                        delay_target <= 27'd360_000; // ~30ms SGP40 conversion time
                        state <= S_CONV_DELAY;
                    end
                end

                S_CONV_DELAY: begin
                    if (delay_cnt >= delay_target) state <= S_I2C_READ_START;
                    else delay_cnt <= delay_cnt + 1;
                end

                S_I2C_READ_START: begin
                    i2c_rw <= 1;
                    i2c_num_bytes <= 3'd3;    // 2 data bytes + CRC
                    i2c_start <= 1;
                    state <= S_I2C_READ_WAIT;
                end

                S_I2C_READ_WAIT: begin
                    i2c_start <= 0;
                    if (!i2c_busy) begin
                        lcd_phase <= 1;
                        lcd_step <= 0;
                        state <= S_LCD_STEP;
                    end
                end

                S_LOOP_DELAY: begin
                    if (delay_cnt >= delay_target) begin
                        delay_cnt <= 0;
                        state <= S_I2C_WRITE_START;
                    end else delay_cnt <= delay_cnt + 1;
                end

                default: state <= S_POWERON;
            endcase
        end
    end
endmodule
