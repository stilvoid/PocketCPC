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

wire cpc_clk;
wire cpc_pll_locked;
wire cpc_pll_locked_74;
reg  cpc_pll_ready_74 = 1'b0;
reg [15:0] cpc_pll_lock_count = 16'd0;
wire cpc_reset_n;
wire cpc_loader_reset_n;
wire host_reset_n;
reg  host_reset_stable_n = 1'b0;
reg [15:0] host_reset_high_count = 16'd0;
reg [15:0] host_reset_low_count  = 16'd0;

cpc_pll cpc_pll_inst (
    .refclk   ( clk_74a ),
    .rst      ( 1'b0 ),
    .outclk_0 ( cpc_clk ),
    .locked   ( cpc_pll_locked )
);

synch_3 cpc_pll_lock_sync_74(cpc_pll_locked, cpc_pll_locked_74, clk_74a);

always @(posedge clk_74a) begin
    if (!core_reset_n) begin
        cpc_pll_ready_74   <= 1'b0;
        cpc_pll_lock_count <= 16'd0;
    end else if (!cpc_pll_ready_74) begin
        if (cpc_pll_locked_74) begin
            cpc_pll_lock_count <= cpc_pll_lock_count + 16'd1;
            if (&cpc_pll_lock_count) begin
                cpc_pll_ready_74 <= 1'b1;
            end
        end else begin
            cpc_pll_lock_count <= 16'd0;
        end
    end
end

always @(posedge clk_74a) begin
    if (!core_reset_n) begin
        host_reset_stable_n   <= 1'b0;
        host_reset_high_count <= 16'd0;
        host_reset_low_count  <= 16'd0;
    end else if (host_reset_n) begin
        host_reset_low_count <= 16'd0;
        if (!host_reset_stable_n) begin
            host_reset_high_count <= host_reset_high_count + 16'd1;
            if (&host_reset_high_count) begin
                host_reset_stable_n <= 1'b1;
            end
        end
    end else begin
        host_reset_high_count <= 16'd0;
        if (host_reset_stable_n) begin
            host_reset_low_count <= host_reset_low_count + 16'd1;
            if (&host_reset_low_count) begin
                host_reset_stable_n <= 1'b0;
            end
        end
    end
end

// Keep the ROM/FDC loader side on the same debounced framework-reset contract as
// the CPC machine itself. Without that, relaunching the core can preserve stale
// loader/runtime state across runs and produce inconsistent warm-start boots.
synch_3 cpc_reset_sync(core_reset_n & cpc_pll_ready_74 & host_reset_stable_n, cpc_reset_n, cpc_clk);
synch_3 cpc_loader_reset_sync(core_reset_n & cpc_pll_ready_74 & host_reset_stable_n, cpc_loader_reset_n, cpc_clk);

// MiSTer runs the CPC from 64 MHz and derives a clean 16 MHz gate-array enable.
reg [1:0]  cpc_div    = 2'd0;
reg        cpc_ce_16  = 1'b0;

always @(posedge cpc_clk) begin
    if (!cpc_reset_n) begin
        cpc_div   <= 2'd0;
        cpc_ce_16 <= 1'b0;
    end else begin
        cpc_div   <= cpc_div + 2'd1;
        cpc_ce_16 <= !cpc_div[1:0];
    end
end

wire [23:0] cpc_rgb;
wire        cpc_hsync;
wire        cpc_vsync;
wire        cpc_hblank;
wire        cpc_vblank;
wire        cpc_rgb_hsync;
wire        cpc_rgb_vsync;
wire        cpc_rgb_hblank;
wire        cpc_rgb_vblank;
wire        cpc_crtc_hsync;
wire        cpc_crtc_vsync;
wire        cpc_crtc_de;
wire        cpc_video_de;
wire        cpc_video_phase_n;
wire        cpc_video_phase_p;
wire [1:0]  cpc_video_mode;
wire [15:0] cpc_cpu_addr_debug;
wire        cpc_mem_rd_debug;
wire        cpc_mem_wr_debug;
wire        cpc_loader_wr;
wire [17:0] cpc_loader_addr;
wire [7:0]  cpc_loader_data;
wire        cpc_loader_done;
wire        cpc_loader_error;
wire        cpc_snapshot_busy_reset;
wire        cpc_snapshot_mem_wr;
wire [16:0] cpc_snapshot_mem_addr;
wire [7:0]  cpc_snapshot_mem_data;
wire        cpc_sna_load;
wire [211:0] cpc_sna_cpu_dir;
wire [4:0]  cpc_sna_crtc_addr;
wire [143:0] cpc_sna_crtc_regs;
wire [4:0]  cpc_sna_ga_inksel;
wire [135:0] cpc_sna_ga_palette;
wire [7:0]  cpc_sna_ga_config;
wire [7:0]  cpc_sna_ram_config;
wire [7:0]  cpc_sna_rom_select;
wire [7:0]  cpc_sna_ppi_a;
wire [7:0]  cpc_sna_ppi_b;
wire [7:0]  cpc_sna_ppi_c;
wire [7:0]  cpc_sna_ppi_control;
wire [3:0]  cpc_sna_psg_addr;
wire [127:0] cpc_sna_psg_regs;
wire [1:0]  cpc_sna_model;
wire [3:0]  cpc_loader_state;
wire [31:0] cpc_loader_offset;
wire        cpc_rom_loaded;
wire [31:0] cpc_sd_lba;
wire [1:0]  cpc_sd_rd;
wire [1:0]  cpc_sd_wr;
wire        cpc_sd_ack;
wire [8:0]  cpc_sd_buff_addr;
wire [7:0]  cpc_sd_buff_dout;
wire [7:0]  cpc_sd_buff_din;
wire        cpc_sd_buff_wr;
wire [1:0]  cpc_img_mounted;
wire [31:0] cpc_img_size;
wire        cpc_img_wp;
wire [1:0]  cpc_drive_ready;
wire        cpc_tape_in;
wire        cpc_tape_out;
wire        cpc_tape_motor;
wire        cpc_tape_running;
wire        host_reset_n_cpc;
wire [31:0] cont1_key_cpc;
wire [31:0] cont3_key_cpc;
wire [31:0] cont3_joy_cpc;
wire [15:0] cont3_trig_cpc;
wire [10:0] cpc_ps2_key;
wire [6:0]  cpc_joy1;
wire [6:0]  cpc_joy2;
wire [7:0]  cpc_audio_l;
wire [7:0]  cpc_audio_r;
wire        cpc_vkb_active;
wire [6:0]  cpc_vkb_index;
wire [1:0]  cpc_vkb_page;
wire        cpc_vkb_shift;
wire        cpc_vkb_ctrl;
wire        cpc_vkb_caps;
wire        cpc_vkb_caps_pulse;
wire        restart_request_toggle_cpc;
reg         restart_request_toggle_cpc_d = 1'b0;
reg  [5:0]  cpc_menu_restart_count = 6'd0;
wire        cpc_menu_restart_pulse = restart_request_toggle_cpc ^ restart_request_toggle_cpc_d;
wire        cpc_menu_restart_active = (cpc_menu_restart_count != 6'd0);

synch_3 host_reset_sync_cpc(host_reset_stable_n, host_reset_n_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) cont1_key_sync_cpc(cont1_key, cont1_key_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) cont3_key_sync_cpc(cont3_key, cont3_key_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) cont3_joy_sync_cpc(cont3_joy, cont3_joy_cpc, cpc_clk);
synch_3 #(.WIDTH(16)) cont3_trig_sync_cpc(cont3_trig, cont3_trig_cpc, cpc_clk);
synch_3 restart_request_sync_cpc(restart_request_toggle, restart_request_toggle_cpc, cpc_clk);

cpc_pocket_input cpc_input (
    .clk       ( cpc_clk ),
    .reset_n   ( cpc_reset_n ),
    .cont1_key ( cont1_key_cpc ),
    .cont3_key ( cont3_key_cpc ),
    .cont3_joy ( cont3_joy_cpc ),
    .cont3_trig( cont3_trig_cpc ),
    .ps2_key   ( cpc_ps2_key ),
    .joy1      ( cpc_joy1 ),
    .joy2      ( cpc_joy2 ),
    .vkb_active( cpc_vkb_active ),
    .vkb_index ( cpc_vkb_index ),
    .vkb_page  ( cpc_vkb_page ),
    .vkb_shift ( cpc_vkb_shift ),
    .vkb_ctrl  ( cpc_vkb_ctrl ),
    .vkb_caps  ( cpc_vkb_caps ),
    .vkb_caps_pulse( cpc_vkb_caps_pulse )
);

cpc_machine_pocket cpc_machine (
    .clk             ( cpc_clk ),
    .reset           ( !cpc_reset_n | cpc_menu_restart_active ),
    .rom_reset       ( !cpc_loader_reset_n ),
    .ce_16           ( cpc_ce_16 ),
    .ce_pix          ( cpc_ce_16 ),
    .joy1            ( cpc_joy1 ),
    .joy2            ( cpc_joy2 ),
    .ps2_key         ( cpc_ps2_key ),
    .vkb_caps_hold   ( cpc_vkb_caps_pulse ),
    .loader_wr       ( cpc_loader_wr ),
    .loader_addr     ( cpc_loader_addr ),
    .loader_data     ( cpc_loader_data ),
    .loader_done     ( cpc_loader_done ),
    .loader_error    ( cpc_loader_error ),
    .snapshot_busy_reset ( cpc_snapshot_busy_reset ),
    .snapshot_mem_wr ( cpc_snapshot_mem_wr ),
    .snapshot_mem_addr ( cpc_snapshot_mem_addr ),
    .snapshot_mem_data ( cpc_snapshot_mem_data ),
    .sna_load        ( cpc_sna_load ),
    .sna_cpu_dir     ( cpc_sna_cpu_dir ),
    .sna_crtc_addr   ( cpc_sna_crtc_addr ),
    .sna_crtc_regs   ( cpc_sna_crtc_regs ),
    .sna_ga_inksel   ( cpc_sna_ga_inksel ),
    .sna_ga_palette  ( cpc_sna_ga_palette ),
    .sna_ga_config   ( cpc_sna_ga_config ),
    .sna_ram_config  ( cpc_sna_ram_config ),
    .sna_rom_select  ( cpc_sna_rom_select ),
    .sna_ppi_a       ( cpc_sna_ppi_a ),
    .sna_ppi_b       ( cpc_sna_ppi_b ),
    .sna_ppi_c       ( cpc_sna_ppi_c ),
    .sna_ppi_control ( cpc_sna_ppi_control ),
    .sna_psg_addr    ( cpc_sna_psg_addr ),
    .sna_psg_regs    ( cpc_sna_psg_regs ),
    .sna_model       ( cpc_sna_model ),
    .rom_loaded      ( cpc_rom_loaded ),
    .sd_lba          ( cpc_sd_lba ),
    .sd_rd           ( cpc_sd_rd ),
    .sd_wr           ( cpc_sd_wr ),
    .sd_ack          ( cpc_sd_ack ),
    .sd_buff_addr    ( cpc_sd_buff_addr ),
    .sd_buff_dout    ( cpc_sd_buff_dout ),
    .sd_buff_din     ( cpc_sd_buff_din ),
    .sd_buff_wr      ( cpc_sd_buff_wr ),
    .img_mounted     ( cpc_img_mounted ),
    .img_size        ( cpc_img_size ),
    .img_wp          ( cpc_img_wp ),
    .fdc_ready       ( cpc_drive_ready ),
    .tape_in         ( cpc_tape_in ),
    .tape_out        ( cpc_tape_out ),
    .tape_motor      ( cpc_tape_motor ),
    .rgb             ( cpc_rgb ),
    .hsync           ( cpc_hsync ),
    .vsync           ( cpc_vsync ),
    .hblank          ( cpc_hblank ),
    .vblank          ( cpc_vblank ),
    .rgb_hsync       ( cpc_rgb_hsync ),
    .rgb_vsync       ( cpc_rgb_vsync ),
    .rgb_hblank      ( cpc_rgb_hblank ),
    .rgb_vblank      ( cpc_rgb_vblank ),
    .crtc_hsync      ( cpc_crtc_hsync ),
    .crtc_vsync      ( cpc_crtc_vsync ),
    .crtc_de         ( cpc_crtc_de ),
    .video_de        ( cpc_video_de ),
    .video_phase_n   ( cpc_video_phase_n ),
    .video_phase_p   ( cpc_video_phase_p ),
    .video_mode      ( cpc_video_mode ),
    .audio_left      ( cpc_audio_l ),
    .audio_right     ( cpc_audio_r ),
    .cpu_addr_debug  ( cpc_cpu_addr_debug ),
    .mem_rd_debug    ( cpc_mem_rd_debug ),
    .mem_wr_debug    ( cpc_mem_wr_debug )
);

localparam integer H_VISIBLE = 320;
localparam integer H_FRONT   = 16;
localparam integer H_SYNC    = 32;
localparam integer H_BACK    = 32;
localparam integer H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;
localparam integer CPC_NATIVE_HSYNC_DELAY      = 7;
localparam integer CPC_PLAYFIELD_HSYNC_DELAY   = 6;
localparam integer CPC_RASTER_TIGHT_WIDTH      = 640;
localparam integer CPC_RASTER_TIGHT_HEIGHT     = 200;
localparam integer CPC_RASTER_TIGHT_LEFT       = 64;
localparam integer CPC_RASTER_TIGHT_RIGHT      = 704;
localparam integer CPC_RASTER_TIGHT_TOP        = 40;
localparam integer CPC_RASTER_TIGHT_BOTTOM     = 240;
localparam integer CPC_RASTER_OVERSCAN_TOP     = 1;
localparam integer CPC_RASTER_OVERSCAN_WIDTH   = 768;
localparam integer CPC_RASTER_OVERSCAN_HEIGHT  = 272;
localparam integer CPC_RASTER_OVERSCAN_LEFT    = 0;
localparam integer CPC_RASTER_OVERSCAN_RIGHT   = CPC_RASTER_OVERSCAN_LEFT + CPC_RASTER_OVERSCAN_WIDTH;
localparam integer CPC_RASTER_OVERSCAN_BOTTOM  = CPC_RASTER_OVERSCAN_TOP + CPC_RASTER_OVERSCAN_HEIGHT;
localparam integer CPC_RASTER_DEFAULT_WIDTH    = 696;
localparam integer CPC_RASTER_DEFAULT_HEIGHT   = 224;
localparam integer CPC_RASTER_DEFAULT_LEFT     = 36;
localparam integer CPC_RASTER_DEFAULT_RIGHT    = 732;
localparam integer CPC_RASTER_DEFAULT_TOP      = 28;
localparam integer CPC_RASTER_DEFAULT_BOTTOM   = 252;
localparam integer CPC_ACTIVITY_INDICATOR_X    = 8;
localparam integer CPC_ACTIVITY_INDICATOR_Y    = 10;
localparam integer CPC_ACTIVITY_INDICATOR_W    = 14;
localparam integer CPC_ACTIVITY_INDICATOR_H    = 6;
localparam [22:0]  CPC_ACTIVITY_HOLD_CYCLES    = 23'd8_000_000;
localparam [17:0]  CPC_DISK_CLICK_CYCLES       = 18'd120_000;
localparam [7:0]   CPC_DISK_CLICK_LEVEL_LOUD   = 8'd18;
localparam [7:0]   CPC_DISK_CLICK_LEVEL_SOFT   = 8'd9;
localparam [1:0]  CPC_ZOOM_PRESET_DEFAULT      = 2'd0;
localparam [1:0]  CPC_ZOOM_PRESET_TIGHT        = 2'd1;
localparam [1:0]  CPC_ZOOM_PRESET_OVERSCAN     = 2'd2;

localparam integer V_VISIBLE = 240;
localparam integer V_FRONT   = 8;
localparam integer V_SYNC    = 4;
localparam integer V_BACK    = 10;
localparam integer V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;
localparam bit DEBUG_FORCE_POCKET_VIDEO = 1'b0;
wire video_domain_reset_n = core_reset_n & cpc_pll_ready_74;

reg [9:0] h_count = 10'd0;
reg [8:0] v_count = 9'd0;
reg       cpc_apf_pixel_clk = 1'b0;
reg       cpc_apf_pixel_clk_90 = 1'b0;
reg       cpc_native_de = 1'b0;
reg       cpc_native_hs = 1'b0;
reg       cpc_native_vs = 1'b0;
reg [23:0] cpc_native_rgb = 24'h000000;
reg       apf_video_de = 1'b0;
reg       apf_video_hs = 1'b0;
reg       apf_video_vs = 1'b0;
reg [23:0] apf_video_rgb = 24'h000000;
reg       debug_native_de = 1'b0;
reg       debug_native_hs = 1'b0;
reg       debug_native_vs = 1'b0;
reg [23:0] debug_native_rgb = 24'h000000;
reg       cpc_hsync_prev = 1'b0;
reg       cpc_vsync_prev = 1'b0;
reg [2:0] cpc_hsync_delay = 3'd0;
reg       debug_hsync_prev = 1'b0;
reg       debug_vsync_prev = 1'b0;
reg [2:0] debug_hsync_delay = 3'd0;
reg       cpc_zoom_de_prev = 1'b0;
reg       cpc_raster_de_prev = 1'b0;
reg [9:0] cpc_raster_x = 10'd0;
reg [8:0] cpc_raster_y = 9'd0;
reg [23:0] cpc_playfield_rgb = 24'h000000;
reg       cpc_playfield_de = 1'b0;
reg       cpc_playfield_hs = 1'b0;
reg       cpc_playfield_vs = 1'b0;
reg [23:0] cpc_tight_rgb = 24'h000000;
reg       cpc_tight_de = 1'b0;
reg [23:0] cpc_default_rgb = 24'h000000;
reg       cpc_default_de = 1'b0;
reg       cpc_crtc_hsync_prev = 1'b0;
reg       cpc_crtc_vsync_prev = 1'b0;
reg [2:0] cpc_crtc_hsync_delay = 3'd0;
wire [23:0] cpc_overlay_native_rgb;
wire [23:0] cpc_overlay_zoom_rgb;
wire        cpc_overlay_native_on;
wire        cpc_overlay_zoom_on;
wire        cpc_zoom_selected;
wire        cpc_zoom_visible;
wire [23:0] cpc_display_rgb;
wire [23:0] cpc_zoom_rgb;
wire [23:0] cpc_video_slot_rgb;
wire        cpc_display_mode_bit0;
wire        cpc_display_mode_bit1;
wire        cpc_activity_indicator_enable = interact_config_cpc[2];
wire        cpc_disk_sound_enable = interact_config_cpc[3];
wire        cpc_disk_activity_raw;
wire        cpc_tape_activity_raw;
wire        cpc_media_activity_raw;
wire        cpc_apf_ce = cpc_ce_16;
wire        cpc_raster_de_now = cpc_rom_loaded && !cpc_rgb_hblank && !cpc_rgb_vblank;
wire [1:0] cpc_zoom_preset = interact_config_cpc[1:0];
wire [10:0] cpc_raster_x_now =
    cpc_raster_de_now ?
    (!cpc_raster_de_prev ? 11'd0 : ({1'b0, cpc_raster_x} + 11'd1)) :
    11'd0;
wire cpc_tight_crop_active =
    cpc_raster_de_now &&
    (cpc_raster_x_now >= CPC_RASTER_TIGHT_LEFT[10:0]) &&
    (cpc_raster_x_now < CPC_RASTER_TIGHT_RIGHT[10:0]) &&
    ({1'b0, cpc_raster_y} >= CPC_RASTER_TIGHT_TOP[9:0]) &&
    ({1'b0, cpc_raster_y} < CPC_RASTER_TIGHT_BOTTOM[9:0]);
wire cpc_default_crop_active =
    cpc_raster_de_now &&
    (cpc_raster_x_now >= CPC_RASTER_DEFAULT_LEFT[10:0]) &&
    (cpc_raster_x_now < CPC_RASTER_DEFAULT_RIGHT[10:0]) &&
    ({1'b0, cpc_raster_y} >= CPC_RASTER_DEFAULT_TOP[9:0]) &&
    ({1'b0, cpc_raster_y} < CPC_RASTER_DEFAULT_BOTTOM[9:0]);
wire cpc_overscan_indicator_active =
    cpc_raster_de_now &&
    (cpc_raster_x_now >= (CPC_RASTER_OVERSCAN_LEFT + CPC_ACTIVITY_INDICATOR_X)) &&
    (cpc_raster_x_now < (CPC_RASTER_OVERSCAN_LEFT + CPC_ACTIVITY_INDICATOR_X + CPC_ACTIVITY_INDICATOR_W)) &&
    ({1'b0, cpc_raster_y} >= (CPC_RASTER_OVERSCAN_BOTTOM - CPC_ACTIVITY_INDICATOR_Y - CPC_ACTIVITY_INDICATOR_H)) &&
    ({1'b0, cpc_raster_y} < (CPC_RASTER_OVERSCAN_BOTTOM - CPC_ACTIVITY_INDICATOR_Y));
wire cpc_default_indicator_active =
    cpc_raster_de_now &&
    (cpc_raster_x_now >= (CPC_RASTER_DEFAULT_LEFT + CPC_ACTIVITY_INDICATOR_X)) &&
    (cpc_raster_x_now < (CPC_RASTER_DEFAULT_LEFT + CPC_ACTIVITY_INDICATOR_X + CPC_ACTIVITY_INDICATOR_W)) &&
    ({1'b0, cpc_raster_y} >= (CPC_RASTER_DEFAULT_BOTTOM - CPC_ACTIVITY_INDICATOR_Y - CPC_ACTIVITY_INDICATOR_H)) &&
    ({1'b0, cpc_raster_y} < (CPC_RASTER_DEFAULT_BOTTOM - CPC_ACTIVITY_INDICATOR_Y));
wire cpc_tight_indicator_active =
    cpc_raster_de_now &&
    (cpc_raster_x_now >= (CPC_RASTER_TIGHT_LEFT + CPC_ACTIVITY_INDICATOR_X)) &&
    (cpc_raster_x_now < (CPC_RASTER_TIGHT_LEFT + CPC_ACTIVITY_INDICATOR_X + CPC_ACTIVITY_INDICATOR_W)) &&
    ({1'b0, cpc_raster_y} >= (CPC_RASTER_TIGHT_BOTTOM - CPC_ACTIVITY_INDICATOR_Y - CPC_ACTIVITY_INDICATOR_H)) &&
    ({1'b0, cpc_raster_y} < (CPC_RASTER_TIGHT_BOTTOM - CPC_ACTIVITY_INDICATOR_Y));
reg  [22:0] cpc_media_activity_hold = 23'd0;
reg  [22:0] cpc_disk_activity_hold = 23'd0;
reg         cpc_disk_activity_raw_d = 1'b0;
reg         cpc_sd_ack_d = 1'b0;
reg  [17:0] cpc_disk_click_count = 18'd0;
wire        cpc_media_activity_visible = (cpc_media_activity_hold != 23'd0);
wire        cpc_disk_activity_visible = (cpc_disk_activity_hold != 23'd0);
wire        cpc_disk_click_trigger =
    (cpc_disk_activity_raw && !cpc_disk_activity_raw_d) ||
    (cpc_sd_ack && !cpc_sd_ack_d);
wire        cpc_activity_indicator_on =
    cpc_activity_indicator_enable &&
    cpc_media_activity_visible &&
    (!cpc_zoom_selected ? cpc_overscan_indicator_active :
     (cpc_zoom_preset == CPC_ZOOM_PRESET_TIGHT) ? cpc_tight_indicator_active :
     (cpc_zoom_preset == CPC_ZOOM_PRESET_DEFAULT) ? cpc_default_indicator_active :
     cpc_overscan_indicator_active);
wire [23:0] cpc_activity_indicator_rgb = 24'hf0f0f0;

always @(posedge cpc_clk) begin
    if (!cpc_reset_n) begin
        cpc_apf_pixel_clk <= 1'b0;
        cpc_apf_pixel_clk_90 <= 1'b0;
    end else begin
        // Keep the APF-side pixel enable and capture clocks on the same phase
        // generator that drives the imported CPC machine. A separate free-
        // running divider can sample the first visible line on the wrong
        // quarter-cycle after reset or warm starts.
        if (cpc_div == 2'd1) cpc_apf_pixel_clk <= 1'b1;
        if (cpc_div == 2'd3) cpc_apf_pixel_clk <= 1'b0;

        if (cpc_div == 2'd2) cpc_apf_pixel_clk_90 <= 1'b1;
        if (cpc_div == 2'd0) cpc_apf_pixel_clk_90 <= 1'b0;
    end
end

always @(posedge cpc_clk) begin
    if (!cpc_reset_n) begin
        restart_request_toggle_cpc_d <= restart_request_toggle_cpc;
        cpc_menu_restart_count <= 6'd0;
        cpc_media_activity_hold <= 23'd0;
        cpc_disk_activity_hold <= 23'd0;
        cpc_disk_activity_raw_d <= 1'b0;
        cpc_sd_ack_d <= 1'b0;
        cpc_disk_click_count <= 18'd0;
    end else begin
        restart_request_toggle_cpc_d <= restart_request_toggle_cpc;
        cpc_disk_activity_raw_d <= cpc_disk_activity_raw;
        cpc_sd_ack_d <= cpc_sd_ack;
        if (cpc_menu_restart_pulse) begin
            cpc_menu_restart_count <= 6'd32;
        end else if (cpc_menu_restart_count != 6'd0) begin
            cpc_menu_restart_count <= cpc_menu_restart_count - 6'd1;
        end

        if (cpc_media_activity_raw) begin
            cpc_media_activity_hold <= CPC_ACTIVITY_HOLD_CYCLES;
        end else if (cpc_media_activity_hold != 23'd0) begin
            cpc_media_activity_hold <= cpc_media_activity_hold - 23'd1;
        end

        if (cpc_disk_activity_raw) begin
            cpc_disk_activity_hold <= CPC_ACTIVITY_HOLD_CYCLES;
        end else if (cpc_disk_activity_hold != 23'd0) begin
            cpc_disk_activity_hold <= cpc_disk_activity_hold - 23'd1;
        end

        if (cpc_ce_16) begin
            if (cpc_disk_click_trigger) begin
                cpc_disk_click_count <= CPC_DISK_CLICK_CYCLES;
            end else if (cpc_disk_click_count != 18'd0) begin
                cpc_disk_click_count <= cpc_disk_click_count - 18'd1;
            end
        end
    end
end

always @(posedge cpc_clk) begin
    if (!video_domain_reset_n) begin
        h_count <= 10'd0;
        v_count <= 9'd0;
    end else if (cpc_apf_ce && (DEBUG_FORCE_POCKET_VIDEO || !cpc_rom_loaded)) begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 10'd0;

            if (v_count == V_TOTAL - 1) v_count <= 9'd0;
            else v_count <= v_count + 9'd1;
        end else begin
            h_count <= h_count + 10'd1;
        end
    end
end

always @(posedge cpc_clk) begin
    if (!cpc_reset_n) begin
        cpc_native_de <= 1'b0;
        cpc_native_hs <= 1'b0;
        cpc_native_vs <= 1'b0;
        cpc_native_rgb <= 24'h000000;
        cpc_hsync_prev <= 1'b0;
        cpc_vsync_prev <= 1'b0;
        cpc_hsync_delay <= 3'd0;
        cpc_zoom_de_prev <= 1'b0;
        cpc_raster_de_prev <= 1'b0;
        cpc_raster_x <= 10'd0;
        cpc_raster_y <= 9'd0;
        cpc_playfield_rgb <= 24'h000000;
        cpc_playfield_de <= 1'b0;
        cpc_playfield_hs <= 1'b0;
        cpc_playfield_vs <= 1'b0;
        cpc_tight_rgb <= 24'h000000;
        cpc_tight_de <= 1'b0;
        cpc_default_rgb <= 24'h000000;
        cpc_default_de <= 1'b0;
        cpc_crtc_hsync_prev <= 1'b0;
        cpc_crtc_vsync_prev <= 1'b0;
        cpc_crtc_hsync_delay <= 3'd0;
    end else if (cpc_apf_ce) begin
        cpc_native_de <= 1'b0;
        cpc_native_hs <= 1'b0;
        cpc_playfield_de <= 1'b0;
        cpc_playfield_hs <= 1'b0;
        cpc_playfield_rgb <= 24'h000000;
        cpc_tight_de <= 1'b0;
        cpc_tight_rgb <= 24'h000000;
        cpc_default_de <= 1'b0;
        cpc_default_rgb <= 24'h000000;
        cpc_native_rgb <= 24'h000000;
        if (cpc_raster_de_now && (cpc_raster_y >= CPC_RASTER_OVERSCAN_TOP[8:0])) begin
            cpc_native_de <= 1'b1;
            cpc_native_rgb <= cpc_rgb;
        end

        if (cpc_crtc_de) begin
            cpc_playfield_de <= 1'b1;
            cpc_playfield_rgb <= cpc_rgb;
        end

        if (cpc_raster_de_now) begin
            if (!cpc_raster_de_prev) begin
                cpc_raster_x <= 10'd0;
            end else begin
                if (cpc_raster_x != 10'h3ff) begin
                    cpc_raster_x <= cpc_raster_x + 10'd1;
                end
            end

            if (cpc_tight_crop_active) begin
                cpc_tight_de <= 1'b1;
                cpc_tight_rgb <= cpc_rgb;
            end

            if (cpc_default_crop_active) begin
                cpc_default_de <= 1'b1;
                cpc_default_rgb <= cpc_rgb;
            end
        end else begin
            cpc_raster_x <= 10'd0;
            if (cpc_raster_de_prev) begin
                if (cpc_raster_y != 9'h1ff) begin
                    cpc_raster_y <= cpc_raster_y + 9'd1;
                end
            end
        end

        if (cpc_hsync_delay != 3'd0) begin
            cpc_hsync_delay <= cpc_hsync_delay - 3'd1;
        end

        if (cpc_hsync_delay == 3'd1) begin
            cpc_native_hs <= 1'b1;
        end

        if (!cpc_hsync_prev && cpc_rgb_hsync) begin
            cpc_hsync_delay <= CPC_NATIVE_HSYNC_DELAY[2:0];
        end

        if (cpc_crtc_hsync_delay != 3'd0) begin
            cpc_crtc_hsync_delay <= cpc_crtc_hsync_delay - 3'd1;
        end

        if (cpc_crtc_hsync_delay == 3'd1) begin
            cpc_playfield_hs <= 1'b1;
        end

        if (!cpc_crtc_hsync_prev && cpc_crtc_hsync) begin
            cpc_crtc_hsync_delay <= CPC_PLAYFIELD_HSYNC_DELAY[2:0];
        end

        cpc_native_vs <= !cpc_vsync_prev && cpc_rgb_vsync;
        cpc_playfield_vs <= !cpc_crtc_vsync_prev && cpc_crtc_vsync;
        if (!cpc_vsync_prev && cpc_rgb_vsync) begin
            cpc_raster_x <= 10'd0;
            cpc_raster_y <= 9'd0;
        end
        cpc_hsync_prev <= cpc_rgb_hsync;
        cpc_vsync_prev <= cpc_rgb_vsync;
        cpc_crtc_hsync_prev <= cpc_crtc_hsync;
        cpc_crtc_vsync_prev <= cpc_crtc_vsync;
        cpc_raster_de_prev <= cpc_raster_de_now;
        cpc_zoom_de_prev <=
            (cpc_zoom_preset == CPC_ZOOM_PRESET_TIGHT) ? cpc_tight_de :
            (cpc_zoom_preset == CPC_ZOOM_PRESET_DEFAULT) ? cpc_default_de :
            cpc_native_de;
    end
end

always @(posedge cpc_clk) begin
    if (!video_domain_reset_n) begin
        debug_native_de <= 1'b0;
        debug_native_hs <= 1'b0;
        debug_native_vs <= 1'b0;
        debug_native_rgb <= 24'h000000;
        debug_hsync_prev <= 1'b0;
        debug_vsync_prev <= 1'b0;
        debug_hsync_delay <= 3'd0;
    end else if (cpc_apf_ce && DEBUG_FORCE_POCKET_VIDEO) begin
        debug_native_de <= 1'b0;
        debug_native_hs <= 1'b0;
        debug_native_rgb <= 24'h000000;

        if (visible) begin
            debug_native_de <= 1'b1;
            debug_native_rgb <= debug_forced_rgb;
        end

        if (debug_hsync_delay != 3'd0) begin
            debug_hsync_delay <= debug_hsync_delay - 3'd1;
        end

        if (debug_hsync_delay == 3'd1) begin
            debug_native_hs <= 1'b1;
        end

        if (!debug_hsync_prev && h_sync) begin
            debug_hsync_delay <= 3'd7;
        end

        debug_native_vs <= !debug_vsync_prev && v_sync;
        debug_hsync_prev <= h_sync;
        debug_vsync_prev <= v_sync;
    end
end

wire visible = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
wire h_sync  = (h_count >= H_VISIBLE + H_FRONT) &&
               (h_count <  H_VISIBLE + H_FRONT + H_SYNC);
wire v_sync  = (v_count >= V_VISIBLE + V_FRONT) &&
               (v_count <  V_VISIBLE + V_FRONT + V_SYNC);
wire [23:0] debug_forced_rgb =
    !visible ? 24'h000000 :
    (v_count < 9'd80)  ? ((h_count < 10'd106) ? 24'hff0000 :
                          (h_count < 10'd212) ? 24'h00ff00 : 24'h0000ff) :
    (v_count < 9'd160) ? ((h_count[4] ^ v_count[4]) ? 24'hffffff : 24'h000000) :
                         ((h_count < 10'd160) ? 24'hff00ff : 24'h00ffff);

reg  [23:0] display_rgb;

always @(*) begin
    if (cpc_rom_loaded && visible) begin
        display_rgb = cpc_rgb;
    end else if (visible) begin
        if (cpc_loader_error) begin
            display_rgb = 24'hff0000;
        end else if (cpc_loader_done) begin
            display_rgb = 24'h000000;
        end else if (host_reset_stable_n) begin
            display_rgb = 24'h000000;
        end else begin
            display_rgb = 24'h000000;
        end
    end else begin
        display_rgb = 24'h000000;
    end
end

cpc_virtual_keyboard_overlay cpc_vkb_native_overlay (
    .clk            ( cpc_clk ),
    .reset_n        ( cpc_reset_n ),
    .ce             ( cpc_apf_ce ),
    .de             ( cpc_native_de ),
    .vs             ( cpc_native_vs ),
    .rgb_in         ( cpc_native_rgb ),
    .active         ( cpc_vkb_active & cpc_rom_loaded & ~cpc_zoom_selected ),
    .selected_index ( cpc_vkb_index ),
    .page           ( cpc_vkb_page ),
    .shift_active   ( cpc_vkb_shift ),
    .ctrl_active    ( cpc_vkb_ctrl ),
    .caps_active    ( cpc_vkb_caps ),
    .rgb_out        ( cpc_overlay_native_rgb ),
    .overlay_on     ( cpc_overlay_native_on )
);

cpc_virtual_keyboard_overlay #(
    .X0(10'd20),
    .Y0(9'd112)
) cpc_vkb_zoom_overlay (
    .clk            ( cpc_clk ),
    .reset_n        ( cpc_reset_n ),
    .ce             ( cpc_apf_ce ),
    .de             ( cpc_zoom_visible ),
    .vs             ( cpc_native_vs ),
    .rgb_in         ( cpc_zoom_rgb ),
    .active         ( cpc_vkb_active & cpc_rom_loaded & cpc_zoom_selected ),
    .selected_index ( cpc_vkb_index ),
    .page           ( cpc_vkb_page ),
    .shift_active   ( cpc_vkb_shift ),
    .ctrl_active    ( cpc_vkb_ctrl ),
    .caps_active    ( cpc_vkb_caps ),
    .rgb_out        ( cpc_overlay_zoom_rgb ),
    .overlay_on     ( cpc_overlay_zoom_on )
);

assign cpc_zoom_selected = (cpc_zoom_preset != CPC_ZOOM_PRESET_OVERSCAN) &
                           ~cpc_snapshot_busy_reset &
                           ~cpc_sna_load;
assign cpc_zoom_visible =
    (cpc_zoom_preset == CPC_ZOOM_PRESET_TIGHT) ? cpc_tight_de :
    (cpc_zoom_preset == CPC_ZOOM_PRESET_DEFAULT) ? cpc_default_de :
    cpc_native_de;
assign cpc_zoom_rgb =
    (cpc_zoom_preset == CPC_ZOOM_PRESET_TIGHT) ? cpc_tight_rgb :
    (cpc_zoom_preset == CPC_ZOOM_PRESET_DEFAULT) ? cpc_default_rgb :
    cpc_native_rgb;
assign cpc_display_rgb =
    (cpc_zoom_selected && cpc_overlay_zoom_on) ? cpc_overlay_zoom_rgb :
    (!cpc_zoom_selected && cpc_overlay_native_on) ? cpc_overlay_native_rgb :
    (cpc_activity_indicator_on ? cpc_activity_indicator_rgb :
     (cpc_zoom_selected ? cpc_zoom_rgb : cpc_native_rgb));
assign cpc_display_mode_bit0 = (cpc_zoom_preset == CPC_ZOOM_PRESET_TIGHT);
assign cpc_display_mode_bit1 = (cpc_zoom_preset == CPC_ZOOM_PRESET_DEFAULT);
assign cpc_video_slot_rgb = {9'b0, cpc_display_mode_bit1, cpc_display_mode_bit0, 10'b0, 3'b0};

wire [23:0] apf_video_rgb_next =
    DEBUG_FORCE_POCKET_VIDEO ? debug_native_rgb :
    (cpc_rom_loaded ? ((cpc_zoom_de_prev && !cpc_zoom_visible) ? cpc_video_slot_rgb :
                      (cpc_zoom_visible ? cpc_display_rgb : 24'h000000)) :
                      (visible ? display_rgb : 24'h000000));
wire apf_video_de_next =
    DEBUG_FORCE_POCKET_VIDEO ? debug_native_de :
    (cpc_rom_loaded ? cpc_zoom_visible : visible);
wire apf_video_hs_next =
    DEBUG_FORCE_POCKET_VIDEO ? debug_native_hs :
    (cpc_rom_loaded ? cpc_native_hs : ~h_sync);
wire apf_video_vs_next =
    DEBUG_FORCE_POCKET_VIDEO ? debug_native_vs :
    (cpc_rom_loaded ? cpc_native_vs : ~v_sync);

always @(posedge cpc_clk) begin
    if (!video_domain_reset_n) begin
        apf_video_rgb <= 24'h000000;
        apf_video_de  <= 1'b0;
        apf_video_hs  <= 1'b0;
        apf_video_vs  <= 1'b0;
    end else if (cpc_apf_ce) begin
        apf_video_rgb <= apf_video_rgb_next;
        apf_video_de  <= apf_video_de_next;
        apf_video_hs  <= apf_video_hs_next;
        apf_video_vs  <= apf_video_vs_next;
    end
end

assign video_rgb          = apf_video_rgb;
assign video_de           = apf_video_de;
assign video_skip         = 1'b0;
assign video_hs           = apf_video_hs;
assign video_vs           = apf_video_vs;
assign video_rgb_clock    = cpc_apf_pixel_clk;
assign video_rgb_clock_90 = cpc_apf_pixel_clk_90;

wire       cpc_disk_click_square = cpc_disk_click_count[12];
wire [7:0] cpc_disk_click_level =
    cpc_disk_click_count[17:16] != 2'b00 ? CPC_DISK_CLICK_LEVEL_LOUD :
    cpc_disk_click_count[15:14] != 2'b00 ? CPC_DISK_CLICK_LEVEL_SOFT :
    8'd0;
wire [7:0] cpc_disk_audio =
    (cpc_disk_sound_enable && cpc_rom_loaded && (cpc_disk_click_count != 18'd0) && cpc_disk_click_square) ?
    cpc_disk_click_level : 8'd0;
wire [8:0] cpc_audio_l_mix = {1'b0, cpc_audio_l} + {1'b0, cpc_disk_audio};
wire [8:0] cpc_audio_r_mix = {1'b0, cpc_audio_r} + {1'b0, cpc_disk_audio};
wire [7:0] cpc_audio_l_out = (cpc_audio_l_mix > 9'd127) ? 8'h7f : cpc_audio_l_mix[7:0];
wire [7:0] cpc_audio_r_out = (cpc_audio_r_mix > 9'd127) ? 8'h7f : cpc_audio_r_mix[7:0];
wire [31:0] cpc_audio_sample = {{cpc_audio_l_out, 8'h00}, {cpc_audio_r_out, 8'h00}};
wire [31:0] cpc_audio_sample_mclk;
wire        cpc_audio_sample_mclk_strobe;
wire        cpc_audio_pll_locked;
wire        cpc_audio_pll_rst = !core_reset_n;
reg  [31:0] cpc_audio_sample_prev = 32'd0;
reg         cpc_audio_sample_write = 1'b0;
reg  [15:0] cpc_audio_l_mclk = 16'd0;
reg  [15:0] cpc_audio_r_mclk = 16'd0;

always @(posedge cpc_clk) begin
    if (!cpc_reset_n || !cpc_rom_loaded) begin
        cpc_audio_sample_prev  <= 32'd0;
        cpc_audio_sample_write <= 1'b0;
    end else begin
        cpc_audio_sample_write <= 1'b0;
        if (cpc_ce_16 && (cpc_audio_sample != cpc_audio_sample_prev)) begin
            cpc_audio_sample_prev  <= cpc_audio_sample;
            cpc_audio_sample_write <= 1'b1;
        end
    end
end

mf_audio_pll cpc_audio_pll (
    .refclk   ( clk_74b ),
    .rst      ( cpc_audio_pll_rst ),
    .outclk_0 ( audio_mclk ),
    .outclk_1 ( ),
    .locked   ( cpc_audio_pll_locked )
);

sync_fifo #(
    .WIDTH(32)
) cpc_audio_sync_fifo (
    .clk_write  ( cpc_clk ),
    .clk_read   ( audio_mclk ),
    .write_en   ( cpc_audio_sample_write ),
    .data       ( cpc_audio_sample ),
    .data_s     ( cpc_audio_sample_mclk ),
    .write_en_s ( cpc_audio_sample_mclk_strobe )
);

always @(posedge audio_mclk) begin
    if (cpc_audio_sample_mclk_strobe) begin
        cpc_audio_l_mclk <= cpc_audio_sample_mclk[31:16];
        cpc_audio_r_mclk <= cpc_audio_sample_mclk[15:0];
    end
end

sound_i2s #(
    .CHANNEL_WIDTH(16),
    .SIGNED_INPUT (0)
) cpc_sound_i2s (
    .audio_clk  ( audio_mclk ),
    .audio_l    ( cpc_audio_l_mclk ),
    .audio_r    ( cpc_audio_r_mclk ),
    .audio_lrck ( audio_lrck ),
    .audio_dac  ( audio_dac )
);

wire [31:0] control;
wire [31:0] model_config;
wire [31:0] av_config;
wire [31:0] interact_config;
wire [31:0] media_flags;
wire [31:0] loader_slot;
wire [31:0] loader_addr;
wire [31:0] loader_data;
wire [31:0] loader_command;
wire [31:0] bridge_status;
wire [31:0] regs_bridge_rd_data;
wire [31:0] cmd_bridge_rd_data;
wire [31:0] interact_config_cpc;
wire        restart_request_toggle;
wire        savestate_start;
wire        savestate_load;
wire [9:0]  datatable_addr;
wire [31:0] datatable_q;
wire        rom_target_dataslot_read;
wire [15:0] rom_target_dataslot_id;
wire [31:0] rom_target_dataslot_slotoffset;
wire [31:0] rom_target_dataslot_bridgeaddr;
wire [31:0] rom_target_dataslot_length;
wire        fdc_target_dataslot_read;
wire [15:0] fdc_target_dataslot_id;
wire [31:0] fdc_target_dataslot_slotoffset;
wire [31:0] fdc_target_dataslot_bridgeaddr;
wire [31:0] fdc_target_dataslot_length;
wire        tape_target_dataslot_read;
wire [15:0] tape_target_dataslot_id;
wire [31:0] tape_target_dataslot_slotoffset;
wire [31:0] tape_target_dataslot_bridgeaddr;
wire [31:0] tape_target_dataslot_length;
wire        target_dataslot_read;
wire [15:0] target_dataslot_id;
wire [31:0] target_dataslot_slotoffset;
wire [31:0] target_dataslot_bridgeaddr;
wire [31:0] target_dataslot_length;
wire        target_dataslot_ack;
wire        target_dataslot_done;
wire [2:0]  target_dataslot_err;
wire        target_dataslot_ack_s;
wire        target_dataslot_done_s;
wire [2:0]  target_dataslot_err_s;
wire        target_dataslot_ack_cpc;
wire        target_dataslot_done_cpc;
wire [2:0]  target_dataslot_err_cpc;
wire        loader_cmd_request_flag;
wire        loader_cmd_write_strobe;
wire        sna_cmd_request_flag;
wire        sna_cmd_write_strobe;
wire        fdc_cmd_request_flag;
wire        fdc_cmd_write_strobe;
wire        tape_cmd_request_flag;
wire        tape_cmd_write_strobe;
wire        bridge_cmd_ack_flag;
wire        fdc_target_active;
wire        tape_target_active;
wire        sna_target_dataslot_read;
wire [15:0] sna_target_dataslot_id;
wire [31:0] sna_target_dataslot_slotoffset;
wire [31:0] sna_target_dataslot_bridgeaddr;
wire [31:0] sna_target_dataslot_length;
wire        sna_target_active;
wire        dataslot_update;
wire [15:0] dataslot_update_id;
wire [31:0] dataslot_update_size;
wire        dataslot_update_s;
wire [15:0] dataslot_update_id_s;
wire [31:0] dataslot_update_size_s;
wire [3:0]  bridge_target_state;
wire [15:0] bridge_target_status;
wire [3:0]  bridge_target_io;
wire        dataslot_runtime_enable = cpc_loader_done & cpc_rom_loaded;
wire        sna_client_selected = dataslot_runtime_enable & sna_target_active;
wire        tape_client_selected = dataslot_runtime_enable & !sna_target_active & tape_target_active;
wire        fdc_client_selected = dataslot_runtime_enable & !sna_target_active & !tape_target_active & fdc_target_active;
assign cpc_disk_activity_raw = (cpc_sd_rd != 2'b00) || (cpc_sd_wr != 2'b00) || cpc_sd_ack || fdc_target_active;
assign cpc_tape_activity_raw = cpc_tape_running || tape_target_active;
assign cpc_media_activity_raw = cpc_disk_activity_raw || cpc_tape_activity_raw;

reg         fdc_dataslot_toggle_74 = 1'b0;
reg  [15:0] fdc_dataslot_id_74 = 16'd0;
reg  [31:0] fdc_dataslot_size_74 = 32'd0;
reg         tape_dataslot_toggle_74 = 1'b0;
reg  [15:0] tape_dataslot_id_74 = 16'd0;
reg  [31:0] tape_dataslot_size_74 = 32'd0;
reg         sna_dataslot_toggle_74 = 1'b0;
reg  [15:0] sna_dataslot_id_74 = 16'd0;
reg  [31:0] sna_dataslot_size_74 = 32'd0;
wire        fdc_dataslot_toggle_cpc;
wire [15:0] fdc_dataslot_id_cpc;
wire [31:0] fdc_dataslot_size_cpc;
reg         fdc_dataslot_toggle_cpc_d = 1'b0;
wire        fdc_dataslot_update_cpc = fdc_dataslot_toggle_cpc ^ fdc_dataslot_toggle_cpc_d;
wire        tape_dataslot_toggle_cpc;
wire [15:0] tape_dataslot_id_cpc;
wire [31:0] tape_dataslot_size_cpc;
reg         tape_dataslot_toggle_cpc_d = 1'b0;
wire        tape_dataslot_update_cpc = tape_dataslot_toggle_cpc ^ tape_dataslot_toggle_cpc_d;
wire        sna_dataslot_toggle_cpc;
wire [15:0] sna_dataslot_id_cpc;
wire [31:0] sna_dataslot_size_cpc;
reg         sna_dataslot_toggle_cpc_d = 1'b0;
wire        sna_dataslot_update_cpc = sna_dataslot_toggle_cpc ^ sna_dataslot_toggle_cpc_d;

assign target_dataslot_read       = sna_client_selected ? sna_target_dataslot_read :
                                    tape_client_selected ? tape_target_dataslot_read :
                                    fdc_client_selected ? fdc_target_dataslot_read :
                                    rom_target_dataslot_read;
assign target_dataslot_id         = sna_client_selected ? sna_target_dataslot_id :
                                    tape_client_selected ? tape_target_dataslot_id :
                                    fdc_client_selected ? fdc_target_dataslot_id :
                                    rom_target_dataslot_id;
assign target_dataslot_slotoffset = sna_client_selected ? sna_target_dataslot_slotoffset :
                                    tape_client_selected ? tape_target_dataslot_slotoffset :
                                    fdc_client_selected ? fdc_target_dataslot_slotoffset :
                                    rom_target_dataslot_slotoffset;
assign target_dataslot_bridgeaddr = sna_client_selected ? sna_target_dataslot_bridgeaddr :
                                    tape_client_selected ? tape_target_dataslot_bridgeaddr :
                                    fdc_client_selected ? fdc_target_dataslot_bridgeaddr :
                                    rom_target_dataslot_bridgeaddr;
assign target_dataslot_length     = sna_client_selected ? sna_target_dataslot_length :
                                    tape_client_selected ? tape_target_dataslot_length :
                                    fdc_client_selected ? fdc_target_dataslot_length :
                                    rom_target_dataslot_length;

always @(posedge clk_74a) begin
    if (!core_reset_n) begin
        fdc_dataslot_toggle_74 <= 1'b0;
        fdc_dataslot_id_74     <= 16'd0;
        fdc_dataslot_size_74   <= 32'd0;
        tape_dataslot_toggle_74 <= 1'b0;
        tape_dataslot_id_74     <= 16'd0;
        tape_dataslot_size_74   <= 32'd0;
        sna_dataslot_toggle_74 <= 1'b0;
        sna_dataslot_id_74     <= 16'd0;
        sna_dataslot_size_74   <= 32'd0;
    end else if (dataslot_update) begin
        if ((dataslot_update_id == 16'h0001) || (dataslot_update_id == 16'h0002)) begin
            fdc_dataslot_toggle_74 <= ~fdc_dataslot_toggle_74;
            fdc_dataslot_id_74     <= dataslot_update_id;
            fdc_dataslot_size_74   <= dataslot_update_size;
        end
        if (dataslot_update_id == 16'h0003) begin
            tape_dataslot_toggle_74 <= ~tape_dataslot_toggle_74;
            tape_dataslot_id_74     <= dataslot_update_id;
            tape_dataslot_size_74   <= dataslot_update_size;
        end
        if (dataslot_update_id == 16'h0004) begin
            sna_dataslot_toggle_74 <= ~sna_dataslot_toggle_74;
            sna_dataslot_id_74     <= dataslot_update_id;
            sna_dataslot_size_74   <= dataslot_update_size;
        end
    end
end

synch_3 fdc_dataslot_toggle_sync(fdc_dataslot_toggle_74, fdc_dataslot_toggle_cpc, cpc_clk);
synch_3 #(.WIDTH(16)) fdc_dataslot_id_sync(fdc_dataslot_id_74, fdc_dataslot_id_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) fdc_dataslot_size_sync(fdc_dataslot_size_74, fdc_dataslot_size_cpc, cpc_clk);
synch_3 tape_dataslot_toggle_sync(tape_dataslot_toggle_74, tape_dataslot_toggle_cpc, cpc_clk);
synch_3 #(.WIDTH(16)) tape_dataslot_id_sync(tape_dataslot_id_74, tape_dataslot_id_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) tape_dataslot_size_sync(tape_dataslot_size_74, tape_dataslot_size_cpc, cpc_clk);
synch_3 sna_dataslot_toggle_sync(sna_dataslot_toggle_74, sna_dataslot_toggle_cpc, cpc_clk);
synch_3 #(.WIDTH(16)) sna_dataslot_id_sync(sna_dataslot_id_74, sna_dataslot_id_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) sna_dataslot_size_sync(sna_dataslot_size_74, sna_dataslot_size_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) interact_config_sync(interact_config, interact_config_cpc, cpc_clk);
synch_3 target_dataslot_ack_sync(target_dataslot_ack, target_dataslot_ack_cpc, cpc_clk);
synch_3 target_dataslot_done_sync(target_dataslot_done, target_dataslot_done_cpc, cpc_clk);
synch_3 #(.WIDTH(3)) target_dataslot_err_sync(target_dataslot_err, target_dataslot_err_cpc, cpc_clk);

always @(posedge cpc_clk) begin
    if (!cpc_loader_reset_n) begin
        fdc_dataslot_toggle_cpc_d <= 1'b0;
        tape_dataslot_toggle_cpc_d <= 1'b0;
        sna_dataslot_toggle_cpc_d <= 1'b0;
    end else begin
        fdc_dataslot_toggle_cpc_d <= fdc_dataslot_toggle_cpc;
        tape_dataslot_toggle_cpc_d <= tape_dataslot_toggle_cpc;
        sna_dataslot_toggle_cpc_d <= sna_dataslot_toggle_cpc;
    end
end

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
    .interact_config ( interact_config ),
    .media_flags    ( media_flags ),
    .loader_slot    ( loader_slot ),
    .loader_addr    ( loader_addr ),
    .loader_data    ( loader_data ),
    .loader_command ( loader_command ),
    .restart_request_toggle ( restart_request_toggle ),
    .status         ( bridge_status )
);

pocket_dataslot_loader #(
    .SLOT_ID     ( 16'h0200 ),
    .TOTAL_BYTES ( 32'h0002_8000 )
) rom_loader (
    .clk                         ( cpc_clk ),
    .bridge_clk                  ( clk_74a ),
    .reset_n                     ( cpc_loader_reset_n ),
    .start                       ( host_reset_n_cpc ),
    .bridge_addr                 ( bridge_addr ),
    .bridge_wr                   ( bridge_wr ),
    .bridge_wr_data              ( bridge_wr_data ),
    .datatable_addr              ( datatable_addr ),
    .datatable_q                 ( datatable_q ),
    .target_dataslot_read        ( rom_target_dataslot_read ),
    .target_dataslot_id          ( rom_target_dataslot_id ),
    .target_dataslot_slotoffset  ( rom_target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr  ( rom_target_dataslot_bridgeaddr ),
    .target_dataslot_length      ( rom_target_dataslot_length ),
    .cmd_request_flag            ( loader_cmd_request_flag ),
    .cmd_write_strobe            ( loader_cmd_write_strobe ),
    .cmd_ack_flag                ( (sna_client_selected || tape_client_selected || fdc_client_selected) ? 1'b0 : bridge_cmd_ack_flag ),
    .target_dataslot_ack         ( (sna_client_selected || tape_client_selected || fdc_client_selected) ? 1'b0 : target_dataslot_ack_cpc ),
    .target_dataslot_done        ( (sna_client_selected || tape_client_selected || fdc_client_selected) ? 1'b0 : target_dataslot_done_cpc ),
    .target_dataslot_err         ( (sna_client_selected || tape_client_selected || fdc_client_selected) ? 3'd0 : target_dataslot_err_cpc ),
    .loader_wr                   ( cpc_loader_wr ),
    .loader_addr                 ( cpc_loader_addr ),
    .loader_data                 ( cpc_loader_data ),
    .loader_done                 ( cpc_loader_done ),
    .loader_error                ( cpc_loader_error ),
    .debug_state                 ( cpc_loader_state ),
    .debug_offset                ( cpc_loader_offset )
);

pocket_sna_dataslot sna_loader (
    .clk                         ( cpc_clk ),
    .bridge_clk                  ( clk_74a ),
    .reset_n                     ( cpc_loader_reset_n ),
    .enable                      ( dataslot_runtime_enable ),
    .bridge_addr                 ( bridge_addr ),
    .bridge_wr                   ( bridge_wr ),
    .bridge_wr_data              ( bridge_wr_data ),
    .dataslot_update             ( sna_dataslot_update_cpc ),
    .dataslot_update_id          ( sna_dataslot_id_cpc ),
    .dataslot_update_size        ( sna_dataslot_size_cpc ),
    .target_dataslot_read        ( sna_target_dataslot_read ),
    .target_dataslot_id          ( sna_target_dataslot_id ),
    .target_dataslot_slotoffset  ( sna_target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr  ( sna_target_dataslot_bridgeaddr ),
    .target_dataslot_length      ( sna_target_dataslot_length ),
    .cmd_request_flag            ( sna_cmd_request_flag ),
    .cmd_write_strobe            ( sna_cmd_write_strobe ),
    .cmd_ack_flag                ( sna_client_selected ? bridge_cmd_ack_flag : 1'b0 ),
    .target_dataslot_ack         ( sna_client_selected ? target_dataslot_ack_cpc : 1'b0 ),
    .target_dataslot_done        ( sna_client_selected ? target_dataslot_done_cpc : 1'b0 ),
    .target_dataslot_err         ( sna_client_selected ? target_dataslot_err_cpc : 3'd0 ),
    .target_active               ( sna_target_active ),
    .snapshot_mem_wr             ( cpc_snapshot_mem_wr ),
    .snapshot_mem_addr           ( cpc_snapshot_mem_addr ),
    .snapshot_mem_data           ( cpc_snapshot_mem_data ),
    .snapshot_busy_reset         ( cpc_snapshot_busy_reset ),
    .sna_load                    ( cpc_sna_load ),
    .sna_cpu_dir                 ( cpc_sna_cpu_dir ),
    .sna_crtc_addr               ( cpc_sna_crtc_addr ),
    .sna_crtc_regs               ( cpc_sna_crtc_regs ),
    .sna_ga_inksel               ( cpc_sna_ga_inksel ),
    .sna_ga_palette              ( cpc_sna_ga_palette ),
    .sna_ga_config               ( cpc_sna_ga_config ),
    .sna_ram_config              ( cpc_sna_ram_config ),
    .sna_rom_select              ( cpc_sna_rom_select ),
    .sna_ppi_a                   ( cpc_sna_ppi_a ),
    .sna_ppi_b                   ( cpc_sna_ppi_b ),
    .sna_ppi_c                   ( cpc_sna_ppi_c ),
    .sna_ppi_control             ( cpc_sna_ppi_control ),
    .sna_psg_addr                ( cpc_sna_psg_addr ),
    .sna_psg_regs                ( cpc_sna_psg_regs ),
    .sna_model                   ( cpc_sna_model )
);

pocket_tape_dataslot tape_loader (
    .clk                         ( cpc_clk ),
    .bridge_clk                  ( clk_74a ),
    .reset_n                     ( cpc_loader_reset_n ),
    .enable                      ( dataslot_runtime_enable ),
    .restart                     ( !cpc_reset_n ),
    .bridge_addr                 ( bridge_addr ),
    .bridge_wr                   ( bridge_wr ),
    .bridge_wr_data              ( bridge_wr_data ),
    .dataslot_update             ( tape_dataslot_update_cpc ),
    .dataslot_update_id          ( tape_dataslot_id_cpc ),
    .dataslot_update_size        ( tape_dataslot_size_cpc ),
    .tape_motor                  ( cpc_tape_motor ),
    .tape_in                     ( cpc_tape_in ),
    .tape_running                ( cpc_tape_running ),
    .target_dataslot_read        ( tape_target_dataslot_read ),
    .target_dataslot_id          ( tape_target_dataslot_id ),
    .target_dataslot_slotoffset  ( tape_target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr  ( tape_target_dataslot_bridgeaddr ),
    .target_dataslot_length      ( tape_target_dataslot_length ),
    .cmd_request_flag            ( tape_cmd_request_flag ),
    .cmd_write_strobe            ( tape_cmd_write_strobe ),
    .cmd_ack_flag                ( tape_client_selected ? bridge_cmd_ack_flag : 1'b0 ),
    .target_dataslot_ack         ( tape_client_selected ? target_dataslot_ack_cpc : 1'b0 ),
    .target_dataslot_done        ( tape_client_selected ? target_dataslot_done_cpc : 1'b0 ),
    .target_dataslot_err         ( tape_client_selected ? target_dataslot_err_cpc : 3'd0 ),
    .target_active               ( tape_target_active )
);

pocket_fdc_dataslot fdc_loader (
    .clk                         ( cpc_clk ),
    .bridge_clk                  ( clk_74a ),
    .reset_n                     ( cpc_loader_reset_n ),
    .enable                      ( dataslot_runtime_enable ),
    .bridge_addr                 ( bridge_addr ),
    .bridge_wr                   ( bridge_wr ),
    .bridge_wr_data              ( bridge_wr_data ),
    .dataslot_update             ( fdc_dataslot_update_cpc ),
    .dataslot_update_id          ( fdc_dataslot_id_cpc ),
    .dataslot_update_size        ( fdc_dataslot_size_cpc ),
    .sd_lba                      ( cpc_sd_lba ),
    .sd_rd                       ( cpc_sd_rd ),
    .sd_wr                       ( cpc_sd_wr ),
    .sd_ack                      ( cpc_sd_ack ),
    .sd_buff_addr                ( cpc_sd_buff_addr ),
    .sd_buff_dout                ( cpc_sd_buff_dout ),
    .sd_buff_din                 ( cpc_sd_buff_din ),
    .sd_buff_wr                  ( cpc_sd_buff_wr ),
    .img_mounted                 ( cpc_img_mounted ),
    .img_size                    ( cpc_img_size ),
    .img_wp                      ( cpc_img_wp ),
    .ready                       ( cpc_drive_ready ),
    .target_dataslot_read        ( fdc_target_dataslot_read ),
    .target_dataslot_id          ( fdc_target_dataslot_id ),
    .target_dataslot_slotoffset  ( fdc_target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr  ( fdc_target_dataslot_bridgeaddr ),
    .target_dataslot_length      ( fdc_target_dataslot_length ),
    .cmd_request_flag            ( fdc_cmd_request_flag ),
    .cmd_write_strobe            ( fdc_cmd_write_strobe ),
    .cmd_ack_flag                ( fdc_client_selected ? bridge_cmd_ack_flag : 1'b0 ),
    .target_dataslot_ack         ( fdc_client_selected ? target_dataslot_ack_cpc : 1'b0 ),
    .target_dataslot_done        ( fdc_client_selected ? target_dataslot_done_cpc : 1'b0 ),
    .target_dataslot_err         ( fdc_client_selected ? target_dataslot_err_cpc : 3'd0 ),
    .target_active               ( fdc_target_active )
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

    .status_boot_done            ( core_reset_n & cpc_pll_ready_74 ),
    .status_setup_done           ( core_reset_n & cpc_pll_ready_74 ),
    .status_running              ( host_reset_stable_n ),
    .osnotify_display_mode       ( ),

    .dataslot_requestread        ( ),
    .dataslot_requestread_id     ( ),
    .dataslot_requestread_ack    ( 1'b1 ),
    .dataslot_requestread_ok     ( 1'b1 ),
    .dataslot_requestwrite       ( ),
    .dataslot_requestwrite_id    ( ),
    .dataslot_requestwrite_size  ( ),
    .dataslot_requestwrite_ack   ( 1'b1 ),
    .dataslot_requestwrite_ok    ( 1'b1 ),
    .dataslot_update             ( dataslot_update ),
    .dataslot_update_id          ( dataslot_update_id ),
    .dataslot_update_size        ( dataslot_update_size ),
    .dataslot_update_s           ( dataslot_update_s ),
    .dataslot_update_id_s        ( dataslot_update_id_s ),
    .dataslot_update_size_s      ( dataslot_update_size_s ),
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
    .target_dataslot_ack_s       ( target_dataslot_ack_s ),
    .target_dataslot_done        ( target_dataslot_done ),
    .target_dataslot_done_s      ( target_dataslot_done_s ),
    .target_dataslot_err         ( target_dataslot_err ),
    .target_dataslot_err_s       ( target_dataslot_err_s ),
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

    .i_clk_sync                  ( cpc_clk ),
    .i_write_strobe              ( sna_client_selected ? sna_cmd_write_strobe :
                                   tape_client_selected ? tape_cmd_write_strobe :
                                   fdc_client_selected ? fdc_cmd_write_strobe :
                                   loader_cmd_write_strobe ),
    .i_request_flag              ( sna_client_selected ? sna_cmd_request_flag :
                                   tape_client_selected ? tape_cmd_request_flag :
                                   fdc_client_selected ? fdc_cmd_request_flag :
                                   loader_cmd_request_flag ),
	    .o_ack_flag                  ( bridge_cmd_ack_flag ),
	    .debug_tstate                ( bridge_target_state ),
	    .debug_target_status         ( bridge_target_status ),
	    .debug_target_io             ( bridge_target_io )
	);

endmodule

`default_nettype wire
