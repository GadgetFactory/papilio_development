/* ****************************************************************************
-- Simplified SUMP2 Logic Analyzer for Gowin FPGA
-- Adapted from blackmesalabs/sump2 project
-- Original: (C) Copyright 2016 Kevin M. Hubbard - CERN OHL v1.2
-- Simplified for Gowin FPGA / Papilio Arcade by GadgetFactory
-- 
-- This version removes deep_sump features and focuses on basic logic analyzer
-- with UART interface for OLS (Open Logic Sniffer) software compatibility
-- ***************************************************************************/
`default_nettype none

module sump2_simple #(
    parameter DEPTH_LEN    = 2048,  // Reduced for Gowin - 2K samples
    parameter DEPTH_BITS   = 11,    // 2^11 = 2048
    parameter EVENT_BYTES  = 4,     // Capture 32 bits
    parameter FREQ_MHZ     = 16'd27 // 27 MHz clock
)
(
    input  wire         clk,
    input  wire         rst,
    
    // UART interface (for SUMP protocol)
    input  wire         uart_rx,
    output wire         uart_tx,
    
    // Signals to capture (32-bit)
    input  wire [31:0]  events_din
);

    // Internal signals
    reg  [31:0]         events_loc;
    reg  [DEPTH_BITS-1:0] c_addr;
    reg                 c_we;
    reg                 armed_jk;
    reg                 triggered_jk;
    reg                 acquired_jk;
    reg  [DEPTH_BITS-1:0] trigger_ptr;
    reg  [DEPTH_BITS-1:0] post_trig_cnt;
    
    // Trigger configuration
    reg  [31:0]         trigger_bits;
    reg  [3:0]          trigger_type;
    reg  [DEPTH_BITS-1:0] trigger_pos;
    
    // Capture RAM (inferred block RAM)
    reg  [31:0]         event_ram_array[DEPTH_LEN-1:0];
    
    // UART interface signals
    wire [7:0]          uart_rx_data;
    wire                uart_rx_valid;
    reg  [7:0]          uart_tx_data;
    reg                 uart_tx_valid;
    wire                uart_tx_ready;
    
    // SUMP command parser
    reg  [5:0]          cmd_reg;
    reg  [31:0]         cmd_data;
    reg  [1:0]          cmd_byte_cnt;
    
    // ID response state
    reg  [1:0]          id_byte_cnt;
    
    // State machine
    localparam ST_IDLE     = 3'h0;
    localparam ST_ARM      = 3'h1;
    localparam ST_CAPTURE  = 3'h2;
    localparam ST_READBACK = 3'h3;
    reg  [2:0]          state;
    
    // Trigger detection
    reg                 trigger_loc;
    reg                 trigger_or;
    reg                 trigger_or_p1;
    reg                 trigger_and;
    reg                 trigger_and_p1;
    
    //=========================================================================
    // UART Modules (115200 baud)
    //=========================================================================
    uart_rx #(
        .CLK_FREQ(27_000_000),
        .BAUD_RATE(115200)
    ) u_uart_rx (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .data(uart_rx_data),
        .valid(uart_rx_valid)
    );
    
    uart_tx #(
        .CLK_FREQ(27_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk(clk),
        .rst(rst),
        .tx(uart_tx),
        .data(uart_tx_data),
        .valid(uart_tx_valid),
        .ready(uart_tx_ready)
    );
    
    //=========================================================================
    // Input event capture
    //=========================================================================
    always @(posedge clk) begin
        if (EVENT_BYTES == 1)
            events_loc <= {24'd0, events_din[7:0]};
        else if (EVENT_BYTES == 2)
            events_loc <= {16'd0, events_din[15:0]};
        else if (EVENT_BYTES == 3)
            events_loc <= {8'd0, events_din[23:0]};
        else
            events_loc <= events_din[31:0];
    end
    
    //=========================================================================
    // Trigger detection logic
    //=========================================================================
    integer i;
    always @(posedge clk) begin
        trigger_or  <= 0;
        trigger_and <= 0;
        trigger_or_p1  <= trigger_or;
        trigger_and_p1 <= trigger_and;
        
        // OR trigger - any bit matches
        for (i = 0; i <= 31; i = i + 1) begin
            if (trigger_bits[i] == 1 && events_loc[i] == 1)
                trigger_or <= 1;
        end
        
        // AND trigger - all bits match
        if ((events_loc[31:0] & trigger_bits[31:0]) == trigger_bits[31:0])
            trigger_and <= 1;
    end
    
    //=========================================================================
    // Capture state machine
    //=========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            armed_jk <= 0;
            triggered_jk <= 0;
            acquired_jk <= 0;
            c_addr <= 0;
            c_we <= 0;
            post_trig_cnt <= 0;
            trigger_ptr <= 0;
        end else begin
            c_we <= 0;
            trigger_loc <= 0;
            
            case (state)
                ST_IDLE: begin
                    if (cmd_reg == 6'h01) begin  // ARM command
                        state <= ST_ARM;
                        armed_jk <= 1;
                        triggered_jk <= 0;
                        acquired_jk <= 0;
                        c_addr <= 0;
                        post_trig_cnt <= 0;
                    end
                end
                
                ST_ARM: begin
                    // Pre-trigger capture (circular buffer)
                    if (!triggered_jk) begin
                        c_we <= 1;
                        c_addr <= c_addr + 1;
                        
                        // Check trigger condition
                        if ((trigger_type == 4'h0 && trigger_and == 1 && trigger_and_p1 == 0) ||  // AND rising
                            (trigger_type == 4'h1 && trigger_and == 0 && trigger_and_p1 == 1) ||  // AND falling
                            (trigger_type == 4'h2 && trigger_or  == 1 && trigger_or_p1  == 0) ||  // OR rising
                            (trigger_type == 4'h3 && trigger_or  == 0 && trigger_or_p1  == 1)) begin // OR falling
                            triggered_jk <= 1;
                            trigger_ptr <= c_addr;
                            trigger_loc <= 1;
                        end
                    end
                    // Post-trigger capture
                    else if (!acquired_jk) begin
                        c_we <= 1;
                        c_addr <= c_addr + 1;
                        post_trig_cnt <= post_trig_cnt + 1;
                        
                        if (post_trig_cnt == trigger_pos[DEPTH_BITS-1:0]) begin
                            acquired_jk <= 1;
                            state <= ST_IDLE;
                        end
                    end
                    
                    // Reset command
                    if (cmd_reg == 6'h02) begin
                        state <= ST_IDLE;
                        armed_jk <= 0;
                        triggered_jk <= 0;
                        acquired_jk <= 0;
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
    
    //=========================================================================
    // Capture RAM write
    //=========================================================================
    always @(posedge clk) begin
        if (c_we)
            event_ram_array[c_addr] <= events_loc;
    end
    
    //=========================================================================
    // SUMP command decoder
    //=========================================================================
    reg [DEPTH_BITS-1:0] read_addr;
    reg [31:0] ram_rd_data;
    
    always @(posedge clk) begin
        if (rst) begin
            cmd_reg <= 0;
            cmd_data <= 0;
            cmd_byte_cnt <= 0;
            uart_tx_valid <= 0;
            read_addr <= 0;
            id_byte_cnt <= 0;
        end else begin
            uart_tx_valid <= 0;
            
            // Send multi-byte ID response
            if (id_byte_cnt > 0 && uart_tx_ready && !uart_rx_valid) begin
                case (id_byte_cnt)
                    2'd1: uart_tx_data <= 8'h4C;  // 'L'
                    2'd2: uart_tx_data <= 8'h41;  // 'A'
                    2'd3: uart_tx_data <= 8'h31;  // '1'
                endcase
                uart_tx_valid <= 1;
                id_byte_cnt <= (id_byte_cnt == 2'd3) ? 2'd0 : id_byte_cnt + 2'd1;
            end
            
            if (uart_rx_valid) begin
                // SUMP protocol commands
                case (uart_rx_data[7:6])
                    2'b00: begin  // Short commands
                        cmd_reg <= uart_rx_data[5:0];
                        cmd_byte_cnt <= 0;
                        
                        // Process immediate commands
                        case (uart_rx_data[5:0])
                            6'h00: begin  // RESET/IDLE
                                cmd_reg <= 6'h02;
                            end
                            6'h01: begin  // ARM
                                cmd_reg <= 6'h01;
                            end
                            6'h02: begin  // ID command - return "SLA1"
                                uart_tx_data <= 8'h53;  // 'S' (first byte)
                                uart_tx_valid <= 1;
                                id_byte_cnt <= 2'd1;    // Start sending remaining bytes
                            end
                        endcase
                    end
                    
                    2'b10: begin  // Long commands (4 bytes follow)
                        cmd_reg <= uart_rx_data[5:0];
                        cmd_byte_cnt <= 0;
                    end
                endcase
                
                // Accumulate command data bytes
                if (cmd_byte_cnt > 0) begin
                    cmd_data <= {cmd_data[23:0], uart_rx_data};
                    cmd_byte_cnt <= cmd_byte_cnt + 1;
                    
                    if (cmd_byte_cnt == 2'd3) begin
                        // Execute command with accumulated data
                        case (cmd_reg)
                            6'h04: trigger_bits <= {cmd_data[23:0], uart_rx_data};
                            6'h07: trigger_pos <= {cmd_data[23:0], uart_rx_data}[DEPTH_BITS-1:0];
                        endcase
                    end
                end
            end
        end
    end
    
    // Read back captured data (simplified)
    always @(posedge clk) begin
        ram_rd_data <= event_ram_array[read_addr];
    end

endmodule

//=============================================================================
// Simple UART RX
//=============================================================================
module uart_rx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    reg [15:0] clk_cnt;
    reg [2:0]  bit_cnt;
    reg [1:0]  state;
    reg        rx_sync1, rx_sync2;
    
    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            valid <= 0;
            clk_cnt <= 0;
            bit_cnt <= 0;
            rx_sync1 <= 1;
            rx_sync2 <= 1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            valid <= 0;
            
            case (state)
                0: begin  // IDLE
                    if (rx_sync2 == 0) begin
                        state <= 1;
                        clk_cnt <= CLKS_PER_BIT / 2;
                    end
                end
                1: begin  // START BIT
                    if (clk_cnt == 0) begin
                        state <= 2;
                        clk_cnt <= CLKS_PER_BIT - 1;
                        bit_cnt <= 0;
                    end else
                        clk_cnt <= clk_cnt - 1;
                end
                2: begin  // DATA BITS
                    if (clk_cnt == 0) begin
                        data[bit_cnt] <= rx_sync2;
                        if (bit_cnt == 7) begin
                            state <= 3;
                            valid <= 1;
                        end else
                            bit_cnt <= bit_cnt + 1;
                        clk_cnt <= CLKS_PER_BIT - 1;
                    end else
                        clk_cnt <= clk_cnt - 1;
                end
                3: begin  // STOP BIT
                    if (clk_cnt == 0)
                        state <= 0;
                    else
                        clk_cnt <= clk_cnt - 1;
                end
            endcase
        end
    end
endmodule

//=============================================================================
// Simple UART TX
//=============================================================================
module uart_tx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    output reg        tx,
    input  wire [7:0] data,
    input  wire       valid,
    output wire       ready
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    reg [15:0] clk_cnt;
    reg [2:0]  bit_cnt;
    reg [1:0]  state;
    reg [7:0]  data_reg;
    
    assign ready = (state == 0);
    
    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            tx <= 1;
            clk_cnt <= 0;
            bit_cnt <= 0;
        end else begin
            case (state)
                0: begin  // IDLE
                    tx <= 1;
                    if (valid) begin
                        data_reg <= data;
                        state <= 1;
                        clk_cnt <= CLKS_PER_BIT - 1;
                    end
                end
                1: begin  // START BIT
                    tx <= 0;
                    if (clk_cnt == 0) begin
                        state <= 2;
                        clk_cnt <= CLKS_PER_BIT - 1;
                        bit_cnt <= 0;
                    end else
                        clk_cnt <= clk_cnt - 1;
                end
                2: begin  // DATA BITS
                    tx <= data_reg[bit_cnt];
                    if (clk_cnt == 0) begin
                        if (bit_cnt == 7) begin
                            state <= 3;
                        end else
                            bit_cnt <= bit_cnt + 1;
                        clk_cnt <= CLKS_PER_BIT - 1;
                    end else
                        clk_cnt <= clk_cnt - 1;
                end
                3: begin  // STOP BIT
                    tx <= 1;
                    if (clk_cnt == 0)
                        state <= 0;
                    else
                        clk_cnt <= clk_cnt - 1;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
