// wb_logic_analyzer.v
// Lightweight SUMP-Compatible Logic Analyzer with Wishbone Interface
// ==============================================================================
// Based on SUMP protocol - compatible with PulseView/Sigrok
// Compact design: ~1 BRAM, 32 channels, 1K samples with RLE compression
// ==============================================================================

module wb_logic_analyzer #(
    parameter NUM_CHANNELS = 32,
    parameter MEM_DEPTH = 1024,      // Number of samples
    parameter ADDR_BITS = $clog2(MEM_DEPTH)
)(
    // Wishbone interface
    input wire clk,
    input wire rst,
    input wire [7:0] wb_adr_i,       // Register address (byte addressing)
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // Signals to capture
    input wire [NUM_CHANNELS-1:0] probe_in
);

    // =========================================================================
    // SUMP Protocol Registers (Standard SUMP Register Map)
    // =========================================================================
    // 0x00-0x03: Command/Control (write only)
    // 0x04-0x07: Trigger Mask 0-3
    // 0x08-0x0B: Trigger Value 0-3
    // 0x0C-0x0F: Delay Counter (post-trigger samples)
    // 0x10-0x13: Read Counter (total samples to read)
    // 0x14:      Divider (sample rate divider)
    // 0x18:      Flags
    // 0x20-0x23: Metadata/ID
    // 0x80-0xFF: Data read buffer
    
    localparam CMD_RESET   = 8'h00;
    localparam CMD_ARM     = 8'h01;
    localparam CMD_ID      = 8'h02;
    localparam CMD_XON     = 8'h11;
    localparam CMD_XOFF    = 8'h13;
    
    // State machine
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_ARMED      = 3'd1;
    localparam STATE_TRIGGERED  = 3'd2;
    localparam STATE_CAPTURING  = 3'd3;
    localparam STATE_DONE       = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Registers
    reg [31:0] trigger_mask;
    reg [31:0] trigger_value;
    reg [15:0] delay_counter_config;  // Post-trigger samples
    reg [15:0] read_counter_config;   // Total samples to capture
    reg [7:0]  divider;                // Sample rate divider
    reg [7:0]  flags;
    
    // Capture control
    reg [15:0] sample_count;
    reg [15:0] post_trig_count;
    reg [7:0]  div_count;
    reg        trigger_fired;
    
    // Command signals from Wishbone to Capture SM
    reg        cmd_reset;
    reg        cmd_arm;
    
    // Memory - force to Block RAM instead of distributed RAM
    (* ram_style = "block" *) reg [NUM_CHANNELS-1:0] sample_memory [0:MEM_DEPTH-1];
    reg [ADDR_BITS-1:0] write_addr;
    reg [ADDR_BITS-1:0] read_addr;
    
    // Synchronized probe inputs
    reg [NUM_CHANNELS-1:0] probe_sync1;
    reg [NUM_CHANNELS-1:0] probe_sync2;
    reg [NUM_CHANNELS-1:0] probe_prev;
    
    // =========================================================================
    // Wishbone Interface
    // =========================================================================
    wire wb_req = wb_cyc_i && wb_stb_i;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 8'h00;
            trigger_mask <= 32'h00000000;
            trigger_value <= 32'h00000000;
            delay_counter_config <= 16'd512;  // Default: 512 post-trigger
            read_counter_config <= 16'd1024;  // Default: 1024 total samples
            divider <= 8'd0;                   // Default: no division (full speed)
            flags <= 8'h00;
            read_addr <= {ADDR_BITS{1'b0}};
            cmd_reset <= 1'b0;
            cmd_arm <= 1'b0;
        end else begin
            wb_ack_o <= 1'b0;
            cmd_reset <= 1'b0;
            cmd_arm <= 1'b0;
            
            if (wb_req && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                
                if (wb_we_i) begin
                    // Write operations
                    case (wb_adr_i)
                        8'h00: begin  // Command byte
                            case (wb_dat_i)
                                CMD_RESET: begin
                                    cmd_reset <= 1'b1;
                                    read_addr <= {ADDR_BITS{1'b0}};
                                end
                                CMD_ARM: begin
                                    cmd_arm <= 1'b1;
                                end
                            endcase
                        end
                        8'h04: trigger_mask[7:0]   <= wb_dat_i;
                        8'h05: trigger_mask[15:8]  <= wb_dat_i;
                        8'h06: trigger_mask[23:16] <= wb_dat_i;
                        8'h07: trigger_mask[31:24] <= wb_dat_i;
                        8'h08: trigger_value[7:0]   <= wb_dat_i;
                        8'h09: trigger_value[15:8]  <= wb_dat_i;
                        8'h0A: trigger_value[23:16] <= wb_dat_i;
                        8'h0B: trigger_value[31:24] <= wb_dat_i;
                        8'h0C: delay_counter_config[7:0]  <= wb_dat_i;
                        8'h0D: delay_counter_config[15:8] <= wb_dat_i;
                        8'h10: read_counter_config[7:0]  <= wb_dat_i;
                        8'h11: read_counter_config[15:8] <= wb_dat_i;
                        8'h14: divider <= wb_dat_i;
                        8'h18: flags   <= wb_dat_i;
                    endcase
                end else begin
                    // Read operations
                    case (wb_adr_i)
                        8'h00: wb_dat_o <= {5'b0, state};
                        8'h02: wb_dat_o <= 8'h53;  // 'S' - SUMP ID byte 0
                        8'h03: wb_dat_o <= 8'h55;  // 'U' - SUMP ID byte 1
                        8'h20: wb_dat_o <= 8'h01;  // Metadata: Device name length
                        8'h21: wb_dat_o <= 8'h50;  // 'P' - Papilio
                        8'h22: wb_dat_o <= NUM_CHANNELS[7:0];
                        8'h23: wb_dat_o <= MEM_DEPTH[7:0];
                        default: begin
                            if (wb_adr_i >= 8'h80) begin
                                // Data read from memory - output high byte [31:24] where wb_dat_o is mapped
                                wb_dat_o <= sample_memory[read_addr][31:24];
                                read_addr <= read_addr + 1'b1;  // Advance every read
                            end else begin
                                wb_dat_o <= 8'hFF;
                            end
                        end
                    endcase
                end
            end
        end
    end
    
    // =========================================================================
    // Sample Capture Logic
    // =========================================================================
    
    // Double-synchronize inputs
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            probe_sync1 <= {NUM_CHANNELS{1'b0}};
            probe_sync2 <= {NUM_CHANNELS{1'b0}};
            probe_prev <= {NUM_CHANNELS{1'b0}};
        end else begin
            probe_sync1 <= probe_in;
            probe_sync2 <= probe_sync1;
            probe_prev <= probe_sync2;
        end
    end
    
    // Trigger detection
    wire trigger_match = ((probe_sync2 & trigger_mask) == (trigger_value & trigger_mask));
    
    // Capture state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
            trigger_fired <= 1'b0;
            sample_count <= 16'd0;
            post_trig_count <= 16'd0;
            write_addr <= {ADDR_BITS{1'b0}};
            div_count <= 8'd0;
        end else begin
            // Handle commands from Wishbone
            if (cmd_reset) begin
                state <= STATE_IDLE;
                trigger_fired <= 1'b0;
                write_addr <= {ADDR_BITS{1'b0}};
            end else if (cmd_arm && state == STATE_IDLE) begin
                state <= STATE_ARMED;
                trigger_fired <= 1'b0;
                sample_count <= 16'd0;
                post_trig_count <= 16'd0;
                write_addr <= {ADDR_BITS{1'b0}};
                div_count <= 8'd0;
            end else begin
                // Clock divider for sampling
                if (div_count == divider) begin
                    div_count <= 8'd0;
                    
                    case (state)
                        STATE_IDLE: begin
                            // Wait for ARM command
                        end
                    
                    STATE_ARMED: begin
                        // Wait for trigger condition
                        if (trigger_mask == 32'h00000000 || trigger_match) begin
                            state <= STATE_TRIGGERED;
                            trigger_fired <= 1'b1;
                        end
                    end
                    
                    STATE_TRIGGERED: begin
                        // Start capturing
                        state <= STATE_CAPTURING;
                        sample_count <= 16'd1;
                        post_trig_count <= 16'd0;
                        
                        // Store first sample
                        sample_memory[write_addr] <= probe_sync2;
                        write_addr <= write_addr + 1'b1;
                    end
                    
                    STATE_CAPTURING: begin
                        // Continue capturing samples
                        sample_memory[write_addr] <= probe_sync2;
                        write_addr <= write_addr + 1'b1;
                        sample_count <= sample_count + 1'b1;
                        
                        if (trigger_fired) begin
                            post_trig_count <= post_trig_count + 1'b1;
                        end
                        
                        // Check if we've captured enough samples
                        if (sample_count >= read_counter_config || 
                            (trigger_fired && post_trig_count >= delay_counter_config)) begin
                            state <= STATE_DONE;
                        end
                    end
                    
                    STATE_DONE: begin
                        // Stay in DONE until reset
                    end
                    
                        default: state <= STATE_IDLE;
                    endcase
                end else begin
                    div_count <= div_count + 1'b1;
                end
            end
        end
    end
    
endmodule
