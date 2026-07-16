//
// Pocket APF data-slot writer for CPC snapshot files.
//
// Snapshot saves are written into a dedicated writable dataslot and opened
// explicitly under /Saves/amstrad/common before the .sna payload is streamed
// in 1 KB chunks.
//

`default_nettype none

module pocket_sna_save_dataslot (
    input  wire         clk,
    input  wire         bridge_clk,
    input  wire         reset_n,
    input  wire         enable,

    input  wire [31:0]  bridge_addr,
    input  wire         bridge_rd,
    output wire [31:0]  bridge_rd_data,
    output wire         bridge_selected,

    input  wire         save_request,
    input  wire         media_busy,

    input  wire [1:0]   state_model,
    input  wire [211:0] state_cpu_dir,
    input  wire [4:0]   state_crtc_addr,
    input  wire [143:0] state_crtc_regs,
    input  wire [4:0]   state_ga_inksel,
    input  wire [135:0] state_ga_palette,
    input  wire [7:0]   state_ga_config,
    input  wire [7:0]   state_ram_config,
    input  wire [7:0]   state_rom_select,
    input  wire [7:0]   state_ppi_a,
    input  wire [7:0]   state_ppi_b,
    input  wire [7:0]   state_ppi_c,
    input  wire [7:0]   state_ppi_control,
    input  wire [3:0]   state_psg_addr,
    input  wire [127:0] state_psg_regs,
    input  wire [31:0]  rtc_date_bcd,
    input  wire [31:0]  rtc_time_bcd,
    input  wire         rtc_valid,

    output reg          freeze_cpu,
    output reg          capture_ram_rd,
    output reg  [15:0]  capture_ram_word_addr,
    input  wire [15:0]  capture_ram_word_data,

    output reg          target_dataslot_write,
    output reg          target_dataslot_openfile,
    output reg  [15:0]  target_dataslot_id,
    output reg  [31:0]  target_dataslot_slotoffset,
    output reg  [31:0]  target_dataslot_bridgeaddr,
    output reg  [31:0]  target_dataslot_length,
    output reg  [31:0]  target_buffer_param_struct,
    output reg          cmd_request_flag,
    output reg          cmd_write_strobe,
    input  wire         cmd_ack_flag,
    input  wire         target_dataslot_ack,
    input  wire         target_dataslot_done,
    input  wire [2:0]   target_dataslot_err,
    output wire         target_active,

    output reg          save_busy,
    output reg          save_ok,
    output reg          save_err
);

localparam [15:0] SLOT_SNAPSHOT_SAVE = 16'h0005;
localparam [31:0] BRIDGE_RAM_ADDR    = 32'h9002_0000;
localparam [31:0] CHUNK_BYTES        = 32'd1024;
localparam [31:0] SNAPSHOT_HDR_SIZE  = 32'd256;
localparam [31:0] SNAPSHOT_SIZE_64K  = 32'd65792;
localparam [31:0] SNAPSHOT_SIZE_128K = 32'd131328;
localparam [7:0]  OPENFILE_FLAGS     = 8'h03;
localparam [7:0]  OPENFILE_WORDS     = 8'd66;

localparam [4:0]
    ST_IDLE               = 5'd0,
    ST_OPENFILE_PREP      = 5'd1,
    ST_OPENFILE_HOLD      = 5'd2,
    ST_WAIT_OPEN_CMD_ACK  = 5'd3,
    ST_WAIT_OPEN_DONE     = 5'd4,
    ST_CHUNK_PREP         = 5'd5,
    ST_FILL_HEADER        = 5'd6,
    ST_FILL_MEM_REQ0      = 5'd7,
    ST_FILL_MEM_WAIT0     = 5'd8,
    ST_FILL_MEM_WAIT1     = 5'd9,
    ST_CHUNK_NEXT         = 5'd10,
    ST_WRITE_HOLD         = 5'd11,
    ST_WAIT_WRITE_CMD_ACK = 5'd12,
    ST_WAIT_WRITE_DONE    = 5'd13;

reg  [4:0]   state = ST_IDLE;
reg  [31:0]  file_offset = 32'd0;
reg  [31:0]  bytes_remaining = 32'd0;
reg  [10:0]  chunk_len = 11'd0;
reg  [7:0]   chunk_word_index = 8'd0;
reg  [8:0]   chunk_word_count = 9'd0;
reg  [15:0]  saved_word_lo = 16'd0;
reg  [15:0]  mem_word_base = 16'd0;
reg          buffer_b_wr = 1'b0;
reg  [7:0]   buffer_b_addr = 8'd0;
reg  [31:0]  buffer_b_din = 32'd0;
wire [31:0]  buffer_a_dout;

reg  [1:0]   snap_state_model = 2'd0;
reg  [211:0] snap_state_cpu_dir = 212'd0;
reg  [4:0]   snap_state_crtc_addr = 5'd0;
reg  [143:0] snap_state_crtc_regs = 144'd0;
reg  [4:0]   snap_state_ga_inksel = 5'd0;
reg  [135:0] snap_state_ga_palette = 136'd0;
reg  [7:0]   snap_state_ga_config = 8'd0;
reg  [7:0]   snap_state_ram_config = 8'd0;
reg  [7:0]   snap_state_rom_select = 8'd0;
reg  [7:0]   snap_state_ppi_a = 8'd0;
reg  [7:0]   snap_state_ppi_b = 8'd0;
reg  [7:0]   snap_state_ppi_c = 8'd0;
reg  [7:0]   snap_state_ppi_control = 8'h9b;
reg  [3:0]   snap_state_psg_addr = 4'd0;
reg  [127:0] snap_state_psg_regs = 128'd0;
reg  [31:0]  snap_rtc_date_bcd = 32'd0;
reg  [31:0]  snap_rtc_time_bcd = 32'd0;
reg          snap_rtc_valid = 1'b0;
reg  [7:0]   save_sequence = 8'd0;
reg  [7:0]   snap_save_sequence = 8'd0;

wire [31:0] current_word_byte_offset = file_offset + {22'd0, chunk_word_index, 2'b00};
wire [31:0] current_mem_byte_offset = current_word_byte_offset - SNAPSHOT_HDR_SIZE;
wire [13:0] bridge_word_addr = bridge_addr[9:2];
wire        bridge_addr_in_range = (bridge_addr[31:10] == BRIDGE_RAM_ADDR[31:10]);
wire [15:0] snapshot_mem_size_kb = (snap_state_model == 2'd0) ? 16'd128 : 16'd64;
wire [31:0] snapshot_total_bytes = (snap_state_model == 2'd0) ? SNAPSHOT_SIZE_128K : SNAPSHOT_SIZE_64K;
wire [7:0]  snapshot_machine_type =
    (snap_state_model == 2'd2) ? 8'd0 :
    (snap_state_model == 2'd1) ? 8'd1 : 8'd2;

assign bridge_selected = bridge_addr_in_range;
assign bridge_rd_data = buffer_a_dout;
assign target_active = save_busy;

function automatic [7:0] ascii_bcd_digit;
    input [3:0] value;
    begin
        ascii_bcd_digit = (value <= 4'd9) ? (8'h30 + {4'd0, value}) : 8'h30;
    end
endfunction

function automatic [7:0] ascii_hex_digit;
    input [3:0] value;
    begin
        ascii_hex_digit = (value <= 4'd9) ? (8'h30 + {4'd0, value}) : (8'h41 + {4'd0, value} - 8'd10);
    end
endfunction

function automatic [7:0] save_path_byte;
    input [7:0] index;
    input [31:0] rtc_date_bcd_arg;
    input [31:0] rtc_time_bcd_arg;
    input        rtc_valid_arg;
    input [7:0]  save_sequence_arg;
    begin
        case (index)
            8'd0:  save_path_byte = "/";
            8'd1:  save_path_byte = "S";
            8'd2:  save_path_byte = "a";
            8'd3:  save_path_byte = "v";
            8'd4:  save_path_byte = "e";
            8'd5:  save_path_byte = "s";
            8'd6:  save_path_byte = "/";
            8'd7:  save_path_byte = "a";
            8'd8:  save_path_byte = "m";
            8'd9:  save_path_byte = "s";
            8'd10: save_path_byte = "t";
            8'd11: save_path_byte = "r";
            8'd12: save_path_byte = "a";
            8'd13: save_path_byte = "d";
            8'd14: save_path_byte = "/";
            8'd15: save_path_byte = "c";
            8'd16: save_path_byte = "o";
            8'd17: save_path_byte = "m";
            8'd18: save_path_byte = "m";
            8'd19: save_path_byte = "o";
            8'd20: save_path_byte = "n";
            8'd21: save_path_byte = "/";
            8'd22: save_path_byte = "c";
            8'd23: save_path_byte = "p";
            8'd24: save_path_byte = "c";
            8'd25: save_path_byte = "_";
            8'd26: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_date_bcd_arg[31:28]) : "0";
            8'd27: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_date_bcd_arg[27:24]) : "0";
            8'd28: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_date_bcd_arg[23:20]) : "0";
            8'd29: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_date_bcd_arg[19:16]) : "0";
            8'd30: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_date_bcd_arg[15:12]) : "0";
            8'd31: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_date_bcd_arg[11:8]) : "0";
            8'd32: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_date_bcd_arg[7:4]) : "0";
            8'd33: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_date_bcd_arg[3:0]) : "0";
            8'd34: save_path_byte = "_";
            8'd35: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_time_bcd_arg[23:20]) : "0";
            8'd36: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_time_bcd_arg[19:16]) : "0";
            8'd37: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_time_bcd_arg[15:12]) : "0";
            8'd38: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_time_bcd_arg[11:8]) : "0";
            8'd39: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_time_bcd_arg[7:4]) : "0";
            8'd40: save_path_byte = rtc_valid_arg ? ascii_bcd_digit(rtc_time_bcd_arg[3:0]) : "0";
            8'd41: save_path_byte = "_";
            8'd42: save_path_byte = ascii_hex_digit(save_sequence_arg[7:4]);
            8'd43: save_path_byte = ascii_hex_digit(save_sequence_arg[3:0]);
            8'd44: save_path_byte = ".";
            8'd45: save_path_byte = "s";
            8'd46: save_path_byte = "n";
            8'd47: save_path_byte = "a";
            default: save_path_byte = 8'd0;
        endcase
    end
endfunction

function automatic [7:0] openfile_byte;
    input [8:0] index;
    input [31:0] snapshot_total_bytes_arg;
    input [31:0] rtc_date_bcd_arg;
    input [31:0] rtc_time_bcd_arg;
    input        rtc_valid_arg;
    input [7:0]  save_sequence_arg;
    begin
        case (index)
            9'd256: openfile_byte = OPENFILE_FLAGS;
            9'd257: openfile_byte = 8'd0;
            9'd258: openfile_byte = 8'd0;
            9'd259: openfile_byte = 8'd0;
            9'd260: openfile_byte = snapshot_total_bytes_arg[7:0];
            9'd261: openfile_byte = snapshot_total_bytes_arg[15:8];
            9'd262: openfile_byte = snapshot_total_bytes_arg[23:16];
            9'd263: openfile_byte = snapshot_total_bytes_arg[31:24];
            default: openfile_byte = (index < 9'd48) ?
                save_path_byte(index[7:0], rtc_date_bcd_arg, rtc_time_bcd_arg, rtc_valid_arg, save_sequence_arg) : 8'd0;
        endcase
    end
endfunction

function automatic [7:0] header_byte;
    input [7:0] index;
    input [211:0] state_cpu_dir_arg;
    input [4:0]   state_crtc_addr_arg;
    input [143:0] state_crtc_regs_arg;
    input [4:0]   state_ga_inksel_arg;
    input [135:0] state_ga_palette_arg;
    input [7:0]   state_ga_config_arg;
    input [7:0]   state_ram_config_arg;
    input [7:0]   state_rom_select_arg;
    input [7:0]   state_ppi_a_arg;
    input [7:0]   state_ppi_b_arg;
    input [7:0]   state_ppi_c_arg;
    input [7:0]   state_ppi_control_arg;
    input [3:0]   state_psg_addr_arg;
    input [127:0] state_psg_regs_arg;
    input [15:0]  snapshot_mem_size_kb_arg;
    input [7:0]   snapshot_machine_type_arg;
    begin
        case (index)
            8'h00: header_byte = "M";
            8'h01: header_byte = "V";
            8'h02: header_byte = " ";
            8'h03: header_byte = "-";
            8'h04: header_byte = " ";
            8'h05: header_byte = "S";
            8'h06: header_byte = "N";
            8'h07: header_byte = "A";
            8'h10: header_byte = 8'd2;
            8'h11: header_byte = state_cpu_dir_arg[15:8];
            8'h12: header_byte = state_cpu_dir_arg[7:0];
            8'h13: header_byte = state_cpu_dir_arg[87:80];
            8'h14: header_byte = state_cpu_dir_arg[95:88];
            8'h15: header_byte = state_cpu_dir_arg[103:96];
            8'h16: header_byte = state_cpu_dir_arg[111:104];
            8'h17: header_byte = state_cpu_dir_arg[119:112];
            8'h18: header_byte = state_cpu_dir_arg[127:120];
            8'h19: header_byte = state_cpu_dir_arg[47:40];
            8'h1a: header_byte = state_cpu_dir_arg[39:32];
            8'h1b: header_byte = {7'd0, state_cpu_dir_arg[210]};
            8'h1c: header_byte = {7'd0, state_cpu_dir_arg[211]};
            8'h1d: header_byte = state_cpu_dir_arg[135:128];
            8'h1e: header_byte = state_cpu_dir_arg[143:136];
            8'h1f: header_byte = state_cpu_dir_arg[199:192];
            8'h20: header_byte = state_cpu_dir_arg[207:200];
            8'h21: header_byte = state_cpu_dir_arg[55:48];
            8'h22: header_byte = state_cpu_dir_arg[63:56];
            8'h23: header_byte = state_cpu_dir_arg[71:64];
            8'h24: header_byte = state_cpu_dir_arg[79:72];
            8'h25: header_byte = {6'd0, state_cpu_dir_arg[209:208]};
            8'h26: header_byte = state_cpu_dir_arg[31:24];
            8'h27: header_byte = state_cpu_dir_arg[23:16];
            8'h28: header_byte = state_cpu_dir_arg[151:144];
            8'h29: header_byte = state_cpu_dir_arg[159:152];
            8'h2a: header_byte = state_cpu_dir_arg[167:160];
            8'h2b: header_byte = state_cpu_dir_arg[175:168];
            8'h2c: header_byte = state_cpu_dir_arg[183:176];
            8'h2d: header_byte = state_cpu_dir_arg[191:184];
            8'h2e: header_byte = {3'd0, state_ga_inksel_arg};
            8'h2f: header_byte = state_ga_palette_arg[7:0];
            8'h30: header_byte = state_ga_palette_arg[15:8];
            8'h31: header_byte = state_ga_palette_arg[23:16];
            8'h32: header_byte = state_ga_palette_arg[31:24];
            8'h33: header_byte = state_ga_palette_arg[39:32];
            8'h34: header_byte = state_ga_palette_arg[47:40];
            8'h35: header_byte = state_ga_palette_arg[55:48];
            8'h36: header_byte = state_ga_palette_arg[63:56];
            8'h37: header_byte = state_ga_palette_arg[71:64];
            8'h38: header_byte = state_ga_palette_arg[79:72];
            8'h39: header_byte = state_ga_palette_arg[87:80];
            8'h3a: header_byte = state_ga_palette_arg[95:88];
            8'h3b: header_byte = state_ga_palette_arg[103:96];
            8'h3c: header_byte = state_ga_palette_arg[111:104];
            8'h3d: header_byte = state_ga_palette_arg[119:112];
            8'h3e: header_byte = state_ga_palette_arg[127:120];
            8'h3f: header_byte = state_ga_palette_arg[135:128];
            8'h40: header_byte = state_ga_config_arg;
            8'h41: header_byte = state_ram_config_arg;
            8'h42: header_byte = {3'd0, state_crtc_addr_arg};
            8'h43: header_byte = state_crtc_regs_arg[7:0];
            8'h44: header_byte = state_crtc_regs_arg[15:8];
            8'h45: header_byte = state_crtc_regs_arg[23:16];
            8'h46: header_byte = state_crtc_regs_arg[31:24];
            8'h47: header_byte = state_crtc_regs_arg[39:32];
            8'h48: header_byte = state_crtc_regs_arg[47:40];
            8'h49: header_byte = state_crtc_regs_arg[55:48];
            8'h4a: header_byte = state_crtc_regs_arg[63:56];
            8'h4b: header_byte = state_crtc_regs_arg[71:64];
            8'h4c: header_byte = state_crtc_regs_arg[79:72];
            8'h4d: header_byte = state_crtc_regs_arg[87:80];
            8'h4e: header_byte = state_crtc_regs_arg[95:88];
            8'h4f: header_byte = state_crtc_regs_arg[103:96];
            8'h50: header_byte = state_crtc_regs_arg[111:104];
            8'h51: header_byte = state_crtc_regs_arg[119:112];
            8'h52: header_byte = state_crtc_regs_arg[127:120];
            8'h53: header_byte = state_crtc_regs_arg[135:128];
            8'h54: header_byte = state_crtc_regs_arg[143:136];
            8'h55: header_byte = state_rom_select_arg;
            8'h56: header_byte = state_ppi_a_arg;
            8'h57: header_byte = state_ppi_b_arg;
            8'h58: header_byte = state_ppi_c_arg;
            8'h59: header_byte = state_ppi_control_arg;
            8'h5a: header_byte = {4'd0, state_psg_addr_arg};
            8'h5b: header_byte = state_psg_regs_arg[7:0];
            8'h5c: header_byte = state_psg_regs_arg[15:8];
            8'h5d: header_byte = state_psg_regs_arg[23:16];
            8'h5e: header_byte = state_psg_regs_arg[31:24];
            8'h5f: header_byte = state_psg_regs_arg[39:32];
            8'h60: header_byte = state_psg_regs_arg[47:40];
            8'h61: header_byte = state_psg_regs_arg[55:48];
            8'h62: header_byte = state_psg_regs_arg[63:56];
            8'h63: header_byte = state_psg_regs_arg[71:64];
            8'h64: header_byte = state_psg_regs_arg[79:72];
            8'h65: header_byte = state_psg_regs_arg[87:80];
            8'h66: header_byte = state_psg_regs_arg[95:88];
            8'h67: header_byte = state_psg_regs_arg[103:96];
            8'h68: header_byte = state_psg_regs_arg[111:104];
            8'h69: header_byte = state_psg_regs_arg[119:112];
            8'h6a: header_byte = state_psg_regs_arg[127:120];
            8'h6b: header_byte = snapshot_mem_size_kb_arg[7:0];
            8'h6c: header_byte = snapshot_mem_size_kb_arg[15:8];
            8'h6d: header_byte = snapshot_machine_type_arg;
            default: header_byte = 8'd0;
        endcase
    end
endfunction

function automatic [31:0] pack_openfile_word;
    input [8:0] base_index;
    input [31:0] snapshot_total_bytes_arg;
    input [31:0] rtc_date_bcd_arg;
    input [31:0] rtc_time_bcd_arg;
    input        rtc_valid_arg;
    input [7:0]  save_sequence_arg;
    begin
        pack_openfile_word = {
            openfile_byte(base_index + 9'd0, snapshot_total_bytes_arg, rtc_date_bcd_arg, rtc_time_bcd_arg, rtc_valid_arg, save_sequence_arg),
            openfile_byte(base_index + 9'd1, snapshot_total_bytes_arg, rtc_date_bcd_arg, rtc_time_bcd_arg, rtc_valid_arg, save_sequence_arg),
            openfile_byte(base_index + 9'd2, snapshot_total_bytes_arg, rtc_date_bcd_arg, rtc_time_bcd_arg, rtc_valid_arg, save_sequence_arg),
            openfile_byte(base_index + 9'd3, snapshot_total_bytes_arg, rtc_date_bcd_arg, rtc_time_bcd_arg, rtc_valid_arg, save_sequence_arg)
        };
    end
endfunction

function automatic [31:0] pack_header_word;
    input [7:0] base_index;
    input [211:0] state_cpu_dir_arg;
    input [4:0]   state_crtc_addr_arg;
    input [143:0] state_crtc_regs_arg;
    input [4:0]   state_ga_inksel_arg;
    input [135:0] state_ga_palette_arg;
    input [7:0]   state_ga_config_arg;
    input [7:0]   state_ram_config_arg;
    input [7:0]   state_rom_select_arg;
    input [7:0]   state_ppi_a_arg;
    input [7:0]   state_ppi_b_arg;
    input [7:0]   state_ppi_c_arg;
    input [7:0]   state_ppi_control_arg;
    input [3:0]   state_psg_addr_arg;
    input [127:0] state_psg_regs_arg;
    input [15:0]  snapshot_mem_size_kb_arg;
    input [7:0]   snapshot_machine_type_arg;
    begin
        pack_header_word = {
            header_byte(base_index + 8'd0, state_cpu_dir_arg, state_crtc_addr_arg, state_crtc_regs_arg, state_ga_inksel_arg, state_ga_palette_arg, state_ga_config_arg, state_ram_config_arg, state_rom_select_arg, state_ppi_a_arg, state_ppi_b_arg, state_ppi_c_arg, state_ppi_control_arg, state_psg_addr_arg, state_psg_regs_arg, snapshot_mem_size_kb_arg, snapshot_machine_type_arg),
            header_byte(base_index + 8'd1, state_cpu_dir_arg, state_crtc_addr_arg, state_crtc_regs_arg, state_ga_inksel_arg, state_ga_palette_arg, state_ga_config_arg, state_ram_config_arg, state_rom_select_arg, state_ppi_a_arg, state_ppi_b_arg, state_ppi_c_arg, state_ppi_control_arg, state_psg_addr_arg, state_psg_regs_arg, snapshot_mem_size_kb_arg, snapshot_machine_type_arg),
            header_byte(base_index + 8'd2, state_cpu_dir_arg, state_crtc_addr_arg, state_crtc_regs_arg, state_ga_inksel_arg, state_ga_palette_arg, state_ga_config_arg, state_ram_config_arg, state_rom_select_arg, state_ppi_a_arg, state_ppi_b_arg, state_ppi_c_arg, state_ppi_control_arg, state_psg_addr_arg, state_psg_regs_arg, snapshot_mem_size_kb_arg, snapshot_machine_type_arg),
            header_byte(base_index + 8'd3, state_cpu_dir_arg, state_crtc_addr_arg, state_crtc_regs_arg, state_ga_inksel_arg, state_ga_palette_arg, state_ga_config_arg, state_ram_config_arg, state_rom_select_arg, state_ppi_a_arg, state_ppi_b_arg, state_ppi_c_arg, state_ppi_control_arg, state_psg_addr_arg, state_psg_regs_arg, snapshot_mem_size_kb_arg, snapshot_machine_type_arg)
        };
    end
endfunction

bram_block_dp #(
    .DATA(32),
    .ADDR(8)
) snapshot_save_buffer (
    .a_clk  ( bridge_clk ),
    .a_wr   ( 1'b0 ),
    .a_addr ( bridge_word_addr[7:0] ),
    .a_din  ( 32'd0 ),
    .a_dout ( buffer_a_dout ),

    .b_clk  ( clk ),
    .b_wr   ( buffer_b_wr ),
    .b_addr ( buffer_b_addr ),
    .b_din  ( buffer_b_din ),
    .b_dout ( )
);

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state                      <= ST_IDLE;
        file_offset                <= 32'd0;
        bytes_remaining            <= 32'd0;
        chunk_len                  <= 11'd0;
        chunk_word_index           <= 8'd0;
        chunk_word_count           <= 9'd0;
        saved_word_lo              <= 16'd0;
        mem_word_base              <= 16'd0;
        buffer_b_wr                <= 1'b0;
        buffer_b_addr              <= 8'd0;
        buffer_b_din               <= 32'd0;
        freeze_cpu                 <= 1'b0;
        capture_ram_rd             <= 1'b0;
        capture_ram_word_addr      <= 16'd0;
        target_dataslot_write      <= 1'b0;
        target_dataslot_openfile   <= 1'b0;
        target_dataslot_id         <= SLOT_SNAPSHOT_SAVE;
        target_dataslot_slotoffset <= 32'd0;
        target_dataslot_bridgeaddr <= BRIDGE_RAM_ADDR;
        target_dataslot_length     <= 32'd0;
        target_buffer_param_struct <= BRIDGE_RAM_ADDR;
        cmd_request_flag           <= 1'b0;
        cmd_write_strobe           <= 1'b0;
        save_busy                  <= 1'b0;
        save_ok                    <= 1'b0;
        save_err                   <= 1'b0;
        snap_state_model           <= 2'd0;
        snap_state_cpu_dir         <= 212'd0;
        snap_state_crtc_addr       <= 5'd0;
        snap_state_crtc_regs       <= 144'd0;
        snap_state_ga_inksel       <= 5'd0;
        snap_state_ga_palette      <= 136'd0;
        snap_state_ga_config       <= 8'd0;
        snap_state_ram_config      <= 8'd0;
        snap_state_rom_select      <= 8'd0;
        snap_state_ppi_a           <= 8'd0;
        snap_state_ppi_b           <= 8'd0;
        snap_state_ppi_c           <= 8'd0;
        snap_state_ppi_control     <= 8'h9b;
        snap_state_psg_addr        <= 4'd0;
        snap_state_psg_regs        <= 128'd0;
        snap_rtc_date_bcd          <= 32'd0;
        snap_rtc_time_bcd          <= 32'd0;
        snap_rtc_valid             <= 1'b0;
        save_sequence              <= 8'd0;
        snap_save_sequence         <= 8'd0;
    end else begin
        buffer_b_wr      <= 1'b0;
        capture_ram_rd <= 1'b0;
        cmd_write_strobe <= 1'b0;

        case (state)
            ST_IDLE: begin
                target_dataslot_write    <= 1'b0;
                target_dataslot_openfile <= 1'b0;
                cmd_request_flag         <= 1'b0;
                freeze_cpu               <= 1'b0;
                save_busy                <= 1'b0;

                if (save_request) begin
                    save_ok  <= 1'b0;
                    save_err <= 1'b0;

                    if (!enable || media_busy) begin
                        save_err <= 1'b1;
                    end else begin
                        freeze_cpu                 <= 1'b1;
                        save_busy                  <= 1'b1;
                        file_offset                <= 32'd0;
                        bytes_remaining            <= (state_model == 2'd0) ? SNAPSHOT_SIZE_128K : SNAPSHOT_SIZE_64K;
                        target_dataslot_id         <= SLOT_SNAPSHOT_SAVE;
                        target_dataslot_bridgeaddr <= BRIDGE_RAM_ADDR;
                        target_buffer_param_struct <= BRIDGE_RAM_ADDR;
                        snap_state_model           <= state_model;
                        snap_state_cpu_dir         <= state_cpu_dir;
                        snap_state_crtc_addr       <= state_crtc_addr;
                        snap_state_crtc_regs       <= state_crtc_regs;
                        snap_state_ga_inksel       <= state_ga_inksel;
                        snap_state_ga_palette      <= state_ga_palette;
                        snap_state_ga_config       <= state_ga_config;
                        snap_state_ram_config      <= state_ram_config;
                        snap_state_rom_select      <= state_rom_select;
                        snap_state_ppi_a           <= state_ppi_a;
                        snap_state_ppi_b           <= state_ppi_b;
                        snap_state_ppi_c           <= state_ppi_c;
                        snap_state_ppi_control     <= state_ppi_control;
                        snap_state_psg_addr        <= state_psg_addr;
                        snap_state_psg_regs        <= state_psg_regs;
                        snap_rtc_date_bcd          <= rtc_date_bcd;
                        snap_rtc_time_bcd          <= rtc_time_bcd;
                        snap_rtc_valid             <= rtc_valid;
                        snap_save_sequence         <= save_sequence;
                        save_sequence              <= save_sequence + 8'd1;
                        chunk_word_index           <= 8'd0;
                        state                      <= ST_OPENFILE_PREP;
                    end
                end
            end

            ST_OPENFILE_PREP: begin
                buffer_b_wr   <= 1'b1;
                buffer_b_addr <= chunk_word_index;
                buffer_b_din  <= pack_openfile_word(
                    {chunk_word_index[6:0], 2'b00},
                    snapshot_total_bytes,
                    snap_rtc_date_bcd,
                    snap_rtc_time_bcd,
                    snap_rtc_valid,
                    snap_save_sequence
                );

                if (chunk_word_index == (OPENFILE_WORDS - 8'd1)) begin
                    target_dataslot_openfile <= 1'b1;
                    cmd_request_flag         <= 1'b1;
                    cmd_write_strobe         <= 1'b1;
                    state                    <= ST_OPENFILE_HOLD;
                end else begin
                    chunk_word_index <= chunk_word_index + 8'd1;
                end
            end

            ST_OPENFILE_HOLD: begin
                target_dataslot_openfile <= 1'b1;
                cmd_request_flag         <= 1'b1;
                cmd_write_strobe         <= 1'b1;
                if (cmd_ack_flag) begin
                    cmd_request_flag <= 1'b0;
                    cmd_write_strobe <= 1'b0;
                    state            <= ST_WAIT_OPEN_CMD_ACK;
                end
            end

            ST_WAIT_OPEN_CMD_ACK: begin
                target_dataslot_openfile <= 1'b1;
                if (target_dataslot_ack) begin
                    target_dataslot_openfile <= 1'b0;
                    state                    <= ST_WAIT_OPEN_DONE;
                end
            end

            ST_WAIT_OPEN_DONE: begin
                if (target_dataslot_done) begin
                    if ((target_dataslot_err != 3'd0) && (target_dataslot_err != 3'd1)) begin
                        freeze_cpu <= 1'b0;
                        save_busy  <= 1'b0;
                        save_err   <= 1'b1;
                        state      <= ST_IDLE;
                    end else begin
                        state <= ST_CHUNK_PREP;
                    end
                end
            end

            ST_CHUNK_PREP: begin
                target_dataslot_slotoffset <= file_offset;
                target_dataslot_length <= (bytes_remaining > CHUNK_BYTES) ? CHUNK_BYTES : bytes_remaining;
                chunk_len <= (bytes_remaining > CHUNK_BYTES) ? CHUNK_BYTES[10:0] : bytes_remaining[10:0];
                chunk_word_count <= (bytes_remaining > CHUNK_BYTES) ? CHUNK_BYTES[10:2] :
                                     bytes_remaining[10:2];
                chunk_word_index <= 8'd0;
                state <= ST_FILL_HEADER;
            end

            ST_FILL_HEADER: begin
                buffer_b_addr <= chunk_word_index;

                if (current_word_byte_offset < SNAPSHOT_HDR_SIZE) begin
                    buffer_b_wr  <= 1'b1;
                    buffer_b_din <= pack_header_word(
                        current_word_byte_offset[7:0],
                        snap_state_cpu_dir,
                        snap_state_crtc_addr,
                        snap_state_crtc_regs,
                        snap_state_ga_inksel,
                        snap_state_ga_palette,
                        snap_state_ga_config,
                        snap_state_ram_config,
                        snap_state_rom_select,
                        snap_state_ppi_a,
                        snap_state_ppi_b,
                        snap_state_ppi_c,
                        snap_state_ppi_control,
                        snap_state_psg_addr,
                        snap_state_psg_regs,
                        snapshot_mem_size_kb,
                        snapshot_machine_type
                    );
                    state        <= ST_CHUNK_NEXT;
                end else begin
                    mem_word_base <= current_mem_byte_offset[16:1];
                    state         <= ST_FILL_MEM_REQ0;
                end
            end

            ST_FILL_MEM_REQ0: begin
                capture_ram_rd        <= 1'b1;
                capture_ram_word_addr <= mem_word_base;
                state                   <= ST_FILL_MEM_WAIT0;
            end

            ST_FILL_MEM_WAIT0: begin
                saved_word_lo           <= capture_ram_word_data;
                capture_ram_rd          <= 1'b1;
                capture_ram_word_addr   <= mem_word_base + 16'd1;
                state                   <= ST_FILL_MEM_WAIT1;
            end

            ST_FILL_MEM_WAIT1: begin
                buffer_b_wr   <= 1'b1;
                buffer_b_addr <= chunk_word_index;
                buffer_b_din  <= {
                    saved_word_lo[7:0],
                    saved_word_lo[15:8],
                    capture_ram_word_data[7:0],
                    capture_ram_word_data[15:8]
                };
                state <= ST_CHUNK_NEXT;
            end

            ST_CHUNK_NEXT: begin
                if ({1'b0, chunk_word_index} == (chunk_word_count - 9'd1)) begin
                    target_dataslot_write <= 1'b1;
                    cmd_request_flag      <= 1'b1;
                    cmd_write_strobe      <= 1'b1;
                    state                 <= ST_WRITE_HOLD;
                end else begin
                    chunk_word_index <= chunk_word_index + 8'd1;
                    state            <= ST_FILL_HEADER;
                end
            end

            ST_WRITE_HOLD: begin
                target_dataslot_write <= 1'b1;
                cmd_request_flag      <= 1'b1;
                cmd_write_strobe      <= 1'b1;
                if (cmd_ack_flag) begin
                    cmd_request_flag <= 1'b0;
                    cmd_write_strobe <= 1'b0;
                    state            <= ST_WAIT_WRITE_CMD_ACK;
                end
            end

            ST_WAIT_WRITE_CMD_ACK: begin
                target_dataslot_write <= 1'b1;
                if (target_dataslot_ack) begin
                    target_dataslot_write <= 1'b0;
                    state                 <= ST_WAIT_WRITE_DONE;
                end
            end

            ST_WAIT_WRITE_DONE: begin
                if (target_dataslot_done) begin
                    if (target_dataslot_err != 3'd0) begin
                        freeze_cpu <= 1'b0;
                        save_busy  <= 1'b0;
                        save_err   <= 1'b1;
                        state      <= ST_IDLE;
                    end else if (bytes_remaining == {21'd0, chunk_len}) begin
                        freeze_cpu <= 1'b0;
                        save_busy  <= 1'b0;
                        save_ok    <= 1'b1;
                        state      <= ST_IDLE;
                    end else begin
                        file_offset     <= file_offset + {21'd0, chunk_len};
                        bytes_remaining <= bytes_remaining - {21'd0, chunk_len};
                        state           <= ST_CHUNK_PREP;
                    end
                end
            end

            default: begin
                state <= ST_IDLE;
            end
        endcase
    end
end

endmodule

`default_nettype wire
