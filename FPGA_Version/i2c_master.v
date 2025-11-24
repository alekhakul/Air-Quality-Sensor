`timescale 1ns/1ns

module i2c_master (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [6:0] addr,  // Slave Address
    input wire [7:0] data,  // Data to write
    input wire sda,         // Bidirectional data line
    output wire scl,        // Clock line
    output reg busy,        // 1 if transaction in prog
    output reg ack_error    // 1 if sensor unresponsive
);

    // Tristate bufer
    reg sda_out;
    reg sda_en;

    assign sda = (sda_en && sda_out == 0) ? 1'b0:1'bz;

    // Timing generator
    reg [4:0] clk_count;
    reg i2c_tick;

    // 12MHz/30 = 400kHz
    always @(posedge clk) begin
        if (clk_count == 29) begin
            clk_count <= 0;
            i2c_tick <= 1;
        end else begin
            clk_count <= clk_count + 1;
            i2c_tick <= 0;
        end
    end

    // State machine
    localparam IDLE = 0, START = 1, ADDR = 2, WAIT_ACK1 = 3,
    DATA = 4, WAIT_ACK2 = 5, STOP = 6;

    reg [2:0] state;
    reg [2:0] bit_count;
    reg [1:0] substate;
    reg scl_reg;

    assign scl = scl_reg;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            scl_reg <= 1;
            sda_en <= 0; sda_out <= 1;
            busy <= 0;
            ack_error <= 0;
        end else if (i2c_tick) begin
            case (state)
                IDLE: begin
                    scl_reg <= 1; sda_en <= 0; busy <= 0;
                    if (start) begin
                        state <= START;
                        substate <= 0;
                        busy <= 1;
                        ack_error <= 0;
                        bit_count <= 6; // Sending 7-bit addr
                    end
                end

                START: begin
                    // Substate 0: (Setup) SDA High, SCL High
                    if (substate == 0) begin sda_en <= 1; sda_out <= 1; scl_reg <= 1; end
                    // Substate 1: (Start Condition) SDA drops low
                    if (substate == 1) begin sda_en <= 1; sda_out <= 0; end
                    // Substate 3: (Prep for Addr) SCL drops low
                    if (substate == 2) begin scl_reg <= 0; state <= ADDR; end
                    substate <= substate + 1;
                end

                ADDR: begin
                    // SCL Pulse
                    scl_reg <= (substate == 1 || substate == 2);
                    // Change data when SCL is low (Substate 0)
                    if (substate == 0) begin
                        sda_en <= 1;
                        sda_out <= addr[bit_count];
                    end

                    if (substate == 3) begin
                        if (bit_count == 0) begin
                            state <= WAIT_ACK1;
                        end else begin
                            bit_count <= bit_count - 1;
                        end
                    end
                    substate <= substate + 1;
                end

                WAIT_ACK1: begin
                    scl_reg <= (substate == 1 || substate == 2);
                    // Release SDA so slave can pull it low
                    if (substate == 0) sda_en <= 0;
                    // Sample SDA in middle of high SCL (Substate 2)
                    if (substate == 2) begin
                        if (sda == 1) ack_error <= 1;
                    end

                    if (substate == 3) begin
                        state <= DATA;
                        bit_count <= 7;
                    end
                    substate <= substate + 1;
                end

                DATA: begin
                    scl_reg <= (substate == 1 || substate == 2);
                    if (substate == 0) begin
                        sda_en <= 1;
                        sda_out <= data[bit_count];
                    end

                    if (substate == 3) begin
                        if (bit_count == 0) state <= WAIT_ACK2;
                        else bit_count <= bit_count - 1;
                    end
                    substate <= substate + 1;
                end 
                
                WAIT_ACK2: begin
                    scl_reg <= (substate == 1 || substate == 2);
                    if (substate == 0) sda_en <= 0;
                    if (substate == 2) begin
                        if (sda == 1) ack_error <= 1;
                    end
                    if (substate == 3) state <= STOP;
                    substate <= substate + 1;
                end

                STOP: begin
                    if (substate == 0) begin sda_en <= 1; sda_out <= 0; scl_reg <= 0; end
                    if (substate == 1) scl_reg <= 1; // SCL High
                    if (substate == 2) sda_out <= 1; // SDA rises while SCL is High
                    if (substate == 3) state <= IDLE;
                    substate <= substate + 1;
                end
            endcase
        end
    end
endmodule