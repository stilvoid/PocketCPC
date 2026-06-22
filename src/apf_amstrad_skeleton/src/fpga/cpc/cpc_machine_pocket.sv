//
// Pocket-side smoke wrapper for the imported MiSTer Amstrad CPC motherboard.
//
// This keeps MiSTer-only transport outside the machine boundary and maps a
// Pocket-loaded boot.rom bundle into the ROM pages expected by the imported
// MiSTer motherboard. Snapshot loads can temporarily switch the machine into
// 64K-model behaviour so 464/664-targeted SNA files see the ROM/RAM shape they
// expect.
//

`default_nettype none

module cpc_machine_pocket (
    input  wire        clk,
    input  wire        reset,
    input  wire        rom_reset,
    input  wire        ce_16,
    input  wire        ce_pix,

    input  wire [6:0]  joy1,
    input  wire [6:0]  joy2,
    input  wire [10:0] ps2_key,
    input  wire        vkb_caps_hold,

    input  wire        loader_wr,
    input  wire [17:0] loader_addr,
    input  wire [7:0]  loader_data,
    input  wire        loader_done,
    input  wire        loader_error,
    input  wire        snapshot_busy_reset,
    input  wire        snapshot_mem_wr,
    input  wire [16:0] snapshot_mem_addr,
    input  wire [7:0]  snapshot_mem_data,
    input  wire        sna_load,
    input  wire [211:0] sna_cpu_dir,
    input  wire [4:0]  sna_crtc_addr,
    input  wire [143:0] sna_crtc_regs,
    input  wire [4:0]  sna_ga_inksel,
    input  wire [135:0] sna_ga_palette,
    input  wire [7:0]  sna_ga_config,
    input  wire [7:0]  sna_ram_config,
    input  wire [7:0]  sna_rom_select,
    input  wire [7:0]  sna_ppi_a,
    input  wire [7:0]  sna_ppi_b,
    input  wire [7:0]  sna_ppi_c,
    input  wire [7:0]  sna_ppi_control,
    input  wire [3:0]  sna_psg_addr,
    input  wire [127:0] sna_psg_regs,
    input  wire [1:0]  sna_model,
    output wire        rom_loaded,
    output wire [31:0] sd_lba,
    output wire [1:0]  sd_rd,
    output wire [1:0]  sd_wr,
    input  wire        sd_ack,
    input  wire [8:0]  sd_buff_addr,
    input  wire [7:0]  sd_buff_dout,
    output wire [7:0]  sd_buff_din,
    input  wire        sd_buff_wr,
    input  wire [1:0]  img_mounted,
    input  wire [31:0] img_size,
    input  wire        img_wp,
    input  wire [1:0]  fdc_ready,
    input  wire        tape_in,
    output wire        tape_out,
    output wire        tape_motor,

    output wire [23:0] rgb,
    output wire        hsync,
    output wire        vsync,
    output wire        hblank,
    output wire        vblank,
    output wire        rgb_hsync,
    output wire        rgb_vsync,
    output wire        rgb_hblank,
    output wire        rgb_vblank,
    output wire        crtc_hsync,
    output wire        crtc_vsync,
    output wire        crtc_de,
    output wire        video_de,
    output wire        video_phase_n,
    output wire        video_phase_p,
    output wire [1:0]  video_mode,
    output wire [7:0]  audio_left,
    output wire [7:0]  audio_right,
    output wire [15:0] cpu_addr_debug,
    output wire        mem_rd_debug,
    output wire        mem_wr_debug
);

wire        joy1_sel;
wire        joy2_sel;
wire        key_nmi;
wire        key_reset;
wire [9:0]  fn_keys;
wire [7:0]  audio_l;
wire [7:0]  audio_r;
wire [1:0]  mode;
wire [1:0]  red;
wire [1:0]  green;
wire [1:0]  blue;
wire        field;
wire [14:0] vram_addr;
wire [22:0] mem_addr;
wire        mem_rd;
wire        mem_wr;
wire        romen;
wire        phi_n;
wire        phi_en_n;
wire        phi_en_p;
wire [15:0] cpu_addr;
wire [7:0]  cpu_dout;
wire [7:0]  memory_cpu_din;
wire        iorq;
wire        mreq;
wire        rd;
wire        wr;
wire        m1;
wire        ga_ready;
wire        cursor;
wire [7:0]  rgb_r;
wire [7:0]  rgb_g;
wire [7:0]  rgb_b;
wire        io_rd = iorq & rd;
wire        io_wr = iorq & wr;
wire [3:0]  fdc_sel = {cpu_addr[10], cpu_addr[8], cpu_addr[7], cpu_addr[0]};
wire        u765_sel = (fdc_sel[3:1] == 3'b010);
wire [7:0]  u765_dout;
wire        fdc_bus_enable = rom_loaded;
wire [7:0]  cpu_din = memory_cpu_din & ((fdc_bus_enable && u765_sel && io_rd) ? u765_dout : 8'hff);
reg         motor = 1'b0;
reg         old_io_wr = 1'b0;
reg  [2:0]  u765_div = 3'd0;
reg         ce_u765 = 1'b0;
reg  [7:0]  audio_left_r = 8'd0;
reg  [7:0]  audio_right_r = 8'd0;
reg  [1:0]  machine_model = 2'd0;

// CPC6128 OS reads PPI port B bits 1..3 as active-low distributor jumpers.
// On this wrapper, 4'b1111 selects the bundled ROM's "Amstrad" string.
localparam [3:0] CPC_DISTRIBUTOR_AMSTRAD = 4'b1111;

wire machine_reset = reset | key_reset | !rom_loaded | snapshot_busy_reset;

assign cpu_addr_debug = cpu_addr;
assign mem_rd_debug   = mem_rd;
assign mem_wr_debug   = mem_wr;
assign video_phase_n  = phi_en_n;
assign video_phase_p  = phi_en_p;
assign video_mode     = mode;
assign audio_left     = audio_left_r;
assign audio_right    = audio_right_r;

wire [15:0] vram_din;
wire [255:0] rom_map;
wire [8:0]  tape_mix = {3'd0, tape_out, 1'b0, (tape_in & tape_motor), 3'd0};
wire [8:0]  audio_mix_l = {1'b0, audio_l} + tape_mix;
wire [8:0]  audio_mix_r = {1'b0, audio_r} + tape_mix;
wire [7:0]  audio_mix_l_sat = audio_mix_l[8] ? 8'hff : audio_mix_l[7:0];
wire [7:0]  audio_mix_r_sat = audio_mix_r[8] ? 8'hff : audio_mix_r[7:0];

cpc_ram_rom memory (
    .clk          ( clk ),
    .reset        ( rom_reset ),
    .mem_addr     ( mem_addr ),
    .mem_rd       ( mem_rd ),
    .mem_wr       ( mem_wr ),
    .cpu_io_rd    ( iorq & rd ),
    .cpu_dout     ( cpu_dout ),
    .cpu_din      ( memory_cpu_din ),
    .vram_addr    ( vram_addr ),
    .vram_din     ( vram_din ),
    .loader_wr    ( loader_wr ),
    .loader_addr  ( loader_addr ),
    .loader_data  ( loader_data ),
    .loader_done  ( loader_done ),
    .loader_error ( loader_error ),
    .model        ( machine_model ),
    .snapshot_mem_wr   ( snapshot_mem_wr ),
    .snapshot_mem_addr ( snapshot_mem_addr ),
    .snapshot_mem_data ( snapshot_mem_data ),
    .rom_loaded   ( rom_loaded ),
    .rom_map      ( rom_map )
);

Amstrad_motherboard motherboard (
    .reset(machine_reset),
    .clk(clk),
    .ce_16(ce_16),

    .joy1(joy1),
    .joy2(joy2),
    .right_shift_mod(1'b0),
    .keypad_mod(1'b0),
    .vkb_caps_hold(vkb_caps_hold),
    .ps2_key(ps2_key),
    .ps2_mouse(25'd0),
    .joy1_sel(joy1_sel),
    .joy2_sel(joy2_sel),
    .key_nmi(key_nmi),
    .key_reset(key_reset),
    .Fn(fn_keys),

    .ppi_jumpers(CPC_DISTRIBUTOR_AMSTRAD),
    .crtc_type(1'b1),
    .sync_filter(1'b1),
    .no_wait(1'b0),

    .sna_load(sna_load),
    .sna_cpu_dir(sna_cpu_dir),
    .sna_crtc_addr(sna_crtc_addr),
    .sna_crtc_regs(sna_crtc_regs),
    .sna_ga_inksel(sna_ga_inksel),
    .sna_ga_palette(sna_ga_palette),
    .sna_ga_config(sna_ga_config),
    .sna_ram_config(sna_ram_config),
    .sna_rom_select(sna_rom_select),
    .sna_ppi_a(sna_ppi_a),
    .sna_ppi_b(sna_ppi_b),
    .sna_ppi_c(sna_ppi_c),
    .sna_ppi_control(sna_ppi_control),
    .sna_psg_addr(sna_psg_addr),
    .sna_psg_regs(sna_psg_regs),

    .tape_in(tape_in),
    .tape_out(tape_out),
    .tape_motor(tape_motor),

    .audio_l(audio_l),
    .audio_r(audio_r),

    .mode(mode),
    .red(red),
    .green(green),
    .blue(blue),
    .hblank(hblank),
    .vblank(vblank),
    .hsync(hsync),
    .vsync(vsync),
    .crtc_hsync(crtc_hsync),
    .crtc_vsync(crtc_vsync),
    .crtc_de_o(crtc_de),
    .video_de_o(video_de),
    .field(field),

    .vram_din(vram_din),
    .vram_addr(vram_addr),

    .rom_map(rom_map),
    .ram64k(machine_model != 2'd0),
    .mem_addr(mem_addr),
    .mem_rd(mem_rd),
    .mem_wr(mem_wr),
    .romen(romen),

    .phi_n(phi_n),
    .phi_en_n(phi_en_n),
    .phi_en_p(phi_en_p),
    .cpu_addr(cpu_addr),
    .cpu_dout(cpu_dout),
    .cpu_din(cpu_din),
    .iorq(iorq),
    .mreq(mreq),
    .rd(rd),
    .wr(wr),
    .m1(m1),
    .ga_ready(ga_ready),
    .irq(1'b0),
    .nmi(1'b0),
    .cursor(cursor)
);

always @(posedge clk) begin
    if (reset || rom_reset) begin
        machine_model <= 2'd0;
    end else if (sna_load) begin
        machine_model <= sna_model;
    end

    // Keep wrapper-local FDC/audio state aligned with the actual CPC machine
    // reset, not only the outer framework reset. Otherwise soft resets and
    // some warm boot paths can leave the FDC clock phase, motor latch, or
    // sampled audio state dirty while the motherboard/u765 were reset.
    if (machine_reset) begin
        old_io_wr <= 1'b0;
        motor     <= 1'b0;
        u765_div  <= 3'd0;
        ce_u765   <= 1'b0;
        audio_left_r  <= 8'd0;
        audio_right_r <= 8'd0;
    end else begin
        old_io_wr <= io_wr;
        if (!old_io_wr && io_wr && !fdc_sel[3:1]) begin
            motor <= cpu_dout[0];
        end

        u765_div <= u765_div + 3'd1;
        ce_u765  <= !u765_div[2:0];

        if (ce_16) begin
            audio_left_r  <= audio_mix_l_sat;
            audio_right_r <= audio_mix_r_sat;
        end
    end
end

u765 u765_drive (
    .clk_sys     ( clk ),
    .ce          ( ce_u765 ),
    .reset       ( machine_reset ),
    .ready       ( fdc_bus_enable ? fdc_ready : 2'b00 ),
    .motor       ( {motor, motor} ),
    .available   ( 2'b11 ),
    .fast        ( 1'b0 ),
    .a0          ( fdc_sel[0] ),
    .nRD         ( ~(fdc_bus_enable & u765_sel & io_rd) ),
    .nWR         ( ~(fdc_bus_enable & u765_sel & io_wr) ),
    .din         ( cpu_dout ),
    .dout        ( u765_dout ),
    .img_mounted ( fdc_bus_enable ? img_mounted : 2'b00 ),
    .img_wp      ( img_wp ),
    .img_size    ( fdc_bus_enable ? img_size : 32'd0 ),
    .sd_lba      ( sd_lba ),
    .sd_rd       ( sd_rd ),
    .sd_wr       ( sd_wr ),
    .sd_ack      ( sd_ack ),
    .sd_buff_addr( sd_buff_addr ),
    .sd_buff_dout( sd_buff_dout ),
    .sd_buff_din ( sd_buff_din ),
    .sd_buff_wr  ( sd_buff_wr )
);

color_mix color_mix (
    .clk_vid    ( clk ),
    .ce_pix     ( ce_pix ),
    .mix        ( 3'd0 ),

    .R_in       ( red ),
    .G_in       ( green ),
    .B_in       ( blue ),
    .HSync_in   ( hsync ),
    .VSync_in   ( vsync ),
    .HBlank_in  ( hblank ),
    .VBlank_in  ( vblank ),

    .R_out      ( rgb_r ),
    .G_out      ( rgb_g ),
    .B_out      ( rgb_b ),
    .HSync_out  ( rgb_hsync ),
    .VSync_out  ( rgb_vsync ),
    .HBlank_out ( rgb_hblank ),
    .VBlank_out ( rgb_vblank )
);

assign rgb = {rgb_r, rgb_g, rgb_b};

endmodule

`default_nettype wire
