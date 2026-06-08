// Simple hardware virtual keyboard overlay for the Pocket CPC core.

`default_nettype none

module cpc_virtual_keyboard_overlay (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        ce,
    input  wire        de,
    input  wire        vs,
    input  wire [23:0] rgb_in,
    input  wire        active,
    input  wire [5:0]  selected_index,
    input  wire [1:0]  page,
    input  wire        shift_active,

    output reg  [23:0] rgb_out
);

localparam [9:0] X0    = 10'd64;
localparam [8:0] Y0    = 9'd168;
localparam [9:0] X1    = X0 + 10'd640;
localparam [8:0] Y1    = Y0 + 9'd64;
localparam [5:0] GLYPH_X = 6'd27;
localparam [3:0] GLYPH_Y = 4'd1;

reg [9:0] x = 10'd0;
reg [8:0] y = 9'd0;
reg       de_prev = 1'b0;
reg       vs_prev = 1'b0;

wire       in_band = active && de && (x >= X0) && (x < X1) && (y >= Y0) && (y < Y1);
wire [9:0] band_x  = x - X0;
wire [8:0] band_y  = y - Y0;
wire [3:0] key_col = band_x[9:6];
wire [1:0] key_row = band_y[5:4];
wire [5:0] key_idx = ({4'd0, key_row} * 6'd10) + {2'd0, key_col};
wire [5:0] local_x = band_x[5:0];
wire [3:0] local_y = band_y[3:0];
wire       selected = key_idx == selected_index;
wire       shift_cell = (page == 2'd1) && (key_idx == 6'd4);
wire       border = (local_x == 6'd0) || (local_x == 6'd63) ||
                    (local_y == 4'd0) || (local_y == 4'd15);
wire [5:0] glyph_x_off = local_x - GLYPH_X;
wire [3:0] glyph_y_off = local_y - GLYPH_Y;

wire       glyph_region = (local_x >= GLYPH_X) && (local_x < GLYPH_X + 6'd10) &&
                          (local_y >= GLYPH_Y) && (local_y < GLYPH_Y + 4'd14);
wire [2:0] glyph_col = glyph_x_off[3:1];
wire [2:0] glyph_row = glyph_y_off[3:1];
wire [7:0] glyph_char = key_index_to_char(key_idx, page, shift_active);
wire [10:0] glyph_addr = {glyph_char, glyph_row};
wire [23:0] key_fill = (shift_active && shift_cell) ? 24'h604800 : 24'h202020;
wire [23:0] key_border = (shift_active && shift_cell) ? 24'hffd000 : 24'h606060;

reg [4:0] font_rom [0:2047];
reg [4:0] font_bits_r = 5'b00000;

reg        in_band_s1 = 1'b0;
reg        selected_s1 = 1'b0;
reg        border_s1 = 1'b0;
reg        glyph_region_s1 = 1'b0;
reg [2:0]  glyph_col_s1 = 3'd0;
reg [23:0] key_fill_s1 = 24'h202020;
reg [23:0] key_border_s1 = 24'h606060;
reg [23:0] rgb_in_s1 = 24'h000000;

reg        in_band_s2 = 1'b0;
reg        glyph_on_s2 = 1'b0;
reg        selected_s2 = 1'b0;
reg        border_s2 = 1'b0;
reg [23:0] key_fill_s2 = 24'h202020;
reg [23:0] key_border_s2 = 24'h606060;
reg [23:0] rgb_in_s2 = 24'h000000;

task set_glyph;
    input [7:0] ch;
    input [4:0] r0;
    input [4:0] r1;
    input [4:0] r2;
    input [4:0] r3;
    input [4:0] r4;
    input [4:0] r5;
    input [4:0] r6;
    begin
        font_rom[{ch, 3'd0}] = r0;
        font_rom[{ch, 3'd1}] = r1;
        font_rom[{ch, 3'd2}] = r2;
        font_rom[{ch, 3'd3}] = r3;
        font_rom[{ch, 3'd4}] = r4;
        font_rom[{ch, 3'd5}] = r5;
        font_rom[{ch, 3'd6}] = r6;
    end
endtask

integer font_i;
initial begin
    for (font_i = 0; font_i < 2048; font_i = font_i + 1) begin
        font_rom[font_i] = 5'b00000;
    end

    set_glyph(8'h21, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00000, 5'b00100);
    set_glyph(8'h22, 5'b01010, 5'b01010, 5'b01010, 5'b00000, 5'b00000, 5'b00000, 5'b00000);
    set_glyph(8'h24, 5'b00100, 5'b01111, 5'b10100, 5'b01110, 5'b00101, 5'b11110, 5'b00100);
    set_glyph(8'h25, 5'b11001, 5'b11010, 5'b00010, 5'b00100, 5'b01000, 5'b01011, 5'b10011);
    set_glyph(8'h26, 5'b01100, 5'b10010, 5'b10100, 5'b01000, 5'b10101, 5'b10010, 5'b01101);
    set_glyph(8'h27, 5'b00100, 5'b00100, 5'b01000, 5'b00000, 5'b00000, 5'b00000, 5'b00000);
    set_glyph(8'h28, 5'b00010, 5'b00100, 5'b01000, 5'b01000, 5'b01000, 5'b00100, 5'b00010);
    set_glyph(8'h29, 5'b01000, 5'b00100, 5'b00010, 5'b00010, 5'b00010, 5'b00100, 5'b01000);
    set_glyph(8'h2A, 5'b00000, 5'b10101, 5'b01110, 5'b11111, 5'b01110, 5'b10101, 5'b00000);
    set_glyph(8'h2B, 5'b00000, 5'b00100, 5'b00100, 5'b11111, 5'b00100, 5'b00100, 5'b00000);
    set_glyph(8'h2C, 5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b00100, 5'b00100, 5'b01000);
    set_glyph(8'h2D, 5'b00000, 5'b00000, 5'b00000, 5'b11111, 5'b00000, 5'b00000, 5'b00000);
    set_glyph(8'h2E, 5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b01100, 5'b01100);
    set_glyph(8'h2F, 5'b00001, 5'b00010, 5'b00010, 5'b00100, 5'b01000, 5'b01000, 5'b10000);
    set_glyph(8'h30, 5'b01110, 5'b10001, 5'b10011, 5'b10101, 5'b11001, 5'b10001, 5'b01110);
    set_glyph(8'h31, 5'b00100, 5'b01100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b01110);
    set_glyph(8'h32, 5'b01110, 5'b10001, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b11111);
    set_glyph(8'h33, 5'b11110, 5'b00001, 5'b00001, 5'b01110, 5'b00001, 5'b00001, 5'b11110);
    set_glyph(8'h34, 5'b00010, 5'b00110, 5'b01010, 5'b10010, 5'b11111, 5'b00010, 5'b00010);
    set_glyph(8'h35, 5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b00001, 5'b00001, 5'b11110);
    set_glyph(8'h36, 5'b01110, 5'b10000, 5'b10000, 5'b11110, 5'b10001, 5'b10001, 5'b01110);
    set_glyph(8'h37, 5'b11111, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b01000, 5'b01000);
    set_glyph(8'h38, 5'b01110, 5'b10001, 5'b10001, 5'b01110, 5'b10001, 5'b10001, 5'b01110);
    set_glyph(8'h39, 5'b01110, 5'b10001, 5'b10001, 5'b01111, 5'b00001, 5'b00001, 5'b01110);
    set_glyph(8'h3A, 5'b00000, 5'b00100, 5'b00100, 5'b00000, 5'b00100, 5'b00100, 5'b00000);
    set_glyph(8'h3B, 5'b00000, 5'b00100, 5'b00100, 5'b00000, 5'b00100, 5'b00100, 5'b01000);
    set_glyph(8'h3C, 5'b00010, 5'b00100, 5'b01000, 5'b10000, 5'b01000, 5'b00100, 5'b00010);
    set_glyph(8'h3E, 5'b01000, 5'b00100, 5'b00010, 5'b00001, 5'b00010, 5'b00100, 5'b01000);
    set_glyph(8'h3F, 5'b01110, 5'b10001, 5'b00001, 5'b00010, 5'b00100, 5'b00000, 5'b00100);
    set_glyph(8'h40, 5'b01110, 5'b10001, 5'b10111, 5'b10101, 5'b10111, 5'b10000, 5'b01110);
    set_glyph(8'h41, 5'b01110, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001);
    set_glyph(8'h42, 5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10001, 5'b10001, 5'b11110);
    set_glyph(8'h43, 5'b01110, 5'b10001, 5'b10000, 5'b10000, 5'b10000, 5'b10001, 5'b01110);
    set_glyph(8'h44, 5'b11110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b11110);
    set_glyph(8'h45, 5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b11111);
    set_glyph(8'h46, 5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b10000);
    set_glyph(8'h47, 5'b01110, 5'b10001, 5'b10000, 5'b10111, 5'b10001, 5'b10001, 5'b01110);
    set_glyph(8'h48, 5'b10001, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001);
    set_glyph(8'h49, 5'b01110, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b01110);
    set_glyph(8'h4A, 5'b00111, 5'b00010, 5'b00010, 5'b00010, 5'b10010, 5'b10010, 5'b01100);
    set_glyph(8'h4B, 5'b10001, 5'b10010, 5'b10100, 5'b11000, 5'b10100, 5'b10010, 5'b10001);
    set_glyph(8'h4C, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b11111);
    set_glyph(8'h4D, 5'b10001, 5'b11011, 5'b10101, 5'b10101, 5'b10001, 5'b10001, 5'b10001);
    set_glyph(8'h4E, 5'b10001, 5'b11001, 5'b10101, 5'b10011, 5'b10001, 5'b10001, 5'b10001);
    set_glyph(8'h4F, 5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110);
    set_glyph(8'h50, 5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10000, 5'b10000, 5'b10000);
    set_glyph(8'h51, 5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10101, 5'b10010, 5'b01101);
    set_glyph(8'h52, 5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10100, 5'b10010, 5'b10001);
    set_glyph(8'h53, 5'b01111, 5'b10000, 5'b10000, 5'b01110, 5'b00001, 5'b00001, 5'b11110);
    set_glyph(8'h54, 5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100);
    set_glyph(8'h55, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110);
    set_glyph(8'h56, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01010, 5'b00100);
    set_glyph(8'h57, 5'b10001, 5'b10001, 5'b10001, 5'b10101, 5'b10101, 5'b10101, 5'b01010);
    set_glyph(8'h58, 5'b10001, 5'b10001, 5'b01010, 5'b00100, 5'b01010, 5'b10001, 5'b10001);
    set_glyph(8'h59, 5'b10001, 5'b10001, 5'b01010, 5'b00100, 5'b00100, 5'b00100, 5'b00100);
    set_glyph(8'h5A, 5'b11111, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b10000, 5'b11111);
    set_glyph(8'h5B, 5'b01110, 5'b01000, 5'b01000, 5'b01000, 5'b01000, 5'b01000, 5'b01110);
    set_glyph(8'h5C, 5'b10000, 5'b01000, 5'b01000, 5'b00100, 5'b00010, 5'b00010, 5'b00001);
    set_glyph(8'h5D, 5'b01110, 5'b00010, 5'b00010, 5'b00010, 5'b00010, 5'b00010, 5'b01110);
    set_glyph(8'h5E, 5'b00100, 5'b01010, 5'b10001, 5'b00000, 5'b00000, 5'b00000, 5'b00000);
    set_glyph(8'h5F, 5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b11111);
    set_glyph(8'h7C, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100);
    set_glyph(8'hA3, 5'b00110, 5'b01001, 5'b01000, 5'b11110, 5'b01000, 5'b10001, 5'b11110);
end

function [7:0] key_index_to_char;
    input [5:0] key_index;
    input [1:0] key_page;
    input       key_shift;
    begin
        key_index_to_char = 8'h20;
        case (key_page)
            2'd0: begin
                case (key_index)
                    6'd0:  key_index_to_char = key_shift ? 8'h21 : 8'h31;
                    6'd1:  key_index_to_char = key_shift ? 8'h22 : 8'h32;
                    6'd2:  key_index_to_char = key_shift ? 8'hA3 : 8'h33;
                    6'd3:  key_index_to_char = key_shift ? 8'h24 : 8'h34;
                    6'd4:  key_index_to_char = key_shift ? 8'h25 : 8'h35;
                    6'd5:  key_index_to_char = key_shift ? 8'h5E : 8'h36;
                    6'd6:  key_index_to_char = key_shift ? 8'h26 : 8'h37;
                    6'd7:  key_index_to_char = key_shift ? 8'h2A : 8'h38;
                    6'd8:  key_index_to_char = key_shift ? 8'h28 : 8'h39;
                    6'd9:  key_index_to_char = key_shift ? 8'h29 : 8'h30;
                    6'd10: key_index_to_char = 8'h51;
                    6'd11: key_index_to_char = 8'h57;
                    6'd12: key_index_to_char = 8'h45;
                    6'd13: key_index_to_char = 8'h52;
                    6'd14: key_index_to_char = 8'h54;
                    6'd15: key_index_to_char = 8'h59;
                    6'd16: key_index_to_char = 8'h55;
                    6'd17: key_index_to_char = 8'h49;
                    6'd18: key_index_to_char = 8'h4F;
                    6'd19: key_index_to_char = 8'h50;
                    6'd20: key_index_to_char = 8'h41;
                    6'd21: key_index_to_char = 8'h53;
                    6'd22: key_index_to_char = 8'h44;
                    6'd23: key_index_to_char = 8'h46;
                    6'd24: key_index_to_char = 8'h47;
                    6'd25: key_index_to_char = 8'h48;
                    6'd26: key_index_to_char = 8'h4A;
                    6'd27: key_index_to_char = 8'h4B;
                    6'd28: key_index_to_char = 8'h4C;
                    6'd29: key_index_to_char = key_shift ? 8'h27 : 8'h3A;
                    6'd30: key_index_to_char = 8'h5A;
                    6'd31: key_index_to_char = 8'h58;
                    6'd32: key_index_to_char = 8'h43;
                    6'd33: key_index_to_char = 8'h56;
                    6'd34: key_index_to_char = 8'h42;
                    6'd35: key_index_to_char = 8'h4E;
                    6'd36: key_index_to_char = 8'h4D;
                    6'd37: key_index_to_char = key_shift ? 8'h3C : 8'h2C;
                    6'd38: key_index_to_char = key_shift ? 8'h3E : 8'h2E;
                    6'd39: key_index_to_char = key_shift ? 8'h3F : 8'h2F;
                    default: key_index_to_char = 8'h20;
                endcase
            end
            2'd1: begin
                case (key_index)
                    6'd0:  key_index_to_char = 8'h45; // Esc
                    6'd1:  key_index_to_char = 8'h54; // Tab
                    6'd2:  key_index_to_char = 8'h4B; // Caps
                    6'd3:  key_index_to_char = 8'h43; // Ctrl
                    6'd4:  key_index_to_char = 8'h53; // Shift
                    6'd5:  key_index_to_char = 8'h52; // Return
                    6'd6:  key_index_to_char = 8'h44; // Del
                    6'd7:  key_index_to_char = 8'h20; // Space
                    6'd8:  key_index_to_char = 8'h50; // Copy
                    6'd9:  key_index_to_char = 8'h4C; // CLR
                    6'd10: key_index_to_char = 8'h40;
                    6'd11: key_index_to_char = key_shift ? 8'h5D : 8'h5B;
                    6'd12: key_index_to_char = key_shift ? 8'h5C : 8'h5D;
                    6'd13: key_index_to_char = key_shift ? 8'h7C : 8'h5C;
                    6'd14: key_index_to_char = key_shift ? 8'h5F : 8'h2D;
                    6'd15: key_index_to_char = 8'h2B;
                    6'd16: key_index_to_char = key_shift ? 8'h3A : 8'h3B;
                    6'd17: key_index_to_char = key_shift ? 8'h27 : 8'h3A;
                    6'd18: key_index_to_char = key_shift ? 8'h3F : 8'h2F;
                    6'd19: key_index_to_char = key_shift ? 8'h3E : 8'h2E;
                    6'd20: key_index_to_char = key_shift ? 8'h3C : 8'h2C;
                    default: key_index_to_char = 8'h20;
                endcase
            end
            2'd2: begin
                case (key_index)
                    6'd0:  key_index_to_char = 8'h30; // F0
                    6'd1:  key_index_to_char = 8'h31; // F1
                    6'd2:  key_index_to_char = 8'h32; // F2
                    6'd3:  key_index_to_char = 8'h33; // F3
                    6'd4:  key_index_to_char = 8'h34; // F4
                    6'd5:  key_index_to_char = 8'h35; // F5
                    6'd6:  key_index_to_char = 8'h36; // F6
                    6'd7:  key_index_to_char = 8'h37; // F7
                    6'd8:  key_index_to_char = 8'h38; // F8
                    6'd9:  key_index_to_char = 8'h39; // F9
                    6'd10: key_index_to_char = 8'h55; // Up
                    6'd11: key_index_to_char = 8'h4C; // Left
                    6'd12: key_index_to_char = 8'h44; // Down
                    6'd13: key_index_to_char = 8'h52; // Right
                    6'd14: key_index_to_char = 8'h45; // keypad Enter
                    6'd15: key_index_to_char = 8'h2E; // keypad .
                    6'd16: key_index_to_char = 8'h50; // Copy
                    6'd17: key_index_to_char = 8'h43; // CLR
                    default: key_index_to_char = 8'h20;
                endcase
            end
            default: key_index_to_char = 8'h20;
        endcase
    end
endfunction

function [4:0] glyph_row_bits;
    input [7:0] ch;
    input [2:0] row;
    begin
        glyph_row_bits = 5'b00000;
        case (ch)
            8'h30: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10011; 3'd3: glyph_row_bits = 5'b10101; 3'd4: glyph_row_bits = 5'b11001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h31: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b01100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h32: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b00001; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b11111; default: glyph_row_bits = 5'b00000; endcase
            8'h33: case (row) 3'd0: glyph_row_bits = 5'b11110; 3'd1: glyph_row_bits = 5'b00001; 3'd2: glyph_row_bits = 5'b00001; 3'd3: glyph_row_bits = 5'b01110; 3'd4: glyph_row_bits = 5'b00001; 3'd5: glyph_row_bits = 5'b00001; 3'd6: glyph_row_bits = 5'b11110; default: glyph_row_bits = 5'b00000; endcase
            8'h34: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00110; 3'd2: glyph_row_bits = 5'b01010; 3'd3: glyph_row_bits = 5'b10010; 3'd4: glyph_row_bits = 5'b11111; 3'd5: glyph_row_bits = 5'b00010; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h35: case (row) 3'd0: glyph_row_bits = 5'b11111; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b10000; 3'd3: glyph_row_bits = 5'b11110; 3'd4: glyph_row_bits = 5'b00001; 3'd5: glyph_row_bits = 5'b00001; 3'd6: glyph_row_bits = 5'b11110; default: glyph_row_bits = 5'b00000; endcase
            8'h36: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b10000; 3'd3: glyph_row_bits = 5'b11110; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h37: case (row) 3'd0: glyph_row_bits = 5'b11111; 3'd1: glyph_row_bits = 5'b00001; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h38: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b01110; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h39: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b01111; 3'd4: glyph_row_bits = 5'b00001; 3'd5: glyph_row_bits = 5'b00001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h21: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h22: case (row) 3'd0: glyph_row_bits = 5'b01010; 3'd1: glyph_row_bits = 5'b01010; 3'd2: glyph_row_bits = 5'b01010; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h24: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b01111; 3'd2: glyph_row_bits = 5'b10100; 3'd3: glyph_row_bits = 5'b01110; 3'd4: glyph_row_bits = 5'b00101; 3'd5: glyph_row_bits = 5'b11110; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h25: case (row) 3'd0: glyph_row_bits = 5'b11001; 3'd1: glyph_row_bits = 5'b11010; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01011; 3'd6: glyph_row_bits = 5'b10011; default: glyph_row_bits = 5'b00000; endcase
            8'h26: case (row) 3'd0: glyph_row_bits = 5'b01100; 3'd1: glyph_row_bits = 5'b10010; 3'd2: glyph_row_bits = 5'b10100; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b10101; 3'd5: glyph_row_bits = 5'b10010; 3'd6: glyph_row_bits = 5'b01101; default: glyph_row_bits = 5'b00000; endcase
            8'h27: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h28: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h29: case (row) 3'd0: glyph_row_bits = 5'b01000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h2A: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b10101; 3'd2: glyph_row_bits = 5'b01110; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b01110; 3'd5: glyph_row_bits = 5'b10101; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h2B: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h2D: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h41: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h42: case (row) 3'd0: glyph_row_bits = 5'b11110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b11110; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b11110; default: glyph_row_bits = 5'b00000; endcase
            8'h43: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10000; 3'd3: glyph_row_bits = 5'b10000; 3'd4: glyph_row_bits = 5'b10000; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h44: case (row) 3'd0: glyph_row_bits = 5'b11110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b11110; default: glyph_row_bits = 5'b00000; endcase
            8'h45: case (row) 3'd0: glyph_row_bits = 5'b11111; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b10000; 3'd3: glyph_row_bits = 5'b11110; 3'd4: glyph_row_bits = 5'b10000; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b11111; default: glyph_row_bits = 5'b00000; endcase
            8'h46: case (row) 3'd0: glyph_row_bits = 5'b11111; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b10000; 3'd3: glyph_row_bits = 5'b11110; 3'd4: glyph_row_bits = 5'b10000; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b10000; default: glyph_row_bits = 5'b00000; endcase
            8'h47: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10000; 3'd3: glyph_row_bits = 5'b10111; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h48: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h49: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h4A: case (row) 3'd0: glyph_row_bits = 5'b00111; 3'd1: glyph_row_bits = 5'b00010; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b10010; 3'd5: glyph_row_bits = 5'b10010; 3'd6: glyph_row_bits = 5'b01100; default: glyph_row_bits = 5'b00000; endcase
            8'h4B: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b10010; 3'd2: glyph_row_bits = 5'b10100; 3'd3: glyph_row_bits = 5'b11000; 3'd4: glyph_row_bits = 5'b10100; 3'd5: glyph_row_bits = 5'b10010; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h4C: case (row) 3'd0: glyph_row_bits = 5'b10000; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b10000; 3'd3: glyph_row_bits = 5'b10000; 3'd4: glyph_row_bits = 5'b10000; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b11111; default: glyph_row_bits = 5'b00000; endcase
            8'h4D: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b11011; 3'd2: glyph_row_bits = 5'b10101; 3'd3: glyph_row_bits = 5'b10101; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h4E: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b11001; 3'd2: glyph_row_bits = 5'b10101; 3'd3: glyph_row_bits = 5'b10011; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h4F: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h50: case (row) 3'd0: glyph_row_bits = 5'b11110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b11110; 3'd4: glyph_row_bits = 5'b10000; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b10000; default: glyph_row_bits = 5'b00000; endcase
            8'h51: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10101; 3'd5: glyph_row_bits = 5'b10010; 3'd6: glyph_row_bits = 5'b01101; default: glyph_row_bits = 5'b00000; endcase
            8'h52: case (row) 3'd0: glyph_row_bits = 5'b11110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b11110; 3'd4: glyph_row_bits = 5'b10100; 3'd5: glyph_row_bits = 5'b10010; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h53: case (row) 3'd0: glyph_row_bits = 5'b01111; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b10000; 3'd3: glyph_row_bits = 5'b01110; 3'd4: glyph_row_bits = 5'b00001; 3'd5: glyph_row_bits = 5'b00001; 3'd6: glyph_row_bits = 5'b11110; default: glyph_row_bits = 5'b00000; endcase
            8'h54: case (row) 3'd0: glyph_row_bits = 5'b11111; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h55: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h56: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b01010; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h57: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10101; 3'd4: glyph_row_bits = 5'b10101; 3'd5: glyph_row_bits = 5'b10101; 3'd6: glyph_row_bits = 5'b01010; default: glyph_row_bits = 5'b00000; endcase
            8'h58: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b01010; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b01010; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h59: case (row) 3'd0: glyph_row_bits = 5'b10001; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b01010; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h5A: case (row) 3'd0: glyph_row_bits = 5'b11111; 3'd1: glyph_row_bits = 5'b00001; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b11111; default: glyph_row_bits = 5'b00000; endcase
            8'h3B: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h3A: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h3C: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b10000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h3E: case (row) 3'd0: glyph_row_bits = 5'b01000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00001; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h3F: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b00001; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h2C: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h2E: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b01100; 3'd6: glyph_row_bits = 5'b01100; default: glyph_row_bits = 5'b00000; endcase
            8'h2F: case (row) 3'd0: glyph_row_bits = 5'b00001; 3'd1: glyph_row_bits = 5'b00010; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b10000; default: glyph_row_bits = 5'b00000; endcase
            8'h40: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10111; 3'd3: glyph_row_bits = 5'b10101; 3'd4: glyph_row_bits = 5'b10111; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h5B: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b01000; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h5C: case (row) 3'd0: glyph_row_bits = 5'b10000; 3'd1: glyph_row_bits = 5'b01000; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00010; 3'd6: glyph_row_bits = 5'b00001; default: glyph_row_bits = 5'b00000; endcase
            8'h5D: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b00010; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00010; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h5E: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b01010; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h5F: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b11111; default: glyph_row_bits = 5'b00000; endcase
            8'h7C: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'hA3: case (row) 3'd0: glyph_row_bits = 5'b00110; 3'd1: glyph_row_bits = 5'b01001; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b11110; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b11110; default: glyph_row_bits = 5'b00000; endcase
            default: glyph_row_bits = 5'b00000;
        endcase
    end
endfunction

always @(posedge clk) begin
    if (!reset_n) begin
	        x            <= 10'd0;
	        y            <= 9'd0;
	        de_prev      <= 1'b0;
	        vs_prev      <= 1'b0;
	        font_bits_r  <= 5'b00000;
	        in_band_s1   <= 1'b0;
	        selected_s1  <= 1'b0;
	        border_s1    <= 1'b0;
	        glyph_region_s1 <= 1'b0;
	        glyph_col_s1 <= 3'd0;
	        key_fill_s1  <= 24'h202020;
	        key_border_s1 <= 24'h606060;
	        rgb_in_s1    <= 24'h000000;
	        in_band_s2   <= 1'b0;
	        glyph_on_s2  <= 1'b0;
	        selected_s2  <= 1'b0;
	        border_s2    <= 1'b0;
	        key_fill_s2  <= 24'h202020;
	        key_border_s2 <= 24'h606060;
	        rgb_in_s2    <= 24'h000000;
	        rgb_out      <= 24'h000000;
	    end else if (ce) begin
        if (!vs_prev && vs) begin
            y <= 9'd0;
        end

        if (de) begin
            if (!de_prev) x <= 10'd0;
            else x <= x + 10'd1;
        end else if (de_prev) begin
            y <= y + 9'd1;
        end

	        de_prev <= de;
	        vs_prev <= vs;

	        font_bits_r <= font_rom[glyph_addr];

	        in_band_s1      <= in_band;
	        selected_s1     <= selected;
	        border_s1       <= border;
	        glyph_region_s1 <= glyph_region;
	        glyph_col_s1    <= glyph_col;
	        key_fill_s1     <= key_fill;
	        key_border_s1   <= key_border;
	        rgb_in_s1       <= rgb_in;

	        in_band_s2    <= in_band_s1;
	        selected_s2   <= selected_s1;
	        border_s2     <= border_s1;
	        key_fill_s2   <= key_fill_s1;
	        key_border_s2 <= key_border_s1;
	        rgb_in_s2     <= rgb_in_s1;
	        case (glyph_col_s1)
	            3'd0: glyph_on_s2 <= glyph_region_s1 && font_bits_r[4];
	            3'd1: glyph_on_s2 <= glyph_region_s1 && font_bits_r[3];
	            3'd2: glyph_on_s2 <= glyph_region_s1 && font_bits_r[2];
	            3'd3: glyph_on_s2 <= glyph_region_s1 && font_bits_r[1];
	            3'd4: glyph_on_s2 <= glyph_region_s1 && font_bits_r[0];
	            default: glyph_on_s2 <= 1'b0;
	        endcase

	        if (in_band_s2 && glyph_on_s2) rgb_out <= selected_s2 ? 24'h000000 : 24'hffffff;
	        else if (in_band_s2 && border_s2) rgb_out <= selected_s2 ? 24'hffffff : key_border_s2;
	        else if (in_band_s2) rgb_out <= selected_s2 ? 24'hffd000 : key_fill_s2;
	        else rgb_out <= rgb_in_s2;
	    end
	end

endmodule

`default_nettype wire
