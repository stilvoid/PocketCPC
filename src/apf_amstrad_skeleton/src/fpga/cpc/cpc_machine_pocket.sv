//
// Pocket-side smoke wrapper for the imported MiSTer Amstrad CPC motherboard.
//
// This is not a complete CPC integration yet. It keeps MiSTer-only transport
// outside the machine boundary, feeds fixed CPC 6128-style defaults, and maps
// a Pocket-loaded boot.rom bundle into the ROM pages expected by the imported
// MiSTer motherboard.
//

`default_nettype none

module cpc_machine_pocket (
    input  wire        clk,
    input  wire        reset,
    input  wire        ce_16,

    input  wire [6:0]  joy1,
    input  wire [6:0]  joy2,
    input  wire [10:0] ps2_key,

    input  wire        loader_wr,
    input  wire [15:0] loader_addr,
    input  wire [7:0]  loader_data,
    input  wire        loader_done,
    input  wire        loader_error,
    output wire        rom_loaded,

    output wire [23:0] rgb,
    output wire        hsync,
    output wire        vsync,
    output wire        hblank,
    output wire        vblank,
    output wire        video_phase_n,
    output wire        video_phase_p,
    output wire [15:0] cpu_addr_debug,
    output wire        mem_rd_debug,
    output wire        mem_wr_debug
);

wire        joy1_sel;
wire        joy2_sel;
wire        key_nmi;
wire        key_reset;
wire [9:0]  fn_keys;
wire        tape_out;
wire        tape_motor;
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
wire        rgb_hsync;
wire        rgb_vsync;
wire        rgb_hblank;
wire        rgb_vblank;

localparam [3:0] CPC_DISTRIBUTOR_AMSTRAD = 4'b1000;

wire machine_reset = reset | key_reset | !rom_loaded;

assign cpu_addr_debug = cpu_addr;
assign mem_rd_debug   = mem_rd;
assign mem_wr_debug   = mem_wr;
assign video_phase_n  = phi_en_n;
assign video_phase_p  = phi_en_p;

wire [7:0]  cpu_din;
wire [15:0] vram_din;
wire [255:0] rom_map;

cpc_ram_rom memory (
    .clk          ( clk ),
    .reset        ( reset ),
    .mem_addr     ( mem_addr ),
    .mem_rd       ( mem_rd ),
    .mem_wr       ( mem_wr ),
    .cpu_dout     ( cpu_dout ),
    .cpu_din      ( cpu_din ),
    .vram_addr    ( vram_addr ),
    .vram_din     ( vram_din ),
    .loader_wr    ( loader_wr ),
    .loader_addr  ( loader_addr ),
    .loader_data  ( loader_data ),
    .loader_done  ( loader_done ),
    .loader_error ( loader_error ),
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

    .sna_load(1'b0),
    .sna_cpu_dir(212'd0),
    .sna_crtc_addr(5'd0),
    .sna_crtc_regs(144'd0),
    .sna_ga_inksel(5'd0),
    .sna_ga_palette(136'd0),
    .sna_ga_config(8'd0),
    .sna_ram_config(8'd0),
    .sna_rom_select(8'd0),
    .sna_ppi_a(8'd0),
    .sna_ppi_b(8'd0),
    .sna_ppi_c(8'd0),
    .sna_ppi_control(8'd0),
    .sna_psg_addr(4'd0),
    .sna_psg_regs(128'd0),

    .tape_in(1'b0),
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
    .field(field),

    .vram_din(vram_din),
    .vram_addr(vram_addr),

    .rom_map(rom_map),
    .ram64k(1'b0),
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

color_mix color_mix (
    .clk_vid    ( clk ),
    .ce_pix     ( video_phase_p ),
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
