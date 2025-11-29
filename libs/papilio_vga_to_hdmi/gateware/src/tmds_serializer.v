// tmds_serializer.v
// TMDS 10:1 serializer for Gowin FPGA
// Converts 10-bit parallel TMDS data to high-speed serial differential output
//
// Uses Gowin OSER10 primitive for 10:1 serialization
// Requires 5x serial clock (DDR output gives 10:1 ratio)

module tmds_serializer (
    input wire clk_pixel,       // Pixel clock (1x)
    input wire clk_serial,      // Serial clock (5x pixel clock)
    input wire rst_n,           // Active low reset
    input wire [9:0] tmds_data, // 10-bit parallel TMDS data
    output wire tmds_p,         // Differential positive output
    output wire tmds_n          // Differential negative output
);

    // Gowin OSER10 primitive for 10:1 serialization
    // This outputs data DDR (both edges) at clk_serial, giving 10:1 ratio
    wire serial_out;
    
    OSER10 #(
        .GSREN("false"),
        .LSREN("true")
    ) u_oser10 (
        .D0(tmds_data[0]),
        .D1(tmds_data[1]),
        .D2(tmds_data[2]),
        .D3(tmds_data[3]),
        .D4(tmds_data[4]),
        .D5(tmds_data[5]),
        .D6(tmds_data[6]),
        .D7(tmds_data[7]),
        .D8(tmds_data[8]),
        .D9(tmds_data[9]),
        .PCLK(clk_pixel),
        .FCLK(clk_serial),
        .RESET(!rst_n),
        .Q(serial_out)
    );
    
    // Differential output buffer for HDMI
    // Note: IOSTANDARD is set in pin constraints, not as parameter
    ELVDS_OBUF u_obuf (
        .I(serial_out),
        .O(tmds_p),
        .OB(tmds_n)
    );

endmodule
