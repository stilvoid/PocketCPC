// Analogue Pocket controller to MiSTer CPC HID adapter.
//
// The imported CPC HID block already understands MiSTer-style 11-bit PS/2 key
// events: {toggle, pressed, extended, scan_code}. This adapter converts Pocket
// button transitions into that event stream without changing the CPC matrix
// implementation.

`default_nettype none

module cpc_pocket_input (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [31:0] cont1_key,

    output reg  [10:0] ps2_key,
    output wire [6:0]  joy1,
    output wire [6:0]  joy2
);

wire [15:0] buttons = cont1_key[15:0];

reg [15:0] buttons_prev = 16'd0;
reg [15:0] pending      = 16'd0;

// Leave joystick lines idle for this first keyboard-focused input path. The
// Pocket buttons below are presented as CPC keyboard keys instead.
assign joy1 = 7'd0;
assign joy2 = 7'd0;

function [9:0] map_button_to_ps2;
    input [3:0] button;
    begin
        case (button)
            4'd0: map_button_to_ps2 = {1'b1, 1'b1, 8'h75}; // D-pad up    -> Cursor up
            4'd1: map_button_to_ps2 = {1'b1, 1'b1, 8'h72}; // D-pad down  -> Cursor down
            4'd2: map_button_to_ps2 = {1'b1, 1'b1, 8'h6B}; // D-pad left  -> Cursor left
            4'd3: map_button_to_ps2 = {1'b1, 1'b1, 8'h74}; // D-pad right -> Cursor right
            4'd4: map_button_to_ps2 = {1'b1, 1'b0, 8'h5A}; // A           -> Enter
            4'd5: map_button_to_ps2 = {1'b1, 1'b0, 8'h29}; // B           -> Space
            4'd6: map_button_to_ps2 = {1'b1, 1'b0, 8'h66}; // X           -> Delete/Backspace
            4'd7: map_button_to_ps2 = {1'b1, 1'b0, 8'h76}; // Y           -> Escape
            4'd8: map_button_to_ps2 = {1'b1, 1'b0, 8'h12}; // L           -> Shift
            4'd9: map_button_to_ps2 = {1'b1, 1'b0, 8'h14}; // R           -> Ctrl
            default: map_button_to_ps2 = 10'd0;
        endcase
    end
endfunction

reg [15:0] next_pending;
reg [3:0]  selected_button;
reg [9:0]  selected_ps2;
reg        selected_valid;
integer    scan_idx;

always @(*) begin
    next_pending    = pending | (buttons ^ buttons_prev);
    selected_button = 4'd0;
    selected_ps2    = 10'd0;
    selected_valid  = 1'b0;

    for (scan_idx = 0; scan_idx < 16; scan_idx = scan_idx + 1) begin
        if (next_pending[scan_idx] && !selected_valid) begin
            selected_ps2 = map_button_to_ps2(scan_idx[3:0]);
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
    end else begin
        buttons_prev <= buttons;
        pending      <= next_pending;

        if (selected_valid) begin
            pending[selected_button] <= 1'b0;
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
