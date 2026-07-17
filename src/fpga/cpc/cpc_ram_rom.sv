//
// CPC RAM/ROM storage for the Pocket wrapper.
//
// Storage uses the ZX Spectrum Pocket core's explicit `dpram`/altsyncram
// primitive instead of inferred large arrays. Addressing follows the MiSTer
// Amstrad_MMU layout used by Amstrad_motherboard:
//   - RAM pages 8..15 map to 128K CPC RAM.
//   - ROM page 0x000 is the lower OS ROM.
//   - ROM page 0x100 is the upper BASIC ROM.
//   - ROM page 0x107 is the AMSDOS expansion ROM.
//   - ROM page 0x106 is an optional custom expansion ROM.
//
// MiSTer's boot.rom contains ten 16K banks:
//   OS6128, BASIC1.1, AMSDOS, MF2,
//   OS664,  BASIC664, AMSDOS, MF2,
//   OS464,  BASIC464
//
// Keep those banks distinct here so snapshot-selected models can see the ROM
// pair they expect instead of whatever happened to overwrite a flattened 48K
// image.
//

`default_nettype none

module cpc_ram_rom (
    input  wire        clk,
    input  wire        reset,

    input  wire [22:0] mem_addr,
    input  wire        mem_rd,
    input  wire        mem_wr,
    input  wire        cpu_io_rd,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din,

    input  wire [14:0] vram_addr,
    output reg  [15:0] vram_din,
    input  wire        capture_rd,
    input  wire [15:0] capture_word_addr,
    output wire [15:0] capture_word_data,

    input  wire        loader_wr,
    input  wire [17:0] loader_addr,
    input  wire [7:0]  loader_data,
    input  wire        loader_done,
    input  wire        loader_error,
    input  wire        custom_rom_enable,
    input  wire [1:0]  model,
    input  wire        snapshot_mem_wr,
    input  wire [16:0] snapshot_mem_addr,
    input  wire [7:0]  snapshot_mem_data,
    input  wire        snapshot_word_wr,
    input  wire [15:0] snapshot_word_addr,
    input  wire [15:0] snapshot_word_data,
    output reg         rom_loaded,
    output wire        custom_rom_loaded,
    output reg  [255:0] rom_map
);

localparam [8:0] PAGE_ROM_OS     = 9'h000;
localparam [8:0] PAGE_ROM_BASIC  = 9'h100;
localparam [8:0] PAGE_ROM_AMSDOS = 9'h107;
localparam [8:0] PAGE_ROM_CUSTOM = 9'h106;
localparam [7:0] ROM_SELECT_BASIC  = 8'h00;
localparam [7:0] ROM_SELECT_AMSDOS = 8'h07;
localparam [7:0] ROM_SELECT_CUSTOM = 8'h06;

localparam [3:0] ROM_BANK_OS_6128     = 4'd0;
localparam [3:0] ROM_BANK_BASIC_6128  = 4'd1;
localparam [3:0] ROM_BANK_AMSDOS_6128 = 4'd2;
localparam [3:0] ROM_BANK_MF2_6128    = 4'd3;
localparam [3:0] ROM_BANK_OS_664      = 4'd4;
localparam [3:0] ROM_BANK_BASIC_664   = 4'd5;
localparam [3:0] ROM_BANK_AMSDOS_664  = 4'd6;
localparam [3:0] ROM_BANK_MF2_664     = 4'd7;
localparam [3:0] ROM_BANK_OS_464      = 4'd8;
localparam [3:0] ROM_BANK_BASIC_464   = 4'd9;
localparam [3:0] ROM_BANK_CUSTOM      = 4'd10;

wire [8:0]  mem_page = mem_addr[22:14];
wire [13:0] mem_offset = mem_addr[13:0];
wire [16:0] ram_addr = mem_addr[16:0];
wire [15:0] ram_word_addr = ram_addr[16:1];
wire [15:0] vram_word_addr = {1'b0, vram_addr};
wire        ram_selected = (mem_page >= 9'd8) && (mem_page <= 9'd15);

wire [7:0] ram_cpu_even_q;
wire [7:0] ram_cpu_odd_q;
wire [7:0] ram_vram_even_q;
wire [7:0] ram_vram_odd_q;
wire [7:0] rom_os_6128_q;
wire [7:0] rom_basic_6128_q;
wire [7:0] rom_amsdos_6128_q;
wire [7:0] rom_os_664_q;
wire [7:0] rom_basic_664_q;
wire [7:0] rom_amsdos_664_q;
wire [7:0] rom_os_464_q;
wire [7:0] rom_basic_464_q;
wire [7:0] rom_custom_q;
wire [7:0] rom_os_q;
wire [7:0] rom_basic_q;
wire [7:0] rom_amsdos_q;
wire [3:0] loader_bank = loader_addr[17:14];
wire [13:0] loader_rom_addr = loader_addr[13:0];
wire [15:0] ram_port_addr =
    snapshot_word_wr ? snapshot_word_addr :
    snapshot_mem_wr ? snapshot_mem_addr[16:1] :
    ram_word_addr;
wire [7:0]  ram_port_even_data =
    snapshot_word_wr ? snapshot_word_data[7:0] :
    snapshot_mem_wr ? snapshot_mem_data :
    cpu_dout;
wire [7:0]  ram_port_odd_data =
    snapshot_word_wr ? snapshot_word_data[15:8] :
    snapshot_mem_wr ? snapshot_mem_data :
    cpu_dout;
wire        ram_port_even_wr =
    snapshot_word_wr ? 1'b1 :
    snapshot_mem_wr ? !snapshot_mem_addr[0] :
    (mem_wr && ram_selected && !ram_addr[0]);
wire        ram_port_odd_wr  =
    snapshot_word_wr ? 1'b1 :
    snapshot_mem_wr ? snapshot_mem_addr[0] :
    (mem_wr && ram_selected && ram_addr[0]);
wire [15:0] ram_read_word_addr = capture_rd ? capture_word_addr : vram_word_addr;

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(16)
) cpc_ram_even (
    .clock     ( clk ),
    .address_a ( ram_port_addr ),
    .data_a    ( ram_port_even_data ),
    .wren_a    ( ram_port_even_wr ),
    .q_a       ( ram_cpu_even_q ),
    .address_b ( ram_read_word_addr ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( ram_vram_even_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(16)
) cpc_ram_odd (
    .clock     ( clk ),
    .address_a ( ram_port_addr ),
    .data_a    ( ram_port_odd_data ),
    .wren_a    ( ram_port_odd_wr ),
    .q_a       ( ram_cpu_odd_q ),
    .address_b ( ram_read_word_addr ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( ram_vram_odd_q )
);

assign capture_word_data = {ram_vram_odd_q, ram_vram_even_q};

assign custom_rom_loaded = custom_rom_enable;

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_os (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_OS_6128) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_os_6128_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_basic (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_BASIC_6128) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_basic_6128_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_amsdos (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_AMSDOS_6128) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_amsdos_6128_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_os_664 (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_OS_664) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_os_664_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_basic_664 (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_BASIC_664) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_basic_664_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_amsdos_664 (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_AMSDOS_664) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_amsdos_664_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_os_464 (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_OS_464) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_os_464_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_basic_464 (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_BASIC_464) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_basic_464_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_custom (
    .clock     ( clk ),
    .address_a ( loader_rom_addr ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_bank == ROM_BANK_CUSTOM) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_custom_q )
);

assign rom_os_q = (model == 2'd2) ? rom_os_464_q :
                  (model == 2'd1) ? rom_os_664_q :
                                    rom_os_6128_q;

assign rom_basic_q = (model == 2'd2) ? rom_basic_464_q :
                     (model == 2'd1) ? rom_basic_664_q :
                                       rom_basic_6128_q;

assign rom_amsdos_q = (model == 2'd1) ? rom_amsdos_664_q :
                                         rom_amsdos_6128_q;

always @(posedge clk) begin
    if (reset) begin
        rom_loaded <= 1'b0;
    end else if (loader_done && !loader_error) begin
        rom_loaded <= 1'b1;
    end
end

always @(*) begin
    rom_map = 256'd0;
    if (rom_loaded) begin
        rom_map[ROM_SELECT_BASIC] = 1'b1;
        if (model != 2'd2) begin
            rom_map[ROM_SELECT_AMSDOS] = 1'b1;
        end
        if (custom_rom_enable) begin
            rom_map[ROM_SELECT_CUSTOM] = 1'b1;
        end
    end

    if (cpu_io_rd) begin
        cpu_din = 8'hff;
    end else begin
        case (mem_page)
            PAGE_ROM_OS:     cpu_din = rom_loaded ? rom_os_q     : 8'hff;
            PAGE_ROM_BASIC:  cpu_din = rom_loaded ? rom_basic_q  : 8'hff;
            PAGE_ROM_AMSDOS: cpu_din = rom_loaded ? rom_amsdos_q : 8'hff;
            PAGE_ROM_CUSTOM: cpu_din = custom_rom_enable ? rom_custom_q : 8'hff;
            default: begin
                if (ram_selected) begin
                    cpu_din = ram_addr[0] ? ram_cpu_odd_q : ram_cpu_even_q;
                end else begin
                    cpu_din = 8'hff;
                end
            end
        endcase
    end

    vram_din = {ram_vram_odd_q, ram_vram_even_q};
end

endmodule

`default_nettype wire
