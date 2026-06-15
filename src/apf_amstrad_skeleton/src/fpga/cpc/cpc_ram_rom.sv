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

    input  wire        loader_wr,
    input  wire [15:0] loader_addr,
    input  wire [7:0]  loader_data,
    input  wire        loader_done,
    input  wire        loader_error,
    output reg         rom_loaded,
    output reg  [255:0] rom_map
);

localparam [8:0] PAGE_ROM_OS     = 9'h000;
localparam [8:0] PAGE_ROM_BASIC  = 9'h100;
localparam [8:0] PAGE_ROM_AMSDOS = 9'h107;
localparam [7:0] ROM_SELECT_BASIC  = 8'h00;
localparam [7:0] ROM_SELECT_AMSDOS = 8'h07;

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
wire [7:0] rom_os_q;
wire [7:0] rom_basic_q;
wire [7:0] rom_amsdos_q;

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(16)
) cpc_ram_even (
    .clock     ( clk ),
    .address_a ( ram_word_addr ),
    .data_a    ( cpu_dout ),
    .wren_a    ( mem_wr && ram_selected && !ram_addr[0] ),
    .q_a       ( ram_cpu_even_q ),
    .address_b ( vram_word_addr ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( ram_vram_even_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(16)
) cpc_ram_odd (
    .clock     ( clk ),
    .address_a ( ram_word_addr ),
    .data_a    ( cpu_dout ),
    .wren_a    ( mem_wr && ram_selected && ram_addr[0] ),
    .q_a       ( ram_cpu_odd_q ),
    .address_b ( vram_word_addr ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( ram_vram_odd_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_os (
    .clock     ( clk ),
    .address_a ( loader_addr[13:0] ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_addr[15:14] == 2'd0) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_os_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_basic (
    .clock     ( clk ),
    .address_a ( loader_addr[13:0] ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_addr[15:14] == 2'd1) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_basic_q )
);

dpram #(
    .DATAWIDTH(8),
    .ADDRWIDTH(14)
) rom_amsdos (
    .clock     ( clk ),
    .address_a ( loader_addr[13:0] ),
    .data_a    ( loader_data ),
    .wren_a    ( loader_wr && (loader_addr[15:14] == 2'd2) ),
    .q_a       ( ),
    .address_b ( mem_offset ),
    .data_b    ( 8'd0 ),
    .wren_b    ( 1'b0 ),
    .q_b       ( rom_amsdos_q )
);

always @(posedge clk) begin
    if (reset) begin
        rom_loaded <= 1'b0;
        rom_map    <= 256'd0;
    end else if (loader_done && !loader_error) begin
        rom_loaded <= 1'b1;
        rom_map[ROM_SELECT_BASIC]  <= 1'b1;
        rom_map[ROM_SELECT_AMSDOS] <= 1'b1;
    end
end

always @(*) begin
    if (cpu_io_rd) begin
        cpu_din = 8'hff;
    end else begin
        case (mem_page)
            PAGE_ROM_OS:     cpu_din = rom_loaded ? rom_os_q     : 8'hff;
            PAGE_ROM_BASIC:  cpu_din = rom_loaded ? rom_basic_q  : 8'hff;
            PAGE_ROM_AMSDOS: cpu_din = rom_loaded ? rom_amsdos_q : 8'hff;
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
