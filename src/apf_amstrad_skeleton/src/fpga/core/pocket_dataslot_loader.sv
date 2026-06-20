//
// Minimal APF dataslot reader derived from the Pocket ZX Spectrum core's
// bridge-RAM loading pattern.
//
// After the framework releases the core from reset, it requests the same 0x200
// `boot.rom` slot used by the Pocket ZX Spectrum core in 1024-byte chunks.
// The Pocket host writes each chunk to bridge RAM at 0x60000000, and this
// loader streams the buffer byte-by-byte to CPC ROM RAM.
//

`default_nettype none

module pocket_dataslot_loader #(
    parameter [15:0] SLOT_ID = 16'h0200,
    parameter [31:0] TOTAL_BYTES = 32'h0000_c000
) (
    input  wire        clk,
    input  wire        bridge_clk,
    input  wire        reset_n,
    input  wire        start,

    input  wire [31:0] bridge_addr,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    output reg  [9:0]  datatable_addr,
    input  wire [31:0] datatable_q,

    output reg         target_dataslot_read,
    output reg [15:0]  target_dataslot_id,
    output reg [31:0]  target_dataslot_slotoffset,
    output reg [31:0]  target_dataslot_bridgeaddr,
    output reg [31:0]  target_dataslot_length,
    output reg         cmd_request_flag,
    output reg         cmd_write_strobe,
    input  wire        cmd_ack_flag,
    input  wire        target_dataslot_ack,
    input  wire        target_dataslot_done,
    input  wire [2:0]  target_dataslot_err,

    output reg         loader_wr,
    output reg [17:0]  loader_addr,
    output reg [7:0]   loader_data,
    output reg         loader_done,
    output reg         loader_error,
    output wire [3:0]  debug_state,
    output wire [31:0] debug_offset
);

localparam [31:0] BRIDGE_RAM_ADDR = 32'h6000_0000;
localparam [31:0] CHUNK_BYTES     = 32'd1024;

localparam [3:0] ST_RESET        = 4'd0;
localparam [3:0] ST_WAIT_START   = 4'd1;
localparam [3:0] ST_REQUEST      = 4'd4;
localparam [3:0] ST_REQUEST_HOLD = 4'd5;
localparam [3:0] ST_WAIT_ACK     = 4'd6;
localparam [3:0] ST_WAIT_DONE    = 4'd7;
localparam [3:0] ST_STREAM_ADDR  = 4'd8;
localparam [3:0] ST_STREAM_WAIT  = 4'd9;
localparam [3:0] ST_STREAM_DATA  = 4'd10;
localparam [3:0] ST_NEXT_CHUNK   = 4'd11;
localparam [3:0] ST_DONE         = 4'd12;
localparam [3:0] ST_ERROR        = 4'd13;

reg [3:0]  state = ST_RESET;
reg [3:0]  debug_state_r = ST_RESET;
reg [15:0] start_delay = 16'd0;
reg [31:0] file_offset = 32'd0;
reg [31:0] remaining = TOTAL_BYTES;
reg [10:0] chunk_len = 11'd0;
reg [10:0] stream_index = 11'd0;
reg [7:0]  bram_rd_addr = 8'd0;
wire [31:0] bram_rd_data;

assign debug_state  = debug_state_r;
assign debug_offset = file_offset;

bram_block_dp #(
    .DATA(32),
    .ADDR(8)
) bridge_ram (
    .a_clk  ( bridge_clk ),
    .a_wr   ( bridge_wr && (bridge_addr[31:28] == 4'h6) ),
    .a_addr ( bridge_addr[9:2] ),
    .a_din  ( {bridge_wr_data[7:0], bridge_wr_data[15:8], bridge_wr_data[23:16], bridge_wr_data[31:24]} ),
    .a_dout ( ),

    .b_clk  ( clk ),
    .b_wr   ( 1'b0 ),
    .b_addr ( bram_rd_addr ),
    .b_din  ( 32'd0 ),
    .b_dout ( bram_rd_data )
);

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state                       <= ST_RESET;
        debug_state_r               <= ST_RESET;
        start_delay                 <= 16'd0;
        file_offset                 <= 32'd0;
        remaining                   <= TOTAL_BYTES;
        chunk_len                   <= 11'd0;
        stream_index                <= 11'd0;
        bram_rd_addr                <= 8'd0;
        datatable_addr              <= 10'd0;
        target_dataslot_read        <= 1'b0;
        target_dataslot_id          <= SLOT_ID;
        target_dataslot_slotoffset  <= 32'd0;
        target_dataslot_bridgeaddr  <= BRIDGE_RAM_ADDR;
        target_dataslot_length      <= 32'd0;
        cmd_request_flag            <= 1'b0;
        cmd_write_strobe            <= 1'b0;
        loader_wr                   <= 1'b0;
        loader_addr                 <= 18'd0;
        loader_data                 <= 8'd0;
        loader_done                 <= 1'b0;
        loader_error                <= 1'b0;
    end else begin
        loader_wr <= 1'b0;
        cmd_write_strobe <= 1'b0;

        case (state)
            ST_RESET: begin
                debug_state_r       <= ST_RESET;
                target_dataslot_read <= 1'b0;
                loader_done          <= 1'b0;
                loader_error         <= 1'b0;
                file_offset          <= 32'd0;
                remaining            <= TOTAL_BYTES;
                start_delay          <= 16'd0;
                state                <= ST_WAIT_START;
            end

            ST_WAIT_START: begin
                debug_state_r       <= ST_WAIT_START;
                target_dataslot_read <= 1'b0;
                cmd_write_strobe     <= 1'b0;
                cmd_request_flag     <= 1'b0;
                datatable_addr       <= 10'd0;
                if (&start_delay) begin
                    file_offset <= 32'd0;
                    remaining   <= TOTAL_BYTES;
                    state       <= ST_REQUEST;
                end else if (start) begin
                    start_delay <= start_delay + 16'd1;
                end else begin
                    start_delay <= 16'd0;
                end
            end

            ST_REQUEST: begin
                debug_state_r              <= ST_REQUEST;
                target_dataslot_id         <= SLOT_ID;
                target_dataslot_slotoffset <= file_offset;
                target_dataslot_bridgeaddr <= BRIDGE_RAM_ADDR;
                target_dataslot_length     <= (remaining > CHUNK_BYTES) ? CHUNK_BYTES : remaining;
                chunk_len                  <= (remaining >= CHUNK_BYTES) ? 11'd1024 : {1'b0, remaining[9:0]};
                target_dataslot_read       <= 1'b1;
                cmd_request_flag           <= 1'b1;
                cmd_write_strobe           <= 1'b1;
                state                      <= ST_REQUEST_HOLD;
            end

            ST_REQUEST_HOLD: begin
                debug_state_r        <= ST_REQUEST_HOLD;
                target_dataslot_read <= 1'b1;
                cmd_request_flag     <= 1'b1;
                cmd_write_strobe     <= 1'b1;
                if (cmd_ack_flag) begin
                    cmd_write_strobe <= 1'b0;
                    cmd_request_flag <= 1'b0;
                    state            <= ST_WAIT_ACK;
                end
            end

            ST_WAIT_ACK: begin
                debug_state_r    <= ST_WAIT_ACK;
                if (target_dataslot_ack) begin
                    target_dataslot_read <= 1'b0;
                    state                <= ST_WAIT_DONE;
                end
            end

            ST_WAIT_DONE: begin
                debug_state_r    <= ST_WAIT_DONE;
                if (target_dataslot_done) begin
                    if (target_dataslot_err != 3'd0) begin
                        state <= ST_ERROR;
                    end else begin
                        stream_index <= 11'd0;
                        bram_rd_addr <= 8'd0;
                        state        <= ST_STREAM_WAIT;
                    end
                end
            end

            ST_STREAM_ADDR: begin
                debug_state_r <= ST_STREAM_ADDR;
                bram_rd_addr <= stream_index[9:2];
                state        <= ST_STREAM_WAIT;
            end

            ST_STREAM_WAIT: begin
                debug_state_r <= ST_STREAM_WAIT;
                state <= ST_STREAM_DATA;
            end

            ST_STREAM_DATA: begin
                debug_state_r <= ST_STREAM_DATA;
                loader_wr   <= 1'b1;
                loader_addr <= file_offset[17:0] + {7'd0, stream_index};

                case (stream_index[1:0])
                    2'b11:   loader_data <= bram_rd_data[31:24];
                    2'b10:   loader_data <= bram_rd_data[23:16];
                    2'b01:   loader_data <= bram_rd_data[15:8];
                    default: loader_data <= bram_rd_data[7:0];
                endcase

                if (stream_index == chunk_len - 11'd1) begin
                    state <= ST_NEXT_CHUNK;
                end else begin
                    stream_index <= stream_index + 11'd1;
                    state        <= ST_STREAM_ADDR;
                end
            end

            ST_NEXT_CHUNK: begin
                debug_state_r <= ST_NEXT_CHUNK;
                file_offset <= file_offset + {21'd0, chunk_len};
                remaining   <= remaining - {21'd0, chunk_len};
                if (remaining == {21'd0, chunk_len}) begin
                    state <= ST_DONE;
                end else begin
                    state <= ST_REQUEST;
                end
            end

            ST_DONE: begin
                debug_state_r <= ST_DONE;
                loader_done <= 1'b1;
            end

            ST_ERROR: begin
                debug_state_r <= ST_ERROR;
                loader_error <= 1'b1;
                loader_done  <= 1'b1;
            end

            default: begin
                debug_state_r <= ST_ERROR;
                state <= ST_ERROR;
            end
        endcase
    end
end

endmodule

`default_nettype wire
