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
//
// Adapted from budude2/openfpga-GBC src/gb/data_loader.sv.

`default_nettype none

module pocket_apf_write_loader #(
    parameter [3:0] ADDRESS_MASK_UPPER_4 = 4'h6,
    parameter integer ADDRESS_SIZE = 18,
    parameter integer WRITE_MEM_CLOCK_DELAY = 4,
    parameter integer WRITE_MEM_EN_CYCLE_LENGTH = 1
) (
    input  wire        clk_74a,
    input  wire        clk_memory,
    input  wire        reset_n,
    input  wire        enable,

    input  wire        bridge_wr,
    input  wire        bridge_endian_little,
    input  wire [31:0] bridge_addr,
    input  wire [31:0] bridge_wr_data,

    output reg         write_en = 1'b0,
    output reg  [ADDRESS_SIZE-1:0] write_addr = {ADDRESS_SIZE{1'b0}},
    output reg  [7:0]  write_data = 8'd0,
    output reg  [31:0] write_count = 32'd0
);

localparam integer FIFO_SIZE = 8 + 28;
localparam [5:0] READ_NONE = 6'd0;
localparam [5:0] READ_DELAY = 6'd1;
localparam [5:0] READ_WRITE = 6'd2;
localparam [5:0] READ_WRITE_EN_CYCLE_OFF = READ_WRITE + WRITE_MEM_EN_CYCLE_LENGTH;
localparam integer READ_WRITE_END_DEFAULT = WRITE_MEM_CLOCK_DELAY - 1;
localparam [5:0] READ_WRITE_END =
    (READ_WRITE_END_DEFAULT > (READ_WRITE_EN_CYCLE_OFF + 1)) ?
        READ_WRITE_END_DEFAULT :
        (READ_WRITE_EN_CYCLE_OFF + 1);
localparam HAS_DELAY = READ_WRITE_END_DEFAULT > READ_WRITE_EN_CYCLE_OFF;

wire mem_empty;
wire [FIFO_SIZE-1:0] fifo_out;

reg        read_req = 1'b0;
reg        write_req = 1'b0;
reg [31:0] shift_data = 32'd0;
reg [27:0] buff_bridge_addr = 28'd0;
reg        prev_bridge_wr = 1'b0;
reg [1:0]  write_count_word = 2'd0;
reg [1:0]  write_state = 2'd0;
reg [5:0]  read_state = 6'd0;

wire [FIFO_SIZE-1:0] fifo_in = {shift_data[7:0], buff_bridge_addr[27:0]};
wire bridge_write_start =
    reset_n &&
    enable &&
    !prev_bridge_wr &&
    bridge_wr &&
    (bridge_addr[31:28] == ADDRESS_MASK_UPPER_4);

dcfifo loader_fifo (
    .data    ( fifo_in ),
    .rdclk   ( clk_memory ),
    .rdreq   ( read_req ),
    .wrclk   ( clk_74a ),
    .wrreq   ( write_req ),
    .q       ( fifo_out ),
    .rdempty ( mem_empty ),
    .aclr    ( !reset_n ),
    .wrempty ( ),
    .eccstatus ( ),
    .rdfull  ( ),
    .rdusedw ( ),
    .wrfull  ( ),
    .wrusedw ( )
);
defparam
    loader_fifo.clocks_are_synchronized = "FALSE",
    loader_fifo.intended_device_family = "Cyclone V",
    loader_fifo.lpm_numwords = 4,
    loader_fifo.lpm_showahead = "OFF",
    loader_fifo.lpm_type = "dcfifo",
    loader_fifo.lpm_width = FIFO_SIZE,
    loader_fifo.lpm_widthu = 2,
    loader_fifo.overflow_checking = "OFF",
    loader_fifo.rdsync_delaypipe = 5,
    loader_fifo.underflow_checking = "OFF",
    loader_fifo.use_eab = "OFF",
    loader_fifo.wrsync_delaypipe = 5;

always @(posedge clk_74a or negedge reset_n) begin
    if (!reset_n) begin
        prev_bridge_wr   <= 1'b0;
        write_req        <= 1'b0;
        shift_data       <= 32'd0;
        buff_bridge_addr <= 28'd0;
        write_count_word <= 2'd0;
        write_state      <= 2'd0;
    end else begin
        prev_bridge_wr <= bridge_wr;

        if (bridge_write_start) begin
            write_state      <= 2'd2;
            write_req        <= 1'b1;
            write_count_word <= 2'd0;
            shift_data       <= bridge_endian_little ? bridge_wr_data : {
                bridge_wr_data[7:0],
                bridge_wr_data[15:8],
                bridge_wr_data[23:16],
                bridge_wr_data[31:24]
            };
            buff_bridge_addr <= bridge_addr[27:0];
        end

        case (write_state)
            2'd1: begin
                write_req   <= 1'b1;
                write_state <= 2'd2;
            end
            2'd2: begin
                write_req        <= 1'b0;
                shift_data       <= {8'h00, shift_data[31:8]};
                buff_bridge_addr <= buff_bridge_addr + 28'd1;
                write_count_word <= write_count_word + 2'd1;
                if (write_count_word == 2'd3) begin
                    write_state <= 2'd0;
                end else begin
                    write_state <= 2'd1;
                end
            end
            default: begin
            end
        endcase
    end
end

always @(posedge clk_memory or negedge reset_n) begin
    if (!reset_n) begin
        read_req    <= 1'b0;
        read_state  <= READ_NONE;
        write_en    <= 1'b0;
        write_addr  <= {ADDRESS_SIZE{1'b0}};
        write_data  <= 8'd0;
        write_count <= 32'd0;
    end else begin
        if (read_state != READ_NONE) begin
            read_state <= read_state + 6'd1;
        end else if (!mem_empty) begin
            read_state <= READ_DELAY;
            read_req   <= 1'b1;
        end

        case (read_state)
            READ_DELAY: begin
                read_req <= 1'b0;
                write_en <= 1'b0;
            end
            READ_WRITE: begin
                write_en    <= 1'b1;
                write_addr  <= fifo_out[ADDRESS_SIZE-1:0];
                write_data  <= fifo_out[FIFO_SIZE-1:28];
                write_count <= write_count + 32'd1;
            end
            READ_WRITE_EN_CYCLE_OFF: begin
                write_en <= 1'b0;
                if (!HAS_DELAY) begin
                    read_state <= READ_NONE;
                end
            end
            READ_WRITE_END: begin
                read_state <= READ_NONE;
            end
            default: begin
            end
        endcase
    end
end

initial begin
    if (WRITE_MEM_CLOCK_DELAY < 4) begin
        $error("WRITE_MEM_CLOCK_DELAY has a minimum value of 4. Received %d", WRITE_MEM_CLOCK_DELAY);
    end
    if ((WRITE_MEM_EN_CYCLE_LENGTH < 1) ||
        (WRITE_MEM_EN_CYCLE_LENGTH >= (WRITE_MEM_CLOCK_DELAY - 2))) begin
        $error("WRITE_MEM_EN_CYCLE_LENGTH is outside the supported range.");
    end
end

endmodule

`default_nettype wire
