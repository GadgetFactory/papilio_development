// tmds_encoder.v
// TMDS encoder for DVI/HDMI video transmission
// Implements the TMDS 8b/10b encoding algorithm
//
// This encoder:
// - Converts 8-bit RGB data to 10-bit TMDS codes
// - Maintains DC balance for reliable differential transmission
// - Minimizes transitions to reduce EMI
// - Sends control codes during blanking periods

module tmds_encoder (
    input wire clk,
    input wire rst,
    input wire video_active,    // 1 = active video, 0 = blanking (control period)
    input wire [7:0] data_in,   // 8-bit RGB data
    input wire c0,              // Control bit 0 (hsync for channel 0)
    input wire c1,              // Control bit 1 (vsync for channel 0)
    output reg [9:0] tmds_out   // 10-bit TMDS encoded output
);

    // Count ones in 8-bit data
    function [3:0] count_ones;
        input [7:0] data;
        integer i;
        begin
            count_ones = 0;
            for (i = 0; i < 8; i = i + 1)
                count_ones = count_ones + data[i];
        end
    endfunction
    
    // XOR operation for encoding (minimize transitions)
    function [8:0] xor_encode;
        input [7:0] data;
        integer i;
        begin
            xor_encode[0] = data[0];
            for (i = 1; i < 8; i = i + 1)
                xor_encode[i] = data[i] ^ xor_encode[i-1];
            xor_encode[8] = 1'b1;  // Bit 8 indicates XOR encoding
        end
    endfunction
    
    // XNOR operation for encoding (alternative transition minimization)
    function [8:0] xnor_encode;
        input [7:0] data;
        integer i;
        begin
            xnor_encode[0] = data[0];
            for (i = 1; i < 8; i = i + 1)
                xnor_encode[i] = ~(data[i] ^ xnor_encode[i-1]);
            xnor_encode[8] = 1'b0;  // Bit 8 indicates XNOR encoding
        end
    endfunction
    
    // DC balance tracking
    reg signed [4:0] disparity;
    
    // Internal signals
    wire [3:0] ones_count;
    wire [8:0] q_m;
    wire [3:0] q_m_ones;
    
    assign ones_count = count_ones(data_in);
    
    // Stage 1: Determine encoding method (XOR or XNOR)
    // Choose method that results in fewer transitions
    assign q_m = (ones_count > 4 || (ones_count == 4 && data_in[0] == 0)) ? 
                 xnor_encode(data_in) : xor_encode(data_in);
    
    assign q_m_ones = count_ones(q_m[7:0]);
    
    // Stage 2: DC balance and output generation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            disparity <= 0;
            tmds_out <= 10'b1101010100; // Control code for c0=0, c1=0
        end else begin
            if (!video_active) begin
                // Control period - send control codes for hsync/vsync
                disparity <= 0;
                case ({c1, c0})
                    2'b00: tmds_out <= 10'b1101010100;
                    2'b01: tmds_out <= 10'b0010101011;
                    2'b10: tmds_out <= 10'b0101010100;
                    2'b11: tmds_out <= 10'b1010101011;
                endcase
            end else begin
                // Video period - encode data with DC balancing
                if (disparity == 0 || q_m_ones == 4) begin
                    // Disparity is zero or q_m has equal 0s and 1s
                    tmds_out[9] <= ~q_m[8];
                    tmds_out[8] <= q_m[8];
                    tmds_out[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
                    
                    if (q_m[8] == 0)
                        disparity <= disparity + (4 - q_m_ones) + (4 - q_m_ones);
                    else
                        disparity <= disparity + q_m_ones - (8 - q_m_ones);
                end else begin
                    // Adjust for DC balance
                    if ((disparity > 0 && q_m_ones > 4) || 
                        (disparity < 0 && q_m_ones < 4)) begin
                        // Invert to counteract imbalance
                        tmds_out[9] <= 1'b1;
                        tmds_out[8] <= q_m[8];
                        tmds_out[7:0] <= ~q_m[7:0];
                        disparity <= disparity + {q_m[8], 1'b0} + (8 - q_m_ones) - q_m_ones;
                    end else begin
                        // Pass through
                        tmds_out[9] <= 1'b0;
                        tmds_out[8] <= q_m[8];
                        tmds_out[7:0] <= q_m[7:0];
                        disparity <= disparity - {~q_m[8], 1'b0} + q_m_ones - (8 - q_m_ones);
                    end
                end
            end
        end
    end
    
endmodule
