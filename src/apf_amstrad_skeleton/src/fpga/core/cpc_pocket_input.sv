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
    input  wire [31:0] cont3_key,
    input  wire [31:0] cont3_joy,
    input  wire [15:0] cont3_trig,

    output reg  [10:0] ps2_key,
    output wire [6:0]  joy1,
    output wire [6:0]  joy2,
    output reg         vkb_active,
    output reg  [6:0]  vkb_index,
    output reg  [1:0]  vkb_page,
    output reg         vkb_shift,
    output reg         vkb_ctrl,
    output reg         vkb_caps,
    output reg         vkb_caps_pulse
);

localparam [7:0] PS2_LSHIFT = 8'h12;
localparam [7:0] PS2_CTRL   = 8'h14;
localparam [22:0] VKB_CAPS_PULSE_CYCLES = 23'd7_999_999;
localparam [20:0] MACRO_PRESS_DELAY_CYCLES   = 21'd1_279_999; // ~20 ms @ 64 MHz
localparam [20:0] MACRO_RELEASE_DELAY_CYCLES = 21'd255_999;   // ~4 ms  @ 64 MHz

wire [15:0] buttons = cont1_key[15:0];
wire [15:0] changed = buttons ^ buttons_prev;
wire [15:0] pressed = buttons & ~buttons_prev;
wire [7:0] dock_keyboard_mods = cont3_key[15:8];
wire [47:0] dock_keyboard_codes = {
    cont3_joy[31:24],
    cont3_joy[23:16],
    cont3_joy[15:8],
    cont3_joy[7:0],
    cont3_trig[15:8],
    cont3_trig[7:0]
};

reg [15:0] buttons_prev = 16'd0;
reg [15:0] pending      = 16'd0;
reg [8:0]  vkb_a_ps2    = {1'b0, 8'h16};
reg [22:0] vkb_caps_pulse_timer = 23'd0;
reg [7:0]  dock_keyboard_mods_active = 8'd0;
reg [47:0] dock_keyboard_codes_active = 48'd0;
reg [7:0]  dock_keyboard_mods_sample = 8'd0;
reg [47:0] dock_keyboard_codes_sample = 48'd0;
reg [1:0]  dock_keyboard_phase = 2'd3;
reg [2:0]  dock_keyboard_index = 3'd0;
reg         macro_active = 1'b0;
reg  [2:0]  macro_id = 3'd0;
reg  [5:0]  macro_step = 6'd0;
reg         macro_release_shift = 1'b0;
reg         macro_release_ctrl = 1'b0;
reg  [20:0] macro_delay = 21'd0;

// Reuse the MiSTer CPC joystick bit ordering exactly as exposed by joydb.sv:
// {fire3, fire2, fire1, up, down, left, right}. hid.sv performs its own final
// row-local remap after this. Blank joystick activity while the virtual
// keyboard overlay is open so overlay navigation doesn't leak into software.
assign joy1 = vkb_active ? 7'd0 : {
    buttons[6], // X -> fire 3
    buttons[5], // B -> fire 2
    buttons[4], // A -> fire 1
    buttons[0], // D-pad up
    buttons[1], // D-pad down
    buttons[2], // D-pad left
    buttons[3]  // D-pad right
};
assign joy2 = 7'd0;

function [9:0] map_vkb_index_to_ps2;
    input [6:0] key_index;
    input [1:0] page;
    begin
        map_vkb_index_to_ps2 = 10'd0;
        case (page)
            2'd0: begin
                case (key_index)
                    6'd0:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h76}; // Esc
                    6'd1:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h16}; // 1
                    6'd2:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1E}; // 2
                    6'd3:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h26}; // 3
                    6'd4:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h25}; // 4
                    6'd5:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2E}; // 5
                    6'd6:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h36}; // 6
                    6'd7:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3D}; // 7
                    6'd8:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3E}; // 8
                    6'd9:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h46}; // 9
                    6'd10: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h45}; // 0
                    6'd11: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4E}; // -
                    6'd12: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h55}; // ^
                    6'd13: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h71}; // CLR
                    6'd14: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h66}; // Del

                    6'd15: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0D}; // Tab
                    6'd16: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h15}; // Q
                    6'd17: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1D}; // W
                    6'd18: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h24}; // E
                    6'd19: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2D}; // R
                    6'd20: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2C}; // T
                    6'd21: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h35}; // Y
                    6'd22: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3C}; // U
                    6'd23: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h43}; // I
                    6'd24: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h44}; // O
                    6'd25: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4D}; // P
                    6'd26: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h54}; // @
                    6'd27: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5B}; // [
                    6'd28: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5A}; // Return

                    6'd30: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h58}; // Caps Lock
                    6'd31: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1C}; // A
                    6'd32: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1B}; // S
                    6'd33: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h23}; // D
                    6'd34: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2B}; // F
                    6'd35: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h34}; // G
                    6'd36: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h33}; // H
                    6'd37: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3B}; // J
                    6'd38: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h42}; // K
                    6'd39: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4B}; // L
                    6'd40: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4C}; // :
                    6'd41: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h52}; // ;
                    6'd42: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5D}; // ]
                    6'd43: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5A}; // Return

                    7'd45: map_vkb_index_to_ps2 = {1'b1, 1'b0, PS2_LSHIFT}; // Left Shift
                    7'd47: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h1A}; // Z
                    7'd48: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h22}; // X
                    7'd49: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h21}; // C
                    7'd50: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h2A}; // V
                    7'd51: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h32}; // B
                    7'd52: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h31}; // N
                    7'd53: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h3A}; // M
                    7'd54: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h41}; // ,
                    7'd55: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h49}; // .
                    7'd56: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4A}; // /
                    7'd57: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h61}; // backslash
                    7'd58: map_vkb_index_to_ps2 = {1'b1, 1'b0, PS2_LSHIFT}; // Right Shift

                    7'd60: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h14}; // Ctrl
                    7'd62: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h70}; // Copy
                    7'd64: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h29}; // Space
                    7'd71: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h69}; // Enter
                    default: map_vkb_index_to_ps2 = 10'd0;
                endcase
            end
            2'd1: begin
                case (key_index)
                    6'd0:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h83}; // F7
                    6'd1:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0A}; // F8
                    6'd2:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h01}; // F9
                    6'd4:  map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h75}; // Up
                    6'd15: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0C}; // F4
                    6'd16: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h03}; // F5
                    6'd17: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0B}; // F6
                    6'd18: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h6B}; // Left
                    6'd19: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h70}; // Copy
                    6'd20: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h74}; // Right
                    6'd30: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h05}; // F1
                    6'd31: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h06}; // F2
                    6'd32: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h04}; // F3
                    6'd34: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h72}; // Down
                    6'd45: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h09}; // F0
                    6'd46: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h69}; // keypad Enter
                    6'd47: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h7A}; // keypad .
                    6'd48: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h71}; // CLR
                    6'd49: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h66}; // Del
                    default: map_vkb_index_to_ps2 = 10'd0;
                endcase
            end
            2'd2: begin
                case (key_index)
                    6'd0:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h76}; // Esc
                    6'd1:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h0D}; // Tab
                    6'd2:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h58}; // Caps Lock
                    6'd3:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h14}; // Ctrl
                    6'd4:  map_vkb_index_to_ps2 = {1'b1, 1'b0, PS2_LSHIFT}; // Shift
                    6'd5:  map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h70}; // Copy
                    6'd6:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h29}; // Space
                    6'd7:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5A}; // Return
                    6'd8:  map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h69}; // Enter
                    6'd9:  map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h66}; // Del
                    6'd10: map_vkb_index_to_ps2 = {1'b1, 1'b1, 8'h71}; // CLR
                    6'd11: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4E}; // -
                    6'd12: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h55}; // ^
                    6'd13: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h54}; // @
                    6'd14: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5B}; // [
                    6'd15: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h5D}; // ]
                    6'd16: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h61}; // backslash
                    6'd17: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4C}; // :
                    6'd18: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h52}; // ;
                    6'd19: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h41}; // ,
                    6'd20: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h49}; // .
                    6'd21: map_vkb_index_to_ps2 = {1'b1, 1'b0, 8'h4A}; // /
                    default: map_vkb_index_to_ps2 = 10'd0;
                endcase
            end
            default: map_vkb_index_to_ps2 = 10'd0;
        endcase
    end
endfunction

function automatic [7:0] dock_keyboard_code_at;
    input [47:0] report;
    input [2:0] index;
    begin
        case (index)
            3'd0: dock_keyboard_code_at = report[47:40];
            3'd1: dock_keyboard_code_at = report[39:32];
            3'd2: dock_keyboard_code_at = report[31:24];
            3'd3: dock_keyboard_code_at = report[23:16];
            3'd4: dock_keyboard_code_at = report[15:8];
            3'd5: dock_keyboard_code_at = report[7:0];
            default: dock_keyboard_code_at = 8'd0;
        endcase
    end
endfunction

function automatic dock_keyboard_code_present;
    input [7:0] code;
    input [47:0] report;
    integer idx;
    begin
        dock_keyboard_code_present = 1'b0;
        if (code != 8'd0) begin
            for (idx = 0; idx < 6; idx = idx + 1) begin
                if (dock_keyboard_code_at(report, idx[2:0]) == code) begin
                    dock_keyboard_code_present = 1'b1;
                end
            end
        end
    end
endfunction

function automatic [9:0] map_usb_hid_to_ps2;
    input [7:0] hid_code;
    begin
        map_usb_hid_to_ps2 = 10'd0;
        case (hid_code)
            8'h04: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h1C}; // A
            8'h05: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h32}; // B
            8'h06: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h21}; // C
            8'h07: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h23}; // D
            8'h08: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h24}; // E
            8'h09: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h2B}; // F
            8'h0A: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h34}; // G
            8'h0B: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h33}; // H
            8'h0C: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h43}; // I
            8'h0D: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h3B}; // J
            8'h0E: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h42}; // K
            8'h0F: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h4B}; // L
            8'h10: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h3A}; // M
            8'h11: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h31}; // N
            8'h12: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h44}; // O
            8'h13: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h4D}; // P
            8'h14: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h15}; // Q
            8'h15: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h2D}; // R
            8'h16: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h1B}; // S
            8'h17: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h2C}; // T
            8'h18: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h3C}; // U
            8'h19: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h2A}; // V
            8'h1A: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h1D}; // W
            8'h1B: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h22}; // X
            8'h1C: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h35}; // Y
            8'h1D: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h1A}; // Z
            8'h1E: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h16}; // 1
            8'h1F: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h1E}; // 2
            8'h20: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h26}; // 3
            8'h21: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h25}; // 4
            8'h22: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h2E}; // 5
            8'h23: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h36}; // 6
            8'h24: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h3D}; // 7
            8'h25: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h3E}; // 8
            8'h26: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h46}; // 9
            8'h27: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h45}; // 0
            8'h28: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h5A}; // Enter
            8'h29: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h76}; // Escape
            8'h2A: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h66}; // Backspace
            8'h2B: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h0D}; // Tab
            8'h2C: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h29}; // Space
            8'h2D: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h4E}; // -
            8'h2E: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h55}; // =
            8'h2F: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h54}; // [
            8'h30: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h5B}; // ]
            8'h31: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h5D}; // backslash
            8'h33: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h4C}; // ;
            8'h34: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h52}; // quote
            8'h36: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h41}; // ,
            8'h37: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h49}; // .
            8'h38: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h4A}; // /
            8'h39: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h58}; // Caps Lock
            8'h3A: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h05}; // F1
            8'h3B: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h06}; // F2
            8'h3C: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h04}; // F3
            8'h3D: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h0C}; // F4
            8'h3E: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h03}; // F5
            8'h3F: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h0B}; // F6
            8'h40: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h83}; // F7
            8'h41: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h0A}; // F8
            8'h42: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h01}; // F9
            8'h43: map_usb_hid_to_ps2 = {1'b1, 1'b0, 8'h09}; // F10 -> CPC F0
            8'h4C: map_usb_hid_to_ps2 = {1'b1, 1'b1, 8'h71}; // Delete
            8'h4F: map_usb_hid_to_ps2 = {1'b1, 1'b1, 8'h74}; // Right
            8'h50: map_usb_hid_to_ps2 = {1'b1, 1'b1, 8'h6B}; // Left
            8'h51: map_usb_hid_to_ps2 = {1'b1, 1'b1, 8'h72}; // Down
            8'h52: map_usb_hid_to_ps2 = {1'b1, 1'b1, 8'h75}; // Up
            default: map_usb_hid_to_ps2 = 10'd0;
        endcase
    end
endfunction

function automatic [9:0] map_dock_modifier_to_ps2;
    input [2:0] mod_index;
    begin
        map_dock_modifier_to_ps2 = 10'd0;
        case (mod_index)
            3'd0: map_dock_modifier_to_ps2 = {1'b1, 1'b0, PS2_CTRL};   // Left Ctrl
            3'd1: map_dock_modifier_to_ps2 = {1'b1, 1'b0, PS2_LSHIFT}; // Left Shift
            3'd4: map_dock_modifier_to_ps2 = {1'b1, 1'b0, PS2_CTRL};   // Right Ctrl
            3'd5: map_dock_modifier_to_ps2 = {1'b1, 1'b0, PS2_LSHIFT}; // Right Shift
            default: map_dock_modifier_to_ps2 = 10'd0;
        endcase
    end
endfunction

function [9:0] map_normal_button_to_ps2;
    input [3:0] button;
    begin
        case (button)
            4'd0: map_normal_button_to_ps2 = 10'd0; // D-pad up handled as joystick
            4'd1: map_normal_button_to_ps2 = 10'd0; // D-pad down handled as joystick
            4'd2: map_normal_button_to_ps2 = 10'd0; // D-pad left handled as joystick
            4'd3: map_normal_button_to_ps2 = 10'd0; // D-pad right handled as joystick
            4'd4: map_normal_button_to_ps2 = 10'd0; // A handled as joystick fire 1
            4'd5: map_normal_button_to_ps2 = 10'd0; // B handled as joystick fire 2
            4'd6: map_normal_button_to_ps2 = 10'd0; // X handled as joystick fire 3
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
            4'd6: map_vkb_button_to_ps2 = {1'b1, 1'b0, 8'h5A}; // X -> Return
            4'd7: map_vkb_button_to_ps2 = {1'b1, 1'b0, 8'h66}; // Y -> Delete/Backspace
            default: map_vkb_button_to_ps2 = 10'd0;
        endcase
    end
endfunction

function vkb_is_macro_key;
    input [6:0] key_index;
    input [1:0] page;
    begin
        vkb_is_macro_key = (page == 2'd3) && (key_index <= 7'd4);
    end
endfunction

function [2:0] vkb_macro_id;
    input [6:0] key_index;
    input [1:0] page;
    begin
        if ((page == 2'd3) && (key_index <= 7'd4)) vkb_macro_id = key_index[2:0] + 3'd1;
        else vkb_macro_id = 3'd0;
    end
endfunction

function [5:0] macro_body_len;
    input [2:0] id;
    begin
        case (id)
            3'd1: macro_body_len = 6'd14; // |TAPE<ret>
            3'd2: macro_body_len = 6'd14; // |DISC<ret>
            3'd3: macro_body_len = 6'd8;  // CAT<ret>
            3'd4: macro_body_len = 6'd12; // RUN"<ret>
            3'd5: macro_body_len = 6'd24; // RUN"DISC"<ret>
            default: macro_body_len = 6'd0;
        endcase
    end
endfunction

function [10:0] macro_body_event;
    input [2:0] id;
    input [5:0] step;
    begin
        macro_body_event = 11'd0;
        case (id)
            3'd1: begin
                case (step)
                    6'd0:  macro_body_event = {1'b1, 1'b1, 1'b0, PS2_LSHIFT};
                    6'd1:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h54};
                    6'd2:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h54};
                    6'd3:  macro_body_event = {1'b1, 1'b0, 1'b0, PS2_LSHIFT};
                    6'd4:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h2C};
                    6'd5:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h2C};
                    6'd6:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h1C};
                    6'd7:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h1C};
                    6'd8:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h4D};
                    6'd9:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h4D};
                    6'd10: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h24};
                    6'd11: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h24};
                    6'd12: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h5A};
                    6'd13: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h5A};
                    default: macro_body_event = 11'd0;
                endcase
            end
            3'd2: begin
                case (step)
                    6'd0:  macro_body_event = {1'b1, 1'b1, 1'b0, PS2_LSHIFT};
                    6'd1:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h54};
                    6'd2:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h54};
                    6'd3:  macro_body_event = {1'b1, 1'b0, 1'b0, PS2_LSHIFT};
                    6'd4:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h23};
                    6'd5:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h23};
                    6'd6:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h43};
                    6'd7:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h43};
                    6'd8:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h1B};
                    6'd9:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h1B};
                    6'd10: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h21};
                    6'd11: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h21};
                    6'd12: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h5A};
                    6'd13: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h5A};
                    default: macro_body_event = 11'd0;
                endcase
            end
            3'd3: begin
                case (step)
                    6'd0: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h21};
                    6'd1: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h21};
                    6'd2: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h1C};
                    6'd3: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h1C};
                    6'd4: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h2C};
                    6'd5: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h2C};
                    6'd6: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h5A};
                    6'd7: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h5A};
                    default: macro_body_event = 11'd0;
                endcase
            end
            3'd4: begin
                case (step)
                    6'd0: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h2D};
                    6'd1: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h2D};
                    6'd2: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h3C};
                    6'd3: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h3C};
                    6'd4: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h31};
                    6'd5: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h31};
                    6'd6: macro_body_event = {1'b1, 1'b1, 1'b0, PS2_LSHIFT};
                    6'd7: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h1E};
                    6'd8: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h1E};
                    6'd9: macro_body_event = {1'b1, 1'b0, 1'b0, PS2_LSHIFT};
                    6'd10: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h5A};
                    6'd11: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h5A};
                    default: macro_body_event = 11'd0;
                endcase
            end
            3'd5: begin
                case (step)
                    6'd0:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h2D};
                    6'd1:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h2D};
                    6'd2:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h3C};
                    6'd3:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h3C};
                    6'd4:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h31};
                    6'd5:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h31};
                    6'd6:  macro_body_event = {1'b1, 1'b1, 1'b0, PS2_LSHIFT};
                    6'd7:  macro_body_event = {1'b1, 1'b1, 1'b0, 8'h1E};
                    6'd8:  macro_body_event = {1'b1, 1'b0, 1'b0, 8'h1E};
                    6'd9:  macro_body_event = {1'b1, 1'b0, 1'b0, PS2_LSHIFT};
                    6'd10: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h23};
                    6'd11: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h23};
                    6'd12: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h43};
                    6'd13: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h43};
                    6'd14: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h1B};
                    6'd15: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h1B};
                    6'd16: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h21};
                    6'd17: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h21};
                    6'd18: macro_body_event = {1'b1, 1'b1, 1'b0, PS2_LSHIFT};
                    6'd19: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h1E};
                    6'd20: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h1E};
                    6'd21: macro_body_event = {1'b1, 1'b0, 1'b0, PS2_LSHIFT};
                    6'd22: macro_body_event = {1'b1, 1'b1, 1'b0, 8'h5A};
                    6'd23: macro_body_event = {1'b1, 1'b0, 1'b0, 8'h5A};
                    default: macro_body_event = 11'd0;
                endcase
            end
            default: macro_body_event = 11'd0;
        endcase
    end
endfunction

function vkb_is_shift_key;
    input [6:0] key_index;
    input [1:0] page;
    begin
        vkb_is_shift_key = ((page == 2'd0) && ((key_index == 7'd45) || (key_index == 7'd58))) ||
                           ((page == 2'd2) && (key_index == 6'd4));
    end
endfunction

function vkb_is_ctrl_key;
    input [6:0] key_index;
    input [1:0] page;
    begin
        vkb_is_ctrl_key = ((page == 2'd0) && (key_index == 7'd60)) ||
                          ((page == 2'd2) && (key_index == 6'd3));
    end
endfunction

function vkb_is_caps_key;
    input [6:0] key_index;
    input [1:0] page;
    begin
        vkb_is_caps_key = ((page == 2'd0) && (key_index == 7'd30)) ||
                          ((page == 2'd2) && (key_index == 6'd2));
    end
endfunction

function [6:0] vkb_clamp_index;
    input [6:0] key_index;
    input [1:0] page;
    begin
        vkb_clamp_index = key_index;
        if (page == 2'd0) begin
            case (key_index)
                7'd29: vkb_clamp_index = 7'd28;
                7'd44: vkb_clamp_index = 7'd43;
                7'd46: vkb_clamp_index = 7'd45;
                7'd59: vkb_clamp_index = 7'd58;
                7'd61: vkb_clamp_index = 7'd60;
                7'd63: vkb_clamp_index = 7'd62;
                7'd65, 7'd66, 7'd67, 7'd68, 7'd69, 7'd70: vkb_clamp_index = 7'd64;
                7'd72, 7'd73, 7'd74: vkb_clamp_index = 7'd71;
                default: vkb_clamp_index = key_index;
            endcase
        end else if (key_index > vkb_page_last_index(page)) begin
            vkb_clamp_index = vkb_page_last_index(page);
        end
    end
endfunction

function [6:0] vkb_page_last_index;
    input [1:0] page;
    begin
        case (page)
            2'd0: vkb_page_last_index = 7'd74;
            2'd1: vkb_page_last_index = 7'd49;
            2'd2: vkb_page_last_index = 7'd21;
            default: vkb_page_last_index = 7'd4;
        endcase
    end
endfunction

function [6:0] vkb_page_last_movable_row;
    input [1:0] page;
    begin
        case (page)
            2'd0: vkb_page_last_movable_row = 7'd59;
            2'd1: vkb_page_last_movable_row = 7'd34;
            2'd2: vkb_page_last_movable_row = 7'd6;
            default: vkb_page_last_movable_row = 7'd0;
        endcase
    end
endfunction

reg [15:0] next_pending;
reg [3:0]  selected_button;
reg [9:0]  selected_ps2;
reg        selected_valid;
integer    scan_idx;

wire [7:0] dock_active_code = dock_keyboard_code_at(dock_keyboard_codes_active, dock_keyboard_index);
wire [7:0] dock_report_code = dock_keyboard_code_at(dock_keyboard_codes_sample, dock_keyboard_index);
wire [9:0] dock_modifier_ps2 = map_dock_modifier_to_ps2(dock_keyboard_index);
wire [9:0] dock_active_ps2 = map_usb_hid_to_ps2(dock_active_code);
wire [9:0] dock_report_ps2 = map_usb_hid_to_ps2(dock_report_code);
wire [1:0] macro_prelude_len = {1'b0, macro_release_ctrl} + {1'b0, macro_release_shift};
wire [5:0] macro_total_len = macro_body_len(macro_id) + {4'd0, macro_prelude_len};
reg  [10:0] macro_ps2_event;
reg         macro_ps2_valid;
reg  [5:0]  macro_body_step;

always @(*) begin
    next_pending    = macro_active ? 16'd0 : (pending | changed);
    selected_button = 4'd0;
    selected_ps2    = 10'd0;
    selected_valid  = 1'b0;
    macro_ps2_event = 11'd0;
    macro_ps2_valid = 1'b0;
    macro_body_step = 6'd0;

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
        if (vkb_is_shift_key(vkb_index, vkb_page) ||
            vkb_is_ctrl_key(vkb_index, vkb_page) ||
            vkb_is_caps_key(vkb_index, vkb_page) ||
            vkb_is_macro_key(vkb_index, vkb_page)) begin
            next_pending[4] = 1'b0;
        end
    end

    if (macro_active && (macro_step < macro_total_len)) begin
        if (macro_release_ctrl && (macro_step == 6'd0)) begin
            macro_ps2_event = {1'b1, 1'b0, 1'b0, PS2_CTRL};
            macro_ps2_valid = 1'b1;
        end else if (macro_release_shift &&
                     (((!macro_release_ctrl) && (macro_step == 6'd0)) ||
                      (macro_release_ctrl && (macro_step == 6'd1)))) begin
            macro_ps2_event = {1'b1, 1'b0, 1'b0, PS2_LSHIFT};
            macro_ps2_valid = 1'b1;
        end else begin
            macro_body_step = macro_step - {4'd0, macro_prelude_len};
            macro_ps2_event = macro_body_event(macro_id, macro_body_step);
            macro_ps2_valid = macro_ps2_event[10];
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
        vkb_index    <= 7'd0;
        vkb_page     <= 2'd0;
        vkb_shift    <= 1'b0;
        vkb_ctrl     <= 1'b0;
        vkb_caps     <= 1'b0;
        vkb_caps_pulse <= 1'b0;
        vkb_a_ps2    <= {1'b0, 8'h16};
        vkb_caps_pulse_timer <= 23'd0;
        dock_keyboard_mods_active  <= 8'd0;
        dock_keyboard_codes_active <= 48'd0;
        dock_keyboard_mods_sample  <= 8'd0;
        dock_keyboard_codes_sample <= 48'd0;
        dock_keyboard_phase <= 2'd3;
        dock_keyboard_index <= 3'd0;
        macro_active <= 1'b0;
        macro_id <= 3'd0;
        macro_step <= 6'd0;
        macro_release_shift <= 1'b0;
        macro_release_ctrl <= 1'b0;
        macro_delay <= 21'd0;
    end else begin
        buttons_prev <= buttons;
        pending      <= next_pending;

        if (vkb_caps_pulse) begin
            if (vkb_caps_pulse_timer == 23'd0) begin
                vkb_caps_pulse <= 1'b0;
            end else begin
                vkb_caps_pulse_timer <= vkb_caps_pulse_timer - 23'd1;
            end
        end

        begin
            if (pressed[14]) begin
                vkb_active <= ~vkb_active;
                pending    <= 16'd0;
                macro_active <= 1'b0;
                macro_step <= 6'd0;
                macro_release_shift <= 1'b0;
                macro_release_ctrl <= 1'b0;
                macro_delay <= 21'd0;
                if (vkb_active && vkb_shift) begin
                    vkb_shift <= 1'b0;
                    ps2_key <= {~ps2_key[10], 1'b0, 1'b0, PS2_LSHIFT};
                end
            end

            if (vkb_active && !macro_active) begin
                if (pressed[8]) begin
                    vkb_shift <= ~vkb_shift;
                    ps2_key <= {~ps2_key[10], !vkb_shift, 1'b0, PS2_LSHIFT};
                end
                if (pressed[4] && vkb_is_shift_key(vkb_index, vkb_page)) begin
                    vkb_shift <= ~vkb_shift;
                    ps2_key <= {~ps2_key[10], !vkb_shift, 1'b0, PS2_LSHIFT};
                end
                if (pressed[4] && vkb_is_ctrl_key(vkb_index, vkb_page)) begin
                    vkb_ctrl <= ~vkb_ctrl;
                    ps2_key <= {~ps2_key[10], !vkb_ctrl, 1'b0, PS2_CTRL};
                end
                if (pressed[4] && vkb_is_caps_key(vkb_index, vkb_page)) begin
                    if (!vkb_caps_pulse) begin
                        vkb_caps <= ~vkb_caps;
                        vkb_caps_pulse <= 1'b1;
                        vkb_caps_pulse_timer <= VKB_CAPS_PULSE_CYCLES;
                    end
                end
                if (pressed[4] && vkb_is_macro_key(vkb_index, vkb_page) && !macro_active) begin
                    macro_active <= 1'b1;
                    macro_id <= vkb_macro_id(vkb_index, vkb_page);
                    macro_step <= 6'd0;
                    macro_release_shift <= vkb_shift;
                    macro_release_ctrl <= vkb_ctrl;
                    macro_delay <= 21'd0;
                    pending <= 16'd0;
                    if (vkb_shift) vkb_shift <= 1'b0;
                    if (vkb_ctrl) vkb_ctrl <= 1'b0;
                end
                if (pressed[9]) begin
                    if (vkb_page == 2'd3) vkb_page <= 2'd0;
                    else vkb_page <= vkb_page + 2'd1;
                    vkb_index <= 7'd0;
                end

                if (pressed[0] && (vkb_index >= 7'd15)) vkb_index <= vkb_clamp_index(vkb_index - 7'd15, vkb_page);
                if (pressed[1] && (vkb_index <= vkb_page_last_movable_row(vkb_page))) vkb_index <= vkb_clamp_index(vkb_index + 7'd15, vkb_page);
                if (pressed[2]) begin
                    if (vkb_index == 7'd0) vkb_index <= vkb_page_last_index(vkb_page);
                    else if (vkb_index == 7'd15) vkb_index <= vkb_clamp_index(7'd29, vkb_page);
                    else if (vkb_index == 7'd30) vkb_index <= vkb_clamp_index(7'd44, vkb_page);
                    else if (vkb_index == 7'd45) vkb_index <= vkb_clamp_index(7'd59, vkb_page);
                    else if (vkb_index == 7'd60) vkb_index <= vkb_clamp_index(vkb_page_last_index(vkb_page), vkb_page);
                    else vkb_index <= vkb_clamp_index(vkb_index - 6'd1, vkb_page);
                end
                if (pressed[3]) begin
                    if (vkb_index == vkb_page_last_index(vkb_page)) vkb_index <= 7'd0;
                    else if ((vkb_page == 2'd0) && (vkb_index == 7'd28)) vkb_index <= 7'd15;
                    else if ((vkb_page == 2'd0) && (vkb_index == 7'd43)) vkb_index <= 7'd30;
                    else if ((vkb_page == 2'd0) && (vkb_index == 7'd45)) vkb_index <= 7'd47;
                    else if ((vkb_page == 2'd0) && (vkb_index == 7'd58)) vkb_index <= 7'd45;
                    else if ((vkb_page == 2'd0) && (vkb_index == 7'd60)) vkb_index <= 7'd62;
                    else if ((vkb_page == 2'd0) && (vkb_index == 7'd62)) vkb_index <= 7'd64;
                    else if ((vkb_page == 2'd0) && (vkb_index == 7'd64)) vkb_index <= 7'd71;
                    else if ((vkb_page == 2'd0) && (vkb_index == 7'd71)) vkb_index <= 7'd60;
                    else if (vkb_index == 7'd29) vkb_index <= 7'd15;
                    else if (vkb_index == 7'd44) vkb_index <= 7'd30;
                    else if (vkb_index == 7'd59) vkb_index <= 7'd45;
                    else vkb_index <= vkb_clamp_index(vkb_index + 6'd1, vkb_page);
                end
            end

            if (macro_active && (macro_delay != 21'd0)) begin
                macro_delay <= macro_delay - 21'd1;
            end else if (macro_active && macro_ps2_valid) begin
                ps2_key <= {~ps2_key[10], macro_ps2_event[9], macro_ps2_event[8], macro_ps2_event[7:0]};
                macro_step <= macro_step + 6'd1;
                if (macro_ps2_event[9]) macro_delay <= MACRO_PRESS_DELAY_CYCLES;
                else macro_delay <= MACRO_RELEASE_DELAY_CYCLES;
                if (macro_step + 6'd1 >= macro_total_len) begin
                    macro_active <= 1'b0;
                    macro_release_shift <= 1'b0;
                    macro_release_ctrl <= 1'b0;
                    macro_delay <= 21'd0;
                end
            end else if (macro_active) begin
                macro_active <= 1'b0;
                macro_step <= 6'd0;
                macro_release_shift <= 1'b0;
                macro_release_ctrl <= 1'b0;
                macro_delay <= 21'd0;
            end else if (selected_valid) begin
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
            end else begin
                case (dock_keyboard_phase)
                2'd0: begin
                    if ((dock_keyboard_mods_sample[dock_keyboard_index] != dock_keyboard_mods_active[dock_keyboard_index]) &&
                        dock_modifier_ps2[9]) begin
                        ps2_key <= {
                            ~ps2_key[10],
                            dock_keyboard_mods_sample[dock_keyboard_index],
                            dock_modifier_ps2[8],
                            dock_modifier_ps2[7:0]
                        };
                        dock_keyboard_mods_active[dock_keyboard_index] <= dock_keyboard_mods_sample[dock_keyboard_index];
                    end

                    if (dock_keyboard_index == 3'd7) begin
                        dock_keyboard_index <= 3'd0;
                        dock_keyboard_phase <= 2'd1;
                    end else begin
                        dock_keyboard_index <= dock_keyboard_index + 3'd1;
                    end
                end

                2'd1: begin
                    if ((dock_active_code != 8'd0) &&
                        !dock_keyboard_code_present(dock_active_code, dock_keyboard_codes_sample) &&
                        dock_active_ps2[9]) begin
                        ps2_key <= {~ps2_key[10], 1'b0, dock_active_ps2[8], dock_active_ps2[7:0]};
                    end

                    if (dock_keyboard_index == 3'd5) begin
                        dock_keyboard_index <= 3'd0;
                        dock_keyboard_phase <= 2'd2;
                    end else begin
                        dock_keyboard_index <= dock_keyboard_index + 3'd1;
                    end
                end

                default: begin
                    if (dock_keyboard_phase == 2'd3) begin
                        dock_keyboard_mods_sample  <= dock_keyboard_mods;
                        dock_keyboard_codes_sample <= dock_keyboard_codes;
                        dock_keyboard_index <= 3'd0;
                        dock_keyboard_phase <= 2'd0;
                    end else begin
                        if ((dock_report_code != 8'd0) &&
                            !dock_keyboard_code_present(dock_report_code, dock_keyboard_codes_active) &&
                            dock_report_ps2[9]) begin
                            ps2_key <= {~ps2_key[10], 1'b1, dock_report_ps2[8], dock_report_ps2[7:0]};
                        end

                        if (dock_keyboard_index == 3'd5) begin
                            dock_keyboard_index <= 3'd0;
                            dock_keyboard_phase <= 2'd3;
                            dock_keyboard_codes_active <= dock_keyboard_codes_sample;
                        end else begin
                            dock_keyboard_index <= dock_keyboard_index + 3'd1;
                        end
                    end
                end
                endcase
            end
        end
    end
end

endmodule

`default_nettype wire
