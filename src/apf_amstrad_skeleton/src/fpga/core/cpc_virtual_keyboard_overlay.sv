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
wire [1:0] glyph_page = (shift_active && (page == 2'd0)) ? 2'd3 : page;
wire [7:0] glyph_char = key_index_to_char(key_idx, glyph_page);
wire [4:0] glyph_bits = glyph_row_bits(glyph_char, glyph_row);
wire       glyph_on = glyph_region && glyph_bits[3'd4 - glyph_col];
wire [23:0] key_fill = (shift_active && shift_cell) ? 24'h604800 : 24'h202020;
wire [23:0] key_border = (shift_active && shift_cell) ? 24'hffd000 : 24'h606060;

reg        in_band_r = 1'b0;
reg        glyph_on_r = 1'b0;
reg        selected_r = 1'b0;
reg        border_r = 1'b0;
reg [23:0] key_fill_r = 24'h202020;
reg [23:0] key_border_r = 24'h606060;
reg [23:0] rgb_in_r = 24'h000000;

function [7:0] key_index_to_char;
    input [5:0] key_index;
    input [1:0] key_page;
    begin
        key_index_to_char = 8'h20;
        case (key_page)
            2'd0: begin
                case (key_index)
                    6'd0:  key_index_to_char = 8'h31;
                    6'd1:  key_index_to_char = 8'h32;
                    6'd2:  key_index_to_char = 8'h33;
                    6'd3:  key_index_to_char = 8'h34;
                    6'd4:  key_index_to_char = 8'h35;
                    6'd5:  key_index_to_char = 8'h36;
                    6'd6:  key_index_to_char = 8'h37;
                    6'd7:  key_index_to_char = 8'h38;
                    6'd8:  key_index_to_char = 8'h39;
                    6'd9:  key_index_to_char = 8'h30;
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
                    6'd29: key_index_to_char = 8'h3B;
                    6'd30: key_index_to_char = 8'h5A;
                    6'd31: key_index_to_char = 8'h58;
                    6'd32: key_index_to_char = 8'h43;
                    6'd33: key_index_to_char = 8'h56;
                    6'd34: key_index_to_char = 8'h42;
                    6'd35: key_index_to_char = 8'h4E;
                    6'd36: key_index_to_char = 8'h4D;
                    6'd37: key_index_to_char = 8'h2C;
                    6'd38: key_index_to_char = 8'h2E;
                    6'd39: key_index_to_char = 8'h2F;
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
                    6'd11: key_index_to_char = 8'h5B;
                    6'd12: key_index_to_char = 8'h5D;
                    6'd13: key_index_to_char = 8'h5C;
                    6'd14: key_index_to_char = 8'h2D;
                    6'd15: key_index_to_char = 8'h2B;
                    6'd16: key_index_to_char = 8'h3B;
                    6'd17: key_index_to_char = 8'h3A;
                    6'd18: key_index_to_char = 8'h2F;
                    6'd19: key_index_to_char = 8'h2E;
                    6'd20: key_index_to_char = 8'h2C;
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
            2'd3: begin
                case (key_index)
                    6'd0:  key_index_to_char = 8'h21; // !
                    6'd1:  key_index_to_char = 8'h22; // "
                    6'd2:  key_index_to_char = 8'hA3; // pound
                    6'd3:  key_index_to_char = 8'h24; // $
                    6'd4:  key_index_to_char = 8'h25; // %
                    6'd5:  key_index_to_char = 8'h5E; // ^
                    6'd6:  key_index_to_char = 8'h26; // &
                    6'd7:  key_index_to_char = 8'h2A; // *
                    6'd8:  key_index_to_char = 8'h28; // (
                    6'd9:  key_index_to_char = 8'h29; // )
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
                    6'd29: key_index_to_char = 8'h3A; // :
                    6'd30: key_index_to_char = 8'h5A;
                    6'd31: key_index_to_char = 8'h58;
                    6'd32: key_index_to_char = 8'h43;
                    6'd33: key_index_to_char = 8'h56;
                    6'd34: key_index_to_char = 8'h42;
                    6'd35: key_index_to_char = 8'h4E;
                    6'd36: key_index_to_char = 8'h4D;
                    6'd37: key_index_to_char = 8'h3C; // <
                    6'd38: key_index_to_char = 8'h3E; // >
                    6'd39: key_index_to_char = 8'h3F; // ?
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
            8'h2B: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h2D: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h21: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h22: case (row) 3'd0: glyph_row_bits = 5'b01010; 3'd1: glyph_row_bits = 5'b01010; 3'd2: glyph_row_bits = 5'b01010; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h24: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b01111; 3'd2: glyph_row_bits = 5'b10100; 3'd3: glyph_row_bits = 5'b01110; 3'd4: glyph_row_bits = 5'b00101; 3'd5: glyph_row_bits = 5'b11110; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h25: case (row) 3'd0: glyph_row_bits = 5'b11001; 3'd1: glyph_row_bits = 5'b11010; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b10110; 3'd5: glyph_row_bits = 5'b00110; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h26: case (row) 3'd0: glyph_row_bits = 5'b01100; 3'd1: glyph_row_bits = 5'b10010; 3'd2: glyph_row_bits = 5'b10100; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b10101; 3'd5: glyph_row_bits = 5'b10010; 3'd6: glyph_row_bits = 5'b01101; default: glyph_row_bits = 5'b00000; endcase
            8'h28: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h29: case (row) 3'd0: glyph_row_bits = 5'b01000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h2A: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b10101; 3'd2: glyph_row_bits = 5'b01110; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b01110; 3'd5: glyph_row_bits = 5'b10101; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h3C: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b10000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h3E: case (row) 3'd0: glyph_row_bits = 5'b01000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00001; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h3F: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b00001; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h5E: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b01010; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'hA3: case (row) 3'd0: glyph_row_bits = 5'b00110; 3'd1: glyph_row_bits = 5'b01001; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b11100; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b11111; default: glyph_row_bits = 5'b00000; endcase
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
            8'h2C: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h2E: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b01100; 3'd6: glyph_row_bits = 5'b01100; default: glyph_row_bits = 5'b00000; endcase
            8'h2F: case (row) 3'd0: glyph_row_bits = 5'b00001; 3'd1: glyph_row_bits = 5'b00010; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b10000; default: glyph_row_bits = 5'b00000; endcase
            8'h40: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10111; 3'd3: glyph_row_bits = 5'b10101; 3'd4: glyph_row_bits = 5'b10111; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h5B: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b01000; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h5C: case (row) 3'd0: glyph_row_bits = 5'b10000; 3'd1: glyph_row_bits = 5'b01000; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00010; 3'd6: glyph_row_bits = 5'b00001; default: glyph_row_bits = 5'b00000; endcase
            8'h5D: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b00010; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00010; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
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
        in_band_r    <= 1'b0;
        glyph_on_r   <= 1'b0;
        selected_r   <= 1'b0;
        border_r     <= 1'b0;
        key_fill_r   <= 24'h202020;
        key_border_r <= 24'h606060;
        rgb_in_r     <= 24'h000000;
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

        in_band_r    <= in_band;
        glyph_on_r   <= glyph_on;
        selected_r   <= selected;
        border_r     <= border;
        key_fill_r   <= key_fill;
        key_border_r <= key_border;
        rgb_in_r     <= rgb_in;

        if (in_band_r && glyph_on_r) rgb_out <= selected_r ? 24'h000000 : 24'hffffff;
        else if (in_band_r && border_r) rgb_out <= selected_r ? 24'hffffff : key_border_r;
        else if (in_band_r) rgb_out <= selected_r ? 24'hffd000 : key_fill_r;
        else rgb_out <= rgb_in_r;
    end
end

endmodule

`default_nettype wire
