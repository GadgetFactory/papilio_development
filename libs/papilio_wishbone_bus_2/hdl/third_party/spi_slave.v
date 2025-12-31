// spi_slave.v - Simple SPI Slave Module (Mode 0)
// Based on proven open-source designs
// CPOL=0, CPHA=0 (Sample on rising edge, shift on falling edge)

module spi_slave (
    // System clock
    input wire clk,
    input wire rst,
    
    // SPI interface
    input wire spi_sclk,
    input wire spi_mosi,
    output reg spi_miso,
    input wire spi_cs_n,
    
    // Parallel interface
    input wire [7:0] tx_data,       // Data to transmit
    output reg [7:0] rx_data,       // Data received
    output reg rx_valid,            // Pulse when byte received
    input wire tx_load              // Load tx_data into shift register
);

// =============================================================================
// Clock Domain Crossing - Synchronize SPI signals
// =============================================================================
reg [2:0] spi_sclk_sync;
reg [2:0] spi_cs_sync;
reg [1:0] spi_mosi_sync;

always @(posedge clk) begin
    if (rst) begin
        spi_sclk_sync <= 3'b000;
        spi_cs_sync <= 3'b111;  // CS is active low
        spi_mosi_sync <= 2'b00;
    end else begin
        spi_sclk_sync <= {spi_sclk_sync[1:0], spi_sclk};
        spi_cs_sync <= {spi_cs_sync[1:0], spi_cs_n};
        spi_mosi_sync <= {spi_mosi_sync[0], spi_mosi};
    end
end

// Edge detection
wire spi_sclk_rising = (spi_sclk_sync[2:1] == 2'b01);
wire spi_sclk_falling = (spi_sclk_sync[2:1] == 2'b10);
wire spi_cs_active = !spi_cs_sync[1];
wire spi_cs_rising = (spi_cs_sync[2:1] == 2'b01);  // CS deasserted

// =============================================================================
// Shift Registers
// =============================================================================
reg [7:0] rx_shift_reg;
reg [7:0] tx_shift_reg;
reg [2:0] bit_counter;

// =============================================================================
// Receive Logic (Sample on rising edge of SCLK)
// =============================================================================
always @(posedge clk) begin
    if (rst || !spi_cs_active) begin
        bit_counter <= 3'd0;
        rx_valid <= 1'b0;
        rx_data <= 8'h00;
    end else begin
        rx_valid <= 1'b0;  // Default: pulse for one cycle
        
        if (spi_sclk_rising) begin
            // Shift in data from MOSI
            rx_shift_reg <= {rx_shift_reg[6:0], spi_mosi_sync[1]};
            bit_counter <= bit_counter + 1'b1;
            
            // After 8 bits, output received byte
            if (bit_counter == 3'd7) begin
                rx_data <= {rx_shift_reg[6:0], spi_mosi_sync[1]};
                rx_valid <= 1'b1;
            end
        end
    end
end

// =============================================================================
// Transmit Logic (Shift on falling edge of SCLK)
// =============================================================================
always @(posedge clk) begin
    if (rst) begin
        tx_shift_reg <= 8'hFF;
        spi_miso <= 1'b1;
    end else begin
        // Load new data when requested
        if (tx_load) begin
            tx_shift_reg <= tx_data;
        end
        // Or when CS goes inactive, prepare for next transaction
        else if (spi_cs_rising) begin
            tx_shift_reg <= tx_data;
        end
        // Shift out data on falling edge
        else if (spi_cs_active && spi_sclk_falling) begin
            tx_shift_reg <= {tx_shift_reg[6:0], 1'b1};
        end
        
        // MISO always outputs MSB of shift register
        spi_miso <= tx_shift_reg[7];
    end
end

endmodule
