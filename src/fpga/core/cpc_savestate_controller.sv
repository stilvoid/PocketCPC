//
// Native APF savestate controller for PocketCPC.
//
// The staged payload lives in external PSRAM as a `.sna`-compatible CPC
// snapshot image. The Pocket bridge sees that PSRAM as the APF savestate
// window, while the CPC clock domain reaches it through a small mailbox so the
// full snapshot stays off-chip instead of being duplicated in Cyclone V block
// RAM.
//

`default_nettype none

module cpc_savestate_controller (
    input  wire         bridge_clk,
    input  wire         clk,
    input  wire         reset_n,

    input  wire [31:0]  bridge_addr,
    input  wire         bridge_rd,
    input  wire         bridge_wr,
    input  wire [31:0]  bridge_wr_data,
    output wire [31:0]  bridge_rd_data,
    output wire         bridge_selected,

    input  wire         savestate_start,
    output wire         savestate_start_ack_s,
    output wire         savestate_start_busy_s,
    output wire         savestate_start_ok_s,
    output wire         savestate_start_err_s,

    input  wire         savestate_load,
    output wire         savestate_load_ack_s,
    output wire         savestate_load_busy_s,
    output wire         savestate_load_ok_s,
    output wire         savestate_load_err_s,

    input  wire         save_safe,
    input  wire         save_defer_ok,
    input  wire         load_safe,
    input  wire         frame_pulse,
    input  wire         custom_rom_enable,

    input  wire [1:0]   state_model,
    input  wire [211:0] state_cpu_dir,
    input  wire [4:0]   state_crtc_addr,
    input  wire [143:0] state_crtc_regs,
    input  wire [63:0]  state_crtc_v3,
    input  wire [4:0]   state_ga_inksel,
    input  wire [135:0] state_ga_palette,
    input  wire [7:0]   state_ga_config,
    input  wire [7:0]   state_ga_vsync_delay,
    input  wire [7:0]   state_ga_int_scanline,
    input  wire         state_ga_irq_active,
    input  wire [7:0]   state_ram_config,
    input  wire [7:0]   state_rom_select,
    input  wire [7:0]   state_ppi_a,
    input  wire [7:0]   state_ppi_b,
    input  wire [7:0]   state_ppi_c,
    input  wire [7:0]   state_ppi_control,
    input  wire [3:0]   state_psg_addr,
    input  wire [127:0] state_psg_regs,

    output reg          freeze_cpu,
    output reg          snapshot_busy_reset,
    output reg          snapshot_word_wr,
    output reg  [15:0]  snapshot_word_addr,
    output reg  [15:0]  snapshot_word_data,
    output reg          sna_load,
    output reg  [211:0] sna_cpu_dir,
    output reg  [4:0]   sna_crtc_addr,
    output reg  [143:0] sna_crtc_regs,
    output reg          sna_crtc_v3_valid,
    output reg  [63:0]  sna_crtc_v3,
    output reg  [4:0]   sna_ga_inksel,
    output reg  [135:0] sna_ga_palette,
    output reg  [7:0]   sna_ga_config,
    output reg  [7:0]   sna_ga_vsync_delay,
    output reg  [7:0]   sna_ga_int_scanline,
    output reg          sna_ga_irq_active,
    output reg  [7:0]   sna_ram_config,
    output reg  [7:0]   sna_rom_select,
    output reg  [7:0]   sna_ppi_a,
    output reg  [7:0]   sna_ppi_b,
    output reg  [7:0]   sna_ppi_c,
    output reg  [7:0]   sna_ppi_control,
    output reg  [3:0]   sna_psg_addr,
    output reg  [127:0] sna_psg_regs,
    output reg  [1:0]   sna_model,

    output reg          capture_ram_rd,
    output reg  [15:0]  capture_ram_word_addr,
    input  wire [15:0]  capture_ram_word_data,

    output wire [21:16] cram_a,
    inout  wire [15:0]  cram_dq,
    input  wire         cram_wait,
    output wire         cram_clk,
    output wire         cram_adv_n,
    output wire         cram_cre,
    output wire         cram_ce0_n,
    output wire         cram_ce1_n,
    output wire         cram_oe_n,
    output wire         cram_we_n,
    output wire         cram_ub_n,
    output wire         cram_lb_n,

    output wire [31:0]  debug_status,
    output wire [31:0]  debug_progress,
    output wire [31:0]  debug_addresses,
    output wire [31:0]  debug_bridge_flags,
    output reg  [31:0]  debug_last_load_word_raw,
    output reg  [31:0]  debug_last_load_word_norm,
    output reg  [31:0]  debug_load_header_word0,
    output reg  [31:0]  debug_load_header_word1,
    output reg  [31:0]  debug_save_readback_word0,
    output reg  [31:0]  debug_save_readback_word1,
    output reg  [31:0]  debug_save_readback_word2,
    output reg  [31:0]  debug_save_readback_word3,
    output reg  [31:0]  debug_bridge_prime_word0,
    output reg  [31:0]  debug_bridge_prime_word1,
    output reg  [31:0]  debug_bridge_host_write_count,
    output reg  [31:0]  debug_bridge_last_host_write,
    output wire         load_progress_active,
    output wire [15:0]  load_progress_words,
    output wire         load_progress_128k,
    output wire         load_progress_complete
);

localparam [31:0] SAVESTATE_ADDR         = 32'h4000_0000;
localparam [31:0] SNAPSHOT_MAGIC0        = 32'h4D56_202D; // "MV -"
localparam [31:0] SNAPSHOT_MAGIC1        = 32'h2053_4E41; // " SNA"
localparam [31:0] SNAPSHOT_HDR_BYTES     = 32'd256;
localparam [31:0] SNAPSHOT_HDR_WORDS     = 32'd64;
localparam [31:0] SNAPSHOT_SIZE_64K      = 32'd65792;
localparam [31:0] SNAPSHOT_SIZE_128K     = 32'd131328;
localparam [31:0] SNAPSHOT_WORDS_64K     = SNAPSHOT_SIZE_64K / 32'd4;
localparam [31:0] SNAPSHOT_WORDS_128K    = SNAPSHOT_SIZE_128K / 32'd4;
localparam [15:0] SNAPSHOT_WORDS_128K_16 = 16'd32832;
localparam [15:0] FRONT_BUFFER_WORDS     = 16'd256;

localparam [5:0]
    SAVE_IDLE          = 6'd0,
    SAVE_SETTLE        = 6'd1,
    SAVE_HEADER_REQ    = 6'd2,
    SAVE_HEADER_WAIT   = 6'd3,
    SAVE_RAM_REQ0      = 6'd4,
    SAVE_RAM_WAIT0     = 6'd5,
    SAVE_RAM_WAIT1     = 6'd6,
    SAVE_RAM_STORE_REQ = 6'd7,
    SAVE_RAM_STORE_SEND = 6'd8,
    SAVE_RAM_STORE_WAIT = 6'd9,
    SAVE_VERIFY_REQ0   = 6'd10,
    SAVE_VERIFY_WAIT0  = 6'd11,
    SAVE_VERIFY_REQ1   = 6'd12,
    SAVE_VERIFY_WAIT1  = 6'd13,
    SAVE_WAIT_FRAME    = 6'd14,
    LOAD_IDLE          = 6'd16,
    LOAD_WAIT_BLOB     = 6'd17,
    LOAD_BUFFER_REQ    = 6'd18,
    LOAD_BUFFER_WAIT   = 6'd19,
    LOAD_CAPTURE       = 6'd20,
    LOAD_RAM_LO        = 6'd21,
    LOAD_RAM_HI        = 6'd22,
    LOAD_COMMIT        = 6'd23,
    LOAD_APPLY_WAIT    = 6'd24,
    LOAD_FRONT_WAIT    = 6'd25,
    LOAD_FRONT_CAPTURE = 6'd26,
    LOAD_WAIT_FRAME    = 6'd27;

localparam [7:0]
    DBG_RESULT_NONE               = 8'd0,
    DBG_RESULT_SAVE_REJECTED      = 8'd1,
    DBG_RESULT_LOAD_REJECTED      = 8'd2,
    DBG_RESULT_LOAD_BAD_MAGIC     = 8'd3,
    DBG_RESULT_LOAD_BAD_VERSION   = 8'd4,
    DBG_RESULT_LOAD_COMMIT_FAILED = 8'd5,
    DBG_RESULT_LOAD_COMMIT_OK     = 8'd6,
    DBG_RESULT_SAVE_ACCEPTED      = 8'd7,
    DBG_RESULT_LOAD_ACCEPTED      = 8'd8,
    DBG_RESULT_LOAD_WAIT_SAFE     = 8'd9,
    DBG_RESULT_LOAD_WAIT_BLOB     = 8'd10,
    DBG_RESULT_SAVE_WAIT_FRAME    = 8'd11,
    DBG_RESULT_LOAD_WAIT_FRAME    = 8'd12;

localparam [3:0]
    MEM_IDLE          = 4'd0,
    MEM_READ_LO_REQ   = 4'd1,
    MEM_READ_LO_WAIT  = 4'd2,
    MEM_READ_HI_REQ   = 4'd3,
    MEM_READ_HI_WAIT  = 4'd4,
    MEM_WRITE_LO_REQ  = 4'd5,
    MEM_WRITE_LO_WAIT = 4'd6,
    MEM_WRITE_HI_REQ  = 4'd7,
    MEM_WRITE_HI_WAIT = 4'd8,
    MEM_COOLDOWN      = 4'd9;

localparam [4:0] BRIDGE_WRITE_QUEUE_DEPTH = 5'd16;
localparam [2:0] MEM_COOLDOWN_CYCLES     = 3'd3;
localparam [4:0] LOAD_READY_SETTLE_CYCLES = 5'd16;
localparam [23:0] FRAME_WAIT_TIMEOUT_CYCLES = 24'd4_000_000;

wire [15:0] bridge_word_addr = bridge_addr[17:2];
wire        bridge_addr_in_range =
    (bridge_addr[31:18] == SAVESTATE_ADDR[31:18]) &&
    (bridge_word_addr < SNAPSHOT_WORDS_128K_16);
wire        bridge_front_buffer_selected = (bridge_word_addr < FRONT_BUFFER_WORDS);
assign bridge_selected = bridge_addr_in_range;

reg        start_ack_cpc = 1'b0;
reg        start_busy_cpc = 1'b0;
reg        start_ok_cpc = 1'b0;
reg        start_err_cpc = 1'b0;
reg        load_ack_cpc = 1'b0;
reg        load_busy_cpc = 1'b0;
reg        load_ok_cpc = 1'b0;
reg        load_err_cpc = 1'b0;
wire       start_ack_sync;
wire       start_busy_sync;
wire       start_ok_sync;
wire       start_err_sync;
wire       load_ack_sync;
wire       load_busy_sync;
wire       load_ok_sync;
wire       load_err_sync;

reg        prev_savestate_start_cpc = 1'b0;
reg        prev_savestate_load_cpc = 1'b0;
wire       savestate_start_cpc;
wire       savestate_load_cpc;

reg  [5:0] save_state = SAVE_IDLE;
reg  [5:0] load_state = LOAD_IDLE;
reg  [31:0] save_word_index = 32'd0;
reg  [31:0] load_word_index = 32'd0;
reg  [1:0]  save_verify_index = 2'd0;
reg  [15:0] ram_capture_base = 16'd0;
reg  [15:0] load_ram_word_base = 16'd0;
reg  [15:0] saved_ram_word_lo = 16'd0;
reg  [31:0] load_word_buffer = 32'd0;
reg  [2:0]  load_apply_cnt = 3'd0;
reg         save_pending_when_safe = 1'b0;
reg  [4:0]  save_settle_count = 5'd0;
reg  [23:0] save_frame_timeout = 24'd0;
reg  [23:0] load_frame_timeout = 24'd0;
reg         load_header_ok = 1'b0;
reg         load_version_ok = 1'b0;
reg  [15:0] load_snapshot_mem_size_kb = 16'd64;
reg  [31:0] load_total_words = SNAPSHOT_WORDS_128K;
reg  [1:0]  load_word_swap_mode = 2'd0;
reg         load_word_swap_locked = 1'b0;
reg  [7:0]  debug_result = DBG_RESULT_NONE;
reg         load_waited_for_ready = 1'b0;
reg  [4:0]  load_ready_settle_count = 5'd0;
reg  [1:0]  save_hdr_model = 2'd0;
reg  [211:0] save_hdr_cpu_dir = 212'd0;
reg  [4:0]  save_hdr_crtc_addr = 5'd0;
reg  [143:0] save_hdr_crtc_regs = 144'd0;
reg  [63:0] save_hdr_crtc_v3 = 64'd0;
reg  [4:0]  save_hdr_ga_inksel = 5'd0;
reg  [135:0] save_hdr_ga_palette = 136'd0;
reg  [7:0]  save_hdr_ga_config = 8'd0;
reg  [7:0]  save_hdr_ga_vsync_delay = 8'd0;
reg  [7:0]  save_hdr_ga_int_scanline = 8'd0;
reg         save_hdr_ga_irq_active = 1'b0;
reg  [7:0]  save_hdr_ram_config = 8'd0;
reg  [7:0]  save_hdr_rom_select = 8'd0;
reg  [7:0]  save_hdr_ppi_a = 8'd0;
reg  [7:0]  save_hdr_ppi_b = 8'd0;
reg  [7:0]  save_hdr_ppi_c = 8'd0;
reg  [7:0]  save_hdr_ppi_control = 8'd0;
reg  [3:0]  save_hdr_psg_addr = 4'd0;
reg  [127:0] save_hdr_psg_regs = 128'd0;
reg  [15:0] save_hdr_mem_size_kb = 16'd64;
reg  [7:0]  save_hdr_machine_type = 8'd2;

reg         sram_req_valid_cpc = 1'b0;
reg  [48:0] sram_req_payload_cpc = 49'd0;
reg  [31:0] sram_resp_word_data_cpc = 32'd0;
reg         sram_resp_pulse_cpc = 1'b0;

reg  [48:0] sram_req_payload_bridge = 49'd0;
reg         sram_req_valid_bridge = 1'b0;
wire        sram_req_write_bridge = sram_req_payload_bridge[48];
wire [15:0] sram_req_word_addr_bridge = sram_req_payload_bridge[47:32];
wire [31:0] sram_req_word_data_bridge = sram_req_payload_bridge[31:0];
reg         sram_resp_valid_bridge = 1'b0;
reg  [31:0] sram_resp_word_data_bridge = 32'd0;
wire [48:0] sram_req_fifo_q;
wire        sram_req_fifo_empty;
reg         sram_req_fifo_rdreq = 1'b0;
reg  [1:0]  sram_req_fifo_state = 2'd0;
wire [31:0] sram_resp_fifo_q;
wire        sram_resp_fifo_empty;
reg         sram_resp_fifo_rdreq = 1'b0;
reg  [1:0]  sram_resp_fifo_state = 2'd0;
reg         start_ok_sync_d = 1'b0;
reg         load_busy_sync_d = 1'b0;

localparam [1:0]
    FIFO_READ_IDLE  = 2'd0,
    FIFO_READ_DELAY = 2'd1,
    FIFO_READ_LATCH = 2'd2;

reg  [3:0]  mem_state = MEM_IDLE;
reg         mem_source_cpc = 1'b0;
reg  [15:0] mem_word_addr = 16'd0;
reg  [31:0] mem_write_data = 32'd0;
reg  [15:0] mem_read_lo = 16'd0;
reg         mem_psram_busy_seen = 1'b0;
reg  [2:0]  mem_cooldown_count = 3'd0;
reg         bridge_read_active = 1'b0;
reg  [15:0] bridge_addr_seen = 16'd0;
reg         bridge_rd_d = 1'b0;
reg         bridge_wr_d = 1'b0;
reg  [15:0] bridge_word_addr_d = 16'd0;
reg  [15:0] bridge_export_addr = 16'd0;
reg  [31:0] bridge_export_data = 32'd0;
reg         bridge_export_valid = 1'b0;
reg         bridge_export_ready = 1'b0;
reg  [3:0]  bridge_wrq_head = 4'd0;
reg  [3:0]  bridge_wrq_tail = 4'd0;
reg  [4:0]  bridge_wrq_count = 5'd0;
reg  [15:0] bridge_wrq_addr [0:15];
reg  [31:0] bridge_wrq_data [0:15];
reg         front_buffer_cpc_wr = 1'b0;
reg  [7:0]  front_buffer_cpc_addr = 8'd0;
reg  [31:0] front_buffer_cpc_din = 32'd0;
wire [31:0] front_buffer_cpc_dout;
wire        front_buffer_bridge_wr =
    bridge_wr_step && bridge_front_buffer_selected;
wire        bridge_rd_step =
    bridge_rd && bridge_addr_in_range &&
    (!bridge_rd_d || (bridge_word_addr != bridge_word_addr_d));
wire        bridge_wr_step =
    bridge_wr && bridge_addr_in_range &&
    (!bridge_wr_d || (bridge_word_addr != bridge_word_addr_d));

reg  [21:0] psram_addr = 22'd0;
reg  [15:0] psram_data_in = 16'd0;
reg         psram_write_en = 1'b0;
reg         psram_read_en = 1'b0;
wire        psram_read_avail;
wire [15:0] psram_data_out;
wire        psram_busy;

assign bridge_rd_data = bridge_export_data;

wire [15:0] save_snapshot_mem_size_kb =
    (state_model == 2'd0) ? 16'd128 : 16'd64;
wire [31:0] save_snapshot_total_words =
    (state_model == 2'd0) ? SNAPSHOT_WORDS_128K : SNAPSHOT_WORDS_64K;
wire [7:0] save_snapshot_machine_type =
    (state_model == 2'd2) ? 8'd0 :
    (state_model == 2'd1) ? 8'd1 : 8'd2;

wire [31:0] load_buffer_word_byte_reversed = {
    load_word_buffer[7:0],
    load_word_buffer[15:8],
    load_word_buffer[23:16],
    load_word_buffer[31:24]
};
wire [31:0] load_buffer_word_halfword_swapped = {
    load_word_buffer[15:0],
    load_word_buffer[31:16]
};
wire [31:0] load_buffer_word_halfword_byte_reversed = {
    load_word_buffer[23:16],
    load_word_buffer[31:24],
    load_word_buffer[7:0],
    load_word_buffer[15:8]
};
wire [31:0] load_capture_word =
    (!load_word_swap_locked && (load_word_index == 32'd0)) ?
        (
            (load_buffer_word_byte_reversed == SNAPSHOT_MAGIC0) ? load_buffer_word_byte_reversed :
            (load_buffer_word_halfword_swapped == SNAPSHOT_MAGIC0) ? load_buffer_word_halfword_swapped :
            (load_buffer_word_halfword_byte_reversed == SNAPSHOT_MAGIC0) ? load_buffer_word_halfword_byte_reversed :
            load_word_buffer
        ) :
        (
            (load_word_swap_mode == 2'd1) ? load_buffer_word_byte_reversed :
            (load_word_swap_mode == 2'd2) ? load_buffer_word_halfword_swapped :
            (load_word_swap_mode == 2'd3) ? load_buffer_word_halfword_byte_reversed :
            load_word_buffer
        );

// Sleep wake can request load before PocketCPC has finished its runtime
// data-slot bootstrap. Accept the APF command, drain the Pocket-written blob,
// then copy RAM immediately. Only the final SNA register/state apply waits for
// CPC-side ROM/data-slot gates, so boot asset loading overlaps the heavy copy.
wire       load_waiting_for_blob_cpc = (load_state == LOAD_WAIT_BLOB);
wire       load_waiting_for_blob_bridge;
wire       load_blob_ready_bridge =
    (bridge_wrq_count == 5'd0) &&
    (mem_state == MEM_IDLE) &&
    !bridge_wr_step;
wire       load_blob_ready_cpc;
wire       bridge_can_drain_host_writes =
    !start_busy_sync &&
    (!load_busy_sync || load_waiting_for_blob_bridge);
wire [15:0] bridge_host_write_count_cpc;
wire [15:0] load_progress_word_count =
    (bridge_host_write_count_cpc > load_word_index[15:0]) ?
    bridge_host_write_count_cpc :
    load_word_index[15:0];

assign debug_status = {18'd0, ((save_state != SAVE_IDLE) ? save_state : load_state), debug_result};
assign debug_progress = {save_word_index[15:0], load_word_index[9:0], load_state};
assign debug_addresses = {
    13'd0,
    (save_state != SAVE_IDLE),
    (load_state != LOAD_IDLE),
    load_err_cpc,
    load_ok_cpc,
    load_busy_cpc,
    start_err_cpc,
    start_ok_cpc,
    start_busy_cpc,
    load_safe,
    save_safe,
    custom_rom_enable,
    load_waited_for_ready,
    load_version_ok,
    load_header_ok,
    load_word_swap_locked,
    load_word_swap_mode[0],
    load_word_swap_mode[1],
    snapshot_busy_reset,
    freeze_cpu
};
assign debug_bridge_flags = {
    bridge_addr_seen,
    bridge_export_addr[7:0],
    mem_state,
    bridge_export_valid,
    bridge_read_active,
    bridge_export_ready,
    load_busy_sync
};
assign load_progress_active = load_busy_cpc;
assign load_progress_words = load_progress_word_count;
assign load_progress_128k = (load_total_words > SNAPSHOT_WORDS_64K);
assign load_progress_complete =
    (load_state == LOAD_APPLY_WAIT) ||
    (load_state == LOAD_WAIT_FRAME) ||
    (load_state == LOAD_COMMIT && load_header_ok && load_version_ok && load_safe);

function automatic [7:0] snapshot_header_byte;
    input [7:0]  index;
    input [1:0]  state_model_arg;
    input [211:0] state_cpu_dir_arg;
    input [4:0]  state_crtc_addr_arg;
    input [143:0] state_crtc_regs_arg;
    input [4:0]  state_ga_inksel_arg;
    input [135:0] state_ga_palette_arg;
    input [7:0]  state_ga_config_arg;
    input [7:0]  state_ram_config_arg;
    input [7:0]  state_rom_select_arg;
    input [7:0]  state_ppi_a_arg;
    input [7:0]  state_ppi_b_arg;
    input [7:0]  state_ppi_c_arg;
    input [7:0]  state_ppi_control_arg;
    input [3:0]  state_psg_addr_arg;
    input [127:0] state_psg_regs_arg;
    input [15:0] snapshot_mem_size_kb_arg;
    input [7:0]  snapshot_machine_type_arg;
    begin
        case (index)
            8'h00: snapshot_header_byte = "M";
            8'h01: snapshot_header_byte = "V";
            8'h02: snapshot_header_byte = " ";
            8'h03: snapshot_header_byte = "-";
            8'h04: snapshot_header_byte = " ";
            8'h05: snapshot_header_byte = "S";
            8'h06: snapshot_header_byte = "N";
            8'h07: snapshot_header_byte = "A";
            8'h10: snapshot_header_byte = 8'd3;
            8'h11: snapshot_header_byte = state_cpu_dir_arg[15:8];
            8'h12: snapshot_header_byte = state_cpu_dir_arg[7:0];
            8'h13: snapshot_header_byte = state_cpu_dir_arg[87:80];
            8'h14: snapshot_header_byte = state_cpu_dir_arg[95:88];
            8'h15: snapshot_header_byte = state_cpu_dir_arg[103:96];
            8'h16: snapshot_header_byte = state_cpu_dir_arg[111:104];
            8'h17: snapshot_header_byte = state_cpu_dir_arg[119:112];
            8'h18: snapshot_header_byte = state_cpu_dir_arg[127:120];
            8'h19: snapshot_header_byte = state_cpu_dir_arg[47:40];
            8'h1a: snapshot_header_byte = state_cpu_dir_arg[39:32];
            8'h1b: snapshot_header_byte = {7'd0, state_cpu_dir_arg[210]};
            8'h1c: snapshot_header_byte = {7'd0, state_cpu_dir_arg[211]};
            8'h1d: snapshot_header_byte = state_cpu_dir_arg[135:128];
            8'h1e: snapshot_header_byte = state_cpu_dir_arg[143:136];
            8'h1f: snapshot_header_byte = state_cpu_dir_arg[199:192];
            8'h20: snapshot_header_byte = state_cpu_dir_arg[207:200];
            8'h21: snapshot_header_byte = state_cpu_dir_arg[55:48];
            8'h22: snapshot_header_byte = state_cpu_dir_arg[63:56];
            8'h23: snapshot_header_byte = state_cpu_dir_arg[71:64];
            8'h24: snapshot_header_byte = state_cpu_dir_arg[79:72];
            8'h25: snapshot_header_byte = {6'd0, state_cpu_dir_arg[209:208]};
            8'h26: snapshot_header_byte = state_cpu_dir_arg[31:24];
            8'h27: snapshot_header_byte = state_cpu_dir_arg[23:16];
            8'h28: snapshot_header_byte = state_cpu_dir_arg[151:144];
            8'h29: snapshot_header_byte = state_cpu_dir_arg[159:152];
            8'h2a: snapshot_header_byte = state_cpu_dir_arg[167:160];
            8'h2b: snapshot_header_byte = state_cpu_dir_arg[175:168];
            8'h2c: snapshot_header_byte = state_cpu_dir_arg[183:176];
            8'h2d: snapshot_header_byte = state_cpu_dir_arg[191:184];
            8'h2e: snapshot_header_byte = {3'd0, state_ga_inksel_arg};
            8'h2f: snapshot_header_byte = state_ga_palette_arg[7:0];
            8'h30: snapshot_header_byte = state_ga_palette_arg[15:8];
            8'h31: snapshot_header_byte = state_ga_palette_arg[23:16];
            8'h32: snapshot_header_byte = state_ga_palette_arg[31:24];
            8'h33: snapshot_header_byte = state_ga_palette_arg[39:32];
            8'h34: snapshot_header_byte = state_ga_palette_arg[47:40];
            8'h35: snapshot_header_byte = state_ga_palette_arg[55:48];
            8'h36: snapshot_header_byte = state_ga_palette_arg[63:56];
            8'h37: snapshot_header_byte = state_ga_palette_arg[71:64];
            8'h38: snapshot_header_byte = state_ga_palette_arg[79:72];
            8'h39: snapshot_header_byte = state_ga_palette_arg[87:80];
            8'h3a: snapshot_header_byte = state_ga_palette_arg[95:88];
            8'h3b: snapshot_header_byte = state_ga_palette_arg[103:96];
            8'h3c: snapshot_header_byte = state_ga_palette_arg[111:104];
            8'h3d: snapshot_header_byte = state_ga_palette_arg[119:112];
            8'h3e: snapshot_header_byte = state_ga_palette_arg[127:120];
            8'h3f: snapshot_header_byte = state_ga_palette_arg[135:128];
            8'h40: snapshot_header_byte = state_ga_config_arg;
            8'h41: snapshot_header_byte = state_ram_config_arg;
            8'h42: snapshot_header_byte = {3'd0, state_crtc_addr_arg};
            8'h43: snapshot_header_byte = state_crtc_regs_arg[7:0];
            8'h44: snapshot_header_byte = state_crtc_regs_arg[15:8];
            8'h45: snapshot_header_byte = state_crtc_regs_arg[23:16];
            8'h46: snapshot_header_byte = state_crtc_regs_arg[31:24];
            8'h47: snapshot_header_byte = state_crtc_regs_arg[39:32];
            8'h48: snapshot_header_byte = state_crtc_regs_arg[47:40];
            8'h49: snapshot_header_byte = state_crtc_regs_arg[55:48];
            8'h4a: snapshot_header_byte = state_crtc_regs_arg[63:56];
            8'h4b: snapshot_header_byte = state_crtc_regs_arg[71:64];
            8'h4c: snapshot_header_byte = state_crtc_regs_arg[79:72];
            8'h4d: snapshot_header_byte = state_crtc_regs_arg[87:80];
            8'h4e: snapshot_header_byte = state_crtc_regs_arg[95:88];
            8'h4f: snapshot_header_byte = state_crtc_regs_arg[103:96];
            8'h50: snapshot_header_byte = state_crtc_regs_arg[111:104];
            8'h51: snapshot_header_byte = state_crtc_regs_arg[119:112];
            8'h52: snapshot_header_byte = state_crtc_regs_arg[127:120];
            8'h53: snapshot_header_byte = state_crtc_regs_arg[135:128];
            8'h54: snapshot_header_byte = state_crtc_regs_arg[143:136];
            8'h55: snapshot_header_byte = state_rom_select_arg;
            8'h56: snapshot_header_byte = state_ppi_a_arg;
            8'h57: snapshot_header_byte = state_ppi_b_arg;
            8'h58: snapshot_header_byte = state_ppi_c_arg;
            8'h59: snapshot_header_byte = state_ppi_control_arg;
            8'h5a: snapshot_header_byte = {4'd0, state_psg_addr_arg};
            8'h5b: snapshot_header_byte = state_psg_regs_arg[7:0];
            8'h5c: snapshot_header_byte = state_psg_regs_arg[15:8];
            8'h5d: snapshot_header_byte = state_psg_regs_arg[23:16];
            8'h5e: snapshot_header_byte = state_psg_regs_arg[31:24];
            8'h5f: snapshot_header_byte = state_psg_regs_arg[39:32];
            8'h60: snapshot_header_byte = state_psg_regs_arg[47:40];
            8'h61: snapshot_header_byte = state_psg_regs_arg[55:48];
            8'h62: snapshot_header_byte = state_psg_regs_arg[63:56];
            8'h63: snapshot_header_byte = state_psg_regs_arg[71:64];
            8'h64: snapshot_header_byte = state_psg_regs_arg[79:72];
            8'h65: snapshot_header_byte = state_psg_regs_arg[87:80];
            8'h66: snapshot_header_byte = state_psg_regs_arg[95:88];
            8'h67: snapshot_header_byte = state_psg_regs_arg[103:96];
            8'h68: snapshot_header_byte = state_psg_regs_arg[111:104];
            8'h69: snapshot_header_byte = state_psg_regs_arg[119:112];
            8'h6a: snapshot_header_byte = state_psg_regs_arg[127:120];
            8'h6b: snapshot_header_byte = snapshot_mem_size_kb_arg[7:0];
            8'h6c: snapshot_header_byte = snapshot_mem_size_kb_arg[15:8];
            8'h6d: snapshot_header_byte = snapshot_machine_type_arg;
            8'h9c: snapshot_header_byte = 8'd0;
            8'ha4: snapshot_header_byte = 8'd1;
            8'ha9: snapshot_header_byte = save_hdr_crtc_v3[7:0];
            8'haa: snapshot_header_byte = 8'd0;
            8'hab: snapshot_header_byte = save_hdr_crtc_v3[15:8];
            8'hac: snapshot_header_byte = save_hdr_crtc_v3[23:16];
            8'had: snapshot_header_byte = save_hdr_crtc_v3[31:24];
            8'hae: snapshot_header_byte = save_hdr_crtc_v3[39:32];
            8'haf: snapshot_header_byte = save_hdr_crtc_v3[47:40];
            8'hb0: snapshot_header_byte = save_hdr_crtc_v3[55:48];
            8'hb1: snapshot_header_byte = save_hdr_crtc_v3[63:56];
            8'hb2: snapshot_header_byte = save_hdr_ga_vsync_delay;
            8'hb3: snapshot_header_byte = save_hdr_ga_int_scanline;
            8'hb4: snapshot_header_byte = {7'd0, save_hdr_ga_irq_active};
            default: snapshot_header_byte = 8'd0;
        endcase
    end
endfunction

function automatic [31:0] snapshot_header_word;
    input [7:0]  base_index;
    input [1:0]  state_model_arg;
    input [211:0] state_cpu_dir_arg;
    input [4:0]  state_crtc_addr_arg;
    input [143:0] state_crtc_regs_arg;
    input [4:0]  state_ga_inksel_arg;
    input [135:0] state_ga_palette_arg;
    input [7:0]  state_ga_config_arg;
    input [7:0]  state_ram_config_arg;
    input [7:0]  state_rom_select_arg;
    input [7:0]  state_ppi_a_arg;
    input [7:0]  state_ppi_b_arg;
    input [7:0]  state_ppi_c_arg;
    input [7:0]  state_ppi_control_arg;
    input [3:0]  state_psg_addr_arg;
    input [127:0] state_psg_regs_arg;
    input [15:0] snapshot_mem_size_kb_arg;
    input [7:0]  snapshot_machine_type_arg;
    begin
        snapshot_header_word = {
            snapshot_header_byte(base_index + 8'd0, state_model_arg, state_cpu_dir_arg, state_crtc_addr_arg, state_crtc_regs_arg, state_ga_inksel_arg, state_ga_palette_arg, state_ga_config_arg, state_ram_config_arg, state_rom_select_arg, state_ppi_a_arg, state_ppi_b_arg, state_ppi_c_arg, state_ppi_control_arg, state_psg_addr_arg, state_psg_regs_arg, snapshot_mem_size_kb_arg, snapshot_machine_type_arg),
            snapshot_header_byte(base_index + 8'd1, state_model_arg, state_cpu_dir_arg, state_crtc_addr_arg, state_crtc_regs_arg, state_ga_inksel_arg, state_ga_palette_arg, state_ga_config_arg, state_ram_config_arg, state_rom_select_arg, state_ppi_a_arg, state_ppi_b_arg, state_ppi_c_arg, state_ppi_control_arg, state_psg_addr_arg, state_psg_regs_arg, snapshot_mem_size_kb_arg, snapshot_machine_type_arg),
            snapshot_header_byte(base_index + 8'd2, state_model_arg, state_cpu_dir_arg, state_crtc_addr_arg, state_crtc_regs_arg, state_ga_inksel_arg, state_ga_palette_arg, state_ga_config_arg, state_ram_config_arg, state_rom_select_arg, state_ppi_a_arg, state_ppi_b_arg, state_ppi_c_arg, state_ppi_control_arg, state_psg_addr_arg, state_psg_regs_arg, snapshot_mem_size_kb_arg, snapshot_machine_type_arg),
            snapshot_header_byte(base_index + 8'd3, state_model_arg, state_cpu_dir_arg, state_crtc_addr_arg, state_crtc_regs_arg, state_ga_inksel_arg, state_ga_palette_arg, state_ga_config_arg, state_ram_config_arg, state_rom_select_arg, state_ppi_a_arg, state_ppi_b_arg, state_ppi_c_arg, state_ppi_control_arg, state_psg_addr_arg, state_psg_regs_arg, snapshot_mem_size_kb_arg, snapshot_machine_type_arg)
        };
    end
endfunction

task automatic apply_snapshot_header_byte;
    input [7:0] byte_addr;
    input [7:0] byte_value;
    begin
        case (byte_addr)
            8'h10: sna_crtc_v3_valid    <= (byte_value == 8'd3);
            8'h11: sna_cpu_dir[15:8]    <= byte_value;
            8'h12: sna_cpu_dir[7:0]     <= byte_value;
            8'h13: sna_cpu_dir[87:80]   <= byte_value;
            8'h14: sna_cpu_dir[95:88]   <= byte_value;
            8'h15: sna_cpu_dir[103:96]  <= byte_value;
            8'h16: sna_cpu_dir[111:104] <= byte_value;
            8'h17: sna_cpu_dir[119:112] <= byte_value;
            8'h18: sna_cpu_dir[127:120] <= byte_value;
            8'h19: sna_cpu_dir[47:40]   <= byte_value;
            8'h1a: sna_cpu_dir[39:32]   <= byte_value;
            8'h1b: sna_cpu_dir[210]     <= byte_value[0];
            8'h1c: sna_cpu_dir[211]     <= byte_value[0];
            8'h1d: sna_cpu_dir[135:128] <= byte_value;
            8'h1e: sna_cpu_dir[143:136] <= byte_value;
            8'h1f: sna_cpu_dir[199:192] <= byte_value;
            8'h20: sna_cpu_dir[207:200] <= byte_value;
            8'h21: sna_cpu_dir[55:48]   <= byte_value;
            8'h22: sna_cpu_dir[63:56]   <= byte_value;
            8'h23: sna_cpu_dir[71:64]   <= byte_value;
            8'h24: sna_cpu_dir[79:72]   <= byte_value;
            8'h25: sna_cpu_dir[209:208] <= byte_value[1:0];
            8'h26: sna_cpu_dir[31:24]   <= byte_value;
            8'h27: sna_cpu_dir[23:16]   <= byte_value;
            8'h28: sna_cpu_dir[151:144] <= byte_value;
            8'h29: sna_cpu_dir[159:152] <= byte_value;
            8'h2a: sna_cpu_dir[167:160] <= byte_value;
            8'h2b: sna_cpu_dir[175:168] <= byte_value;
            8'h2c: sna_cpu_dir[183:176] <= byte_value;
            8'h2d: sna_cpu_dir[191:184] <= byte_value;
            8'h2e: sna_ga_inksel        <= byte_value[4:0];
            8'h40: sna_ga_config        <= byte_value;
            8'h41: sna_ram_config       <= byte_value;
            8'h42: sna_crtc_addr        <= byte_value[4:0];
            8'h55: sna_rom_select       <= byte_value;
            8'h56: sna_ppi_a            <= byte_value;
            8'h57: sna_ppi_b            <= byte_value;
            8'h58: sna_ppi_c            <= byte_value;
            8'h59: sna_ppi_control      <= byte_value;
            8'h5a: sna_psg_addr         <= byte_value[3:0];
            8'h6b: load_snapshot_mem_size_kb[7:0] <= byte_value;
            8'h6c: begin
                load_snapshot_mem_size_kb[15:8] <= byte_value;
                if ({byte_value, load_snapshot_mem_size_kb[7:0]} > 16'd64) begin
                    sna_model <= 2'd0;
                end else if (sna_cpu_dir[79:64] == 16'h0038) begin
                    sna_model <= 2'd2;
                end
            end
            8'h6d: begin
                if (load_snapshot_mem_size_kb > 16'd64) begin
                    sna_model <= 2'd0;
                end else begin
                    case (byte_value)
                        8'd0: sna_model <= 2'd2;
                        8'd1: sna_model <= 2'd1;
                        8'd2, 8'd4, 8'd6: sna_model <= 2'd0;
                        default: begin end
                    endcase
                end
            end
            8'ha9: sna_crtc_v3[7:0]     <= byte_value;
            8'hab: sna_crtc_v3[15:8]    <= byte_value;
            8'hac: sna_crtc_v3[23:16]   <= byte_value;
            8'had: sna_crtc_v3[31:24]   <= byte_value;
            8'hae: sna_crtc_v3[39:32]   <= byte_value;
            8'haf: sna_crtc_v3[47:40]   <= byte_value;
            8'hb0: sna_crtc_v3[55:48]   <= byte_value;
            8'hb1: sna_crtc_v3[63:56]   <= byte_value;
            8'hb2: sna_ga_vsync_delay   <= byte_value;
            8'hb3: sna_ga_int_scanline  <= byte_value;
            8'hb4: sna_ga_irq_active    <= byte_value[0];
            default: begin end
        endcase

        if ((byte_addr >= 8'h2f) && (byte_addr <= 8'h3f)) begin
            sna_ga_palette[((byte_addr - 8'h2f) * 8) +: 8] <= byte_value;
        end
        if ((byte_addr >= 8'h43) && (byte_addr <= 8'h54)) begin
            sna_crtc_regs[((byte_addr - 8'h43) * 8) +: 8] <= byte_value;
        end
        if ((byte_addr >= 8'h5b) && (byte_addr <= 8'h6a)) begin
            sna_psg_regs[((byte_addr - 8'h5b) * 8) +: 8] <= byte_value;
        end
    end
endtask

synch_3 #(
    .WIDTH(2)
) savestate_in_sync (
    .i   ( {savestate_load, savestate_start} ),
    .o   ( {savestate_load_cpc, savestate_start_cpc} ),
    .clk ( clk ),
    .rise( ),
    .fall( )
);

synch_3 #(
    .WIDTH(8)
) savestate_out_sync (
    .i   ( {
        load_err_cpc,
        load_ok_cpc,
        load_busy_cpc,
        load_ack_cpc,
        start_err_cpc,
        start_ok_cpc,
        start_busy_cpc,
        start_ack_cpc
    } ),
    .o   ( {
        load_err_sync,
        load_ok_sync,
        load_busy_sync,
        load_ack_sync,
        start_err_sync,
        start_ok_sync,
        start_busy_sync,
        start_ack_sync
    } ),
    .clk ( bridge_clk ),
    .rise( ),
    .fall( )
);

synch_3 load_waiting_for_blob_sync (
    .i   ( load_waiting_for_blob_cpc ),
    .o   ( load_waiting_for_blob_bridge ),
    .clk ( bridge_clk ),
    .rise( ),
    .fall( )
);

synch_3 load_blob_ready_sync (
    .i   ( load_blob_ready_bridge ),
    .o   ( load_blob_ready_cpc ),
    .clk ( clk ),
    .rise( ),
    .fall( )
);

synch_3 #(
    .WIDTH(16)
) bridge_host_write_count_sync (
    .i   ( debug_bridge_host_write_count[15:0] ),
    .o   ( bridge_host_write_count_cpc ),
    .clk ( clk ),
    .rise( ),
    .fall( )
);

dcfifo sram_req_fifo (
    .data      ( sram_req_payload_cpc ),
    .rdclk     ( bridge_clk ),
    .rdreq     ( sram_req_fifo_rdreq ),
    .wrclk     ( clk ),
    .wrreq     ( sram_req_valid_cpc ),
    .q         ( sram_req_fifo_q ),
    .rdempty   ( sram_req_fifo_empty ),
    .aclr      ( ~reset_n ),
    .eccstatus ( ),
    .rdfull    ( ),
    .rdusedw   ( ),
    .wrempty   ( ),
    .wrfull    ( ),
    .wrusedw   ( )
);
defparam
    sram_req_fifo.intended_device_family = "Cyclone V",
    sram_req_fifo.lpm_numwords = 4,
    sram_req_fifo.lpm_showahead = "OFF",
    sram_req_fifo.lpm_type = "dcfifo",
    sram_req_fifo.lpm_width = 49,
    sram_req_fifo.lpm_widthu = 2,
    sram_req_fifo.overflow_checking = "ON",
    sram_req_fifo.rdsync_delaypipe = 5,
    sram_req_fifo.underflow_checking = "ON",
    sram_req_fifo.use_eab = "ON",
    sram_req_fifo.wrsync_delaypipe = 5;

dcfifo sram_resp_fifo (
    .data      ( sram_resp_word_data_bridge ),
    .rdclk     ( clk ),
    .rdreq     ( sram_resp_fifo_rdreq ),
    .wrclk     ( bridge_clk ),
    .wrreq     ( sram_resp_valid_bridge ),
    .q         ( sram_resp_fifo_q ),
    .rdempty   ( sram_resp_fifo_empty ),
    .aclr      ( ~reset_n ),
    .eccstatus ( ),
    .rdfull    ( ),
    .rdusedw   ( ),
    .wrempty   ( ),
    .wrfull    ( ),
    .wrusedw   ( )
);
defparam
    sram_resp_fifo.intended_device_family = "Cyclone V",
    sram_resp_fifo.lpm_numwords = 4,
    sram_resp_fifo.lpm_showahead = "OFF",
    sram_resp_fifo.lpm_type = "dcfifo",
    sram_resp_fifo.lpm_width = 32,
    sram_resp_fifo.lpm_widthu = 2,
    sram_resp_fifo.overflow_checking = "ON",
    sram_resp_fifo.rdsync_delaypipe = 5,
    sram_resp_fifo.underflow_checking = "ON",
    sram_resp_fifo.use_eab = "ON",
    sram_resp_fifo.wrsync_delaypipe = 5;

dpram_dc_async #(
    .DATAWIDTH(32),
    .ADDRWIDTH(8),
    .NUMWORDS(256)
) savestate_front_buffer (
    .clock_a   ( bridge_clk ),
    .address_a ( bridge_word_addr[7:0] ),
    .data_a    ( bridge_wr_data ),
    .wren_a    ( front_buffer_bridge_wr ),
    .q_a       ( ),

    .clock_b   ( clk ),
    .address_b ( front_buffer_cpc_addr ),
    .data_b    ( front_buffer_cpc_din ),
    .wren_b    ( front_buffer_cpc_wr ),
    .q_b       ( front_buffer_cpc_dout )
);

psram #(
    .CLOCK_SPEED(74.25)
) savestate_psram (
    .clk             ( bridge_clk ),
    .bank_sel        ( 1'b0 ),
    .addr            ( psram_addr ),
    .write_en        ( psram_write_en ),
    .data_in         ( psram_data_in ),
    .write_high_byte ( 1'b1 ),
    .write_low_byte  ( 1'b1 ),
    .read_en         ( psram_read_en ),
    .read_avail      ( psram_read_avail ),
    .data_out        ( psram_data_out ),
    .busy            ( psram_busy ),
    .cram_a          ( cram_a ),
    .cram_dq         ( cram_dq ),
    .cram_wait       ( cram_wait ),
    .cram_clk        ( cram_clk ),
    .cram_adv_n      ( cram_adv_n ),
    .cram_cre        ( cram_cre ),
    .cram_ce0_n      ( cram_ce0_n ),
    .cram_ce1_n      ( cram_ce1_n ),
    .cram_oe_n       ( cram_oe_n ),
    .cram_we_n       ( cram_we_n ),
    .cram_ub_n       ( cram_ub_n ),
    .cram_lb_n       ( cram_lb_n )
);

assign savestate_start_ack_s  = start_ack_sync;
assign savestate_start_busy_s = start_busy_sync | (start_ok_sync & !bridge_export_ready);
assign savestate_start_ok_s   = start_ok_sync & bridge_export_ready;
assign savestate_start_err_s  = start_err_sync;
assign savestate_load_ack_s   = load_ack_sync;
assign savestate_load_busy_s  = load_busy_sync;
assign savestate_load_ok_s    = load_ok_sync;
assign savestate_load_err_s   = load_err_sync;

always @(posedge bridge_clk or negedge reset_n) begin
    if (!reset_n) begin
        debug_bridge_host_write_count <= 32'd0;
        debug_bridge_last_host_write  <= 32'd0;
        psram_addr                    <= 22'd0;
        psram_data_in                 <= 16'd0;
        psram_write_en                <= 1'b0;
        psram_read_en                 <= 1'b0;
        sram_req_fifo_rdreq           <= 1'b0;
        sram_req_fifo_state           <= FIFO_READ_IDLE;
        sram_req_payload_bridge       <= 49'd0;
        sram_req_valid_bridge         <= 1'b0;
        sram_resp_valid_bridge        <= 1'b0;
        sram_resp_word_data_bridge    <= 32'd0;
        start_ok_sync_d               <= 1'b0;
        load_busy_sync_d              <= 1'b0;
        mem_state                     <= MEM_IDLE;
        mem_source_cpc                <= 1'b0;
        mem_word_addr                 <= 16'd0;
        mem_write_data                <= 32'd0;
        mem_read_lo                   <= 16'd0;
        mem_psram_busy_seen           <= 1'b0;
        mem_cooldown_count            <= 3'd0;
        bridge_read_active            <= 1'b0;
        bridge_addr_seen              <= 16'd0;
        bridge_rd_d                   <= 1'b0;
        bridge_wr_d                   <= 1'b0;
        bridge_word_addr_d            <= 16'd0;
        bridge_export_addr            <= 16'd0;
        bridge_export_data            <= 32'd0;
        bridge_export_valid           <= 1'b0;
        bridge_export_ready           <= 1'b0;
        bridge_wrq_head               <= 4'd0;
        bridge_wrq_tail               <= 4'd0;
        bridge_wrq_count              <= 5'd0;
    end else begin
        psram_addr     <= 22'd0;
        psram_data_in  <= 16'd0;
        psram_write_en <= 1'b0;
        psram_read_en  <= 1'b0;
        sram_req_fifo_rdreq    <= 1'b0;
        sram_req_valid_bridge  <= 1'b0;
        sram_resp_valid_bridge <= 1'b0;
        bridge_rd_d <= bridge_rd;
        bridge_wr_d <= bridge_wr;
        bridge_word_addr_d <= bridge_word_addr;

        case (sram_req_fifo_state)
            FIFO_READ_IDLE: begin
                if (!sram_req_fifo_empty) begin
                    sram_req_fifo_rdreq <= 1'b1;
                    sram_req_fifo_state <= FIFO_READ_DELAY;
                end
            end
            FIFO_READ_DELAY: begin
                sram_req_fifo_state <= FIFO_READ_LATCH;
            end
            FIFO_READ_LATCH: begin
                sram_req_payload_bridge <= sram_req_fifo_q;
                sram_req_valid_bridge   <= 1'b1;
                sram_req_fifo_state     <= FIFO_READ_IDLE;
            end
            default: begin
                sram_req_fifo_state <= FIFO_READ_IDLE;
            end
        endcase

        start_ok_sync_d   <= start_ok_sync;
        load_busy_sync_d <= load_busy_sync;

        if (!start_ok_sync) begin
            bridge_export_valid <= 1'b0;
            bridge_export_ready <= 1'b0;
        end

        if (start_ok_sync && !start_ok_sync_d) begin
            bridge_export_addr       <= 16'd0;
            bridge_export_data       <= 32'd0;
            bridge_export_valid      <= 1'b0;
            bridge_read_active       <= 1'b0;
            bridge_export_ready      <= 1'b1;
            debug_bridge_prime_word0 <= snapshot_header_word(
                                            8'd0,
                                            save_hdr_model,
                                            save_hdr_cpu_dir,
                                            save_hdr_crtc_addr,
                                            save_hdr_crtc_regs,
                                            save_hdr_ga_inksel,
                                            save_hdr_ga_palette,
                                            save_hdr_ga_config,
                                            save_hdr_ram_config,
                                            save_hdr_rom_select,
                                            save_hdr_ppi_a,
                                            save_hdr_ppi_b,
                                            save_hdr_ppi_c,
                                            save_hdr_ppi_control,
                                            save_hdr_psg_addr,
                                            save_hdr_psg_regs,
                                            save_hdr_mem_size_kb,
                                            save_hdr_machine_type
                                        );
            debug_bridge_prime_word1 <= snapshot_header_word(
                                            8'd4,
                                            save_hdr_model,
                                            save_hdr_cpu_dir,
                                            save_hdr_crtc_addr,
                                            save_hdr_crtc_regs,
                                            save_hdr_ga_inksel,
                                            save_hdr_ga_palette,
                                            save_hdr_ga_config,
                                            save_hdr_ram_config,
                                            save_hdr_rom_select,
                                            save_hdr_ppi_a,
                                            save_hdr_ppi_b,
                                            save_hdr_ppi_c,
                                            save_hdr_ppi_control,
                                            save_hdr_psg_addr,
                                            save_hdr_psg_regs,
                                            save_hdr_mem_size_kb,
                                            save_hdr_machine_type
                                        );
        end

        if (load_busy_sync && !load_busy_sync_d) begin
            debug_bridge_host_write_count <= 32'd0;
        end

        bridge_addr_seen <= bridge_word_addr;

        if (bridge_wr_step) begin
            if (bridge_word_addr == 16'd0) begin
                debug_bridge_host_write_count <= 32'd1;
            end else begin
                debug_bridge_host_write_count <= debug_bridge_host_write_count + 32'd1;
            end
            if (bridge_wrq_count < BRIDGE_WRITE_QUEUE_DEPTH) begin
                bridge_wrq_addr[bridge_wrq_tail] <= bridge_word_addr;
                bridge_wrq_data[bridge_wrq_tail] <= bridge_wr_data;
                bridge_wrq_tail                  <= bridge_wrq_tail + 4'd1;
                bridge_wrq_count                 <= bridge_wrq_count + 5'd1;
            end
            bridge_read_active <= 1'b0;
            bridge_export_valid <= 1'b0;
            debug_bridge_last_host_write <= {bridge_word_addr, bridge_wr_data[15:0]};
        end

        case (mem_state)
            MEM_IDLE: begin
                if (sram_req_valid_bridge) begin
                    mem_source_cpc              <= 1'b1;
                    mem_word_addr               <= sram_req_word_addr_bridge;
                    mem_write_data              <= sram_req_word_data_bridge;
                    mem_state                   <= sram_req_write_bridge ? MEM_WRITE_LO_REQ : MEM_READ_LO_REQ;
                    mem_psram_busy_seen         <= 1'b0;
                    if (sram_req_write_bridge) begin
                        bridge_export_valid <= 1'b0;
                        bridge_read_active  <= 1'b0;
                    end
                end else if ((bridge_wrq_count != 5'd0) &&
                             bridge_can_drain_host_writes) begin
                    mem_source_cpc      <= 1'b0;
                    mem_word_addr       <= bridge_wrq_addr[bridge_wrq_head];
                    mem_write_data      <= bridge_wrq_data[bridge_wrq_head];
                    mem_state           <= MEM_WRITE_LO_REQ;
                    mem_psram_busy_seen <= 1'b0;
                    bridge_wrq_head     <= bridge_wrq_head + 4'd1;
                    bridge_wrq_count    <= bridge_wrq_count - 5'd1;
                end else if (!start_busy_sync && !load_busy_sync) begin
                    if (bridge_rd_step) begin
                        if (bridge_word_addr < SNAPSHOT_HDR_WORDS[15:0]) begin
                            bridge_export_addr  <= bridge_word_addr;
                            bridge_export_data  <= snapshot_header_word(
                                                     bridge_word_addr[7:0] << 2,
                                                     save_hdr_model,
                                                     save_hdr_cpu_dir,
                                                     save_hdr_crtc_addr,
                                                     save_hdr_crtc_regs,
                                                     save_hdr_ga_inksel,
                                                     save_hdr_ga_palette,
                                                     save_hdr_ga_config,
                                                     save_hdr_ram_config,
                                                     save_hdr_rom_select,
                                                     save_hdr_ppi_a,
                                                     save_hdr_ppi_b,
                                                     save_hdr_ppi_c,
                                                     save_hdr_ppi_control,
                                                     save_hdr_psg_addr,
                                                     save_hdr_psg_regs,
                                                     save_hdr_mem_size_kb,
                                                     save_hdr_machine_type
                                                 );
                            bridge_export_valid <= 1'b1;

                            if (bridge_word_addr == 16'd0) begin
                                debug_bridge_prime_word0 <= snapshot_header_word(
                                    8'd0,
                                    save_hdr_model,
                                    save_hdr_cpu_dir,
                                    save_hdr_crtc_addr,
                                    save_hdr_crtc_regs,
                                    save_hdr_ga_inksel,
                                    save_hdr_ga_palette,
                                    save_hdr_ga_config,
                                    save_hdr_ram_config,
                                    save_hdr_rom_select,
                                    save_hdr_ppi_a,
                                    save_hdr_ppi_b,
                                    save_hdr_ppi_c,
                                    save_hdr_ppi_control,
                                    save_hdr_psg_addr,
                                    save_hdr_psg_regs,
                                    save_hdr_mem_size_kb,
                                    save_hdr_machine_type
                                );
                            end
                            if (bridge_word_addr == 16'd1) begin
                                debug_bridge_prime_word1 <= snapshot_header_word(
                                    8'd4,
                                    save_hdr_model,
                                    save_hdr_cpu_dir,
                                    save_hdr_crtc_addr,
                                    save_hdr_crtc_regs,
                                    save_hdr_ga_inksel,
                                    save_hdr_ga_palette,
                                    save_hdr_ga_config,
                                    save_hdr_ram_config,
                                    save_hdr_rom_select,
                                    save_hdr_ppi_a,
                                    save_hdr_ppi_b,
                                    save_hdr_ppi_c,
                                    save_hdr_ppi_control,
                                    save_hdr_psg_addr,
                                    save_hdr_psg_regs,
                                    save_hdr_mem_size_kb,
                                    save_hdr_machine_type
                                );
                            end
                        end else if (!bridge_read_active) begin
                            mem_source_cpc      <= 1'b0;
                            mem_word_addr       <= bridge_word_addr;
                            mem_state           <= MEM_READ_LO_REQ;
                            mem_psram_busy_seen <= 1'b0;
                            bridge_read_active  <= 1'b1;
                        end
                    end
                end
            end

            MEM_READ_LO_REQ: begin
                psram_addr    <= {5'd0, mem_word_addr, 1'b0};
                psram_read_en <= 1'b1;
                mem_state     <= MEM_READ_LO_WAIT;
            end

            MEM_READ_LO_WAIT: begin
                if (psram_read_avail) begin
                    mem_read_lo <= psram_data_out;
                    mem_state   <= MEM_READ_HI_REQ;
                end
            end

            MEM_READ_HI_REQ: begin
                psram_addr    <= {5'd0, mem_word_addr, 1'b1};
                psram_read_en <= 1'b1;
                mem_state     <= MEM_READ_HI_WAIT;
            end

            MEM_READ_HI_WAIT: begin
                if (psram_read_avail) begin
                    if (mem_source_cpc) begin
                        sram_resp_word_data_bridge <= {psram_data_out, mem_read_lo};
                        sram_resp_valid_bridge     <= 1'b1;
                    end else begin
                        bridge_export_addr  <= mem_word_addr;
                        bridge_export_data  <= {psram_data_out, mem_read_lo};
                        bridge_export_valid <= 1'b1;
                        bridge_read_active  <= 1'b0;
                    end
                    mem_cooldown_count <= MEM_COOLDOWN_CYCLES;
                    mem_state          <= MEM_COOLDOWN;
                end
            end

            MEM_WRITE_LO_REQ: begin
                psram_addr     <= {5'd0, mem_word_addr, 1'b0};
                psram_data_in  <= mem_write_data[15:0];
                psram_write_en <= 1'b1;
                mem_psram_busy_seen <= 1'b0;
                mem_state      <= MEM_WRITE_LO_WAIT;
            end

            MEM_WRITE_LO_WAIT: begin
                if (psram_busy) begin
                    mem_psram_busy_seen <= 1'b1;
                end
                if (mem_psram_busy_seen && !psram_busy) begin
                    mem_psram_busy_seen <= 1'b0;
                    mem_state           <= MEM_WRITE_HI_REQ;
                end
            end

            MEM_WRITE_HI_REQ: begin
                psram_addr     <= {5'd0, mem_word_addr, 1'b1};
                psram_data_in  <= mem_write_data[31:16];
                psram_write_en <= 1'b1;
                mem_psram_busy_seen <= 1'b0;
                mem_state      <= MEM_WRITE_HI_WAIT;
            end

            MEM_WRITE_HI_WAIT: begin
                if (psram_busy) begin
                    mem_psram_busy_seen <= 1'b1;
                end
                if (mem_psram_busy_seen && !psram_busy) begin
                    mem_psram_busy_seen <= 1'b0;
                    if (mem_source_cpc) begin
                        sram_resp_word_data_bridge <= 32'd0;
                        sram_resp_valid_bridge     <= 1'b1;
                    end
                    mem_cooldown_count <= MEM_COOLDOWN_CYCLES;
                    mem_state          <= MEM_COOLDOWN;
                end
            end

            MEM_COOLDOWN: begin
                if (mem_cooldown_count == 3'd0) begin
                    mem_state <= MEM_IDLE;
                end else begin
                    mem_cooldown_count <= mem_cooldown_count - 3'd1;
                end
            end

            default: begin
                mem_state <= MEM_IDLE;
            end
        endcase
    end
end

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        save_state                <= SAVE_IDLE;
        load_state                <= LOAD_IDLE;
        save_word_index           <= 32'd0;
        load_word_index           <= 32'd0;
        save_verify_index         <= 2'd0;
        ram_capture_base          <= 16'd0;
        load_ram_word_base        <= 16'd0;
        saved_ram_word_lo         <= 16'd0;
        load_word_buffer          <= 32'd0;
        load_apply_cnt            <= 3'd0;
        save_pending_when_safe    <= 1'b0;
        save_settle_count         <= 5'd0;
        save_frame_timeout        <= 24'd0;
        load_frame_timeout        <= 24'd0;
        load_header_ok            <= 1'b0;
        load_version_ok           <= 1'b0;
        load_snapshot_mem_size_kb <= 16'd64;
        load_total_words          <= SNAPSHOT_WORDS_128K;
        load_word_swap_mode       <= 2'd0;
        load_word_swap_locked     <= 1'b0;
        debug_result              <= DBG_RESULT_NONE;
        load_waited_for_ready     <= 1'b0;
        load_ready_settle_count   <= 5'd0;
        debug_last_load_word_raw  <= 32'd0;
        debug_last_load_word_norm <= 32'd0;
        debug_load_header_word0   <= 32'd0;
        debug_load_header_word1   <= 32'd0;
        save_hdr_crtc_v3          <= 64'd0;
        save_hdr_ga_vsync_delay   <= 8'd0;
        save_hdr_ga_int_scanline  <= 8'd0;
        save_hdr_ga_irq_active    <= 1'b0;
        debug_save_readback_word0 <= 32'd0;
        debug_save_readback_word1 <= 32'd0;
        debug_save_readback_word2 <= 32'd0;
        debug_save_readback_word3 <= 32'd0;
        sram_resp_word_data_cpc   <= 32'd0;
        sram_resp_pulse_cpc       <= 1'b0;
        sram_resp_fifo_rdreq      <= 1'b0;
        sram_resp_fifo_state      <= FIFO_READ_IDLE;
        prev_savestate_start_cpc  <= 1'b0;
        prev_savestate_load_cpc   <= 1'b0;
        freeze_cpu                <= 1'b0;
        snapshot_busy_reset       <= 1'b0;
        snapshot_word_wr          <= 1'b0;
        snapshot_word_addr        <= 16'd0;
        snapshot_word_data        <= 16'd0;
        sna_load                  <= 1'b0;
        sna_cpu_dir               <= 212'd0;
        sna_crtc_addr             <= 5'd0;
        sna_crtc_regs             <= 144'd0;
        sna_crtc_v3_valid         <= 1'b0;
        sna_crtc_v3               <= 64'd0;
        sna_ga_inksel             <= 5'd0;
        sna_ga_palette            <= 136'd0;
        sna_ga_config             <= 8'd0;
        sna_ga_vsync_delay        <= 8'd0;
        sna_ga_int_scanline       <= 8'd0;
        sna_ga_irq_active         <= 1'b0;
        sna_ram_config            <= 8'd0;
        sna_rom_select            <= 8'd0;
        sna_ppi_a                 <= 8'd0;
        sna_ppi_b                 <= 8'd0;
        sna_ppi_c                 <= 8'd0;
        sna_ppi_control           <= 8'h9b;
        sna_psg_addr              <= 4'd0;
        sna_psg_regs              <= 128'd0;
        sna_model                 <= 2'd0;
        capture_ram_rd            <= 1'b0;
        capture_ram_word_addr     <= 16'd0;
        front_buffer_cpc_wr       <= 1'b0;
        front_buffer_cpc_addr     <= 8'd0;
        front_buffer_cpc_din      <= 32'd0;
        sram_req_valid_cpc        <= 1'b0;
        sram_req_payload_cpc      <= 49'd0;
        start_ack_cpc             <= 1'b0;
        start_busy_cpc            <= 1'b0;
        start_ok_cpc              <= 1'b0;
        start_err_cpc             <= 1'b0;
        load_ack_cpc              <= 1'b0;
        load_busy_cpc             <= 1'b0;
        load_ok_cpc               <= 1'b0;
        load_err_cpc              <= 1'b0;
    end else begin
        prev_savestate_start_cpc  <= savestate_start_cpc;
        prev_savestate_load_cpc   <= savestate_load_cpc;
        front_buffer_cpc_wr       <= 1'b0;
        sram_req_valid_cpc        <= 1'b0;
        sram_resp_pulse_cpc       <= 1'b0;
        sram_resp_fifo_rdreq      <= 1'b0;
        snapshot_word_wr          <= 1'b0;
        sna_load                  <= 1'b0;
        capture_ram_rd            <= 1'b0;
        start_ack_cpc             <= 1'b0;
        load_ack_cpc              <= 1'b0;

        case (sram_resp_fifo_state)
            FIFO_READ_IDLE: begin
                if (!sram_resp_fifo_empty) begin
                    sram_resp_fifo_rdreq <= 1'b1;
                    sram_resp_fifo_state <= FIFO_READ_DELAY;
                end
            end
            FIFO_READ_DELAY: begin
                sram_resp_fifo_state <= FIFO_READ_LATCH;
            end
            FIFO_READ_LATCH: begin
                sram_resp_word_data_cpc <= sram_resp_fifo_q;
                sram_resp_pulse_cpc     <= 1'b1;
                sram_resp_fifo_state    <= FIFO_READ_IDLE;
            end
            default: begin
                sram_resp_fifo_state <= FIFO_READ_IDLE;
            end
        endcase

        if (load_apply_cnt != 3'd0) begin
            load_apply_cnt <= load_apply_cnt - 3'd1;
            // Keep the CPU stopped while reset is released and the SNA state is
            // injected. T80 accepts DIRSet independently of normal clock-enable
            // execution, so this prevents the reset vector from running first.
            freeze_cpu <= 1'b1;
            snapshot_busy_reset <= (load_apply_cnt > 3'd4);
            if (load_apply_cnt == 3'd2) begin
                sna_load <= 1'b1;
            end
        end

        if (save_pending_when_safe &&
            (save_state == SAVE_IDLE) &&
            !load_busy_cpc &&
            save_safe) begin
            save_state             <= SAVE_WAIT_FRAME;
            save_word_index        <= 32'd0;
            save_verify_index      <= 2'd0;
            ram_capture_base       <= 16'd0;
            save_settle_count      <= 5'd0;
            save_frame_timeout     <= FRAME_WAIT_TIMEOUT_CYCLES;
            save_pending_when_safe <= 1'b0;
            freeze_cpu             <= 1'b0;
            start_busy_cpc         <= 1'b1;
            start_err_cpc          <= 1'b0;
            start_ok_cpc           <= 1'b0;
            debug_result           <= DBG_RESULT_SAVE_WAIT_FRAME;
        end

        if (savestate_start_cpc && !prev_savestate_start_cpc) begin
            start_ack_cpc <= 1'b1;
            start_ok_cpc  <= 1'b0;
            start_err_cpc <= 1'b0;
            debug_save_readback_word0 <= 32'd0;
            debug_save_readback_word1 <= 32'd0;
            debug_save_readback_word2 <= 32'd0;
            debug_save_readback_word3 <= 32'd0;

            if ((save_state != SAVE_IDLE) || load_busy_cpc || start_busy_cpc) begin
                start_err_cpc  <= 1'b1;
                start_busy_cpc <= 1'b0;
                debug_result   <= DBG_RESULT_SAVE_REJECTED;
            end else if (!save_safe) begin
                if (save_defer_ok) begin
                    save_pending_when_safe <= 1'b1;
                    start_busy_cpc         <= 1'b1;
                    debug_result           <= DBG_RESULT_SAVE_ACCEPTED;
                end else begin
                    start_err_cpc  <= 1'b1;
                    start_busy_cpc <= 1'b0;
                    debug_result   <= DBG_RESULT_SAVE_REJECTED;
                end
            end else begin
                save_state        <= SAVE_WAIT_FRAME;
                save_word_index   <= 32'd0;
                save_verify_index <= 2'd0;
                ram_capture_base  <= 16'd0;
                save_settle_count <= 5'd0;
                save_frame_timeout <= FRAME_WAIT_TIMEOUT_CYCLES;
                freeze_cpu        <= 1'b0;
                start_busy_cpc    <= 1'b1;
                debug_result      <= DBG_RESULT_SAVE_WAIT_FRAME;
            end
        end

        if (savestate_load_cpc && !prev_savestate_load_cpc) begin
            load_ack_cpc <= 1'b1;
            load_ok_cpc  <= 1'b0;
            load_err_cpc <= 1'b0;

            if ((save_state != SAVE_IDLE) || load_busy_cpc) begin
                load_err_cpc  <= 1'b1;
                load_busy_cpc <= 1'b0;
                debug_result  <= DBG_RESULT_LOAD_REJECTED;
            end else begin
                load_busy_cpc            <= 1'b1;
                load_word_index          <= 32'd0;
                load_word_swap_mode      <= 2'd0;
                load_word_swap_locked    <= 1'b0;
                load_header_ok           <= 1'b0;
                load_version_ok          <= 1'b0;
                load_snapshot_mem_size_kb <= 16'd64;
                load_total_words         <= SNAPSHOT_WORDS_128K;
                load_waited_for_ready    <= 1'b0;
                load_ready_settle_count  <= LOAD_READY_SETTLE_CYCLES;
                debug_load_header_word0  <= 32'd0;
                debug_load_header_word1  <= 32'd0;
                sna_crtc_v3_valid        <= 1'b0;
                sna_crtc_v3              <= 64'd0;
                sna_ga_vsync_delay       <= 8'd0;
                sna_ga_int_scanline      <= 8'd0;
                sna_ga_irq_active        <= 1'b0;
                freeze_cpu               <= 1'b1;
                snapshot_busy_reset      <= 1'b0;
                debug_result             <= DBG_RESULT_LOAD_ACCEPTED;
                load_state               <= LOAD_WAIT_BLOB;
            end
        end

        case (save_state)
            SAVE_IDLE: begin
                if (!load_busy_cpc) begin
                    freeze_cpu <= 1'b0;
                end
            end

            SAVE_WAIT_FRAME: begin
                freeze_cpu <= 1'b0;
                debug_result <= DBG_RESULT_SAVE_WAIT_FRAME;
                if (save_frame_timeout != 24'd0) begin
                    save_frame_timeout <= save_frame_timeout - 24'd1;
                end
                if (save_safe && (frame_pulse || (save_frame_timeout == 24'd0))) begin
                    freeze_cpu        <= 1'b1;
                    save_settle_count <= 5'd0;
                    save_state        <= SAVE_SETTLE;
                    debug_result      <= DBG_RESULT_SAVE_ACCEPTED;
                end
            end

            SAVE_SETTLE: begin
                freeze_cpu <= 1'b1;
                if (save_settle_count == 5'd0) begin
                    save_hdr_model        <= state_model;
                    save_hdr_cpu_dir      <= state_cpu_dir;
                    save_hdr_crtc_addr    <= state_crtc_addr;
                    save_hdr_crtc_regs    <= state_crtc_regs;
                    save_hdr_crtc_v3      <= state_crtc_v3;
                    save_hdr_ga_inksel    <= state_ga_inksel;
                    save_hdr_ga_palette   <= state_ga_palette;
                    save_hdr_ga_config    <= state_ga_config;
                    save_hdr_ga_vsync_delay <= state_ga_vsync_delay;
                    save_hdr_ga_int_scanline <= state_ga_int_scanline;
                    save_hdr_ga_irq_active <= state_ga_irq_active;
                    save_hdr_ram_config   <= state_ram_config;
                    save_hdr_rom_select   <= state_rom_select;
                    save_hdr_ppi_a        <= state_ppi_a;
                    save_hdr_ppi_b        <= state_ppi_b;
                    save_hdr_ppi_c        <= state_ppi_c;
                    save_hdr_ppi_control  <= state_ppi_control;
                    save_hdr_psg_addr     <= state_psg_addr;
                    save_hdr_psg_regs     <= state_psg_regs;
                    save_hdr_mem_size_kb  <= save_snapshot_mem_size_kb;
                    save_hdr_machine_type <= save_snapshot_machine_type;
                end
                if (save_settle_count == 5'd7) begin
                    save_state <= SAVE_HEADER_REQ;
                end else begin
                    save_settle_count <= save_settle_count + 5'd1;
                end
            end

            SAVE_HEADER_REQ: begin
                freeze_cpu             <= 1'b1;
                if (save_word_index < SNAPSHOT_HDR_WORDS) begin
                    if (save_word_index < FRONT_BUFFER_WORDS) begin
                        front_buffer_cpc_wr   <= 1'b1;
                        front_buffer_cpc_addr <= save_word_index[7:0];
                        front_buffer_cpc_din  <= snapshot_header_word(
                            save_word_index[7:0] << 2,
                            save_hdr_model,
                            save_hdr_cpu_dir,
                            save_hdr_crtc_addr,
                            save_hdr_crtc_regs,
                            save_hdr_ga_inksel,
                            save_hdr_ga_palette,
                            save_hdr_ga_config,
                            save_hdr_ram_config,
                            save_hdr_rom_select,
                            save_hdr_ppi_a,
                            save_hdr_ppi_b,
                            save_hdr_ppi_c,
                            save_hdr_ppi_control,
                            save_hdr_psg_addr,
                            save_hdr_psg_regs,
                            save_hdr_mem_size_kb,
                            save_hdr_machine_type
                        );
                    end
                    sram_req_payload_cpc <= {
                        1'b1,
                        save_word_index[15:0],
                        snapshot_header_word(
                            save_word_index[7:0] << 2,
                            save_hdr_model,
                            save_hdr_cpu_dir,
                            save_hdr_crtc_addr,
                            save_hdr_crtc_regs,
                            save_hdr_ga_inksel,
                            save_hdr_ga_palette,
                            save_hdr_ga_config,
                            save_hdr_ram_config,
                            save_hdr_rom_select,
                            save_hdr_ppi_a,
                            save_hdr_ppi_b,
                            save_hdr_ppi_c,
                            save_hdr_ppi_control,
                            save_hdr_psg_addr,
                            save_hdr_psg_regs,
                            save_hdr_mem_size_kb,
                            save_hdr_machine_type
                        )
                    };
                    sram_req_valid_cpc <= 1'b1;
                    save_state         <= SAVE_HEADER_WAIT;
                end else begin
                    save_state <= SAVE_RAM_REQ0;
                end
            end

            SAVE_HEADER_WAIT: begin
                freeze_cpu <= 1'b1;
                if (sram_resp_pulse_cpc) begin
                    if (save_word_index == (SNAPSHOT_HDR_WORDS - 32'd1)) begin
                        save_word_index <= SNAPSHOT_HDR_WORDS;
                        save_state      <= SAVE_RAM_REQ0;
                    end else begin
                        save_word_index <= save_word_index + 32'd1;
                        save_state      <= SAVE_HEADER_REQ;
                    end
                end
            end

            SAVE_RAM_REQ0: begin
                freeze_cpu            <= 1'b1;
                capture_ram_rd        <= 1'b1;
                capture_ram_word_addr <= ram_capture_base;
                save_state            <= SAVE_RAM_WAIT0;
            end

            // The shared CPC RAM capture port has a registered address path.
            // Hold each requested word address for a full cycle before sampling.
            SAVE_RAM_WAIT0: begin
                freeze_cpu            <= 1'b1;
                capture_ram_rd        <= 1'b1;
                capture_ram_word_addr <= ram_capture_base;
                save_state            <= SAVE_RAM_WAIT1;
            end

            SAVE_RAM_WAIT1: begin
                freeze_cpu            <= 1'b1;
                capture_ram_rd        <= 1'b1;
                saved_ram_word_lo     <= capture_ram_word_data;
                capture_ram_word_addr <= ram_capture_base + 16'd1;
                save_state            <= SAVE_RAM_STORE_REQ;
            end

            SAVE_RAM_STORE_REQ: begin
                freeze_cpu            <= 1'b1;
                capture_ram_rd        <= 1'b1;
                capture_ram_word_addr <= ram_capture_base + 16'd1;
                save_state            <= SAVE_RAM_STORE_SEND;
            end

            SAVE_RAM_STORE_SEND: begin
                freeze_cpu            <= 1'b1;
                capture_ram_rd        <= 1'b1;
                capture_ram_word_addr <= ram_capture_base + 16'd1;
                if (save_word_index < FRONT_BUFFER_WORDS) begin
                    front_buffer_cpc_wr   <= 1'b1;
                    front_buffer_cpc_addr <= save_word_index[7:0];
                    front_buffer_cpc_din  <= {
                        saved_ram_word_lo[7:0],
                        saved_ram_word_lo[15:8],
                        capture_ram_word_data[7:0],
                        capture_ram_word_data[15:8]
                    };
                end
                sram_req_payload_cpc <= {
                    1'b1,
                    save_word_index[15:0],
                    {
                        saved_ram_word_lo[7:0],
                        saved_ram_word_lo[15:8],
                        capture_ram_word_data[7:0],
                        capture_ram_word_data[15:8]
                    }
                };
                sram_req_valid_cpc <= 1'b1;
                save_state         <= SAVE_RAM_STORE_WAIT;
            end

            SAVE_RAM_STORE_WAIT: begin
                freeze_cpu <= 1'b1;
                if (sram_resp_pulse_cpc) begin
                    if (save_word_index == (save_snapshot_total_words - 32'd1)) begin
                        save_verify_index <= 2'd0;
                        save_state <= SAVE_VERIFY_REQ0;
                    end else begin
                        save_word_index  <= save_word_index + 32'd1;
                        ram_capture_base <= ram_capture_base + 16'd2;
                        save_state       <= SAVE_RAM_REQ0;
                    end
                end
            end

            SAVE_VERIFY_REQ0: begin
                freeze_cpu <= 1'b1;
                sram_req_payload_cpc <= {1'b0, {14'd0, save_verify_index}, 32'd0};
                sram_req_valid_cpc   <= 1'b1;
                save_state           <= SAVE_VERIFY_WAIT0;
            end

            SAVE_VERIFY_WAIT0: begin
                freeze_cpu <= 1'b1;
                if (sram_resp_pulse_cpc) begin
                    case (save_verify_index)
                        2'd0: debug_save_readback_word0 <= sram_resp_word_data_cpc;
                        2'd1: debug_save_readback_word1 <= sram_resp_word_data_cpc;
                        2'd2: debug_save_readback_word2 <= sram_resp_word_data_cpc;
                        2'd3: debug_save_readback_word3 <= sram_resp_word_data_cpc;
                        default: begin end
                    endcase
                    if (save_verify_index == 2'd3) begin
                        save_state     <= SAVE_IDLE;
                        freeze_cpu     <= 1'b0;
                        start_busy_cpc <= 1'b0;
                        start_ok_cpc   <= 1'b1;
                    end else begin
                        save_verify_index <= save_verify_index + 2'd1;
                        save_state        <= SAVE_VERIFY_REQ0;
                    end
                end
            end

            default: begin
                save_state <= SAVE_IDLE;
            end
        endcase

        case (load_state)
            LOAD_IDLE: begin
            end

            LOAD_WAIT_BLOB: begin
                freeze_cpu <= 1'b1;
                if (load_ready_settle_count != 5'd0) begin
                    load_ready_settle_count <= load_ready_settle_count - 5'd1;
                    load_waited_for_ready   <= 1'b1;
                    debug_result            <= DBG_RESULT_LOAD_WAIT_BLOB;
                end else if (!load_blob_ready_cpc) begin
                    load_waited_for_ready <= 1'b1;
                    debug_result          <= DBG_RESULT_LOAD_WAIT_BLOB;
                end else begin
                    load_state <= LOAD_BUFFER_REQ;
                end
            end

            LOAD_BUFFER_REQ: begin
                if (load_word_index == load_total_words) begin
                    load_state <= LOAD_COMMIT;
                end else if (load_word_index < FRONT_BUFFER_WORDS) begin
                    front_buffer_cpc_addr <= load_word_index[7:0];
                    load_state            <= LOAD_FRONT_WAIT;
                end else begin
                    sram_req_payload_cpc <= {
                        1'b0,
                        load_word_index[15:0],
                        32'd0
                    };
                    sram_req_valid_cpc <= 1'b1;
                    load_state         <= LOAD_BUFFER_WAIT;
                end
            end

            LOAD_BUFFER_WAIT: begin
                if (sram_resp_pulse_cpc) begin
                    load_word_buffer <= sram_resp_word_data_cpc;
                    load_state       <= LOAD_CAPTURE;
                end
            end

            LOAD_FRONT_WAIT: begin
                load_state <= LOAD_FRONT_CAPTURE;
            end

            LOAD_FRONT_CAPTURE: begin
                load_word_buffer <= front_buffer_cpc_dout;
                load_state       <= LOAD_CAPTURE;
            end

            LOAD_CAPTURE: begin
                debug_last_load_word_raw  <= load_word_buffer;
                debug_last_load_word_norm <= load_capture_word;
                if (!load_word_swap_locked && (load_word_index == 32'd0)) begin
                    if (load_buffer_word_byte_reversed == SNAPSHOT_MAGIC0) begin
                        load_word_swap_mode <= 2'd1;
                    end else if (load_buffer_word_halfword_swapped == SNAPSHOT_MAGIC0) begin
                        load_word_swap_mode <= 2'd2;
                    end else if (load_buffer_word_halfword_byte_reversed == SNAPSHOT_MAGIC0) begin
                        load_word_swap_mode <= 2'd3;
                    end else begin
                        load_word_swap_mode <= 2'd0;
                    end
                    load_word_swap_locked <= 1'b1;
                end
                if (load_word_index == 32'd0) begin
                    debug_load_header_word0 <= load_capture_word;
                end
                if (load_word_index == 32'd1) begin
                    debug_load_header_word1 <= load_capture_word;
                end
                if (load_word_index == 32'd0) begin
                    if (load_capture_word != SNAPSHOT_MAGIC0) begin
                        snapshot_busy_reset <= 1'b0;
                        freeze_cpu          <= 1'b0;
                        load_busy_cpc       <= 1'b0;
                        load_err_cpc        <= 1'b1;
                        load_state          <= LOAD_IDLE;
                        debug_result        <= DBG_RESULT_LOAD_BAD_MAGIC;
                    end else begin
                        load_header_ok      <= 1'b1;
                        snapshot_busy_reset <= 1'b1;
                        load_word_index     <= load_word_index + 32'd1;
                        load_state          <= LOAD_BUFFER_REQ;
                    end
                end else if (load_word_index == 32'd1) begin
                    snapshot_busy_reset <= 1'b1;
                    load_word_index     <= load_word_index + 32'd1;
                    load_state          <= LOAD_BUFFER_REQ;
                end else if (load_word_index < SNAPSHOT_HDR_WORDS) begin
                    if ((load_word_index == 32'd4) &&
                        (load_capture_word[31:24] != 8'd2) &&
                        (load_capture_word[31:24] != 8'd3)) begin
                        snapshot_busy_reset <= 1'b0;
                        freeze_cpu          <= 1'b0;
                        load_busy_cpc       <= 1'b0;
                        load_err_cpc        <= 1'b1;
                        load_state          <= LOAD_IDLE;
                        debug_result        <= DBG_RESULT_LOAD_BAD_VERSION;
                    end else begin
                    apply_snapshot_header_byte((load_word_index[7:0] << 2) + 8'd0, load_capture_word[31:24]);
                    apply_snapshot_header_byte((load_word_index[7:0] << 2) + 8'd1, load_capture_word[23:16]);
                    apply_snapshot_header_byte((load_word_index[7:0] << 2) + 8'd2, load_capture_word[15:8]);
                    apply_snapshot_header_byte((load_word_index[7:0] << 2) + 8'd3, load_capture_word[7:0]);
                    if (load_word_index == 32'd4) begin
                        load_version_ok <= 1'b1;
                    end
                    if (load_word_index == (SNAPSHOT_HDR_WORDS - 32'd1)) begin
                        load_total_words <=
                            (load_snapshot_mem_size_kb > 16'd64) ?
                                SNAPSHOT_WORDS_128K : SNAPSHOT_WORDS_64K;
                    end
                    load_word_index <= load_word_index + 32'd1;
                    load_state      <= LOAD_BUFFER_REQ;
                    end
                end else begin
                    load_ram_word_base <= (load_word_index[15:0] - SNAPSHOT_HDR_WORDS[15:0]) << 1;
                    load_state         <= LOAD_RAM_LO;
                end
            end

            LOAD_RAM_LO: begin
                snapshot_word_wr   <= 1'b1;
                snapshot_word_addr <= load_ram_word_base;
                snapshot_word_data <= {load_capture_word[23:16], load_capture_word[31:24]};
                load_state         <= LOAD_RAM_HI;
            end

            LOAD_RAM_HI: begin
                snapshot_word_wr   <= 1'b1;
                snapshot_word_addr <= load_ram_word_base + 16'd1;
                snapshot_word_data <= {load_capture_word[7:0], load_capture_word[15:8]};
                load_word_index    <= load_word_index + 32'd1;
                load_state         <= LOAD_BUFFER_REQ;
            end

            LOAD_COMMIT: begin
                freeze_cpu <= 1'b1;
                if (!load_header_ok) begin
                    snapshot_busy_reset <= 1'b0;
                    freeze_cpu          <= 1'b0;
                    load_busy_cpc       <= 1'b0;
                    load_err_cpc        <= 1'b1;
                    load_state          <= LOAD_IDLE;
                    debug_result        <= DBG_RESULT_LOAD_BAD_MAGIC;
                end else if (!load_version_ok) begin
                    snapshot_busy_reset <= 1'b0;
                    freeze_cpu          <= 1'b0;
                    load_busy_cpc       <= 1'b0;
                    load_err_cpc        <= 1'b1;
                    load_state          <= LOAD_IDLE;
                    debug_result        <= DBG_RESULT_LOAD_BAD_VERSION;
                end else if (!load_safe) begin
                    load_waited_for_ready <= 1'b1;
                    debug_result          <= DBG_RESULT_LOAD_WAIT_SAFE;
                end else begin
                    load_apply_cnt       <= 3'd7;
                    load_frame_timeout   <= FRAME_WAIT_TIMEOUT_CYCLES;
                    snapshot_busy_reset  <= 1'b1;
                    load_state           <= LOAD_APPLY_WAIT;
                end
            end

            LOAD_APPLY_WAIT: begin
                if (load_apply_cnt == 3'd0) begin
                    snapshot_busy_reset <= 1'b0;
                    freeze_cpu          <= 1'b1;
                    load_frame_timeout  <= FRAME_WAIT_TIMEOUT_CYCLES;
                    load_state          <= LOAD_WAIT_FRAME;
                    debug_result        <= DBG_RESULT_LOAD_WAIT_FRAME;
                end
            end

            LOAD_WAIT_FRAME: begin
                snapshot_busy_reset <= 1'b0;
                freeze_cpu          <= 1'b1;
                debug_result        <= DBG_RESULT_LOAD_WAIT_FRAME;
                if (load_frame_timeout != 24'd0) begin
                    load_frame_timeout <= load_frame_timeout - 24'd1;
                end
                if (frame_pulse || (load_frame_timeout == 24'd0)) begin
                    freeze_cpu          <= 1'b0;
                    load_busy_cpc       <= 1'b0;
                    load_ok_cpc         <= 1'b1;
                    load_state          <= LOAD_IDLE;
                    debug_result        <= DBG_RESULT_LOAD_COMMIT_OK;
                end
            end

            default: begin
                load_state <= LOAD_IDLE;
            end
        endcase
    end
end

endmodule

`default_nettype wire
