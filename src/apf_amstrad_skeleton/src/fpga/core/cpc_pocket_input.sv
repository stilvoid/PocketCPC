// Analogue Pocket controller to MiSTer CPC HID adapter.
//
// The imported CPC HID block already understands MiSTer-style 11-bit PS/2 key
// events: {toggle, pressed, extended, scan_code}. This adapter converts Pocket
// button transitions into that event stream without changing the CPC matrix
// implementation. Select toggles a small hardware virtual keyboard layer.

`default_nettype none

module cpc_pocket_input (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [31:0] cont1_key,

    output reg  [10:0] ps2_key,
    output wire [6:0]  joy1,
    output wire [6:0]  joy2,
    output reg         vkb_active,
    output reg  [5:0]  vkb_index,
    output reg  [1:0]  vkb_page,
    output reg         vkb_shift
);

localparam [7:0] PS2_LSHIFT = 8'h12;

wire [15:0] buttons = cont1_key[15:0];
wire [15:0] changed = buttons ^ buttons_prev;
wire [15:0] pressed = buttons & ~buttons_prev;

reg [15:0] buttons_prev = 16'd0;
reg [15:0] pending      = 16'd0;
reg [8:0]  vkb_a_ps2    = {1'b0, 8'h16};

// Leave joystick lines idle for this first keyboard-focused input path. The
// Pocket buttons below are presented as CPC keyboard keys instead.
assign joy1 = 7'd0;
assign joy2 = 7'd0;

function [9:0] map_vkb_index_to_ps2;
    input [5:0] key_index;
    input [1:0] page;
    begin
        map_vkb_index_to_ps2 = 10'd0;
        case (page)
            2'd0: begin
                case (key_index)
                    6'd0:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h16}; // 1
                    6'd1:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1E}; // 2
                    6'd2:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h26}; // 3
                    6'd3:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h25}; // 4
                    6'd4:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2E}; // 5
                    6'd5:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h36}; // 6
                    6'd6:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3D}; // 7
                    6'd7:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3E}; // 8
                    6'd8:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h46}; // 9
                    6'd9:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h45}; // 0
                    6'd10: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h15}; // Q
                    6'd11: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1D}; // W
                    6'd12: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h24}; // E
                    6'd13: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2D}; // R
                    6'd14: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2C}; // T
                    6'd15: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h35}; // Y
                    6'd16: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3C}; // U
                    6'd17: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h43}; // I
                    6'd18: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h44}; // O
                    6'd19: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4D}; // P
                    6'd20: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1C}; // A
                    6'd21: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1B}; // S
                    6'd22: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h23}; // D
                    6'd23: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2B}; // F
                    6'd24: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h34}; // G
                    6'd25: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h33}; // H
                    6'd26: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3B}; // J
                    6'd27: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h42}; // K
                    6'd28: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4B}; // L
                    6'd29: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4C}; // :
                    6'd30: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1A}; // Z
                    6'd31: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h22}; // X
                    6'd32: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h21}; // C
                    6'd33: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2A}; // V
                    6'd34: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h32}; // B
                    6'd35: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h31}; // N
                    6'd36: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3A}; // M
                    6'd37: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h41}; // ,
                    6'd38: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h49}; // .
                    6'd39: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4A}; // /
                    default: map_vkb_index_to_ps2 = 10'd0;
                endcase
            end
            2'd1: begin
                case (key_index)
                    6'd0:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h76}; // Esc
                    6'd1:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0D}; // Tab
                    6'd2:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h58}; // Caps Lock
                    6'd3:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h14}; // Ctrl
                    6'd5:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5A}; // Enter
                    6'd6:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h66}; // Del
                    6'd7:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h29}; // Space
                    6'd8:  map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h70}; // Copy
                    6'd9:  map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h71}; // CLR
                    6'd10: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h54}; // @
                    6'd11: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5B}; // [
                    6'd12: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5D}; // ]
                    6'd13: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h61}; // backslash
                    6'd14: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4E}; // -
                    6'd15: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h55}; // +
                    6'd16: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h52}; // ;
                    6'd17: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4C}; // :
                    6'd18: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4A}; // /
                    6'd19: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h49}; // .
                    6'd20: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h41}; // ,
                    default: map_vkb_index_to_ps2 = 10'd0;
                endcase
            end
            2'd2: begin
                case (key_index)
                    6'd0:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h09}; // F0
                    6'd1:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h05}; // F1
                    6'd2:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h06}; // F2
                    6'd3:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h04}; // F3
                    6'd4:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0C}; // F4
                    6'd5:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h03}; // F5
                    6'd6:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0B}; // F6
                    6'd7:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h83}; // F7
                    6'd8:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0A}; // F8
                    6'd9:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h01}; // F9
                    6'd10: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h75}; // Up
                    6'd11: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h6B}; // Left
                    6'd12: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h72}; // Down
                    6'd13: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h74}; // Right
                    6'd14: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h69}; // keypad Enter
                    6'd15: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h7A}; // keypad .
                    6'd16: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h70}; // Copy
                    6'd17: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h71}; // CLR
                    default: map_vkb_index_to_ps2 = 10'd0;
                endcase
            end
            default: map_vkb_index_to_ps2 = 10'd0;
        endcase
    end
endfunction

function [9:0] map_normal_button_to_ps2;
    input [3:0] button;
    begin
        case (button)
            4'd0: map_normal_button_to_ps2 = {1'b1, 1'b1, 8'h75}; // D-pad up    -> Cursor up
            4'd1: map_normal_button_to_ps2 = {1'b1, 1'b1, 8'h72}; // D-pad down  -> Cursor down
            4'd2: map_normal_button_to_ps2 = {1'b1, 1'b1, 8'h6B}; // D-pad left  -> Cursor left
            4'd3: map_normal_button_to_ps2 = {1'b1, 1'b1, 8'h74}; // D-pad right -> Cursor right
            4'd4: map_normal_button_to_ps2 = {1'b1, 1'b0, 8'h5A}; // A           -> Enter
            4'd5: map_normal_button_to_ps2 = {1'b1, 1'b0, 8'h29}; // B           -> Space
            4'd6: map_normal_button_to_ps2 = {1'b1, 1'b0, 8'h66}; // X           -> Delete/Backspace
            4'd7: map_normal_button_to_ps2 = {1'b1, 1'b0, 8'h76}; // Y           -> Escape
            4'd8: map_normal_button_to_ps2 = {1'b1, 1'b0, PS2_LSHIFT}; // L       -> Shift
            4'd9: map_normal_button_to_ps2 = {1'b1, 1'b0, 8'h14}; // R           -> Ctrl
            default: map_normal_button_to_ps2 = 10'd0;
        endcase
    end
endfunction

function [9:0] map_vkb_button_to_ps2;
    input [3:0] button;
    input       is_pressed;
    begin
        case (button)
            4'd4: map_vkb_button_to_ps2 = is_pressed ? map_vkb_index_to_ps2(vkb_index, vkb_page) : {1'b1, vkb_a_ps2};
            4'd5: map_vkb_button_to_ps2 = {1'b1, 1'b0, 8'h29}; // B -> Space
            4'd6: map_vkb_button_to_ps2 = {1'b1, 1'b0, 8'h66}; // X -> Delete/Backspace
            4'd7: map_vkb_button_to_ps2 = {1'b1, 1'b0, 8'h76}; // Y -> Escape
            default: map_vkb_button_to_ps2 = 10'd0;
        endcase
    end
endfunction

function vkb_is_shift_key;
    input [5:0] key_index;
    input [1:0] page;
    begin
        vkb_is_shift_key = (page == 2'd1) && (key_index == 6'd4);
    end
endfunction

reg [15:0] next_pending;
reg [3:0]  selected_button;
reg [9:0]  selected_ps2;
reg        selected_valid;
integer    scan_idx;

always @(*) begin
    next_pending    = pending | changed;
    selected_button = 4'd0;
    selected_ps2    = 10'd0;
    selected_valid  = 1'b0;

    // Select toggles the on-screen keyboard locally, and Start is consumed by
    // the existing core reset path in core_top.
    next_pending[14] = 1'b0;
    next_pending[15] = 1'b0;

    if (vkb_active) begin
        next_pending[3:0] = 4'b0000;
        next_pending[8]   = 1'b0;
        next_pending[9]   = 1'b0;
        next_pending[10]  = 1'b0;
        next_pending[11]  = 1'b0;
        next_pending[12]  = 1'b0;
        next_pending[13]  = 1'b0;
        if (vkb_is_shift_key(vkb_index, vkb_page)) begin
            next_pending[4] = 1'b0;
        end
    end

    for (scan_idx = 0; scan_idx < 16; scan_idx = scan_idx + 1) begin
        if (next_pending[scan_idx] && !selected_valid) begin
            if (vkb_active) selected_ps2 = map_vkb_button_to_ps2(scan_idx[3:0], buttons[scan_idx]);
            else selected_ps2 = map_normal_button_to_ps2(scan_idx[3:0]);

            if (selected_ps2[9]) begin
                selected_button = scan_idx[3:0];
                selected_valid  = 1'b1;
            end else begin
                next_pending[scan_idx] = 1'b0;
            end
        end
    end
end

always @(posedge clk) begin
    if (!reset_n) begin
        buttons_prev <= 16'd0;
        pending      <= 16'd0;
        ps2_key      <= 11'd0;
        vkb_active   <= 1'b0;
        vkb_index    <= 6'd0;
        vkb_page     <= 2'd0;
        vkb_shift    <= 1'b0;
        vkb_a_ps2    <= {1'b0, 8'h16};
    end else begin
        buttons_prev <= buttons;
        pending      <= next_pending;

        if (pressed[14]) begin
            vkb_active <= ~vkb_active;
            pending    <= 16'd0;
            if (vkb_active && vkb_shift) begin
                vkb_shift <= 1'b0;
                ps2_key <= {~ps2_key[10], 1'b0, 1'b0, PS2_LSHIFT};
            end
        end

        if (vkb_active) begin
            if (pressed[8]) begin
                vkb_shift <= ~vkb_shift;
                ps2_key <= {~ps2_key[10], !vkb_shift, 1'b0, PS2_LSHIFT};
            end
            if (pressed[4] && vkb_is_shift_key(vkb_index, vkb_page)) begin
                vkb_shift <= ~vkb_shift;
                ps2_key <= {~ps2_key[10], !vkb_shift, 1'b0, PS2_LSHIFT};
            end
            if (pressed[9]) begin
                if (vkb_page == 2'd2) vkb_page <= 2'd0;
                else vkb_page <= vkb_page + 2'd1;
            end

            if (pressed[0] && (vkb_index >= 6'd10)) vkb_index <= vkb_index - 6'd10;
            if (pressed[1] && (vkb_index <  6'd30)) vkb_index <= vkb_index + 6'd10;
            if (pressed[2]) begin
                if (vkb_index == 6'd0) vkb_index <= 6'd9;
                else if (vkb_index == 6'd10) vkb_index <= 6'd19;
                else if (vkb_index == 6'd20) vkb_index <= 6'd29;
                else if (vkb_index == 6'd30) vkb_index <= 6'd39;
                else vkb_index <= vkb_index - 6'd1;
            end
            if (pressed[3]) begin
                if (vkb_index == 6'd9) vkb_index <= 6'd0;
                else if (vkb_index == 6'd19) vkb_index <= 6'd10;
                else if (vkb_index == 6'd29) vkb_index <= 6'd20;
                else if (vkb_index == 6'd39) vkb_index <= 6'd30;
                else vkb_index <= vkb_index + 6'd1;
            end
        end

        if (selected_valid) begin
            pending[selected_button] <= 1'b0;
            if (vkb_active && selected_button == 4'd4 && buttons[4]) begin
                vkb_a_ps2 <= selected_ps2[8:0];
            end
            ps2_key <= {
                ~ps2_key[10],
                buttons[selected_button],
                selected_ps2[8],
                selected_ps2[7:0]
            };
        end
    end
end

endmodule

`default_nettype wire
