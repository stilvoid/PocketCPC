// Simple hardware virtual keyboard overlay for the Pocket CPC core.

`default_nettype none

module cpc_virtual_keyboard_overlay (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        ce,
    input  wire        de,
    input  wire        vs,
    input  wire [23:0] rgb_in,
    input  wire [9:0]  origin_x,
    input  wire [8:0]  origin_y,
    input  wire        active,
    input  wire [6:0]  selected_index,
    input  wire [1:0]  page,
    input  wire        shift_active,
    input  wire        ctrl_active,
    input  wire        caps_active,
    output reg  [23:0] rgb_out,
    output reg         overlay_on
);

localparam [9:0] KEY_W = 10'd40;
wire [9:0] x1 = origin_x + 10'd600;
wire [8:0] y1 = origin_y + 9'd80;

reg [9:0] x = 10'd0;
reg [8:0] y = 9'd0;
reg       de_prev = 1'b0;
reg       vs_prev = 1'b0;

wire       in_band = active && de && (x >= origin_x) && (x < x1) && (y >= origin_y) && (y < y1);
wire [9:0] band_x  = x - origin_x;
wire [8:0] band_y  = y - origin_y;
wire [2:0] key_row = band_y[6:4];

function [3:0] band_x_to_col;
    input [9:0] x_pos;
    begin
        if (x_pos < 10'd40) band_x_to_col = 4'd0;
        else if (x_pos < 10'd80) band_x_to_col = 4'd1;
        else if (x_pos < 10'd120) band_x_to_col = 4'd2;
        else if (x_pos < 10'd160) band_x_to_col = 4'd3;
        else if (x_pos < 10'd200) band_x_to_col = 4'd4;
        else if (x_pos < 10'd240) band_x_to_col = 4'd5;
        else if (x_pos < 10'd280) band_x_to_col = 4'd6;
        else if (x_pos < 10'd320) band_x_to_col = 4'd7;
        else if (x_pos < 10'd360) band_x_to_col = 4'd8;
        else if (x_pos < 10'd400) band_x_to_col = 4'd9;
        else if (x_pos < 10'd440) band_x_to_col = 4'd10;
        else if (x_pos < 10'd480) band_x_to_col = 4'd11;
        else if (x_pos < 10'd520) band_x_to_col = 4'd12;
        else if (x_pos < 10'd560) band_x_to_col = 4'd13;
        else band_x_to_col = 4'd14;
    end
endfunction

function [9:0] col_to_x0;
    input [3:0] col;
    begin
        case (col)
            4'd0:  col_to_x0 = 10'd0;
            4'd1:  col_to_x0 = 10'd40;
            4'd2:  col_to_x0 = 10'd80;
            4'd3:  col_to_x0 = 10'd120;
            4'd4:  col_to_x0 = 10'd160;
            4'd5:  col_to_x0 = 10'd200;
            4'd6:  col_to_x0 = 10'd240;
            4'd7:  col_to_x0 = 10'd280;
            4'd8:  col_to_x0 = 10'd320;
            4'd9:  col_to_x0 = 10'd360;
            4'd10: col_to_x0 = 10'd400;
            4'd11: col_to_x0 = 10'd440;
            4'd12: col_to_x0 = 10'd480;
            4'd13: col_to_x0 = 10'd520;
            default: col_to_x0 = 10'd560;
        endcase
    end
endfunction

function [6:0] row_col_to_key_index;
    input [2:0] row;
    input [3:0] col;
    begin
        case (row)
            3'd0: row_col_to_key_index = {3'd0, col};
            3'd1: row_col_to_key_index = 7'd15 + {3'd0, col};
            3'd2: row_col_to_key_index = 7'd30 + {3'd0, col};
            3'd3: row_col_to_key_index = 7'd45 + {3'd0, col};
            default: row_col_to_key_index = 7'd60 + {3'd0, col};
        endcase
    end
endfunction

function [3:0] page0_anchor_col;
    input [2:0] row;
    input [3:0] col;
    begin
        page0_anchor_col = col;
        case (row)
            3'd1: if (col == 4'd14) page0_anchor_col = 4'd13;
            3'd2: if (col == 4'd14) page0_anchor_col = 4'd13;
            3'd3: begin
                if (col == 4'd1) page0_anchor_col = 4'd0;
                else if (col == 4'd14) page0_anchor_col = 4'd13;
            end
            3'd4: begin
                if (col == 4'd1) page0_anchor_col = 4'd0;
                else if (col == 4'd3) page0_anchor_col = 4'd2;
                else if ((col >= 4'd5) && (col <= 4'd10)) page0_anchor_col = 4'd4;
                else if (col >= 4'd12) page0_anchor_col = 4'd11;
            end
            default: page0_anchor_col = col;
        endcase
    end
endfunction

function [2:0] page0_anchor_row;
    input [2:0] row;
    input [3:0] col;
    begin
        page0_anchor_row = row;
        if ((row == 3'd2) && (col >= 4'd13)) page0_anchor_row = 3'd1;
    end
endfunction

function [3:0] page0_cell_span;
    input [2:0] row;
    input [3:0] anchor_col;
    begin
        page0_cell_span = 4'd1;
        case (row)
            3'd1, 3'd2: if (anchor_col == 4'd13) page0_cell_span = 4'd2;
            3'd3: begin
                if ((anchor_col == 4'd0) || (anchor_col == 4'd13)) page0_cell_span = 4'd2;
            end
            3'd4: begin
                case (anchor_col)
                    4'd0, 4'd2: page0_cell_span = 4'd2;
                    4'd4: page0_cell_span = 4'd7;
                    4'd11: page0_cell_span = 4'd4;
                    default: page0_cell_span = 4'd1;
                endcase
            end
            default: page0_cell_span = 4'd1;
        endcase
    end
endfunction

function [2:0] page0_row_span;
    input [2:0] anchor_row;
    input [3:0] anchor_col;
    begin
        page0_row_span = 3'd1;
        if ((anchor_row == 3'd1) && (anchor_col == 4'd13)) page0_row_span = 3'd2;
    end
endfunction

wire [3:0] anchor_col = (page == 2'd0) ? page0_anchor_col(key_row, key_col) : key_col;
wire [2:0] anchor_row = (page == 2'd0) ? page0_anchor_row(key_row, key_col) : key_row;
wire [3:0] key_col = band_x_to_col(band_x);
wire [9:0] anchor_x0  = col_to_x0(anchor_col);
wire [8:0] anchor_y0  = {anchor_row, 4'd0};
wire [6:0] key_idx = row_col_to_key_index(anchor_row, anchor_col);
wire [9:0] local_x_ext = band_x - anchor_x0;
wire [8:0] local_y_ext_full = band_y - anchor_y0;
wire [5:0] local_y_ext = local_y_ext_full[5:0];
wire [3:0] cell_span = (page == 2'd0) ? page0_cell_span(key_row, anchor_col) : 4'd1;
wire [2:0] cell_row_span = (page == 2'd0) ? page0_row_span(anchor_row, anchor_col) : 3'd1;
wire [9:0] cell_width =
    (cell_span == 4'd7) ? 10'd280 :
    (cell_span == 4'd4) ? 10'd160 :
    (cell_span == 4'd2) ? 10'd80  :
                           10'd40;
wire [5:0] cell_height = (cell_row_span == 3'd2) ? 6'd32 : 6'd16;
wire       return_alias_selected = (page == 2'd0) && (key_idx == 7'd28) && (selected_index == 7'd43);
wire       selected = (key_idx == selected_index) || return_alias_selected;
wire       shift_cell = ((page == 2'd0) && ((key_idx == 7'd45) || (key_idx == 7'd58))) ||
                        ((page == 2'd2) && (key_idx == 6'd4));
wire       ctrl_cell = ((page == 2'd0) && (key_idx == 7'd60)) ||
                       ((page == 2'd2) && (key_idx == 6'd3));
wire       caps_cell = ((page == 2'd0) && (key_idx == 7'd30)) ||
                       ((page == 2'd2) && (key_idx == 6'd2));
wire       border = (local_x_ext == 7'd0) || (local_x_ext == (cell_width - 7'd1)) ||
                    (local_y_ext == 6'd0) || (local_y_ext == (cell_height - 6'd1));
wire       shift_label_mode = shift_active && (page == 2'd0);
wire [1:0] label_size = label_len(key_idx, page);
wire [7:0] label_char0 = label_char(key_idx, page, shift_label_mode, 2'd0);
wire [7:0] label_char1 = label_char(key_idx, page, shift_label_mode, 2'd1);
wire [7:0] label_char2 = label_char(key_idx, page, shift_label_mode, 2'd2);
wire [9:0] glyph_start_x =
    (cell_width == 10'd280) ? ((label_size == 2'd3) ? 10'd123 : (label_size == 2'd2) ? 10'd129 : 10'd135) :
    (cell_width == 10'd160) ? ((label_size == 2'd3) ? 10'd63  : (label_size == 2'd2) ? 10'd69  : 10'd75)  :
    (cell_width == 10'd80)  ? ((label_size == 2'd3) ? 10'd23  : (label_size == 2'd2) ? 10'd29  : 10'd35)  :
                              ((label_size == 2'd3) ? 10'd3   : (label_size == 2'd2) ? 10'd9   : 10'd15);
wire [5:0] glyph_start_y = (cell_height == 6'd32) ? 6'd9 : 6'd1;
wire [9:0] glyph0_x = glyph_start_x;
wire [9:0] glyph1_x = glyph_start_x + 10'd12;
wire [9:0] glyph2_x = glyph_start_x + 10'd24;
wire [5:0] glyph_y_off = local_y_ext - glyph_start_y;
wire       glyph_region0 = (local_x_ext >= glyph0_x) && (local_x_ext < (glyph0_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region1 = (label_size != 2'd1) &&
                           (local_x_ext >= glyph1_x) && (local_x_ext < (glyph1_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region2 = (label_size == 2'd3) &&
                           (local_x_ext >= glyph2_x) && (local_x_ext < (glyph2_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire [9:0] glyph_dx0 = local_x_ext - glyph0_x;
wire [9:0] glyph_dx1 = local_x_ext - glyph1_x;
wire [9:0] glyph_dx2 = local_x_ext - glyph2_x;
wire [2:0] glyph_col0 = glyph_dx0[3:1];
wire [2:0] glyph_col1 = glyph_dx1[3:1];
wire [2:0] glyph_col2 = glyph_dx2[3:1];
wire [2:0] glyph_row = glyph_y_off[3:1];
wire [4:0] glyph_bits0 = glyph_row_bits(label_char0, glyph_row);
wire [4:0] glyph_bits1 = glyph_row_bits(label_char1, glyph_row);
wire [4:0] glyph_bits2 = glyph_row_bits(label_char2, glyph_row);
wire       glyph_on = (glyph_region0 && glyph_bits0[3'd4 - glyph_col0]) ||
                      (glyph_region1 && glyph_bits1[3'd4 - glyph_col1]) ||
                      (glyph_region2 && glyph_bits2[3'd4 - glyph_col2]);
wire       modifier_latched = (shift_active && shift_cell) || (ctrl_active && ctrl_cell) ||
                              (caps_active && caps_cell);
wire [23:0] key_fill = modifier_latched ? 24'h604800 : 24'h202020;
wire [23:0] key_border = modifier_latched ? 24'hffd000 : 24'h606060;

reg        in_band_r = 1'b0;
reg        glyph_on_r = 1'b0;
reg        selected_r = 1'b0;
reg        border_r = 1'b0;
reg [23:0] key_fill_r = 24'h202020;
reg [23:0] key_border_r = 24'h606060;

function key_is_alpha;
    input [6:0] key_index;
    begin
        case (key_index)
            7'd16, 7'd17, 7'd18, 7'd19, 7'd20, 7'd21, 7'd22, 7'd23,
            7'd24, 7'd25, 7'd31, 7'd32, 7'd33, 7'd34, 7'd35, 7'd36,
            7'd37, 7'd38, 7'd39, 7'd47, 7'd48, 7'd49, 7'd50, 7'd51,
            7'd52, 7'd53: key_is_alpha = 1'b1;
            default: key_is_alpha = 1'b0;
        endcase
    end
endfunction

function [1:0] label_len;
    input [6:0] key_index;
    input [1:0] key_page;
    begin
        label_len = 2'd1;
        case (key_page)
            2'd0: begin
                case (key_index)
                    7'd0, 7'd13, 7'd14, 7'd15, 7'd28, 7'd30, 7'd43,
                    7'd45, 7'd58, 7'd60, 7'd62, 7'd64, 7'd71: label_len = 2'd3;
                    default: label_len = 2'd1;
                endcase
            end
            2'd1: begin
                case (key_index)
                    6'd0, 6'd1, 6'd2, 6'd15, 6'd16, 6'd17, 6'd30, 6'd31,
                    6'd32, 6'd45: label_len = 2'd2;
                    6'd4, 6'd18, 6'd19, 6'd20, 6'd34, 6'd46, 6'd48,
                    6'd49: label_len = 2'd3;
                    default: label_len = 2'd1;
                endcase
            end
            2'd2: begin
                case (key_index)
                    6'd0, 6'd1, 6'd2, 6'd3, 6'd4, 6'd5, 6'd7, 6'd8,
                    6'd9, 6'd10: label_len = 2'd3;
                    default: label_len = 2'd1;
                endcase
            end
            2'd3: begin
                case (key_index)
                    6'd0, 6'd1, 6'd2, 6'd3, 6'd4: label_len = 2'd3;
                    default: label_len = 2'd1;
                endcase
            end
            default: label_len = 2'd1;
        endcase
    end
endfunction

function [7:0] label_char;
    input [6:0] key_index;
    input [1:0] key_page;
    input       shift_main_page;
    input [1:0] pos;
    begin
        label_char = 8'h20;
        case (key_page)
            2'd0: begin
                case (key_index)
                    7'd0:  case (pos) 2'd0: label_char = "E"; 2'd1: label_char = "S"; 2'd2: label_char = "C"; default: label_char = 8'h20; endcase
                    7'd13: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "L"; 2'd2: label_char = "R"; default: label_char = 8'h20; endcase
                    7'd14: case (pos) 2'd0: label_char = "D"; 2'd1: label_char = "E"; 2'd2: label_char = "L"; default: label_char = 8'h20; endcase
                    7'd15: case (pos) 2'd0: label_char = "T"; 2'd1: label_char = "A"; 2'd2: label_char = "B"; default: label_char = 8'h20; endcase
                    7'd28, 7'd43: case (pos) 2'd0: label_char = "R"; 2'd1: label_char = "E"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    7'd30: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "A"; 2'd2: label_char = "P"; default: label_char = 8'h20; endcase
                    7'd45, 7'd58: case (pos) 2'd0: label_char = "S"; 2'd1: label_char = "H"; 2'd2: label_char = "F"; default: label_char = 8'h20; endcase
                    7'd60: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "T"; 2'd2: label_char = "R"; default: label_char = 8'h20; endcase
                    7'd62: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "P"; 2'd2: label_char = "Y"; default: label_char = 8'h20; endcase
                    7'd64: case (pos) 2'd0: label_char = "S"; 2'd1: label_char = "P"; 2'd2: label_char = "C"; default: label_char = 8'h20; endcase
                    7'd71: case (pos) 2'd0: label_char = "E"; 2'd1: label_char = "N"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    default: if (pos == 2'd0) begin
                        if (key_is_alpha(key_index)) begin
                            label_char = key_index_to_char(key_index, (caps_active ^ shift_main_page) ? 2'd3 : 2'd0);
                        end else begin
                            label_char = key_index_to_char(key_index, shift_main_page ? 2'd3 : 2'd0);
                        end
                    end
                endcase
            end
            2'd1: begin
                case (key_index)
                    6'd0:  case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "7"; default: label_char = 8'h20; endcase
                    6'd1:  case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "8"; default: label_char = 8'h20; endcase
                    6'd2:  case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "9"; default: label_char = 8'h20; endcase
                    6'd4:  case (pos) 2'd0: label_char = "U"; 2'd1: label_char = "P"; default: label_char = 8'h20; endcase
                    6'd15: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "4"; default: label_char = 8'h20; endcase
                    6'd16: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "5"; default: label_char = 8'h20; endcase
                    6'd17: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "6"; default: label_char = 8'h20; endcase
                    6'd18: case (pos) 2'd0: label_char = "L"; 2'd1: label_char = "F"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    6'd19: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "P"; 2'd2: label_char = "Y"; default: label_char = 8'h20; endcase
                    6'd20: case (pos) 2'd0: label_char = "R"; 2'd1: label_char = "G"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    6'd30: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "1"; default: label_char = 8'h20; endcase
                    6'd31: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "2"; default: label_char = 8'h20; endcase
                    6'd32: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "3"; default: label_char = 8'h20; endcase
                    6'd34: case (pos) 2'd0: label_char = "D"; 2'd1: label_char = "N"; default: label_char = 8'h20; endcase
                    6'd45: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "0"; default: label_char = 8'h20; endcase
                    6'd46: case (pos) 2'd0: label_char = "E"; 2'd1: label_char = "N"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    6'd48: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "L"; 2'd2: label_char = "R"; default: label_char = 8'h20; endcase
                    6'd49: case (pos) 2'd0: label_char = "D"; 2'd1: label_char = "E"; 2'd2: label_char = "L"; default: label_char = 8'h20; endcase
                    default: if (pos == 2'd0) label_char = key_index_to_char(key_index, key_page);
                endcase
            end
            2'd2: begin
                case (key_index)
                    6'd0:  case (pos) 2'd0: label_char = "E"; 2'd1: label_char = "S"; 2'd2: label_char = "C"; default: label_char = 8'h20; endcase
                    6'd1:  case (pos) 2'd0: label_char = "T"; 2'd1: label_char = "A"; 2'd2: label_char = "B"; default: label_char = 8'h20; endcase
                    6'd2:  case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "A"; 2'd2: label_char = "P"; default: label_char = 8'h20; endcase
                    6'd3:  case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "T"; 2'd2: label_char = "R"; default: label_char = 8'h20; endcase
                    6'd4:  case (pos) 2'd0: label_char = "S"; 2'd1: label_char = "H"; 2'd2: label_char = "F"; default: label_char = 8'h20; endcase
                    6'd5:  case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "P"; 2'd2: label_char = "Y"; default: label_char = 8'h20; endcase
                    6'd7:  case (pos) 2'd0: label_char = "R"; 2'd1: label_char = "E"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    6'd8:  case (pos) 2'd0: label_char = "E"; 2'd1: label_char = "N"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    6'd9:  case (pos) 2'd0: label_char = "D"; 2'd1: label_char = "E"; 2'd2: label_char = "L"; default: label_char = 8'h20; endcase
                    6'd10: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "L"; 2'd2: label_char = "R"; default: label_char = 8'h20; endcase
                    default: if (pos == 2'd0) label_char = key_index_to_char(key_index, key_page);
                endcase
            end
            2'd3: begin
                case (key_index)
                    6'd0:  case (pos) 2'd0: label_char = "T"; 2'd1: label_char = "A"; 2'd2: label_char = "P"; default: label_char = 8'h20; endcase
                    6'd1:  case (pos) 2'd0: label_char = "D"; 2'd1: label_char = "S"; 2'd2: label_char = "C"; default: label_char = 8'h20; endcase
                    6'd2:  case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "A"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    6'd3:  case (pos) 2'd0: label_char = "R"; 2'd1: label_char = "U"; 2'd2: label_char = "N"; default: label_char = 8'h20; endcase
                    6'd4:  case (pos) 2'd0: label_char = "R"; 2'd1: label_char = "D"; 2'd2: label_char = "S"; default: label_char = 8'h20; endcase
                    default: label_char = 8'h20;
                endcase
            end
            default: begin
                label_char = 8'h20;
            end
        endcase
    end
endfunction

function [7:0] key_index_to_char;
    input [6:0] key_index;
    input [1:0] key_page;
    begin
        key_index_to_char = 8'h20;
        case (key_page)
            2'd0: begin
                case (key_index)
                    6'd0:  key_index_to_char = 8'h45; // Esc
                    6'd1:  key_index_to_char = 8'h31;
                    6'd2:  key_index_to_char = 8'h32;
                    6'd3:  key_index_to_char = 8'h33;
                    6'd4:  key_index_to_char = 8'h34;
                    6'd5:  key_index_to_char = 8'h35;
                    6'd6:  key_index_to_char = 8'h36;
                    6'd7:  key_index_to_char = 8'h37;
                    6'd8:  key_index_to_char = 8'h38;
                    6'd9:  key_index_to_char = 8'h39;
                    6'd10: key_index_to_char = 8'h30;
                    6'd11: key_index_to_char = 8'h2D;
                    6'd12: key_index_to_char = 8'h5E;
                    6'd13: key_index_to_char = 8'h43; // CLR
                    6'd14: key_index_to_char = 8'h44; // Del

                    6'd15: key_index_to_char = 8'h54; // Tab
                    6'd16: key_index_to_char = 8'h71;
                    6'd17: key_index_to_char = 8'h77;
                    6'd18: key_index_to_char = 8'h65;
                    6'd19: key_index_to_char = 8'h72;
                    6'd20: key_index_to_char = 8'h74;
                    6'd21: key_index_to_char = 8'h79;
                    6'd22: key_index_to_char = 8'h75;
                    6'd23: key_index_to_char = 8'h69;
                    6'd24: key_index_to_char = 8'h6F;
                    6'd25: key_index_to_char = 8'h70;
                    6'd26: key_index_to_char = 8'h40;
                    6'd27: key_index_to_char = 8'h5B;
                    6'd28: key_index_to_char = 8'h0D;

                    6'd30: key_index_to_char = 8'h4B; // Caps
                    6'd31: key_index_to_char = 8'h61;
                    6'd32: key_index_to_char = 8'h73;
                    6'd33: key_index_to_char = 8'h64;
                    6'd34: key_index_to_char = 8'h66;
                    6'd35: key_index_to_char = 8'h67;
                    6'd36: key_index_to_char = 8'h68;
                    6'd37: key_index_to_char = 8'h6A;
                    6'd38: key_index_to_char = 8'h6B;
                    6'd39: key_index_to_char = 8'h6C;
                    6'd40: key_index_to_char = 8'h3A;
                    6'd41: key_index_to_char = 8'h3B;
                    6'd42: key_index_to_char = 8'h5D;
                    6'd43: key_index_to_char = 8'h0D;

                    7'd45: key_index_to_char = 8'h53; // Shift
                    7'd47: key_index_to_char = 8'h7A;
                    7'd48: key_index_to_char = 8'h78;
                    7'd49: key_index_to_char = 8'h63;
                    7'd50: key_index_to_char = 8'h76;
                    7'd51: key_index_to_char = 8'h62;
                    7'd52: key_index_to_char = 8'h6E;
                    7'd53: key_index_to_char = 8'h6D;
                    7'd54: key_index_to_char = 8'h2C;
                    7'd55: key_index_to_char = 8'h2E;
                    7'd56: key_index_to_char = 8'h2F;
                    7'd57: key_index_to_char = 8'h5C;
                    7'd58: key_index_to_char = 8'h53; // Shift

                    7'd60: key_index_to_char = 8'h43; // Ctrl
                    7'd62: key_index_to_char = 8'h50; // Copy
                    7'd64: key_index_to_char = 8'h20;
                    7'd71: key_index_to_char = 8'h0D;
                    default: key_index_to_char = 8'h20;
                endcase
            end
            2'd1: begin
                case (key_index)
                    6'd0:  key_index_to_char = 8'h37;
                    6'd1:  key_index_to_char = 8'h38;
                    6'd2:  key_index_to_char = 8'h39;
                    6'd4:  key_index_to_char = 8'h55; // Up
                    6'd15: key_index_to_char = 8'h34;
                    6'd16: key_index_to_char = 8'h35;
                    6'd17: key_index_to_char = 8'h36;
                    6'd18: key_index_to_char = 8'h4C; // Left
                    6'd19: key_index_to_char = 8'h50; // Copy
                    6'd20: key_index_to_char = 8'h52; // Right
                    6'd30: key_index_to_char = 8'h31;
                    6'd31: key_index_to_char = 8'h32;
                    6'd32: key_index_to_char = 8'h33;
                    6'd34: key_index_to_char = 8'h44; // Down
                    6'd45: key_index_to_char = 8'h30;
                    6'd46: key_index_to_char = 8'h0D;
                    6'd47: key_index_to_char = 8'h2E;
                    6'd48: key_index_to_char = 8'h43; // CLR
                    6'd49: key_index_to_char = 8'h44; // Del
                    default: key_index_to_char = 8'h20;
                endcase
            end
            2'd2: begin
                case (key_index)
                    6'd0:  key_index_to_char = 8'h45; // Esc
                    6'd1:  key_index_to_char = 8'h54; // Tab
                    6'd2:  key_index_to_char = 8'h4B; // Caps
                    6'd3:  key_index_to_char = 8'h43; // Ctrl
                    6'd4:  key_index_to_char = 8'h53; // Shift
                    6'd5:  key_index_to_char = 8'h50; // Copy
                    6'd7:  key_index_to_char = 8'h0D;
                    6'd8:  key_index_to_char = 8'h0D;
                    6'd9:  key_index_to_char = 8'h44; // Del
                    6'd10: key_index_to_char = 8'h43; // CLR
                    6'd11: key_index_to_char = 8'h2D;
                    6'd12: key_index_to_char = 8'h5E;
                    6'd13: key_index_to_char = 8'h40;
                    6'd14: key_index_to_char = 8'h5B;
                    6'd15: key_index_to_char = 8'h5D;
                    6'd16: key_index_to_char = 8'h5C;
                    6'd17: key_index_to_char = 8'h3A;
                    6'd18: key_index_to_char = 8'h3B;
                    6'd19: key_index_to_char = 8'h2C;
                    6'd20: key_index_to_char = 8'h2E;
                    6'd21: key_index_to_char = 8'h2F;
                    default: key_index_to_char = 8'h20;
                endcase
            end
            2'd3: begin
                case (key_index)
                    6'd0:  key_index_to_char = 8'h45; // Esc
                    6'd1:  key_index_to_char = 8'h21;
                    6'd2:  key_index_to_char = 8'h22;
                    6'd3:  key_index_to_char = 8'h23;
                    6'd4:  key_index_to_char = 8'h24;
                    6'd5:  key_index_to_char = 8'h25;
                    6'd6:  key_index_to_char = 8'h26;
                    6'd7:  key_index_to_char = 8'h27;
                    6'd8:  key_index_to_char = 8'h28;
                    6'd9:  key_index_to_char = 8'h29;
                    6'd10: key_index_to_char = 8'h5F;
                    6'd11: key_index_to_char = 8'h3D;
                    6'd12: key_index_to_char = 8'hA3;
                    6'd13: key_index_to_char = 8'h43; // CLR
                    6'd14: key_index_to_char = 8'h44; // Del

                    6'd15: key_index_to_char = 8'h54; // Tab
                    6'd16: key_index_to_char = 8'h51;
                    6'd17: key_index_to_char = 8'h57;
                    6'd18: key_index_to_char = 8'h45;
                    6'd19: key_index_to_char = 8'h52;
                    6'd20: key_index_to_char = 8'h54;
                    6'd21: key_index_to_char = 8'h59;
                    6'd22: key_index_to_char = 8'h55;
                    6'd23: key_index_to_char = 8'h49;
                    6'd24: key_index_to_char = 8'h4F;
                    6'd25: key_index_to_char = 8'h50;
                    6'd26: key_index_to_char = 8'h7C;
                    6'd27: key_index_to_char = 8'h7B;
                    6'd28: key_index_to_char = 8'h0D;

                    6'd30: key_index_to_char = 8'h4B; // Caps
                    6'd31: key_index_to_char = 8'h41;
                    6'd32: key_index_to_char = 8'h53;
                    6'd33: key_index_to_char = 8'h44;
                    6'd34: key_index_to_char = 8'h46;
                    6'd35: key_index_to_char = 8'h47;
                    6'd36: key_index_to_char = 8'h48;
                    6'd37: key_index_to_char = 8'h4A;
                    6'd38: key_index_to_char = 8'h4B;
                    6'd39: key_index_to_char = 8'h4C;
                    6'd40: key_index_to_char = 8'h2A;
                    6'd41: key_index_to_char = 8'h2B;
                    6'd42: key_index_to_char = 8'h7D;
                    6'd43: key_index_to_char = 8'h0D;

                    7'd45: key_index_to_char = 8'h53; // Shift
                    7'd47: key_index_to_char = 8'h5A;
                    7'd48: key_index_to_char = 8'h58;
                    7'd49: key_index_to_char = 8'h43;
                    7'd50: key_index_to_char = 8'h56;
                    7'd51: key_index_to_char = 8'h42;
                    7'd52: key_index_to_char = 8'h4E;
                    7'd53: key_index_to_char = 8'h4D;
                    7'd54: key_index_to_char = 8'h3C;
                    7'd55: key_index_to_char = 8'h3E;
                    7'd56: key_index_to_char = 8'h3F;
                    7'd57: key_index_to_char = 8'h5C;
                    7'd58: key_index_to_char = 8'h53; // Shift

                    7'd60: key_index_to_char = 8'h43; // Ctrl
                    7'd62: key_index_to_char = 8'h50; // Copy
                    7'd64: key_index_to_char = 8'h20;
                    7'd71: key_index_to_char = 8'h0D;
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
            8'h0D: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00010; 3'd2: glyph_row_bits = 5'b11111; 3'd3: glyph_row_bits = 5'b00110; 3'd4: glyph_row_bits = 5'b01010; 3'd5: glyph_row_bits = 5'b00010; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h2B: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h2D: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h21: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h22: case (row) 3'd0: glyph_row_bits = 5'b01010; 3'd1: glyph_row_bits = 5'b01010; 3'd2: glyph_row_bits = 5'b01010; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h23: case (row) 3'd0: glyph_row_bits = 5'b01010; 3'd1: glyph_row_bits = 5'b01010; 3'd2: glyph_row_bits = 5'b11111; 3'd3: glyph_row_bits = 5'b01010; 3'd4: glyph_row_bits = 5'b11111; 3'd5: glyph_row_bits = 5'b01010; 3'd6: glyph_row_bits = 5'b01010; default: glyph_row_bits = 5'b00000; endcase
            8'h24: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b01111; 3'd2: glyph_row_bits = 5'b10100; 3'd3: glyph_row_bits = 5'b01110; 3'd4: glyph_row_bits = 5'b00101; 3'd5: glyph_row_bits = 5'b11110; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h25: case (row) 3'd0: glyph_row_bits = 5'b11001; 3'd1: glyph_row_bits = 5'b11010; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b10110; 3'd5: glyph_row_bits = 5'b00110; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h26: case (row) 3'd0: glyph_row_bits = 5'b01100; 3'd1: glyph_row_bits = 5'b10010; 3'd2: glyph_row_bits = 5'b10100; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b10101; 3'd5: glyph_row_bits = 5'b10010; 3'd6: glyph_row_bits = 5'b01101; default: glyph_row_bits = 5'b00000; endcase
            8'h27: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h28: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h29: case (row) 3'd0: glyph_row_bits = 5'b01000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h2A: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b10101; 3'd2: glyph_row_bits = 5'b01110; 3'd3: glyph_row_bits = 5'b11111; 3'd4: glyph_row_bits = 5'b01110; 3'd5: glyph_row_bits = 5'b10101; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h3C: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b10000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h3E: case (row) 3'd0: glyph_row_bits = 5'b01000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00001; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h3F: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b00001; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h5E: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b01010; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h5F: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b11111; default: glyph_row_bits = 5'b00000; endcase
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
            8'h61: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b01110; 3'd3: glyph_row_bits = 5'b00001; 3'd4: glyph_row_bits = 5'b01111; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01111; default: glyph_row_bits = 5'b00000; endcase
            8'h62: case (row) 3'd0: glyph_row_bits = 5'b10000; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b11110; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b11110; default: glyph_row_bits = 5'b00000; endcase
            8'h63: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b01111; 3'd3: glyph_row_bits = 5'b10000; 3'd4: glyph_row_bits = 5'b10000; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b01111; default: glyph_row_bits = 5'b00000; endcase
            8'h64: case (row) 3'd0: glyph_row_bits = 5'b00001; 3'd1: glyph_row_bits = 5'b00001; 3'd2: glyph_row_bits = 5'b01111; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01111; default: glyph_row_bits = 5'b00000; endcase
            8'h65: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b01110; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b11111; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h66: case (row) 3'd0: glyph_row_bits = 5'b00110; 3'd1: glyph_row_bits = 5'b01001; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b11100; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h67: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b01111; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b01111; 3'd5: glyph_row_bits = 5'b00001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h68: case (row) 3'd0: glyph_row_bits = 5'b10000; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b11110; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h69: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b01100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h6A: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00110; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b10010; 3'd6: glyph_row_bits = 5'b01100; default: glyph_row_bits = 5'b00000; endcase
            8'h6B: case (row) 3'd0: glyph_row_bits = 5'b10000; 3'd1: glyph_row_bits = 5'b10000; 3'd2: glyph_row_bits = 5'b10010; 3'd3: glyph_row_bits = 5'b10100; 3'd4: glyph_row_bits = 5'b11000; 3'd5: glyph_row_bits = 5'b10100; 3'd6: glyph_row_bits = 5'b10010; default: glyph_row_bits = 5'b00000; endcase
            8'h6C: case (row) 3'd0: glyph_row_bits = 5'b01100; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h6D: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b11010; 3'd3: glyph_row_bits = 5'b10101; 3'd4: glyph_row_bits = 5'b10101; 3'd5: glyph_row_bits = 5'b10101; 3'd6: glyph_row_bits = 5'b10101; default: glyph_row_bits = 5'b00000; endcase
            8'h6E: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b11110; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h6F: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b01110; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h70: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b11110; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b11110; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b10000; default: glyph_row_bits = 5'b00000; endcase
            8'h71: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b01111; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b01111; 3'd5: glyph_row_bits = 5'b00001; 3'd6: glyph_row_bits = 5'b00001; default: glyph_row_bits = 5'b00000; endcase
            8'h72: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b10110; 3'd3: glyph_row_bits = 5'b11001; 3'd4: glyph_row_bits = 5'b10000; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b10000; default: glyph_row_bits = 5'b00000; endcase
            8'h73: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b01111; 3'd3: glyph_row_bits = 5'b10000; 3'd4: glyph_row_bits = 5'b01110; 3'd5: glyph_row_bits = 5'b00001; 3'd6: glyph_row_bits = 5'b11110; default: glyph_row_bits = 5'b00000; endcase
            8'h74: case (row) 3'd0: glyph_row_bits = 5'b01000; 3'd1: glyph_row_bits = 5'b01000; 3'd2: glyph_row_bits = 5'b11100; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01001; 3'd6: glyph_row_bits = 5'b00110; default: glyph_row_bits = 5'b00000; endcase
            8'h75: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b10011; 3'd6: glyph_row_bits = 5'b01101; default: glyph_row_bits = 5'b00000; endcase
            8'h76: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10001; 3'd5: glyph_row_bits = 5'b01010; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h77: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b10101; 3'd5: glyph_row_bits = 5'b10101; 3'd6: glyph_row_bits = 5'b01010; default: glyph_row_bits = 5'b00000; endcase
            8'h78: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b01010; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b01010; 3'd6: glyph_row_bits = 5'b10001; default: glyph_row_bits = 5'b00000; endcase
            8'h79: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b10001; 3'd3: glyph_row_bits = 5'b10001; 3'd4: glyph_row_bits = 5'b01111; 3'd5: glyph_row_bits = 5'b00001; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h7A: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b11111; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b11111; default: glyph_row_bits = 5'b00000; endcase
            8'h3B: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h3A: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h2C: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
            8'h2E: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b00000; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b00000; 3'd5: glyph_row_bits = 5'b01100; 3'd6: glyph_row_bits = 5'b01100; default: glyph_row_bits = 5'b00000; endcase
            8'h2F: case (row) 3'd0: glyph_row_bits = 5'b00001; 3'd1: glyph_row_bits = 5'b00010; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b10000; default: glyph_row_bits = 5'b00000; endcase
            8'h40: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b10001; 3'd2: glyph_row_bits = 5'b10111; 3'd3: glyph_row_bits = 5'b10101; 3'd4: glyph_row_bits = 5'b10111; 3'd5: glyph_row_bits = 5'b10000; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h3D: case (row) 3'd0: glyph_row_bits = 5'b00000; 3'd1: glyph_row_bits = 5'b00000; 3'd2: glyph_row_bits = 5'b11111; 3'd3: glyph_row_bits = 5'b00000; 3'd4: glyph_row_bits = 5'b11111; 3'd5: glyph_row_bits = 5'b00000; 3'd6: glyph_row_bits = 5'b00000; default: glyph_row_bits = 5'b00000; endcase
            8'h5B: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b01000; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b01000; 3'd5: glyph_row_bits = 5'b01000; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h5C: case (row) 3'd0: glyph_row_bits = 5'b10000; 3'd1: glyph_row_bits = 5'b01000; 3'd2: glyph_row_bits = 5'b01000; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00010; 3'd6: glyph_row_bits = 5'b00001; default: glyph_row_bits = 5'b00000; endcase
            8'h5D: case (row) 3'd0: glyph_row_bits = 5'b01110; 3'd1: glyph_row_bits = 5'b00010; 3'd2: glyph_row_bits = 5'b00010; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00010; 3'd5: glyph_row_bits = 5'b00010; 3'd6: glyph_row_bits = 5'b01110; default: glyph_row_bits = 5'b00000; endcase
            8'h7B: case (row) 3'd0: glyph_row_bits = 5'b00010; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b01000; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00010; default: glyph_row_bits = 5'b00000; endcase
            8'h7C: case (row) 3'd0: glyph_row_bits = 5'b00100; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00100; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b00100; default: glyph_row_bits = 5'b00000; endcase
            8'h7D: case (row) 3'd0: glyph_row_bits = 5'b01000; 3'd1: glyph_row_bits = 5'b00100; 3'd2: glyph_row_bits = 5'b00100; 3'd3: glyph_row_bits = 5'b00010; 3'd4: glyph_row_bits = 5'b00100; 3'd5: glyph_row_bits = 5'b00100; 3'd6: glyph_row_bits = 5'b01000; default: glyph_row_bits = 5'b00000; endcase
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
        rgb_out      <= 24'h000000;
        overlay_on   <= 1'b0;
    end else if (ce) begin
        if (!vs_prev && vs) begin
            y <= 9'd0;
        end

        if (de) begin
            if (!de_prev) x <= 10'd0;
            else x <= x + 10'd1;
        end else if (de_prev) begin
            x <= 10'd0;
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
        overlay_on   <= in_band_r;

        if (in_band_r && glyph_on_r) rgb_out <= selected_r ? 24'h000000 : 24'hffffff;
        else if (in_band_r && border_r) rgb_out <= selected_r ? 24'hffffff : key_border_r;
        else if (in_band_r) rgb_out <= selected_r ? 24'hffd000 : key_fill_r;
        else rgb_out <= rgb_in;
    end
end

endmodule

`default_nettype wire
