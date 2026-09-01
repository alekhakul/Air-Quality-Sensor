`timescale 1ns/1ns

module i2c_master (
    input wire clk,
    input wire reset,
    input wire start,
    input wire rw,          // 0 = write, 1 = read
    input wire [6:0] addr,  // Slave Address
    input wire [2:0] num_bytes, // number of data bytes to write/read this transaction (1-7)
    input wire [7:0] wr_data,   // byte to transmit for the *current* byte_index (write mode)

    inout wire sda,         // Bidirectional data line
    output wire scl,        // Clock line

    output reg [2:0] byte_index, // which byte (0-based) is currently being sent/received
    output reg [7:0] rd_data,    // byte received (read mode), valid when byte_ready pulses
    output reg byte_ready,       // 1-cycle pulse: rd_data holds a freshly received byte

    output reg busy,        // 1 if transaction in prog
    output reg ack_error    // 1 if sensor unresponsive
);

    // Tristate buffer
    reg sda_out;
    reg sda_en;

    assign sda = (sda_en && sda_out == 0) ? 1'b0 : 1'bz;

    // Timing generator
    reg [4:0] clk_count;
    reg i2c_tick;

    // 12MHz/30 = 400kHz
    always @(posedge clk) begin
        if (reset) begin
            clk_count <= 0;
            i2c_tick <= 0;
        end else if (clk_count == 29) begin
            clk_count <= 0;
            i2c_tick <= 1;
        end else begin
            clk_count <= clk_count + 1;
            i2c_tick <= 0;
        end
    end

    // State machine
    localparam IDLE          = 0,
               START         = 1,
               ADDR           = 2,
               WAIT_ACK_ADDR  = 3,
               WRITE_DATA     = 4,
               WAIT_ACK_WR    = 5,
               READ_DATA      = 6,
               MASTER_ACK     = 7,
               STOP           = 8;

    reg [3:0] state;
    reg [2:0] bit_count;   // bit position within the current byte (7 downto 0)
    reg [1:0] substate;
    reg scl_reg;
    reg rw_latched;
    reg [7:0] rx_shift;

    wire [7:0] addr_byte = {addr, rw_latched}; // 7-bit address + R/W bit

    assign scl = scl_reg;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            scl_reg <= 1;
            sda_en <= 0; sda_out <= 1;
            busy <= 0;
            ack_error <= 0;
            substate <= 0;
            byte_index <= 0;
            byte_ready <= 0;
            rw_latched <= 0;
        end else if (i2c_tick) begin
            byte_ready <= 0; // default; MASTER_ACK pulses it high for one tick

            case (state)
                IDLE: begin
                    scl_reg <= 1; sda_en <= 0; busy <= 0;
                    if (start) begin
                        state <= START;
                        substate <= 0;
                        busy <= 1;
                        ack_error <= 0;
                        rw_latched <= rw;
                        byte_index <= 0;
                        bit_count <= 7; // Sending 8-bit addr+rw byte
                    end
                end

                START: begin
                    // Substate 0: (Setup) SDA High, SCL High
                    if (substate == 0) begin sda_en <= 1; sda_out <= 1; scl_reg <= 1; end
                    // Substate 1: (Start Condition) SDA drops low
                    if (substate == 1) begin sda_en <= 1; sda_out <= 0; end
                    // Substate 2: (Prep for Addr) SCL drops low
                    if (substate == 2) begin scl_reg <= 0; state <= ADDR; end
                    substate <= substate + 1;
                end

                ADDR: begin
                    // SCL Pulse
                    scl_reg <= (substate == 1 || substate == 2);
                    // Change data when SCL is low (Substate 0)
                    if (substate == 0) begin
                        sda_en <= 1;
                        sda_out <= addr_byte[bit_count];
                    end

                    if (substate == 3) begin
                        if (bit_count == 0) begin
                            state <= WAIT_ACK_ADDR;
                        end else begin
                            bit_count <= bit_count - 1;
                        end
                    end
                    substate <= substate + 1;
                end

                WAIT_ACK_ADDR: begin
                    scl_reg <= (substate == 1 || substate == 2);
                    // Release SDA so slave can pull it low
                    if (substate == 0) sda_en <= 0;
                    // Sample SDA in middle of high SCL (Substate 2)
                    if (substate == 2) begin
                        if (sda == 1) ack_error <= 1;
                    end

                    if (substate == 3) begin
                        bit_count <= 7;
                        if (rw_latched) begin
                            state <= READ_DATA;
                            rx_shift <= 0;
                        end else begin
                            state <= WRITE_DATA;
                        end
                    end
                    substate <= substate + 1;
                end

                WRITE_DATA: begin
                    scl_reg <= (substate == 1 || substate == 2);
                    if (substate == 0) begin
                        sda_en <= 1;
                        sda_out <= wr_data[bit_count];
                    end

                    if (substate == 3) begin
                        if (bit_count == 0) state <= WAIT_ACK_WR;
                        else bit_count <= bit_count - 1;
                    end
                    substate <= substate + 1;
                end

                WAIT_ACK_WR: begin
                    scl_reg <= (substate == 1 || substate == 2);
                    if (substate == 0) sda_en <= 0;
                    if (substate == 2) begin
                        if (sda == 1) ack_error <= 1;
                    end
                    if (substate == 3) begin
                        if (byte_index == num_bytes - 1) begin
                            state <= STOP;
                        end else begin
                            byte_index <= byte_index + 1;
                            bit_count <= 7;
                            state <= WRITE_DATA;
                        end
                    end
                    substate <= substate + 1;
                end

                READ_DATA: begin
                    scl_reg <= (substate == 1 || substate == 2);
                    // Master keeps SDA released (sda_en==0) throughout; slave drives bits
                    if (substate == 2) begin
                        rx_shift[bit_count] <= sda;
                    end

                    if (substate == 3) begin
                        if (bit_count == 0) state <= MASTER_ACK;
                        else bit_count <= bit_count - 1;
                    end
                    substate <= substate + 1;
                end

                MASTER_ACK: begin
                    scl_reg <= (substate == 1 || substate == 2);
                    if (substate == 0) begin
                        sda_en <= 1;
                        // ACK (pull low) all but the last requested byte; NACK the last one
                        sda_out <= (byte_index == num_bytes - 1) ? 1'b1 : 1'b0;
                        rd_data <= rx_shift;
                        byte_ready <= 1;
                    end
                    if (substate == 3) begin
                        if (byte_index == num_bytes - 1) begin
                            state <= STOP;
                        end else begin
                            byte_index <= byte_index + 1;
                            bit_count <= 7;
                            rx_shift <= 0;
                            sda_en <= 0; // release the bus so the slave can drive the next byte
                            state <= READ_DATA;
                        end
                    end
                    substate <= substate + 1;
                end

                STOP: begin
                    if (substate == 0) begin sda_en <= 1; sda_out <= 0; scl_reg <= 0; end
                    if (substate == 1) scl_reg <= 1; // SCL High
                    if (substate == 2) sda_out <= 1; // SDA rises while SCL is High
                    if (substate == 3) state <= IDLE;
                    substate <= substate + 1;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
