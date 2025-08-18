module lcd(
    input clk,          // 12 MHz clock
    input rst,          // Active-high reset
    input rs_in,        // 0 for command, 1 for data
    input start,        // Pulse high to start a user write
    input [7:0] data_in,
    
    output reg rs_out,
    output reg enable_out,
    output reg busy,
    output reg [3:0] data_out
);

    // State machine definitions
    // Init states
    localparam STATE_IDLE             = 5'd0;
    localparam STATE_INIT_POWERON_WAIT= 5'd1;
    localparam STATE_INIT_PULSE_1     = 5'd2;
    localparam STATE_INIT_WAIT_1      = 5'd3;
    localparam STATE_INIT_PULSE_2     = 5'd4;
    localparam STATE_INIT_WAIT_2      = 5'd5;
    localparam STATE_INIT_PULSE_3     = 5'd6;
    localparam STATE_INIT_WAIT_3      = 5'd7;
    localparam STATE_INIT_PULSE_4BIT  = 5'd8;
    localparam STATE_INIT_CMD_FUNCSET = 5'd9;
    localparam STATE_INIT_CMD_DISPON  = 5'd10;
    localparam STATE_INIT_CMD_CLEAR   = 5'd11;
    localparam STATE_INIT_CMD_ENTRY   = 5'd12;
    
    // User write cycle states
    localparam STATE_SETUP_ADDR       = 5'd20;
    localparam STATE_SEND_HIGH_NIBBLE = 5'd21;
    localparam STATE_PULSE_EN_HIGH    = 5'd22;
    localparam STATE_PULSE_EN_LOW     = 5'd23;
    localparam STATE_SEND_LOW_NIBBLE  = 5'd24;
    localparam STATE_WAIT_CYCLE       = 5'd25;

    reg [4:0] state = STATE_IDLE;
    reg [7:0] data_reg;
    reg send_low_nibble_next;

    // Timer
    reg [19:0] timer = 0;
    localparam DELAY_40MS  = 20'd480_000;
    localparam DELAY_5MS   = 20'd60_000;
    localparam DELAY_100US = 20'd1_200;
    localparam DELAY_2MS   = 20'd24_000;

    // State machine logic
    always @(posedge clk) begin
        if(rst) begin
            state <= STATE_INIT_POWERON_WAIT;
            busy <= 1; timer <= 0;
        end else begin
            case(state)
                STATE_IDLE: begin
                    busy <= 0;
                    if(start && !busy) begin
                        data_reg <= data_in; rs_out <= rs_in; send_low_nibble_next <= 1;
                        busy <= 1; state <= STATE_SETUP_ADDR;
                    end
                end

                // -- Initialization Sequence --
                STATE_INIT_POWERON_WAIT: if(timer >= DELAY_40MS) begin timer <= 0; state <= STATE_INIT_PULSE_1; end else timer <= timer + 1;
                STATE_INIT_PULSE_1:      state <= STATE_INIT_WAIT_1; // Pulse for 1 cycle
                STATE_INIT_WAIT_1:       if(timer >= DELAY_5MS) begin timer <= 0; state <= STATE_INIT_PULSE_2; end else timer <= timer + 1;
                STATE_INIT_PULSE_2:      state <= STATE_INIT_WAIT_2;
                STATE_INIT_WAIT_2:       if(timer >= DELAY_100US) begin timer <= 0; state <= STATE_INIT_PULSE_3; end else timer <= timer + 1;
                STATE_INIT_PULSE_3:      state <= STATE_INIT_WAIT_3;
                STATE_INIT_WAIT_3:       if(timer >= DELAY_100US) begin timer <= 0; state <= STATE_INIT_PULSE_4BIT; end else timer <= timer + 1;
                STATE_INIT_PULSE_4BIT:   state <= STATE_INIT_CMD_FUNCSET;
                
                // After magic sequence, send remaining init commands by starting a write cycle
                STATE_INIT_CMD_FUNCSET: begin data_reg <= 8'h28; rs_out <= 0; send_low_nibble_next <= 1; busy <= 1; state <= STATE_SETUP_ADDR; end
                STATE_INIT_CMD_DISPON:  begin data_reg <= 8'h0C; rs_out <= 0; send_low_nibble_next <= 1; busy <= 1; state <= STATE_SETUP_ADDR; end
                STATE_INIT_CMD_CLEAR:   begin data_reg <= 8'h01; rs_out <= 0; send_low_nibble_next <= 1; busy <= 1; state <= STATE_SETUP_ADDR; end
                STATE_INIT_CMD_ENTRY:   begin data_reg <= 8'h06; rs_out <= 0; send_low_nibble_next <= 1; busy <= 1; state <= STATE_SETUP_ADDR; end

                // -- Precise Write Cycle --
                STATE_SETUP_ADDR:       state <= STATE_SEND_HIGH_NIBBLE;
                STATE_SEND_HIGH_NIBBLE: state <= STATE_PULSE_EN_HIGH;
                STATE_PULSE_EN_HIGH:    if (timer == 3) begin timer <= 0; state <= STATE_PULSE_EN_LOW; end else timer <= timer + 1;
                STATE_PULSE_EN_LOW:     if (send_low_nibble_next) begin send_low_nibble_next <= 0; state <= STATE_SEND_LOW_NIBBLE; end else state <= STATE_WAIT_CYCLE;
                STATE_SEND_LOW_NIBBLE:  state <= STATE_PULSE_EN_HIGH;

                STATE_WAIT_CYCLE: begin
                    // After a write, decide where to go next based on what was just sent
                    if (rs_out==0 && data_reg==8'h28) state <= STATE_INIT_CMD_DISPON;
                    else if (rs_out==0 && data_reg==8'h0C) state <= STATE_INIT_CMD_CLEAR;
                    else if (rs_out==0 && data_reg==8'h01) begin if (timer >= DELAY_2MS) begin timer <= 0; state <= STATE_INIT_CMD_ENTRY; end else timer <= timer + 1; end
                    else if (rs_out==0 && data_reg==8'h06) state <= STATE_IDLE;
                    else state <= STATE_IDLE;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

    // Output logic
    always @(*) begin
        // Defaults
        enable_out = 0;
        rs_out = 0; // Will be overridden
        data_out = 4'bxxxx;
        
        case(state)
            STATE_INIT_PULSE_1, STATE_INIT_PULSE_2, STATE_INIT_PULSE_3: begin enable_out = 1; rs_out = 0; data_out = 4'h3; end
            STATE_INIT_PULSE_4BIT: begin enable_out = 1; rs_out = 0; data_out = 4'h2; end
            
            STATE_SEND_HIGH_NIBBLE: data_out = data_reg[7:4];
            STATE_SEND_LOW_NIBBLE:  data_out = data_reg[3:0];
            
            STATE_PULSE_EN_HIGH: begin
                enable_out = 1;
                data_out = send_low_nibble_next ? data_reg[7:4] : data_reg[3:0];
            end
        endcase
    end
endmodule