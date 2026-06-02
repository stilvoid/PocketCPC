// MIT License
//
// Copyright (c) 2022 Adam Gastineau
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

`default_nettype none

module sound_i2s #(
    parameter CHANNEL_WIDTH = 16,
    parameter SIGNED_INPUT  = 0
) (
    input  wire                       audio_clk,
    input  wire [CHANNEL_WIDTH-1:0]   audio_l,
    input  wire [CHANNEL_WIDTH-1:0]   audio_r,
    output reg                        audio_lrck = 1'b0,
    output reg                        audio_dac  = 1'b0
);

localparam integer CHANNEL_LEFT_HIGH  = 16;
localparam integer CHANNEL_RIGHT_HIGH = 32;
localparam integer SIGNED_CHANNEL_WIDTH = SIGNED_INPUT ? CHANNEL_WIDTH : CHANNEL_WIDTH + 1;

wire [CHANNEL_WIDTH-1:0] sign_converted_audio_l = {
    audio_l[CHANNEL_WIDTH-1:CHANNEL_WIDTH-1], audio_l[CHANNEL_WIDTH-2:0]
};
wire [CHANNEL_WIDTH-1:0] sign_converted_audio_r = {
    audio_r[CHANNEL_WIDTH-1:CHANNEL_WIDTH-1], audio_r[CHANNEL_WIDTH-2:0]
};

wire [31:0] audgen_sampdata;

assign audgen_sampdata[CHANNEL_LEFT_HIGH-1:CHANNEL_LEFT_HIGH-CHANNEL_WIDTH] =
    SIGNED_INPUT ? audio_l : sign_converted_audio_l;
assign audgen_sampdata[CHANNEL_RIGHT_HIGH-1:CHANNEL_RIGHT_HIGH-CHANNEL_WIDTH] =
    SIGNED_INPUT ? audio_r : sign_converted_audio_r;

generate
    if (15 - SIGNED_CHANNEL_WIDTH > 0) begin : gen_pad
        assign audgen_sampdata[31-SIGNED_CHANNEL_WIDTH:16] = '0;
        assign audgen_sampdata[15-SIGNED_CHANNEL_WIDTH:0]  = '0;
    end
endgenerate

reg [31:0] audgen_sampshift = 32'd0;
reg [4:0]  audio_lrck_cnt   = 5'd0;
reg [1:0]  audio_clk_div    = 2'd0;

always @(posedge audio_clk) begin
    audio_clk_div <= audio_clk_div + 2'd1;

    if (audio_clk_div == 2'd3) begin
        audio_dac <= audgen_sampshift[31];
        audio_lrck_cnt <= audio_lrck_cnt + 5'd1;

        if (audio_lrck_cnt == 5'd31) begin
            audio_lrck <= ~audio_lrck;
            if (!audio_lrck) begin
                audgen_sampshift <= audgen_sampdata;
            end
        end else if (audio_lrck_cnt < 5'd16) begin
            audgen_sampshift <= {audgen_sampshift[30:0], 1'b0};
        end
    end
end

initial begin
    if (CHANNEL_WIDTH > 16) begin
        $error("CHANNEL_WIDTH must be <= 16. Received %0d", CHANNEL_WIDTH);
    end
    if ((SIGNED_INPUT != 0) && (SIGNED_INPUT != 1)) begin
        $error("SIGNED_INPUT must be 0 or 1. Received %0d", SIGNED_INPUT);
    end
end

endmodule

`default_nettype wire
