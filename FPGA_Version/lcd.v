module lcd(
    input clk,
    input rst,
    input rs_in,
    input start,
    input [7:0] data_in,
    
    output reg rs_out,
    output reg enable_out,
    output reg busy,
    output reg [3:0] data_out
    );

    localparam STATE_IDLE             = 4'd0;
    localparam STATE_SETUP_ADDR       = 4'd1;
    localparam STATE_SEND_HIGH_NIBBLE = 4'd2;
    localparam STATE_PULSE_EN_HIGH    = 4'd3;
    localparam STATE_PULSE_EN_LOW     = 4'd4;
    localparam STATE_SEND_LOW_NIBBLE  = 4'd5;
    localparam STATE_WAIT_CYCLE       = 4'd6;

    reg [3:0] state = STATE_IDLE;
    reg [7:0] data_reg;
    reg send_low_nibble_next;
    reg [10:0] timer = 0;

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            busy <= 0;
            timer <= 0;
            rs_out <= 0;
            enable_out <= 0;
        end else begin
            case(state)
                STATE_IDLE: begin
                    busy <= 0;
                    if (start && !busy) begin
                        data_reg <= data_in;
                        rs_out <= rs_in;
                        send_low_nibble_next <= 1;
                        busy <= 1;
                        state <= STATE_SETUP_ADDR;
                    end
                end

                STATE_SETUP_ADDR:       state <= STATE_SEND_HIGH_NIBBLE;
                STATE_SEND_HIGH_NIBBLE: state <= STATE_PULSE_EN_HIGH;
                
                STATE_PULSE_EN_HIGH: begin
                    if (timer >= 3) begin
                        timer <= 0;
                        state <= STATE_PULSE_EN_LOW;
                    end else timer <= timer + 1;
                end

                STATE_PULSE_EN_LOW: begin
                    // Send one nibble for magic init number sequence
                    if (send_low_nibble_next) begin
                        send_low_nibble_next <= 0; 
                        state <= STATE_SEND_LOW_NIBBLE;
                    end else state <= STATE_WAIT_CYCLE;
                end
                
                STATE_SEND_LOW_NIBBLE: state <= STATE_PULSE_EN_HIGH;

                STATE_WAIT_CYCLE: begin
                    // Wait ~50us
                    if (timer >= 600) begin
                        timer <= 0;
                        state <= STATE_IDLE;
                    end else timer <= timer + 1;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

    always @(*) begin
        enable_out = (state == STATE_PULSE_EN_HIGH);
        case(state)
            STATE_SEND_HIGH_NIBBLE, STATE_PULSE_EN_HIGH: 
                data_out = send_low_nibble_next ? data_reg[7:4] : data_reg[3:0];
            STATE_SEND_LOW_NIBBLE:  
                data_out = data_reg[3:0];
            STATE_PULSE_EN_LOW:
                data_out = send_low_nibble_next ? data_reg[7:4] : data_reg[3:0];
            default:
                data_out = 4'bxxxx;
        endcase
    end
endmodule