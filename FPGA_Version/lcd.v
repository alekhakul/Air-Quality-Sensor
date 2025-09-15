module lcd(
    input clk,
    output reg rs_out,
    output reg enable_out,
    output reg [3:0] data_out
    );

    // Power-on reset generator
    reg [7:0] reset_counter = 0;
    wire rst = (reset_counter < 255);
    always @(posedge clk) if (reset_counter < 255) reset_counter <= reset_counter + 1;

    // 12MHz clock prescaler (~100kHz output)
    reg [15:0] prescaler = 0;
    reg fsm_clk = 0;
    always @(posedge clk) begin
        if (prescaler == 120) {prescaler, fsm_clk} <= {16'd0, ~fsm_clk};
        else prescaler <= prescaler + 1;
    end

    // State definitions
    reg [7:0] state = 0;
    reg [7:0] data_reg;

// State logic
    always @(posedge fsm_clk) begin
        if (rst) begin
            state <= 0;
            rs_out <= 0;
            enable_out <= 0;
            data_out <= 4'h0;
            data_reg <= 8'h0;
        end else begin
            enable_out <= (state[0] == 1); // Pulse enable high on odd states
            
            case(state)
                // LCD Initialization Sequence
                0,1:   {rs_out, data_reg} <= {1'b0, 8'h33};
                2,3:   {rs_out, data_reg} <= {1'b0, 8'h32};
                4,5:   {rs_out, data_reg} <= {1'b0, 8'h28}; // Function Set: 4-bit, 2-line
                6,7:   {rs_out, data_reg} <= {1'b0, 8'h0C}; // Display ON, Cursor OFF
                8,9:   {rs_out, data_reg} <= {1'b0, 8'h01}; // Clear Display
                10,11: ; // Wait state with a null statement.
                12,13: {rs_out, data_reg} <= {1'b0, 8'h06}; // Entry Mode Set

                // Write "HELLO!"
                14,15: {rs_out, data_reg} <= {1'b1, "H"};
                16,17: {rs_out, data_reg} <= {1'b1, "E"};
                18,19: {rs_out, data_reg} <= {1'b1, "L"};
                20,21: {rs_out, data_reg} <= {1'b1, "L"};
                22,23: {rs_out, data_reg} <= {1'b1, "O"};
                24,25: {rs_out, data_reg} <= {1'b1, "!"};

                default: state <= state; // Hold state when finished
            endcase
            
            // Output
            if (state[0] == 0) data_out <= data_reg[3:0]; // Send high nibble
            else data_out <= data_reg[7:4]; // Send low nibble
            
            if (state < 26) state <= state + 1; // Updated final state number
        end
    end
endmodule