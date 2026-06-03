//
// Analogue Pocket Amstrad CPC user core top-level.
//
// Phase 1 implementation: APF-compatible dummy core with a test pattern,
// silent audio, safe external-interface tie-offs, and CPC-oriented bridge
// registers. CPC machine logic is imported behind this boundary later.
//

`default_nettype none

module core_top (
    input   wire            clk_74a,
    input   wire            clk_74b,

    inout   wire    [7:0]   cart_tran_bank2,
    output  wire            cart_tran_bank2_dir,
    inout   wire    [7:0]   cart_tran_bank3,
    output  wire            cart_tran_bank3_dir,
    inout   wire    [7:0]   cart_tran_bank1,
    output  wire            cart_tran_bank1_dir,
    inout   wire    [7:4]   cart_tran_bank0,
    output  wire            cart_tran_bank0_dir,
    inout   wire            cart_tran_pin30,
    output  wire            cart_tran_pin30_dir,
    output  wire            cart_pin30_pwroff_reset,
    inout   wire            cart_tran_pin31,
    output  wire            cart_tran_pin31_dir,

    input   wire            port_ir_rx,
    output  wire            port_ir_tx,
    output  wire            port_ir_rx_disable,

    inout   wire            port_tran_si,
    output  wire            port_tran_si_dir,
    inout   wire            port_tran_so,
    output  wire            port_tran_so_dir,
    inout   wire            port_tran_sck,
    output  wire            port_tran_sck_dir,
    inout   wire            port_tran_sd,
    output  wire            port_tran_sd_dir,

    output  wire    [21:16] cram0_a,
    inout   wire    [15:0]  cram0_dq,
    input   wire            cram0_wait,
    output  wire            cram0_clk,
    output  wire            cram0_adv_n,
    output  wire            cram0_cre,
    output  wire            cram0_ce0_n,
    output  wire            cram0_ce1_n,
    output  wire            cram0_oe_n,
    output  wire            cram0_we_n,
    output  wire            cram0_ub_n,
    output  wire            cram0_lb_n,

    output  wire    [21:16] cram1_a,
    inout   wire    [15:0]  cram1_dq,
    input   wire            cram1_wait,
    output  wire            cram1_clk,
    output  wire            cram1_adv_n,
    output  wire            cram1_cre,
    output  wire            cram1_ce0_n,
    output  wire            cram1_ce1_n,
    output  wire            cram1_oe_n,
    output  wire            cram1_we_n,
    output  wire            cram1_ub_n,
    output  wire            cram1_lb_n,

    output  wire    [12:0]  dram_a,
    output  wire    [1:0]   dram_ba,
    inout   wire    [15:0]  dram_dq,
    output  wire    [1:0]   dram_dqm,
    output  wire            dram_clk,
    output  wire            dram_cke,
    output  wire            dram_ras_n,
    output  wire            dram_cas_n,
    output  wire            dram_we_n,

    output  wire    [16:0]  sram_a,
    inout   wire    [15:0]  sram_dq,
    output  wire            sram_oe_n,
    output  wire            sram_we_n,
    output  wire            sram_ub_n,
    output  wire            sram_lb_n,

    input   wire            vblank,

    output  wire            dbg_tx,
    input   wire            dbg_rx,

    output  wire            user1,
    input   wire            user2,

    inout   wire            aux_sda,
    output  wire            aux_scl,

    output  wire            vpll_feed,

    output  wire    [23:0]  video_rgb,
    output  wire            video_rgb_clock,
    output  wire            video_rgb_clock_90,
    output  wire            video_de,
    output  wire            video_skip,
    output  wire            video_vs,
    output  wire            video_hs,

    output  wire            audio_mclk,
    input   wire            audio_adc,
    output  wire            audio_dac,
    output  wire            audio_lrck,

    output  wire            bridge_endian_little,
    input   wire    [31:0]  bridge_addr,
    input   wire            bridge_rd,
    output  wire    [31:0]  bridge_rd_data,
    input   wire            bridge_wr,
    input   wire    [31:0]  bridge_wr_data,

    input   wire    [31:0]  cont1_key,
    input   wire    [31:0]  cont2_key,
    input   wire    [31:0]  cont3_key,
    input   wire    [31:0]  cont4_key,
    input   wire    [31:0]  cont1_joy,
    input   wire    [31:0]  cont2_joy,
    input   wire    [31:0]  cont3_joy,
    input   wire    [31:0]  cont4_joy,
    input   wire    [15:0]  cont1_trig,
    input   wire    [15:0]  cont2_trig,
    input   wire    [15:0]  cont3_trig,
    input   wire    [15:0]  cont4_trig
);

assign bridge_endian_little = 1'b0;

reg [15:0] reset_count = 16'h0000;
reg        core_reset_n = 1'b0;

always @(posedge clk_74a) begin
    if (!core_reset_n) begin
        reset_count <= reset_count + 16'd1;
        if (&reset_count) begin
            core_reset_n <= 1'b1;
        end
    end
end

assign port_ir_tx         = 1'b0;
assign port_ir_rx_disable = 1'b1;

assign cart_tran_bank3     = 8'hzz;
assign cart_tran_bank3_dir = 1'b0;
assign cart_tran_bank2     = 8'hzz;
assign cart_tran_bank2_dir = 1'b0;
assign cart_tran_bank1     = 8'hzz;
assign cart_tran_bank1_dir = 1'b0;
assign cart_tran_bank0     = 4'hz;
assign cart_tran_bank0_dir = 1'b0;
assign cart_tran_pin30     = 1'bz;
assign cart_tran_pin30_dir = 1'b0;
assign cart_pin30_pwroff_reset = 1'b0;
assign cart_tran_pin31     = 1'bz;
assign cart_tran_pin31_dir = 1'b0;

assign port_tran_so      = 1'bz;
assign port_tran_so_dir  = 1'b0;
assign port_tran_si      = 1'bz;
assign port_tran_si_dir  = 1'b0;
assign port_tran_sck     = 1'bz;
assign port_tran_sck_dir = 1'b0;
assign port_tran_sd      = 1'bz;
assign port_tran_sd_dir  = 1'b0;

assign cram0_a      = 6'h00;
assign cram0_dq     = 16'hzzzz;
assign cram0_clk    = 1'b0;
assign cram0_adv_n  = 1'b1;
assign cram0_cre    = 1'b0;
assign cram0_ce0_n  = 1'b1;
assign cram0_ce1_n  = 1'b1;
assign cram0_oe_n   = 1'b1;
assign cram0_we_n   = 1'b1;
assign cram0_ub_n   = 1'b1;
assign cram0_lb_n   = 1'b1;

assign cram1_a      = 6'h00;
assign cram1_dq     = 16'hzzzz;
assign cram1_clk    = 1'b0;
assign cram1_adv_n  = 1'b1;
assign cram1_cre    = 1'b0;
assign cram1_ce0_n  = 1'b1;
assign cram1_ce1_n  = 1'b1;
assign cram1_oe_n   = 1'b1;
assign cram1_we_n   = 1'b1;
assign cram1_ub_n   = 1'b1;
assign cram1_lb_n   = 1'b1;

assign dram_a     = 13'h0000;
assign dram_ba    = 2'b00;
assign dram_dq    = 16'hzzzz;
assign dram_dqm   = 2'b11;
assign dram_clk   = 1'b0;
assign dram_cke   = 1'b0;
assign dram_ras_n = 1'b1;
assign dram_cas_n = 1'b1;
assign dram_we_n  = 1'b1;

assign sram_a    = 17'h00000;
assign sram_dq   = 16'hzzzz;
assign sram_oe_n = 1'b1;
assign sram_we_n = 1'b1;
assign sram_ub_n = 1'b1;
assign sram_lb_n = 1'b1;

assign dbg_tx    = 1'b1;
assign user1     = 1'b0;
assign aux_sda   = 1'bz;
assign aux_scl   = 1'bz;
assign vpll_feed = 1'b0;

// The imported MiSTer CPC motherboard expects a 16 MHz gate-array enable.
// Pocket's clk_74a is 74.25 MHz, so a /4 divider runs the CPC about 16% fast.
localparam [31:0] CPC_CE_16_INC = 32'd925514838; // round(16e6 / 74.25e6 * 2^32)
reg [31:0] cpc_ce_acc = 32'd0;
reg        cpc_ce_16  = 1'b0;
wire [32:0] cpc_ce_next = {1'b0, cpc_ce_acc} + {1'b0, CPC_CE_16_INC};

always @(posedge clk_74a) begin
    cpc_ce_acc <= cpc_ce_next[31:0];
    cpc_ce_16  <= cpc_ce_next[32];
end

wire [23:0] cpc_rgb;
wire        cpc_hsync;
wire        cpc_vsync;
wire        cpc_hblank;
wire        cpc_vblank;
wire        cpc_video_phase_n;
wire        cpc_video_phase_p;
wire [15:0] cpc_cpu_addr_debug;
wire        cpc_mem_rd_debug;
wire        cpc_mem_wr_debug;
wire        cpc_loader_wr;
wire [15:0] cpc_loader_addr;
wire [7:0]  cpc_loader_data;
wire        cpc_loader_done;
wire        cpc_loader_error;
wire [3:0]  cpc_loader_state;
wire [31:0] cpc_loader_offset;
wire        cpc_rom_loaded;

cpc_machine_pocket cpc_machine (
    .clk             ( clk_74a ),
    .reset           ( !core_reset_n ),
    .ce_16           ( cpc_ce_16 ),
    .joy1            ( cont1_joy[6:0] ),
    .joy2            ( cont2_joy[6:0] ),
    .ps2_key         ( 11'd0 ),
    .loader_wr       ( cpc_loader_wr ),
    .loader_addr     ( cpc_loader_addr ),
    .loader_data     ( cpc_loader_data ),
    .loader_done     ( cpc_loader_done ),
    .loader_error    ( cpc_loader_error ),
    .rom_loaded      ( cpc_rom_loaded ),
    .rgb             ( cpc_rgb ),
    .hsync           ( cpc_hsync ),
    .vsync           ( cpc_vsync ),
    .hblank          ( cpc_hblank ),
    .vblank          ( cpc_vblank ),
    .video_phase_n   ( cpc_video_phase_n ),
    .video_phase_p   ( cpc_video_phase_p ),
    .cpu_addr_debug  ( cpc_cpu_addr_debug ),
    .mem_rd_debug    ( cpc_mem_rd_debug ),
    .mem_wr_debug    ( cpc_mem_wr_debug )
);

localparam integer H_VISIBLE = 320;
localparam integer H_FRONT   = 16;
localparam integer H_SYNC    = 32;
localparam integer H_BACK    = 32;
localparam integer H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

localparam integer V_VISIBLE = 240;
localparam integer V_FRONT   = 8;
localparam integer V_SYNC    = 4;
localparam integer V_BACK    = 10;
localparam integer V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

reg [9:0] h_count = 10'd0;
reg [8:0] v_count = 9'd0;
reg [3:0] pixel_div = 4'd0;
reg       pixel_clk = 1'b0;
reg       pixel_clk_90 = 1'b0;
reg       cpc_pixel_clk = 1'b0;
reg [5:0] cpc_pixel_clk_delay = 6'd0;
reg       cpc_native_de = 1'b0;
reg       cpc_native_hs = 1'b0;
reg       cpc_native_vs = 1'b0;
reg [23:0] cpc_native_rgb = 24'h000000;
reg       cpc_hsync_prev = 1'b0;
reg       cpc_vsync_prev = 1'b0;

always @(posedge clk_74a) begin
    if (cpc_video_phase_n) begin
        cpc_pixel_clk <= 1'b1;
    end
    if (cpc_video_phase_p) begin
        cpc_pixel_clk <= 1'b0;

        cpc_native_hs  <= !cpc_hsync_prev && cpc_hsync;
        cpc_native_vs  <= !cpc_vsync_prev && cpc_vsync;
        cpc_native_de  <= cpc_rom_loaded && !cpc_hblank && !cpc_vblank;
        cpc_native_rgb <= (cpc_rom_loaded && !cpc_hblank && !cpc_vblank) ? cpc_rgb : 24'h000000;

        cpc_hsync_prev <= cpc_hsync;
        cpc_vsync_prev <= cpc_vsync;
    end

    cpc_pixel_clk_delay <= {cpc_pixel_clk_delay[4:0], cpc_pixel_clk};
end

always @(posedge clk_74a) begin
    pixel_clk    <= (pixel_div < 4'd6);
    pixel_clk_90 <= (pixel_div >= 4'd3) && (pixel_div < 4'd9);

    if (pixel_div == 4'd11) begin
        pixel_div <= 4'd0;

        if (h_count == H_TOTAL - 1) begin
            h_count <= 10'd0;

            if (v_count == V_TOTAL - 1) begin
                v_count <= 9'd0;
            end else begin
                v_count <= v_count + 9'd1;
            end
        end else begin
            h_count <= h_count + 10'd1;
        end
    end else begin
        pixel_div <= pixel_div + 4'd1;
    end
end

wire visible = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
wire h_sync  = (h_count >= H_VISIBLE + H_FRONT) &&
               (h_count <  H_VISIBLE + H_FRONT + H_SYNC);
wire v_sync  = (v_count >= V_VISIBLE + V_FRONT) &&
               (v_count <  V_VISIBLE + V_FRONT + V_SYNC);

reg  [23:0] display_rgb;

always @(*) begin
    if (cpc_rom_loaded && visible) begin
        display_rgb = cpc_rgb;
    end else if (visible) begin
        if (cpc_loader_error) begin
            display_rgb = 24'hff0000;
        end else if (cpc_loader_done) begin
            display_rgb = 24'h000000;
        end else if (host_reset_n) begin
            display_rgb = 24'h000000;
        end else begin
            display_rgb = 24'h000000;
        end
    end else begin
        display_rgb = 24'h000000;
    end
end

assign video_rgb          = cpc_rom_loaded ? cpc_native_rgb : (visible ? display_rgb : 24'h000000);
assign video_de           = cpc_rom_loaded ? cpc_native_de : visible;
assign video_skip         = 1'b0;
assign video_hs           = cpc_rom_loaded ? cpc_native_hs : ~h_sync;
assign video_vs           = cpc_rom_loaded ? cpc_native_vs : ~v_sync;
assign video_rgb_clock    = cpc_rom_loaded ? cpc_pixel_clk : pixel_clk;
assign video_rgb_clock_90 = cpc_rom_loaded ? cpc_pixel_clk_delay[4] : pixel_clk_90;

reg [10:0] audio_div = 11'd0;
reg        audio_lr  = 1'b0;

always @(posedge clk_74a) begin
    audio_div <= audio_div + 11'd1;
    if (audio_div == 11'd0) begin
        audio_lr <= ~audio_lr;
    end
end

assign audio_mclk = clk_74a;
assign audio_lrck = audio_lr;
assign audio_dac  = 1'b0;

wire [31:0] control;
wire [31:0] model_config;
wire [31:0] av_config;
wire [31:0] media_flags;
wire [31:0] loader_slot;
wire [31:0] loader_addr;
wire [31:0] loader_data;
wire [31:0] loader_command;
wire [31:0] bridge_status;
wire [31:0] regs_bridge_rd_data;
wire [31:0] cmd_bridge_rd_data;
wire        host_reset_n;
wire        savestate_start;
wire        savestate_load;
wire [9:0]  datatable_addr;
wire [31:0] datatable_q;
wire        target_dataslot_read;
wire [15:0] target_dataslot_id;
wire [31:0] target_dataslot_slotoffset;
wire [31:0] target_dataslot_bridgeaddr;
wire [31:0] target_dataslot_length;
wire        target_dataslot_ack;
wire        target_dataslot_done;
wire [2:0]  target_dataslot_err;
wire        loader_cmd_request_flag;
wire        loader_cmd_write_strobe;
wire [3:0]  bridge_target_state;
wire [15:0] bridge_target_status;
wire [3:0]  bridge_target_io;

assign bridge_rd_data = (bridge_addr[31:24] == 8'hf8) ? cmd_bridge_rd_data : regs_bridge_rd_data;

pocket_bridge_regs regs (
    .clk            ( clk_74a ),
    .reset_n        ( core_reset_n ),
    .bridge_addr    ( bridge_addr ),
    .bridge_rd      ( bridge_rd ),
    .bridge_rd_data ( regs_bridge_rd_data ),
    .bridge_wr      ( bridge_wr ),
    .bridge_wr_data ( bridge_wr_data ),
    .cont1_key      ( cont1_key ),
    .control        ( control ),
    .model_config   ( model_config ),
    .av_config      ( av_config ),
    .media_flags    ( media_flags ),
    .loader_slot    ( loader_slot ),
    .loader_addr    ( loader_addr ),
    .loader_data    ( loader_data ),
    .loader_command ( loader_command ),
    .status         ( bridge_status )
);

pocket_dataslot_loader #(
    .SLOT_ID     ( 16'h0200 ),
    .TOTAL_BYTES ( 32'h0000_c000 )
) rom_loader (
    .clk                         ( clk_74a ),
    .reset_n                     ( core_reset_n ),
    .start                       ( host_reset_n ),
    .bridge_addr                 ( bridge_addr ),
    .bridge_wr                   ( bridge_wr ),
    .bridge_wr_data              ( bridge_wr_data ),
    .datatable_addr              ( datatable_addr ),
    .datatable_q                 ( datatable_q ),
    .target_dataslot_read        ( target_dataslot_read ),
    .target_dataslot_id          ( target_dataslot_id ),
    .target_dataslot_slotoffset  ( target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr  ( target_dataslot_bridgeaddr ),
    .target_dataslot_length      ( target_dataslot_length ),
    .cmd_request_flag            ( loader_cmd_request_flag ),
    .cmd_write_strobe            ( loader_cmd_write_strobe ),
    .target_dataslot_ack         ( target_dataslot_ack ),
    .target_dataslot_done        ( target_dataslot_done ),
    .target_dataslot_err         ( target_dataslot_err ),
    .loader_wr                   ( cpc_loader_wr ),
    .loader_addr                 ( cpc_loader_addr ),
    .loader_data                 ( cpc_loader_data ),
    .loader_done                 ( cpc_loader_done ),
    .loader_error                ( cpc_loader_error ),
    .debug_state                 ( cpc_loader_state ),
    .debug_offset                ( cpc_loader_offset )
);

core_bridge_cmd cmd (
    .clk                         ( clk_74a ),
    .reset_n                     ( host_reset_n ),
    .bridge_endian_little        ( bridge_endian_little ),
    .bridge_addr                 ( bridge_addr ),
    .bridge_rd                   ( bridge_rd ),
    .bridge_rd_data              ( cmd_bridge_rd_data ),
    .bridge_wr                   ( bridge_wr ),
    .bridge_wr_data              ( bridge_wr_data ),

    .status_boot_done            ( core_reset_n ),
    .status_setup_done           ( core_reset_n ),
    .status_running              ( host_reset_n ),

    .dataslot_requestread        ( ),
    .dataslot_requestread_id     ( ),
    .dataslot_requestread_ack    ( 1'b1 ),
    .dataslot_requestread_ok     ( 1'b1 ),
    .dataslot_requestwrite       ( ),
    .dataslot_requestwrite_id    ( ),
    .dataslot_requestwrite_size  ( ),
    .dataslot_requestwrite_ack   ( 1'b1 ),
    .dataslot_requestwrite_ok    ( 1'b1 ),
    .dataslot_update             ( ),
    .dataslot_update_id          ( ),
    .dataslot_update_size        ( ),
    .dataslot_update_s           ( ),
    .dataslot_update_id_s        ( ),
    .dataslot_update_size_s      ( ),
    .dataslot_allcomplete        ( ),

    .rtc_epoch_seconds           ( ),
    .rtc_date_bcd                ( ),
    .rtc_time_bcd                ( ),
    .rtc_valid                   ( ),

    .savestate_supported         ( 1'b0 ),
    .savestate_addr              ( 32'd0 ),
    .savestate_size              ( 32'd0 ),
    .savestate_maxloadsize       ( 32'd0 ),
    .osnotify_inmenu             ( ),
    .savestate_start             ( savestate_start ),
    .savestate_start_ack         ( savestate_start ),
    .savestate_start_busy        ( 1'b0 ),
    .savestate_start_ok          ( 1'b0 ),
    .savestate_start_err         ( 1'b0 ),
    .savestate_load              ( savestate_load ),
    .savestate_load_ack          ( savestate_load ),
    .savestate_load_busy         ( 1'b0 ),
    .savestate_load_ok           ( 1'b0 ),
    .savestate_load_err          ( 1'b0 ),

    .target_dataslot_read_s      ( target_dataslot_read ),
    .target_dataslot_read_48_s   ( 1'b0 ),
    .target_dataslot_write_s     ( 1'b0 ),
    .target_dataslot_write_48_s  ( 1'b0 ),
    .target_dataslot_getfile_s   ( 1'b0 ),
    .target_dataslot_openfile_s  ( 1'b0 ),
    .target_dataslot_ack         ( target_dataslot_ack ),
    .target_dataslot_ack_s       ( ),
    .target_dataslot_done        ( target_dataslot_done ),
    .target_dataslot_done_s      ( ),
    .target_dataslot_err         ( target_dataslot_err ),
    .target_dataslot_err_s       ( ),
    .target_dataslot_id_s        ( target_dataslot_id ),
    .target_dataslot_slotoffset_s ( target_dataslot_slotoffset ),
    .target_dataslot_slotoffset_48_s ( 16'd0 ),
    .target_dataslot_bridgeaddr_s ( target_dataslot_bridgeaddr ),
    .target_dataslot_length_s    ( target_dataslot_length ),
    .target_buffer_param_struct  ( 32'd0 ),
    .target_buffer_resp_struct   ( 32'd0 ),

    .datatable_addr              ( datatable_addr ),
    .datatable_wren              ( 1'b0 ),
    .datatable_data              ( 32'd0 ),
    .datatable_q                 ( datatable_q ),

    .i_clk_sync                  ( clk_74a ),
    .i_write_strobe              ( loader_cmd_write_strobe ),
    .i_request_flag              ( loader_cmd_request_flag ),
	    .o_ack_flag                  ( ),
	    .debug_tstate                ( bridge_target_state ),
	    .debug_target_status         ( bridge_target_status ),
	    .debug_target_io             ( bridge_target_io )
	);

endmodule

`default_nettype wire
