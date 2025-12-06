// Minimal RGB LED module for read testing
// Just stores 3 bytes and allows readback

module minimal_rgb_test (
    input wire clk,
    input wire rst,
    
    // Wishbone interface
    input wire [7:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // LED output (not used, just for compatibility)
    output wire led_out
);

    // Storage registers
    reg [7:0] green_reg;
    reg [7:0] red_reg;
    reg [7:0] blue_reg;
    
    assign led_out = 1'b0;  // Tie off for now
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 8'h00;
            green_reg <= 8'h00;
            red_reg <= 8'h00;
            blue_reg <= 8'h00;
        end else begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 8'h00;
            
            if (wb_cyc_i && wb_stb_i) begin
                wb_ack_o <= 1'b1;
                
                if (wb_we_i) begin
                    // Write
                    case (wb_adr_i[1:0])
                        2'b00: green_reg <= wb_dat_i;
                        2'b01: red_reg <= wb_dat_i;
                        2'b10: blue_reg <= wb_dat_i;
                    endcase
                end else begin
                    // Read
                    case (wb_adr_i[1:0])
                        2'b00: wb_dat_o <= green_reg;
                        2'b01: wb_dat_o <= red_reg;
                        2'b10: wb_dat_o <= blue_reg;
                        2'b11: wb_dat_o <= 8'hAA;  // Test pattern
                    endcase
                end
            end
        end
    end

endmodule
