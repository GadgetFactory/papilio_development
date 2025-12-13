// custom_uart_receiver.v
// Simple UART receiver that works reliably on Gowin FPGA
// Replaces the broken SUMP receiver.vhd component

module custom_uart_receiver #(
    parameter FREQ = 100000000,  // Clock frequency in Hz
    parameter RATE = 115200       // Baud rate
)(
    input wire clock,
    input wire reset,
    input wire rx,
    output reg [7:0] op,           // Opcode output (matches receiver.vhd interface)
    output reg [31:0] data,        // Data output (matches receiver.vhd interface)
    output reg execute             // Execute pulse (matches receiver.vhd interface)
);

    // Calculate baud rate divisor
    localparam BAUD_DIVIDE = FREQ / RATE;
    
    // UART receiver state machine
    reg [2:0] rx_state;
    reg [31:0] rx_baud_counter;
    reg [3:0] rx_bit_index;
    reg [7:0] rx_shift_reg;
    reg [1:0] rx_sync;
    
    localparam RX_IDLE = 3'd0;
    localparam RX_START = 3'd1;
    localparam RX_DATA = 3'd2;
    localparam RX_STOP = 3'd3;
    
    // Command decoder state
    reg [2:0] cmd_state;
    reg [3:0] byte_count;
    
    localparam CMD_IDLE = 3'd0;
    localparam CMD_OPCODE = 3'd1;
    localparam CMD_DATA0 = 3'd2;
    localparam CMD_DATA1 = 3'd3;
    localparam CMD_DATA2 = 3'd4;
    localparam CMD_DATA3 = 3'd5;
    localparam CMD_EXECUTE = 3'd6;
    
    // Byte received flag
    reg byte_valid;
    reg [7:0] rx_byte;
    
    // UART Receiver - detects start bit, receives 8 data bits, checks stop bit
    always @(posedge clock) begin
        if (reset) begin
            rx_state <= RX_IDLE;
            rx_baud_counter <= 0;
            rx_bit_index <= 0;
            rx_shift_reg <= 8'h00;
            rx_sync <= 2'b11;
            byte_valid <= 0;
            rx_byte <= 8'h00;
        end else begin
            // Synchronize input to prevent metastability
            rx_sync <= {rx_sync[0], rx};
            byte_valid <= 0;  // Pulse for one cycle
            
            case (rx_state)
                RX_IDLE: begin
                    rx_baud_counter <= 0;
                    if (rx_sync[1] == 0) begin  // Start bit detected
                        rx_state <= RX_START;
                    end
                end
                
                RX_START: begin
                    if (rx_baud_counter == (BAUD_DIVIDE / 2)) begin
                        // Sample in middle of start bit
                        if (rx_sync[1] == 0) begin
                            rx_state <= RX_DATA;
                            rx_baud_counter <= 0;
                            rx_bit_index <= 0;
                        end else begin
                            rx_state <= RX_IDLE;  // False start
                        end
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
                
                RX_DATA: begin
                    if (rx_baud_counter == BAUD_DIVIDE - 1) begin
                        rx_baud_counter <= 0;
                        rx_shift_reg <= {rx_sync[1], rx_shift_reg[7:1]};  // LSB first
                        if (rx_bit_index == 7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_index <= rx_bit_index + 1;
                        end
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
                
                RX_STOP: begin
                    if (rx_baud_counter == BAUD_DIVIDE - 1) begin
                        if (rx_sync[1] == 1) begin  // Valid stop bit
                            rx_byte <= rx_shift_reg;
                            byte_valid <= 1;
                        end
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
                
                default: rx_state <= RX_IDLE;
            endcase
        end
    end
    
    // Command decoder - matches SUMP protocol byte ordering
    // Opcode comes first, then 4 data bytes (little endian)
    always @(posedge clock) begin
        if (reset) begin
            cmd_state <= CMD_IDLE;
            op <= 8'h00;
            data <= 32'h00000000;
            execute <= 0;
            byte_count <= 0;
        end else begin
            execute <= 0;  // Pulse for one cycle
            
            if (byte_valid) begin
                case (cmd_state)
                    CMD_IDLE, CMD_OPCODE: begin
                        // First byte is the opcode
                        op <= rx_byte;
                        
                        // Check if this is a short command (no data bytes)
                        if (rx_byte[7:4] == 4'h0) begin
                            // Short commands: 0x00-0x0F don't need data bytes
                            data <= 32'h00000000;
                            execute <= 1;
                            cmd_state <= CMD_IDLE;
                        end else begin
                            // Long commands: need 4 data bytes
                            cmd_state <= CMD_DATA0;
                            data <= 32'h00000000;
                        end
                    end
                    
                    CMD_DATA0: begin
                        data[7:0] <= rx_byte;
                        cmd_state <= CMD_DATA1;
                    end
                    
                    CMD_DATA1: begin
                        data[15:8] <= rx_byte;
                        cmd_state <= CMD_DATA2;
                    end
                    
                    CMD_DATA2: begin
                        data[23:16] <= rx_byte;
                        cmd_state <= CMD_DATA3;
                    end
                    
                    CMD_DATA3: begin
                        data[31:24] <= rx_byte;
                        execute <= 1;
                        cmd_state <= CMD_IDLE;
                    end
                    
                    default: cmd_state <= CMD_IDLE;
                endcase
            end
        end
    end

endmodule
