// Simple hardware virtual keyboard overlay for the Pocket CPC core.

`default_nettype none

module cpc_virtual_keyboard_overlay #(
    parameter [3:0] MAX_LABEL_GLYPHS = 4'd8,
    parameter       COMPACT_PAGE1_MACRO_LABELS = 1'b0
) (
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
    input  wire        bind_mode,
    input  wire        bind_feedback_active,
    input  wire [3:0]  bind_feedback_button,
    input  wire [6:0]  bind_feedback_index,
    input  wire [1:0]  bind_feedback_page,
    input  wire [6:0]  bound_valid_mask,
    input  wire [48:0] bound_index_bus,
    input  wire [13:0] bound_page_bus,
    output reg  [23:0] rgb_out,
    output reg         overlay_on
);

localparam [9:0] KEY_W = 10'd40;
wire       status_active = bind_mode | bind_feedback_active | bound_hover_active;
wire [9:0] x1 = origin_x + 10'd600;
wire [8:0] y1 = origin_y + (status_active ? 9'd96 : 9'd80);

reg [9:0] x = 10'd0;
reg [8:0] y = 9'd0;
reg       de_prev = 1'b0;
reg       vs_prev = 1'b0;

wire       in_band = active && de && (x >= origin_x) && (x < x1) && (y >= origin_y) && (y < y1);
wire [9:0] band_x  = x - origin_x;
wire [8:0] band_y  = y - origin_y;
wire       status_row_active = status_active && (band_y >= 9'd80);
wire [8:0] status_band_y = band_y - 9'd80;
wire [8:0] key_band_y = band_y;
wire [2:0] key_row = key_band_y[6:4];

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

function [3:0] page1_anchor_col;
    input [2:0] row;
    input [3:0] col;
    begin
        page1_anchor_col = col;
        if (col >= 4'd12) page1_anchor_col = 4'd11;
    end
endfunction

function [9:0] key_cell_width;
    input [6:0] key_index;
    input [1:0] key_page;
    begin
        key_cell_width = 10'd40;
        case (key_page)
            2'd0: begin
                case (key_index)
                    7'd28, 7'd45, 7'd58, 7'd60, 7'd62: key_cell_width = 10'd80;
                    7'd64: key_cell_width = 10'd280;
                    7'd71: key_cell_width = 10'd160;
                    default: key_cell_width = 10'd40;
                endcase
            end
            2'd1: begin
                case (key_index)
                    7'd11, 7'd26, 7'd41, 7'd56, 7'd71: key_cell_width = 10'd160;
                    default: key_cell_width = 10'd40;
                endcase
            end
            default: key_cell_width = 10'd40;
        endcase
    end
endfunction

function [5:0] key_cell_height;
    input [6:0] key_index;
    input [1:0] key_page;
    begin
        key_cell_height = 6'd16;
        if ((key_page == 2'd0) && (key_index == 7'd28)) key_cell_height = 6'd32;
    end
endfunction

function [9:0] glyph_start_x_for_width;
    input [9:0] width;
    input [3:0] size;
    begin
        glyph_start_x_for_width = 10'd0;
        case (width)
            10'd40: begin
                case (size)
                    4'd1: glyph_start_x_for_width = 10'd15;
                    4'd2: glyph_start_x_for_width = 10'd9;
                    4'd3: glyph_start_x_for_width = 10'd3;
                    default: glyph_start_x_for_width = 10'd0;
                endcase
            end
            10'd80: begin
                case (size)
                    4'd1: glyph_start_x_for_width = 10'd35;
                    4'd2: glyph_start_x_for_width = 10'd29;
                    4'd3: glyph_start_x_for_width = 10'd23;
                    4'd4: glyph_start_x_for_width = 10'd17;
                    4'd5: glyph_start_x_for_width = 10'd11;
                    4'd6: glyph_start_x_for_width = 10'd5;
                    default: glyph_start_x_for_width = 10'd0;
                endcase
            end
            10'd160: begin
                case (size)
                    4'd1: glyph_start_x_for_width = 10'd75;
                    4'd2: glyph_start_x_for_width = 10'd69;
                    4'd3: glyph_start_x_for_width = 10'd63;
                    4'd4: glyph_start_x_for_width = 10'd57;
                    4'd5: glyph_start_x_for_width = 10'd51;
                    4'd6: glyph_start_x_for_width = 10'd45;
                    4'd7: glyph_start_x_for_width = 10'd39;
                    4'd8: glyph_start_x_for_width = 10'd33;
                    default: glyph_start_x_for_width = 10'd0;
                endcase
            end
            10'd280: begin
                case (size)
                    4'd1: glyph_start_x_for_width = 10'd135;
                    4'd2: glyph_start_x_for_width = 10'd129;
                    4'd3: glyph_start_x_for_width = 10'd123;
                    4'd4: glyph_start_x_for_width = 10'd117;
                    4'd5: glyph_start_x_for_width = 10'd111;
                    4'd6: glyph_start_x_for_width = 10'd105;
                    4'd7: glyph_start_x_for_width = 10'd99;
                    4'd8: glyph_start_x_for_width = 10'd93;
                    default: glyph_start_x_for_width = 10'd0;
                endcase
            end
            default: glyph_start_x_for_width = 10'd0;
        endcase
    end
endfunction

wire [3:0] key_col = band_x_to_col(band_x);
wire [3:0] anchor_col = (page == 2'd0) ? page0_anchor_col(key_row, key_col) :
                        (page == 2'd1) ? page1_anchor_col(key_row, key_col) :
                                         key_col;
wire [2:0] anchor_row = (page == 2'd0) ? page0_anchor_row(key_row, key_col) : key_row;
wire [9:0] anchor_x0  = col_to_x0(anchor_col);
wire [8:0] anchor_y0  = {anchor_row, 4'd0};
wire [6:0] key_idx = row_col_to_key_index(anchor_row, anchor_col);
wire [9:0] local_x_ext = band_x - anchor_x0;
wire [8:0] local_y_ext_full = key_band_y - anchor_y0;
wire [5:0] local_y_ext = local_y_ext_full[5:0];
wire [9:0] cell_width = key_cell_width(key_idx, page);
wire [5:0] cell_height = key_cell_height(key_idx, page);
wire       return_alias_selected = (page == 2'd0) && (key_idx == 7'd28) && (selected_index == 7'd43);
wire       selected = (key_idx == selected_index) || return_alias_selected;
wire       shift_cell = (page == 2'd0) && ((key_idx == 7'd45) || (key_idx == 7'd58));
wire       ctrl_cell = (page == 2'd0) && (key_idx == 7'd60);
wire       caps_cell = (page == 2'd0) && (key_idx == 7'd30);
wire       border = (local_x_ext == 7'd0) || (local_x_ext == (cell_width - 7'd1)) ||
                    (local_y_ext == 6'd0) || (local_y_ext == (cell_height - 6'd1));
wire       shift_label_mode = shift_active && (page == 2'd0);
wire [3:0] label_size_raw = label_len(key_idx, page);
wire [3:0] label_size = (label_size_raw > MAX_LABEL_GLYPHS) ? MAX_LABEL_GLYPHS : label_size_raw;
wire [7:0] label_char0 = label_char(key_idx, page, shift_label_mode, 3'd0);
wire [7:0] label_char1 = label_char(key_idx, page, shift_label_mode, 3'd1);
wire [7:0] label_char2 = label_char(key_idx, page, shift_label_mode, 3'd2);
wire [7:0] label_char3 = label_char(key_idx, page, shift_label_mode, 3'd3);
wire [7:0] label_char4 = label_char(key_idx, page, shift_label_mode, 3'd4);
wire [7:0] label_char5 = label_char(key_idx, page, shift_label_mode, 3'd5);
wire [7:0] label_char6 = label_char(key_idx, page, shift_label_mode, 3'd6);
wire [7:0] label_char7 = label_char(key_idx, page, shift_label_mode, 3'd7);
wire [9:0] glyph_start_x = glyph_start_x_for_width(cell_width, label_size);
wire [5:0] glyph_start_y = (cell_height == 6'd32) ? 6'd9 : 6'd1;
wire [9:0] glyph0_x = glyph_start_x;
wire [9:0] glyph1_x = glyph_start_x + 10'd12;
wire [9:0] glyph2_x = glyph_start_x + 10'd24;
wire [9:0] glyph3_x = glyph_start_x + 10'd36;
wire [9:0] glyph4_x = glyph_start_x + 10'd48;
wire [9:0] glyph5_x = glyph_start_x + 10'd60;
wire [9:0] glyph6_x = glyph_start_x + 10'd72;
wire [9:0] glyph7_x = glyph_start_x + 10'd84;
wire [5:0] glyph_y_off = local_y_ext - glyph_start_y;
wire       glyph_region0 = (local_x_ext >= glyph0_x) && (local_x_ext < (glyph0_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region1 = (label_size > 4'd1) &&
                           (local_x_ext >= glyph1_x) && (local_x_ext < (glyph1_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region2 = (label_size > 4'd2) &&
                           (local_x_ext >= glyph2_x) && (local_x_ext < (glyph2_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region3 = (MAX_LABEL_GLYPHS > 4'd3) && (label_size > 4'd3) &&
                           (local_x_ext >= glyph3_x) && (local_x_ext < (glyph3_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region4 = (MAX_LABEL_GLYPHS > 4'd4) && (label_size > 4'd4) &&
                           (local_x_ext >= glyph4_x) && (local_x_ext < (glyph4_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region5 = (MAX_LABEL_GLYPHS > 4'd5) && (label_size > 4'd5) &&
                           (local_x_ext >= glyph5_x) && (local_x_ext < (glyph5_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region6 = (MAX_LABEL_GLYPHS > 4'd6) && (label_size > 4'd6) &&
                           (local_x_ext >= glyph6_x) && (local_x_ext < (glyph6_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire       glyph_region7 = (MAX_LABEL_GLYPHS > 4'd7) && (label_size > 4'd7) &&
                           (local_x_ext >= glyph7_x) && (local_x_ext < (glyph7_x + 7'd10)) &&
                           (local_y_ext >= glyph_start_y) && (local_y_ext < (glyph_start_y + 6'd14));
wire [9:0] glyph_dx0 = local_x_ext - glyph0_x;
wire [9:0] glyph_dx1 = local_x_ext - glyph1_x;
wire [9:0] glyph_dx2 = local_x_ext - glyph2_x;
wire [9:0] glyph_dx3 = local_x_ext - glyph3_x;
wire [9:0] glyph_dx4 = local_x_ext - glyph4_x;
wire [9:0] glyph_dx5 = local_x_ext - glyph5_x;
wire [9:0] glyph_dx6 = local_x_ext - glyph6_x;
wire [9:0] glyph_dx7 = local_x_ext - glyph7_x;
wire [2:0] glyph_col0 = glyph_dx0[3:1];
wire [2:0] glyph_col1 = glyph_dx1[3:1];
wire [2:0] glyph_col2 = glyph_dx2[3:1];
wire [2:0] glyph_col3 = glyph_dx3[3:1];
wire [2:0] glyph_col4 = glyph_dx4[3:1];
wire [2:0] glyph_col5 = glyph_dx5[3:1];
wire [2:0] glyph_col6 = glyph_dx6[3:1];
wire [2:0] glyph_col7 = glyph_dx7[3:1];
wire [2:0] glyph_row = glyph_y_off[3:1];
wire [4:0] glyph_bits0 = glyph_row_bits(label_char0, glyph_row);
wire [4:0] glyph_bits1 = glyph_row_bits(label_char1, glyph_row);
wire [4:0] glyph_bits2 = glyph_row_bits(label_char2, glyph_row);
wire [4:0] glyph_bits3 = glyph_row_bits(label_char3, glyph_row);
wire [4:0] glyph_bits4 = glyph_row_bits(label_char4, glyph_row);
wire [4:0] glyph_bits5 = glyph_row_bits(label_char5, glyph_row);
wire [4:0] glyph_bits6 = glyph_row_bits(label_char6, glyph_row);
wire [4:0] glyph_bits7 = glyph_row_bits(label_char7, glyph_row);
wire       glyph_on = (glyph_region0 && glyph_bits0[3'd4 - glyph_col0]) ||
                      (glyph_region1 && glyph_bits1[3'd4 - glyph_col1]) ||
                      (glyph_region2 && glyph_bits2[3'd4 - glyph_col2]) ||
                      (glyph_region3 && glyph_bits3[3'd4 - glyph_col3]) ||
                      (glyph_region4 && glyph_bits4[3'd4 - glyph_col4]) ||
                      (glyph_region5 && glyph_bits5[3'd4 - glyph_col5]) ||
                      (glyph_region6 && glyph_bits6[3'd4 - glyph_col6]) ||
                      (glyph_region7 && glyph_bits7[3'd4 - glyph_col7]);
wire       modifier_latched = (shift_active && shift_cell) || (ctrl_active && ctrl_cell) ||
                              (caps_active && caps_cell);
wire [6:0]  key_bound_mask = bound_mask_for_target(key_idx, page, bound_valid_mask, bound_index_bus, bound_page_bus);
wire        bound_cell = (key_bound_mask != 7'd0);
wire [23:0] key_fill = modifier_latched ? (bound_cell ? 24'h405020 : 24'h604800) :
                                          (bound_cell ? 24'h183428 : 24'h202020);
wire [23:0] key_border = modifier_latched ? 24'hffd000 :
                                           (bound_cell ? 24'h58d8a0 : 24'h606060);
wire [5:0] status_glyph_y_off = band_y[5:0] - 6'd1;
wire [2:0] status_glyph_row = status_glyph_y_off[3:1];

function [2:0] button_label_len;
    input [3:0] button;
    begin
        case (button)
            4'd15: button_label_len = 3'd5;
            4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9: button_label_len = 3'd1;
            default: button_label_len = 3'd1;
        endcase
    end
endfunction

function [7:0] button_label_char;
    input [3:0] button;
    input [2:0] pos;
    begin
        button_label_char = 8'h20;
        case (button)
            4'd4:  if (pos == 2'd0) button_label_char = "A";
            4'd5:  if (pos == 2'd0) button_label_char = "B";
            4'd6:  if (pos == 2'd0) button_label_char = "X";
            4'd7:  if (pos == 2'd0) button_label_char = "Y";
            4'd8:  if (pos == 2'd0) button_label_char = "L";
            4'd9:  if (pos == 2'd0) button_label_char = "R";
            4'd15: case (pos)
                3'd0: button_label_char = "S";
                3'd1: button_label_char = "T";
                3'd2: button_label_char = "A";
                3'd3: button_label_char = "R";
                3'd4: button_label_char = "T";
                default: button_label_char = 8'h20;
            endcase
            default: button_label_char = 8'h20;
        endcase
    end
endfunction

function [3:0] binding_slot_to_button;
    input [2:0] slot;
    begin
        case (slot)
            3'd0: binding_slot_to_button = 4'd4;  // A
            3'd1: binding_slot_to_button = 4'd5;  // B
            3'd2: binding_slot_to_button = 4'd6;  // X
            3'd3: binding_slot_to_button = 4'd7;  // Y
            3'd4: binding_slot_to_button = 4'd8;  // L
            3'd5: binding_slot_to_button = 4'd9;  // R
            default: binding_slot_to_button = 4'd15; // Start
        endcase
    end
endfunction

function [6:0] binding_slot_index;
    input [48:0] bus;
    input [2:0] slot;
    begin
        case (slot)
            3'd0: binding_slot_index = bus[6:0];
            3'd1: binding_slot_index = bus[13:7];
            3'd2: binding_slot_index = bus[20:14];
            3'd3: binding_slot_index = bus[27:21];
            3'd4: binding_slot_index = bus[34:28];
            3'd5: binding_slot_index = bus[41:35];
            default: binding_slot_index = bus[48:42];
        endcase
    end
endfunction

function [1:0] binding_slot_page;
    input [13:0] bus;
    input [2:0] slot;
    begin
        case (slot)
            3'd0: binding_slot_page = bus[1:0];
            3'd1: binding_slot_page = bus[3:2];
            3'd2: binding_slot_page = bus[5:4];
            3'd3: binding_slot_page = bus[7:6];
            3'd4: binding_slot_page = bus[9:8];
            3'd5: binding_slot_page = bus[11:10];
            default: binding_slot_page = bus[13:12];
        endcase
    end
endfunction

function target_matches;
    input [6:0] lhs_index;
    input [1:0] lhs_page;
    input [6:0] rhs_index;
    input [1:0] rhs_page;
    begin
        target_matches = 1'b0;
        if ((lhs_page == rhs_page) && (lhs_index == rhs_index)) begin
            target_matches = 1'b1;
        end else if ((lhs_page == 2'd0) && (rhs_page == 2'd0) &&
                     (((lhs_index == 7'd28) && (rhs_index == 7'd43)) ||
                      ((lhs_index == 7'd43) && (rhs_index == 7'd28)))) begin
            target_matches = 1'b1;
        end
    end
endfunction

function [6:0] bound_mask_for_target;
    input [6:0] target_index;
    input [1:0] target_page;
    input [6:0] valid_mask;
    input [48:0] index_bus;
    input [13:0] page_bus;
    integer slot_idx;
    begin
        bound_mask_for_target = 7'd0;
        for (slot_idx = 0; slot_idx < 7; slot_idx = slot_idx + 1) begin
            if (valid_mask[slot_idx] &&
                target_matches(
                    binding_slot_index(index_bus, slot_idx[2:0]),
                    binding_slot_page(page_bus, slot_idx[2:0]),
                    target_index,
                    target_page
                )) begin
                bound_mask_for_target[slot_idx] = 1'b1;
            end
        end
    end
endfunction

function any_bound_after_slot;
    input [6:0] mask;
    input [2:0] slot;
    begin
        case (slot)
            3'd0: any_bound_after_slot = |mask[6:1];
            3'd1: any_bound_after_slot = |mask[6:2];
            3'd2: any_bound_after_slot = |mask[6:3];
            3'd3: any_bound_after_slot = |mask[6:4];
            3'd4: any_bound_after_slot = |mask[6:5];
            3'd5: any_bound_after_slot = mask[6];
            default: any_bound_after_slot = 1'b0;
        endcase
    end
endfunction

function [5:0] bound_label_char_count;
    input [6:0] mask;
    integer slot_idx;
    reg [3:0] button;
    begin
        bound_label_char_count = 6'd0;
        for (slot_idx = 0; slot_idx < 7; slot_idx = slot_idx + 1) begin
            if (mask[slot_idx]) begin
                button = binding_slot_to_button(slot_idx[2:0]);
                bound_label_char_count = bound_label_char_count + {3'd0, button_label_len(button)};
                if (any_bound_after_slot(mask, slot_idx[2:0])) begin
                    bound_label_char_count = bound_label_char_count + 6'd2;
                end
            end
        end
    end
endfunction

function [5:0] status_char_count;
    input       bind_active;
    input       feedback_active;
    input [3:0] button;
    input [3:0] key_len;
    input [6:0] hover_mask;
    begin
        if (feedback_active) status_char_count = {3'd0, button_label_len(button)} + 6'd4 + {2'd0, key_len};
        else if (bind_active) status_char_count = 6'd33; // BIND: PRESS BUTTON, SELECT=CANCEL
        else status_char_count = 6'd7 + bound_label_char_count(hover_mask); // BOUND:
    end
endfunction

function [7:0] status_char;
    input [5:0] pos;
    input       bind_active;
    input       feedback_active;
    input [3:0] button;
    input [3:0] key_len;
    input [7:0] key0;
    input [7:0] key1;
    input [7:0] key2;
    input [6:0] hover_mask;
    reg [5:0] button_len;
    reg [5:0] remaining;
    reg [3:0] slot_button;
    integer slot_idx;
    begin
        status_char = 8'h20;
        button_len = 6'd0;
        if (feedback_active) begin
            button_len = {3'd0, button_label_len(button)};
            if (pos < button_len) begin
                status_char = button_label_char(button, pos[2:0]);
            end else if (pos == button_len) begin
                status_char = 8'h20;
            end else if (pos == (button_len + 6'd1)) begin
                status_char = "T";
            end else if (pos == (button_len + 6'd2)) begin
                status_char = "O";
            end else if (pos == (button_len + 6'd3)) begin
                status_char = 8'h20;
            end else begin
                case (pos - button_len - 6'd4)
                    6'd0: status_char = key0;
                    6'd1: status_char = (key_len >= 4'd2) ? key1 : 8'h20;
                    6'd2: status_char = (key_len >= 4'd3) ? key2 : 8'h20;
                    default: status_char = 8'h20;
                endcase
            end
        end else if (bind_active) begin
            case (pos)
                6'd0:  status_char = "B";
                6'd1:  status_char = "I";
                6'd2:  status_char = "N";
                6'd3:  status_char = "D";
                6'd4:  status_char = 8'h3A;
                6'd5:  status_char = 8'h20;
                6'd6:  status_char = "P";
                6'd7:  status_char = "R";
                6'd8:  status_char = "E";
                6'd9:  status_char = "S";
                6'd10: status_char = "S";
                6'd11: status_char = 8'h20;
                6'd12: status_char = "B";
                6'd13: status_char = "U";
                6'd14: status_char = "T";
                6'd15: status_char = "T";
                6'd16: status_char = "O";
                6'd17: status_char = "N";
                6'd18: status_char = 8'h2C;
                6'd19: status_char = 8'h20;
                6'd20: status_char = "S";
                6'd21: status_char = "E";
                6'd22: status_char = "L";
                6'd23: status_char = "E";
                6'd24: status_char = "C";
                6'd25: status_char = "T";
                6'd26: status_char = 8'h3D;
                6'd27: status_char = "C";
                6'd28: status_char = "A";
                6'd29: status_char = "N";
                6'd30: status_char = "C";
                6'd31: status_char = "E";
                6'd32: status_char = "L";
                default: status_char = 8'h20;
            endcase
        end else begin : bound_text
            case (pos)
                6'd0: status_char = "B";
                6'd1: status_char = "O";
                6'd2: status_char = "U";
                6'd3: status_char = "N";
                6'd4: status_char = "D";
                6'd5: status_char = 8'h3A;
                6'd6: status_char = 8'h20;
                default: begin
                    remaining = pos - 6'd7;
                    for (slot_idx = 0; slot_idx < 7; slot_idx = slot_idx + 1) begin
                        if (hover_mask[slot_idx]) begin
                            slot_button = binding_slot_to_button(slot_idx[2:0]);
                            if (remaining < {3'd0, button_label_len(slot_button)}) begin
                                status_char = button_label_char(slot_button, remaining[2:0]);
                                disable bound_text;
                            end
                            remaining = remaining - {3'd0, button_label_len(slot_button)};
                            if (any_bound_after_slot(hover_mask, slot_idx[2:0])) begin
                                if (remaining == 6'd0) begin
                                    status_char = 8'h2C;
                                    disable bound_text;
                                end
                                if (remaining == 6'd1) begin
                                    status_char = 8'h20;
                                    disable bound_text;
                                end
                                remaining = remaining - 6'd2;
                            end
                        end
                    end
                end
            endcase
        end
    end
endfunction

function [5:0] status_char_index_from_x;
    input [7:0] x_pos;
    begin
        if (x_pos < 8'd6) status_char_index_from_x = 6'd0;
        else if (x_pos < 8'd12) status_char_index_from_x = 6'd1;
        else if (x_pos < 8'd18) status_char_index_from_x = 6'd2;
        else if (x_pos < 8'd24) status_char_index_from_x = 6'd3;
        else if (x_pos < 8'd30) status_char_index_from_x = 6'd4;
        else if (x_pos < 8'd36) status_char_index_from_x = 6'd5;
        else if (x_pos < 8'd42) status_char_index_from_x = 6'd6;
        else if (x_pos < 8'd48) status_char_index_from_x = 6'd7;
        else if (x_pos < 8'd54) status_char_index_from_x = 6'd8;
        else if (x_pos < 8'd60) status_char_index_from_x = 6'd9;
        else if (x_pos < 8'd66) status_char_index_from_x = 6'd10;
        else if (x_pos < 8'd72) status_char_index_from_x = 6'd11;
        else if (x_pos < 8'd78) status_char_index_from_x = 6'd12;
        else if (x_pos < 8'd84) status_char_index_from_x = 6'd13;
        else if (x_pos < 8'd90) status_char_index_from_x = 6'd14;
        else if (x_pos < 8'd96) status_char_index_from_x = 6'd15;
        else if (x_pos < 8'd102) status_char_index_from_x = 6'd16;
        else if (x_pos < 8'd108) status_char_index_from_x = 6'd17;
        else if (x_pos < 8'd114) status_char_index_from_x = 6'd18;
        else if (x_pos < 8'd120) status_char_index_from_x = 6'd19;
        else if (x_pos < 8'd126) status_char_index_from_x = 6'd20;
        else if (x_pos < 8'd132) status_char_index_from_x = 6'd21;
        else if (x_pos < 8'd138) status_char_index_from_x = 6'd22;
        else if (x_pos < 8'd144) status_char_index_from_x = 6'd23;
        else if (x_pos < 8'd150) status_char_index_from_x = 6'd24;
        else if (x_pos < 8'd156) status_char_index_from_x = 6'd25;
        else if (x_pos < 8'd162) status_char_index_from_x = 6'd26;
        else if (x_pos < 8'd168) status_char_index_from_x = 6'd27;
        else if (x_pos < 8'd174) status_char_index_from_x = 6'd28;
        else if (x_pos < 8'd180) status_char_index_from_x = 6'd29;
        else if (x_pos < 8'd186) status_char_index_from_x = 6'd30;
        else if (x_pos < 8'd192) status_char_index_from_x = 6'd31;
        else if (x_pos < 8'd198) status_char_index_from_x = 6'd32;
        else status_char_index_from_x = 6'd63;
    end
endfunction

function [7:0] status_glyph_col_from_x;
    input [7:0] x_pos;
    begin
        if (x_pos < 8'd6) status_glyph_col_from_x = x_pos[2:0];
        else if (x_pos < 8'd12) status_glyph_col_from_x = x_pos - 8'd6;
        else if (x_pos < 8'd18) status_glyph_col_from_x = x_pos - 8'd12;
        else if (x_pos < 8'd24) status_glyph_col_from_x = x_pos - 8'd18;
        else if (x_pos < 8'd30) status_glyph_col_from_x = x_pos - 8'd24;
        else if (x_pos < 8'd36) status_glyph_col_from_x = x_pos - 8'd30;
        else if (x_pos < 8'd42) status_glyph_col_from_x = x_pos - 8'd36;
        else if (x_pos < 8'd48) status_glyph_col_from_x = x_pos - 8'd42;
        else if (x_pos < 8'd54) status_glyph_col_from_x = x_pos - 8'd48;
        else if (x_pos < 8'd60) status_glyph_col_from_x = x_pos - 8'd54;
        else if (x_pos < 8'd66) status_glyph_col_from_x = x_pos - 8'd60;
        else if (x_pos < 8'd72) status_glyph_col_from_x = x_pos - 8'd66;
        else if (x_pos < 8'd78) status_glyph_col_from_x = x_pos - 8'd72;
        else if (x_pos < 8'd84) status_glyph_col_from_x = x_pos - 8'd78;
        else if (x_pos < 8'd90) status_glyph_col_from_x = x_pos - 8'd84;
        else if (x_pos < 8'd96) status_glyph_col_from_x = x_pos - 8'd90;
        else if (x_pos < 8'd102) status_glyph_col_from_x = x_pos - 8'd96;
        else if (x_pos < 8'd108) status_glyph_col_from_x = x_pos - 8'd102;
        else if (x_pos < 8'd114) status_glyph_col_from_x = x_pos - 8'd108;
        else if (x_pos < 8'd120) status_glyph_col_from_x = x_pos - 8'd114;
        else if (x_pos < 8'd126) status_glyph_col_from_x = x_pos - 8'd120;
        else if (x_pos < 8'd132) status_glyph_col_from_x = x_pos - 8'd126;
        else if (x_pos < 8'd138) status_glyph_col_from_x = x_pos - 8'd132;
        else if (x_pos < 8'd144) status_glyph_col_from_x = x_pos - 8'd138;
        else if (x_pos < 8'd150) status_glyph_col_from_x = x_pos - 8'd144;
        else if (x_pos < 8'd156) status_glyph_col_from_x = x_pos - 8'd150;
        else if (x_pos < 8'd162) status_glyph_col_from_x = x_pos - 8'd156;
        else if (x_pos < 8'd168) status_glyph_col_from_x = x_pos - 8'd162;
        else if (x_pos < 8'd174) status_glyph_col_from_x = x_pos - 8'd168;
        else if (x_pos < 8'd180) status_glyph_col_from_x = x_pos - 8'd174;
        else if (x_pos < 8'd186) status_glyph_col_from_x = x_pos - 8'd180;
        else if (x_pos < 8'd192) status_glyph_col_from_x = x_pos - 8'd186;
        else if (x_pos < 8'd198) status_glyph_col_from_x = x_pos - 8'd192;
        else status_glyph_col_from_x = 3'd7;
    end
endfunction

wire [6:0] selected_bound_mask = bound_mask_for_target(selected_index, page, bound_valid_mask, bound_index_bus, bound_page_bus);
wire       bound_hover_active = (selected_bound_mask != 7'd0) && !bind_mode && !bind_feedback_active;
wire [6:0] status_key_index = bind_feedback_active ? bind_feedback_index : selected_index;
wire [1:0] status_key_page = bind_feedback_active ? bind_feedback_page : page;
wire [3:0] status_key_label_len = label_len(status_key_index, status_key_page);
wire [7:0] status_key_char0 = label_char(status_key_index, status_key_page, shift_label_mode, 3'd0);
wire [7:0] status_key_char1 = label_char(status_key_index, status_key_page, shift_label_mode, 3'd1);
wire [7:0] status_key_char2 = label_char(status_key_index, status_key_page, shift_label_mode, 3'd2);
wire [5:0] status_chars = status_char_count(bind_mode, bind_feedback_active, bind_feedback_button, status_key_label_len, selected_bound_mask);
localparam [7:0] STATUS_TEXT_X0 = 8'd6;
localparam [7:0] STATUS_TEXT_W = 8'd198;
wire [8:0] status_text_x_full = band_x[9:1] - {1'b0, STATUS_TEXT_X0};
wire [7:0] status_text_x = status_text_x_full[7:0];
wire       status_text_active = status_row_active &&
                                (band_x[9:1] >= STATUS_TEXT_X0) &&
                                (band_x[9:1] < (STATUS_TEXT_X0 + STATUS_TEXT_W));
wire [5:0] status_char_index = status_char_index_from_x(status_text_x);
wire [7:0] status_glyph_col_full = status_glyph_col_from_x(status_text_x);
wire [2:0] status_glyph_col = status_glyph_col_full[2:0];
wire [7:0] status_char_code = status_char(
    status_char_index,
    bind_mode,
    bind_feedback_active,
    bind_feedback_button,
    status_key_label_len,
    status_key_char0,
    status_key_char1,
    status_key_char2,
    selected_bound_mask
);
wire [4:0] status_glyph_bits = glyph_row_bits(status_char_code, status_glyph_row);
wire       status_glyph_region = status_text_active &&
                                 (status_band_y >= 9'd1) && (status_band_y < 9'd15) &&
                                 (status_char_index < status_chars) &&
                                 (status_glyph_col < 3'd5);
wire       status_glyph_on = status_glyph_region && status_glyph_bits[3'd4 - status_glyph_col];
wire       status_border = status_row_active && ((status_band_y == 9'd0) || (status_band_y == 9'd15) || (band_x == 10'd0) || (band_x == 10'd599));
wire [23:0] status_fill = bind_feedback_active ? 24'h203840 :
                          bind_mode ? 24'h402060 :
                                      24'h203820;
wire [23:0] status_border_color = bind_feedback_active ? 24'h8fd8ff :
                                  bind_mode ? 24'hb020ff :
                                              24'h58d8a0;
wire [23:0] status_glyph_color = 24'hffffff;

reg        in_band_r = 1'b0;
reg        glyph_on_r = 1'b0;
reg        selected_r = 1'b0;
reg        border_r = 1'b0;
reg        bind_mode_r = 1'b0;
reg        status_row_r = 1'b0;
reg        status_glyph_on_r = 1'b0;
reg        bind_feedback_active_r = 1'b0;
reg        status_border_r = 1'b0;
reg [23:0] key_fill_r = 24'h202020;
reg [23:0] key_border_r = 24'h606060;
reg [23:0] status_fill_r = 24'h402060;
reg [23:0] status_border_color_r = 24'hb020ff;

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

function [3:0] label_len;
    input [6:0] key_index;
    input [1:0] key_page;
    begin
        label_len = 4'd1;
        case (key_page)
            2'd0: begin
                case (key_index)
                    7'd0, 7'd13, 7'd14, 7'd15, 7'd28, 7'd30, 7'd43,
                    7'd45, 7'd58, 7'd60, 7'd62, 7'd64, 7'd71: label_len = 4'd3;
                    default: label_len = 4'd1;
                endcase
            end
            2'd1: begin
                case (key_index)
                    6'd0, 6'd1, 6'd2, 6'd15, 6'd16, 6'd17, 6'd30, 6'd31,
                    6'd32, 6'd45: label_len = 4'd2;
                    7'd8, 7'd22, 7'd23, 7'd24, 7'd38, 7'd52, 7'd53: label_len = 4'd3;
                    7'd11, 7'd26: label_len = COMPACT_PAGE1_MACRO_LABELS ? 4'd3 : 4'd5;
                    7'd41: label_len = 4'd3;
                    7'd56: label_len = COMPACT_PAGE1_MACRO_LABELS ? 4'd3 : 4'd4;
                    7'd71: label_len = COMPACT_PAGE1_MACRO_LABELS ? 4'd3 : 4'd8;
                    6'd4, 6'd18, 6'd19, 6'd20, 6'd34, 6'd46, 6'd48,
                    6'd49: label_len = 4'd3;
                    default: label_len = 4'd1;
                endcase
            end
            2'd2: begin
                case (key_index)
                    6'd0, 6'd1, 6'd2, 6'd3, 6'd4, 6'd5, 6'd7, 6'd8,
                    6'd9, 6'd10,
                    7'd30, 7'd31, 7'd32, 7'd33, 7'd34, 7'd35, 7'd36: label_len = 4'd3;
                    default: label_len = 4'd1;
                endcase
            end
            2'd3: begin
                case (key_index)
                    6'd0, 6'd1, 6'd2, 6'd3, 6'd4: label_len = 4'd3;
                    default: label_len = 4'd1;
                endcase
            end
            default: label_len = 4'd1;
        endcase
    end
endfunction

function [7:0] label_char;
    input [6:0] key_index;
    input [1:0] key_page;
    input       shift_main_page;
    input [2:0] pos;
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
                    7'd8:  case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "U"; 2'd2: label_char = "P"; default: label_char = 8'h20; endcase
                    7'd11: case (pos)
                        3'd0: label_char = COMPACT_PAGE1_MACRO_LABELS ? "T" : 8'h7C;
                        3'd1: label_char = COMPACT_PAGE1_MACRO_LABELS ? "A" : "T";
                        3'd2: label_char = COMPACT_PAGE1_MACRO_LABELS ? "P" : "A";
                        3'd3: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : "P";
                        3'd4: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : "E";
                        default: label_char = 8'h20;
                    endcase
                    7'd22: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "L"; 2'd2: label_char = "F"; default: label_char = 8'h20; endcase
                    7'd23: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "F"; 2'd2: label_char = "1"; default: label_char = 8'h20; endcase
                    7'd24: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "R"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    7'd26: case (pos)
                        3'd0: label_char = COMPACT_PAGE1_MACRO_LABELS ? "D" : 8'h7C;
                        3'd1: label_char = COMPACT_PAGE1_MACRO_LABELS ? "S" : "D";
                        3'd2: label_char = COMPACT_PAGE1_MACRO_LABELS ? "C" : "I";
                        3'd3: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : "S";
                        3'd4: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : "C";
                        default: label_char = 8'h20;
                    endcase
                    6'd30: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "1"; default: label_char = 8'h20; endcase
                    6'd31: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "2"; default: label_char = 8'h20; endcase
                    6'd32: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "3"; default: label_char = 8'h20; endcase
                    6'd34: case (pos) 2'd0: label_char = "D"; 2'd1: label_char = "N"; default: label_char = 8'h20; endcase
                    7'd38: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "D"; 2'd2: label_char = "N"; default: label_char = 8'h20; endcase
                    7'd41: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "A"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    6'd45: case (pos) 2'd0: label_char = "F"; 2'd1: label_char = "0"; default: label_char = 8'h20; endcase
                    6'd46: case (pos) 2'd0: label_char = "E"; 2'd1: label_char = "N"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    6'd48: case (pos) 2'd0: label_char = "C"; 2'd1: label_char = "L"; 2'd2: label_char = "R"; default: label_char = 8'h20; endcase
                    6'd49: case (pos) 2'd0: label_char = "D"; 2'd1: label_char = "E"; 2'd2: label_char = "L"; default: label_char = 8'h20; endcase
                    7'd52: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "F"; 2'd2: label_char = "2"; default: label_char = 8'h20; endcase
                    7'd53: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "F"; 2'd2: label_char = "3"; default: label_char = 8'h20; endcase
                    7'd56: case (pos)
                        3'd0: label_char = "R";
                        3'd1: label_char = "U";
                        3'd2: label_char = "N";
                        3'd3: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : 8'h22;
                        default: label_char = 8'h20;
                    endcase
                    7'd71: case (pos)
                        3'd0: label_char = COMPACT_PAGE1_MACRO_LABELS ? "R" : "R";
                        3'd1: label_char = COMPACT_PAGE1_MACRO_LABELS ? "D" : "U";
                        3'd2: label_char = COMPACT_PAGE1_MACRO_LABELS ? "S" : "N";
                        3'd3: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : 8'h22;
                        3'd4: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : "D";
                        3'd5: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : "I";
                        3'd6: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : "S";
                        3'd7: label_char = COMPACT_PAGE1_MACRO_LABELS ? 8'h20 : "C";
                        default: label_char = 8'h20;
                    endcase
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
                    7'd30: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "U"; 2'd2: label_char = "P"; default: label_char = 8'h20; endcase
                    7'd31: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "D"; 2'd2: label_char = "N"; default: label_char = 8'h20; endcase
                    7'd32: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "L"; 2'd2: label_char = "F"; default: label_char = 8'h20; endcase
                    7'd33: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "R"; 2'd2: label_char = "T"; default: label_char = 8'h20; endcase
                    7'd34: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "F"; 2'd2: label_char = "1"; default: label_char = 8'h20; endcase
                    7'd35: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "F"; 2'd2: label_char = "2"; default: label_char = 8'h20; endcase
                    7'd36: case (pos) 2'd0: label_char = "J"; 2'd1: label_char = "F"; 2'd2: label_char = "3"; default: label_char = 8'h20; endcase
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
                    7'd8:  key_index_to_char = 8'h55; // joy up
                    6'd15: key_index_to_char = 8'h34;
                    6'd16: key_index_to_char = 8'h35;
                    6'd17: key_index_to_char = 8'h36;
                    6'd18: key_index_to_char = 8'h4C; // Left
                    6'd19: key_index_to_char = 8'h50; // Copy
                    6'd20: key_index_to_char = 8'h52; // Right
                    7'd22: key_index_to_char = 8'h4C; // joy left
                    7'd23: key_index_to_char = 8'h31; // joy fire 1
                    7'd24: key_index_to_char = 8'h52; // joy right
                    6'd30: key_index_to_char = 8'h31;
                    6'd31: key_index_to_char = 8'h32;
                    6'd32: key_index_to_char = 8'h33;
                    6'd34: key_index_to_char = 8'h44; // Down
                    7'd38: key_index_to_char = 8'h44; // joy down
                    6'd45: key_index_to_char = 8'h30;
                    6'd46: key_index_to_char = 8'h0D;
                    6'd47: key_index_to_char = 8'h2E;
                    6'd48: key_index_to_char = 8'h43; // CLR
                    6'd49: key_index_to_char = 8'h44; // Del
                    7'd52: key_index_to_char = 8'h32; // joy fire 2
                    7'd53: key_index_to_char = 8'h33; // joy fire 3
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
                    7'd30: key_index_to_char = 8'h55; // joy up
                    7'd31: key_index_to_char = 8'h44; // joy down
                    7'd32: key_index_to_char = 8'h4C; // joy left
                    7'd33: key_index_to_char = 8'h52; // joy right
                    7'd34: key_index_to_char = 8'h31; // joy fire 1
                    7'd35: key_index_to_char = 8'h32; // joy fire 2
                    7'd36: key_index_to_char = 8'h33; // joy fire 3
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
        bind_mode_r  <= 1'b0;
        status_row_r <= 1'b0;
        status_glyph_on_r <= 1'b0;
        bind_feedback_active_r <= 1'b0;
        status_border_r <= 1'b0;
        key_fill_r   <= 24'h202020;
        key_border_r <= 24'h606060;
        status_fill_r <= 24'h402060;
        status_border_color_r <= 24'hb020ff;
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
        bind_mode_r  <= bind_mode;
        status_row_r <= status_row_active;
        status_glyph_on_r <= status_glyph_on;
        bind_feedback_active_r <= bind_feedback_active;
        status_border_r <= status_border;
        key_fill_r   <= key_fill;
        key_border_r <= key_border;
        status_fill_r <= status_fill;
        status_border_color_r <= status_border_color;
        overlay_on   <= in_band_r;

        if (in_band_r && status_row_r && status_glyph_on_r) rgb_out <= status_glyph_color;
        else if (in_band_r && status_row_r && status_border_r) rgb_out <= status_border_color_r;
        else if (in_band_r && status_row_r) rgb_out <= status_fill_r;
        else if (in_band_r && glyph_on_r) rgb_out <= selected_r ? 24'h000000 : 24'hffffff;
        else if (in_band_r && border_r) rgb_out <= selected_r ? 24'hffffff : key_border_r;
        else if (in_band_r) rgb_out <= selected_r ? (bind_mode_r ? 24'h8fd8ff : (bind_feedback_active_r ? 24'h7ad6ff : 24'hffd000)) : key_fill_r;
        else rgb_out <= rgb_in;
    end
end

endmodule

`default_nettype wire
