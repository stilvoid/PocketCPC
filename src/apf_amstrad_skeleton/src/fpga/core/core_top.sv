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
wire        cpc_video_phase_n;
wire        cpc_video_phase_p;
wire [1:0]  cpc_video_mode;
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

synch_3 host_reset_sync_cpc(host_reset_stable_n, host_reset_n_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) cont1_key_sync_cpc(cont1_key, cont1_key_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) cont3_key_sync_cpc(cont3_key, cont3_key_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) cont3_joy_sync_cpc(cont3_joy, cont3_joy_cpc, cpc_clk);
synch_3 #(.WIDTH(16)) cont3_trig_sync_cpc(cont3_trig, cont3_trig_cpc, cpc_clk);

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
    .reset           ( !cpc_reset_n | cont1_key_cpc[15] ),
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
    .rgb             ( cpc_rgb ),
    .hsync           ( cpc_hsync ),
    .vsync           ( cpc_vsync ),
    .hblank          ( cpc_hblank ),
    .vblank          ( cpc_vblank ),
    .rgb_hsync       ( cpc_rgb_hsync ),
    .rgb_vsync       ( cpc_rgb_vsync ),
    .rgb_hblank      ( cpc_rgb_hblank ),
    .rgb_vblank      ( cpc_rgb_vblank ),
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

localparam integer V_VISIBLE = 240;
localparam integer V_FRONT   = 8;
localparam integer V_SYNC    = 4;
localparam integer V_BACK    = 10;
localparam integer V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;
localparam bit DEBUG_FORCE_POCKET_VIDEO = 1'b0;

reg [9:0] h_count = 10'd0;
reg [8:0] v_count = 9'd0;
reg [1:0] cpc_apf_counter = 2'd0;
reg       cpc_apf_ce = 1'b0;
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
wire [23:0] cpc_overlay_rgb;

always @(posedge cpc_clk) begin
    if (!(DEBUG_FORCE_POCKET_VIDEO ? (core_reset_n & cpc_pll_ready_74) : cpc_reset_n)) begin
        cpc_apf_counter <= 2'd0;
        cpc_apf_ce <= 1'b0;
        cpc_apf_pixel_clk <= 1'b0;
        cpc_apf_pixel_clk_90 <= 1'b0;
    end else begin
        cpc_apf_counter <= cpc_apf_counter + 2'd1;
        cpc_apf_ce <= (cpc_apf_counter == 2'd0);

        // Update the APF-facing video data on cpc_apf_ce first, then raise the
        // DDR capture clock a quarter-cycle later. This matches the intent of the
        // ZX Pocket core's dedicated pixel phase more closely and gives the DDIO
        // path real setup margin instead of relying on same-edge capture.
        if (cpc_apf_counter == 2'd1) cpc_apf_pixel_clk <= 1'b1;
        if (cpc_apf_counter == 2'd3) cpc_apf_pixel_clk <= 1'b0;

        if (cpc_apf_counter == 2'd2) cpc_apf_pixel_clk_90 <= 1'b1;
        if (cpc_apf_counter == 2'd0) cpc_apf_pixel_clk_90 <= 1'b0;
    end
end

always @(posedge cpc_clk) begin
    if (!(DEBUG_FORCE_POCKET_VIDEO ? (core_reset_n & cpc_pll_ready_74) : cpc_reset_n)) begin
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
    end else if (cpc_apf_ce) begin
        cpc_native_de <= 1'b0;
        cpc_native_hs <= 1'b0;
        cpc_native_rgb <= 24'h000000;

        if (cpc_rom_loaded && !cpc_rgb_hblank && !cpc_rgb_vblank) begin
            cpc_native_de <= 1'b1;
            cpc_native_rgb <= cpc_rgb;
        end

        if (cpc_hsync_delay != 3'd0) begin
            cpc_hsync_delay <= cpc_hsync_delay - 3'd1;
        end

        if (cpc_hsync_delay == 3'd1) begin
            cpc_native_hs <= 1'b1;
        end

        if (!cpc_hsync_prev && cpc_rgb_hsync) begin
            cpc_hsync_delay <= 3'd7;
        end

        cpc_native_vs <= !cpc_vsync_prev && cpc_rgb_vsync;
        cpc_hsync_prev <= cpc_rgb_hsync;
        cpc_vsync_prev <= cpc_rgb_vsync;
    end
end

always @(posedge cpc_clk) begin
    if (!(core_reset_n & cpc_pll_ready_74)) begin
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

cpc_virtual_keyboard_overlay cpc_vkb_overlay (
    .clk            ( cpc_clk ),
    .reset_n        ( cpc_reset_n ),
    .ce             ( cpc_apf_ce ),
    .de             ( cpc_native_de ),
    .vs             ( cpc_native_vs ),
    .rgb_in         ( cpc_native_rgb ),
    .active         ( cpc_vkb_active & cpc_rom_loaded ),
    .selected_index ( cpc_vkb_index ),
    .page           ( cpc_vkb_page ),
    .shift_active   ( cpc_vkb_shift ),
    .ctrl_active    ( cpc_vkb_ctrl ),
    .caps_active    ( cpc_vkb_caps ),
    .rgb_out        ( cpc_overlay_rgb )
);

wire [23:0] apf_video_rgb_next =
    DEBUG_FORCE_POCKET_VIDEO ? debug_native_rgb :
    (cpc_rom_loaded ? (cpc_vkb_active ? cpc_overlay_rgb : cpc_native_rgb) :
                      (visible ? display_rgb : 24'h000000));
wire apf_video_de_next =
    DEBUG_FORCE_POCKET_VIDEO ? debug_native_de :
    (cpc_rom_loaded ? cpc_native_de : visible);
wire apf_video_hs_next =
    DEBUG_FORCE_POCKET_VIDEO ? debug_native_hs :
    (cpc_rom_loaded ? cpc_native_hs : ~h_sync);
wire apf_video_vs_next =
    DEBUG_FORCE_POCKET_VIDEO ? debug_native_vs :
    (cpc_rom_loaded ? cpc_native_vs : ~v_sync);

always @(posedge cpc_clk) begin
    if (!(DEBUG_FORCE_POCKET_VIDEO ? (core_reset_n & cpc_pll_ready_74) : cpc_reset_n)) begin
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

wire [31:0] cpc_audio_sample = {{cpc_audio_l, 8'h00}, {cpc_audio_r, 8'h00}};
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
wire [31:0] media_flags;
wire [31:0] loader_slot;
wire [31:0] loader_addr;
wire [31:0] loader_data;
wire [31:0] loader_command;
wire [31:0] bridge_status;
wire [31:0] regs_bridge_rd_data;
wire [31:0] cmd_bridge_rd_data;
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
wire        loader_cmd_request_flag;
wire        loader_cmd_write_strobe;
wire        fdc_cmd_request_flag;
wire        fdc_cmd_write_strobe;
wire        bridge_cmd_ack_flag;
wire        fdc_target_active;
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
wire        fdc_client_selected = dataslot_runtime_enable & fdc_target_active;

reg         fdc_dataslot_toggle_74 = 1'b0;
reg  [15:0] fdc_dataslot_id_74 = 16'd0;
reg  [31:0] fdc_dataslot_size_74 = 32'd0;
wire        fdc_dataslot_toggle_cpc;
wire [15:0] fdc_dataslot_id_cpc;
wire [31:0] fdc_dataslot_size_cpc;
reg         fdc_dataslot_toggle_cpc_d = 1'b0;
wire        fdc_dataslot_update_cpc = fdc_dataslot_toggle_cpc ^ fdc_dataslot_toggle_cpc_d;

assign target_dataslot_read       = fdc_client_selected ? fdc_target_dataslot_read       : rom_target_dataslot_read;
assign target_dataslot_id         = fdc_client_selected ? fdc_target_dataslot_id         : rom_target_dataslot_id;
assign target_dataslot_slotoffset = fdc_client_selected ? fdc_target_dataslot_slotoffset : rom_target_dataslot_slotoffset;
assign target_dataslot_bridgeaddr = fdc_client_selected ? fdc_target_dataslot_bridgeaddr : rom_target_dataslot_bridgeaddr;
assign target_dataslot_length     = fdc_client_selected ? fdc_target_dataslot_length     : rom_target_dataslot_length;

always @(posedge clk_74a) begin
    if (!core_reset_n) begin
        fdc_dataslot_toggle_74 <= 1'b0;
        fdc_dataslot_id_74     <= 16'd0;
        fdc_dataslot_size_74   <= 32'd0;
    end else if (dataslot_update) begin
        fdc_dataslot_toggle_74 <= ~fdc_dataslot_toggle_74;
        fdc_dataslot_id_74     <= dataslot_update_id;
        fdc_dataslot_size_74   <= dataslot_update_size;
    end
end

synch_3 fdc_dataslot_toggle_sync(fdc_dataslot_toggle_74, fdc_dataslot_toggle_cpc, cpc_clk);
synch_3 #(.WIDTH(16)) fdc_dataslot_id_sync(fdc_dataslot_id_74, fdc_dataslot_id_cpc, cpc_clk);
synch_3 #(.WIDTH(32)) fdc_dataslot_size_sync(fdc_dataslot_size_74, fdc_dataslot_size_cpc, cpc_clk);

always @(posedge cpc_clk) begin
    if (!cpc_loader_reset_n) begin
        fdc_dataslot_toggle_cpc_d <= 1'b0;
    end else begin
        fdc_dataslot_toggle_cpc_d <= fdc_dataslot_toggle_cpc;
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
    .target_dataslot_ack         ( fdc_client_selected ? 1'b0 : target_dataslot_ack_s ),
    .target_dataslot_done        ( fdc_client_selected ? 1'b0 : target_dataslot_done_s ),
    .target_dataslot_err         ( fdc_client_selected ? 3'd0 : target_dataslot_err_s ),
    .loader_wr                   ( cpc_loader_wr ),
    .loader_addr                 ( cpc_loader_addr ),
    .loader_data                 ( cpc_loader_data ),
    .loader_done                 ( cpc_loader_done ),
    .loader_error                ( cpc_loader_error ),
    .debug_state                 ( cpc_loader_state ),
    .debug_offset                ( cpc_loader_offset )
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
    .target_dataslot_ack         ( fdc_client_selected ? target_dataslot_ack_s : 1'b0 ),
    .target_dataslot_done        ( fdc_client_selected ? target_dataslot_done_s : 1'b0 ),
    .target_dataslot_err         ( fdc_client_selected ? target_dataslot_err_s : 3'd0 ),
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
    .i_write_strobe              ( fdc_client_selected ? fdc_cmd_write_strobe : loader_cmd_write_strobe ),
    .i_request_flag              ( fdc_client_selected ? fdc_cmd_request_flag : loader_cmd_request_flag ),
	    .o_ack_flag                  ( bridge_cmd_ack_flag ),
	    .debug_tstate                ( bridge_target_state ),
	    .debug_target_status         ( bridge_target_status ),
	    .debug_target_io             ( bridge_target_io )
	);

endmodule

`default_nettype wire
