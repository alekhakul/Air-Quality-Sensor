module lcd(
    input clk,          // 12 MHz clock
    input rst,          // Active-high reset
    input rs_in,        // 0 for command, 1 for data
    input start,        // Pulse high to start a write
    input [7:0] data_in,
    
    output reg rs_out,
    output reg enable_out,
    output reg busy,
    output reg [3:0] data_out
);

    // State machine definitions
    localparam STATE_IDLE             = 5'd0;
    localparam STATE_INIT_POWERON_WAIT= 5'd1;
    localparam STATE_INIT_FUNC1       = 5'd2;
    localparam STATE_INIT_FUNC2       = 5'd3;
    localparam STATE_INIT_FUNC3       = 5'd4;
    localparam STATE_INIT_4BIT        = 5'd5;
    // States for sending standard init commands
    localparam STATE_INIT_CMD_FUNCSET = 5'd6;
    localparam STATE_INIT_CMD_DISPON  = 5'd7;
    localparam STATE_INIT_CMD_CLEAR   = 5'd8;
    localparam STATE_INIT_CMD_ENTRY   = 5'd9;
    // States for a precise write cycle
    localparam STATE_SETUP_ADDR       = 5'd10;
    localparam STATE_SEND_HIGH_NIBBLE = 5'd11;
    localparam STATE_PULSE_EN_HIGH    = 5'd12;
    localparam STATE_PULSE_EN_LOW     = 5'd13;
    localparam STATE_SEND_LOW_NIBBLE  = 5'd14;
    localparam STATE_WAIT_CYCLE       = 5'd15;

    reg [4:0] state = STATE_IDLE;
    reg [7:0] data_reg;
    reg send_low_nibble_next;

    // Timer
    // At 12MHz, 1 cycle = ~83ns.
    reg [19:0] timer = 0;
    localparam DELAY_40MS  = 20'd480_000; // 40ms * 12MHz
    localparam DELAY_5MS   = 20'd60_000;  // 5ms * 12MHz
    localparam DELAY_100US = 20'd1_200;   // 100us * 12MHz
    localparam DELAY_2MS   = 20'd24_000;  // 2ms * 12MHz (for clear display)


    // State machine logic
    always @(posedge clk) begin
        if(rst) begin
            // Begin initialization on reset
            state <= STATE_INIT_POWERON_WAIT; 
            busy <= 1;
            timer <= 0;
            rs_out <= 0;
            enable_out <= 0;
            send_low_nibble_next <= 0;
        end else begin
            case(state)
                STATE_IDLE: begin
                    busy <= 0;
                    if(start) begin 
                        data_reg <= data_in;
                        rs_out <= rs_in;
                        send_low_nibble_next <= 1;
                        busy <= 1;
                        state <= STATE_SETUP_ADDR;
                    end
                end

                // Initialization
                STATE_INIT_POWERON_WAIT: begin
                    if(timer == DELAY_40MS) begin
                        timer <= 0;
                        state <= STATE_INIT_FUNC1;
                    end else timer <= timer + 1;
                end

                STATE_INIT_FUNC1, STATE_INIT_FUNC2: begin
                    if(timer == DELAY_5MS) begin
                        timer <= 0;
                        state <= state + 1;
                    end else timer <= timer + 1;
                end
                
                STATE_INIT_FUNC3, STATE_INIT_4BIT: begin
                    if(timer == DELAY_100US) begin
                        timer <= 0;
                        state <= state + 1;
                    end else timer <= timer + 1;
                end

                // After the magic sequence, send remaining init commands
                STATE_INIT_CMD_FUNCSET, STATE_INIT_CMD_DISPON, STATE_INIT_CMD_ENTRY: begin
                    if (busy == 0) state <= state + 1;
                end

                STATE_INIT_CMD_CLEAR: begin
                    if (timer == DELAY_2MS) begin
                        timer <= 0;
                        // Initialization is complete
                        state <= STATE_IDLE; 
                    end else timer <= timer + 1;
                end

                // Precise write cycle
                STATE_SETUP_ADDR: state <= STATE_SEND_HIGH_NIBBLE;
                
                STATE_SEND_HIGH_NIBBLE: state <= STATE_PULSE_EN_HIGH;

                STATE_PULSE_EN_HIGH: begin
                    // 3 cycles > 230ns
                    if (timer == 3) begin
                        timer <= 0;
                        state <= STATE_PULSE_EN_LOW;
                    end else timer <= timer + 1;
                end

                STATE_PULSE_EN_LOW: begin
                    if (send_low_nibble_next) begin
                        send_low_nibble_next <= 0; 
                        state <= STATE_SEND_LOW_NIBBLE;
                    end else state <= STATE_WAIT_CYCLE;
                end
                
                STATE_SEND_LOW_NIBBLE: state <= STATE_PULSE_EN_HIGH;

                STATE_WAIT_CYCLE: begin
                    // Wait before next command
                    if (timer == DELAY_100US) begin 
                        timer <= 0;
                        state <= STATE_IDLE;
                    end else timer <= timer + 1;
                end
                
                default: state <= STATE_IDLE;

            endcase
        end
    end

    // Output logic
    always @(*) begin
        // Default values
        data_out = 4'bxxxx;
        enable_out = 0;

        case(state)
            // Magic init sequence
            STATE_INIT_FUNC1, STATE_INIT_FUNC2, STATE_INIT_FUNC3: begin
                enable_out = 1;
                rs_out = 0;
                data_out = 4'h3;
            end
            STATE_INIT_4BIT: begin
                enable_out = 1;
                rs_out = 0;
                data_out = 4'h2;
            end

            // Standard init commands
            STATE_INIT_CMD_FUNCSET: {rs_in, data_in, start} = {1'b0, 8'h28, 1'b1};
            STATE_INIT_CMD_DISPON:  {rs_in, data_in, start} = {1'b0, 8'h0C, 1'b1};
            STATE_INIT_CMD_CLEAR:   {rs_in, data_in, start} = {1'b0, 8'h01, 1'b1};
            STATE_INIT_CMD_ENTRY:   {rs_in, data_in, start} = {1'b0, 8'h06, 1'b1};

            // User write cycle
            STATE_SEND_HIGH_NIBBLE: data_out = data_reg[7:4];
            STATE_SEND_LOW_NIBBLE:  data_out = data_reg[3:0];

            STATE_PULSE_EN_HIGH: begin
                enable_out = 1;
                // Keep data stable during pulse
                data_out = send_low_nibble_next ? data_reg[7:4] : data_reg[3:0];
            end
        endcase
    end
endmodule
