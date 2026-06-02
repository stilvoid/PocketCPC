//
// Pocket APF data-slot feeder for the MiSTer CPC `tzxplayer`.
//
// CDT playback is sequential, so this adapter keeps the original MiSTer tape
// parser and replaces its byte source with a double-buffered APF bridge-RAM
// cache. While one chunk is being consumed, the next chunk can be prefetched
// into the other half of local BRAM to avoid mid-block pauses.
//

`default_nettype none

module pocket_tape_dataslot (
    input  wire        clk,
    input  wire        bridge_clk,
    input  wire        reset_n,
    input  wire        enable,
    input  wire        restart,

    input  wire [31:0] bridge_addr,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    input  wire        dataslot_update,
    input  wire [15:0] dataslot_update_id,
    input  wire [31:0] dataslot_update_size,

    input  wire        tape_motor,
    output wire        tape_in,
    output wire        tape_running,

    output reg         target_dataslot_read,
    output reg  [15:0] target_dataslot_id,
    output reg  [31:0] target_dataslot_slotoffset,
    output reg  [31:0] target_dataslot_bridgeaddr,
    output reg  [31:0] target_dataslot_length,
    output reg         cmd_request_flag,
    output reg         cmd_write_strobe,
    input  wire        cmd_ack_flag,
    input  wire        target_dataslot_ack,
    input  wire        target_dataslot_done,
    input  wire [2:0]  target_dataslot_err,
    output wire        target_active
);

localparam [15:0] SLOT_TAPE       = 16'h0003;
localparam [31:0] BRIDGE_RAM_ADDR = 32'h9000_0000;
localparam [31:0] CHUNK_BYTES     = 32'd4096;
localparam [12:0] CHUNK_LEN_MAX   = 13'd4096;

localparam [2:0] FT_IDLE         = 3'd0;
localparam [2:0] FT_REQUEST      = 3'd1;
localparam [2:0] FT_REQUEST_HOLD = 3'd2;
localparam [2:0] FT_WAIT_ACK     = 3'd3;
localparam [2:0] FT_WAIT_DONE    = 3'd4;

localparam [1:0] SV_IDLE         = 2'd0;
localparam [1:0] SV_BRAM_ADDR    = 2'd1;
localparam [1:0] SV_BRAM_WAIT    = 2'd2;
localparam [1:0] SV_RESPOND      = 2'd3;

reg  [2:0] fetch_state = FT_IDLE;
reg  [1:0] serve_state = SV_IDLE;
reg        tape_reset = 1'b1;
reg  [31:0] tape_size = 32'd0;
reg  [31:0] play_addr = 32'd0;

reg         current_valid = 1'b0;
reg  [31:0] current_base = 32'd0;
reg  [12:0] current_len = 13'd0;
reg         current_bank = 1'b0;

reg         next_valid = 1'b0;
reg  [31:0] next_base = 32'd0;
reg  [12:0] next_len = 13'd0;
reg         next_bank = 1'b1;

reg  [31:0] fetch_base = 32'd0;
reg  [12:0] fetch_len = 13'd0;
reg         fetch_bank = 1'b0;
reg         fetch_to_next = 1'b0;

reg  [31:0] serve_offset = 32'd0;
reg         serve_bank = 1'b0;
reg  [1:0]  serve_byte_sel = 2'd0;
reg  [10:0] bram_rd_addr = 11'd0;

reg  [7:0]  tape_dout = 8'd0;
reg         tape_data_ack = 1'b0;
reg         tape_data_ack_d = 1'b0;

wire [31:0] bram_rd_data;
wire        tape_data_req;
wire        tape_rd = tape_data_req ^ tape_data_ack;
wire [31:0] current_offset = play_addr - current_base;
wire [31:0] next_offset = play_addr - next_base;
wire        current_hit = current_valid &&
                          (play_addr >= current_base) &&
                          (current_offset < {19'd0, current_len});
wire        next_hit = next_valid &&
                       (play_addr >= next_base) &&
                       (next_offset < {19'd0, next_len});
wire [31:0] remaining_bytes = tape_size - play_addr;
wire        fetch_busy = (fetch_state != FT_IDLE);
wire [31:0] current_limit = current_base + {19'd0, current_len};
wire        prefetch_needed = enable &&
                              current_valid &&
                              !next_valid &&
                              !fetch_busy &&
                              (current_limit < tape_size);

assign target_active = fetch_busy;

function automatic [7:0] bridge_byte;
    input [31:0] word;
    input [1:0] idx;
    begin
        case (idx)
            2'b11: bridge_byte = word[31:24];
            2'b10: bridge_byte = word[23:16];
            2'b01: bridge_byte = word[15:8];
            default: bridge_byte = word[7:0];
        endcase
    end
endfunction

function automatic [12:0] chunk_len13;
    input [31:0] bytes_left;
    begin
        if (bytes_left >= CHUNK_BYTES) begin
            chunk_len13 = CHUNK_LEN_MAX;
        end else begin
            chunk_len13 = {1'b0, bytes_left[11:0]};
        end
    end
endfunction

function automatic [31:0] chunk_bridge_addr;
    input bank;
    begin
        chunk_bridge_addr = BRIDGE_RAM_ADDR + (bank ? CHUNK_BYTES : 32'd0);
    end
endfunction

bram_block_dp #(
    .DATA(32),
    .ADDR(11)
) tape_bridge_ram (
    .a_clk  ( bridge_clk ),
    .a_wr   ( bridge_wr && (bridge_addr[31:28] == 4'h9) ),
    .a_addr ( bridge_addr[12:2] ),
    .a_din  ( {bridge_wr_data[7:0], bridge_wr_data[15:8], bridge_wr_data[23:16], bridge_wr_data[31:24]} ),
    .a_dout ( ),

    .b_clk  ( clk ),
    .b_wr   ( 1'b0 ),
    .b_addr ( bram_rd_addr ),
    .b_din  ( 32'd0 ),
    .b_dout ( bram_rd_data )
);

tzxplayer #(
    .NORMAL_PILOT_LEN(2000),
    .NORMAL_SYNC1_LEN(855),
    .NORMAL_SYNC2_LEN(855),
    .NORMAL_ZERO_LEN(855),
    .NORMAL_ONE_LEN(1710),
    .HEADER_PILOT_PULSES(4095),
    .NORMAL_PILOT_PULSES(4095)
) tzxplayer_inst (
    .clk          ( clk ),
    .ce           ( 1'b1 ),
    .restart_tape ( tape_reset ),
    .host_tap_in  ( tape_dout ),
    .tzx_req      ( tape_data_req ),
    .tzx_ack      ( tape_data_ack ),
    .loop_start   ( ),
    .loop_next    ( ),
    .stop         ( ),
    .stop48k      ( ),
    .cass_read    ( tape_in ),
    .cass_motor   ( tape_motor ),
    .cass_running ( tape_running )
);

always @(posedge clk or negedge reset_n) begin
    reg [31:0] prefetch_base;
    reg [31:0] prefetch_remaining;
    reg [31:0] miss_remaining;
    reg        prefetch_bank;
    reg        miss_bank;

    if (!reset_n) begin
        fetch_state                 <= FT_IDLE;
        serve_state                 <= SV_IDLE;
        tape_reset                  <= 1'b1;
        tape_size                   <= 32'd0;
        play_addr                   <= 32'd0;
        current_valid               <= 1'b0;
        current_base                <= 32'd0;
        current_len                 <= 13'd0;
        current_bank                <= 1'b0;
        next_valid                  <= 1'b0;
        next_base                   <= 32'd0;
        next_len                    <= 13'd0;
        next_bank                   <= 1'b1;
        fetch_base                  <= 32'd0;
        fetch_len                   <= 13'd0;
        fetch_bank                  <= 1'b0;
        fetch_to_next               <= 1'b0;
        serve_offset                <= 32'd0;
        serve_bank                  <= 1'b0;
        serve_byte_sel              <= 2'd0;
        bram_rd_addr                <= 11'd0;
        tape_dout                   <= 8'd0;
        tape_data_ack               <= 1'b0;
        tape_data_ack_d             <= 1'b0;
        target_dataslot_read        <= 1'b0;
        target_dataslot_id          <= SLOT_TAPE;
        target_dataslot_slotoffset  <= 32'd0;
        target_dataslot_bridgeaddr  <= BRIDGE_RAM_ADDR;
        target_dataslot_length      <= 32'd0;
        cmd_request_flag            <= 1'b0;
        cmd_write_strobe            <= 1'b0;
    end else begin
        tape_reset       <= 1'b0;
        cmd_write_strobe <= 1'b0;
        tape_data_ack_d  <= tape_data_ack;

        if ((tape_data_ack_d ^ tape_data_ack) && (play_addr < tape_size)) begin
            play_addr <= play_addr + 32'd1;
        end

        if (dataslot_update && (dataslot_update_id == SLOT_TAPE)) begin
            tape_size                  <= dataslot_update_size;
            play_addr                  <= 32'd0;
            current_valid              <= 1'b0;
            current_base               <= 32'd0;
            current_len                <= 13'd0;
            current_bank               <= 1'b0;
            next_valid                 <= 1'b0;
            next_base                  <= 32'd0;
            next_len                   <= 13'd0;
            next_bank                  <= 1'b1;
            fetch_base                 <= 32'd0;
            fetch_len                  <= chunk_len13(dataslot_update_size);
            fetch_bank                 <= 1'b0;
            fetch_to_next              <= 1'b0;
            serve_state                <= SV_IDLE;
            fetch_state                <= |dataslot_update_size ? FT_REQUEST : FT_IDLE;
            tape_data_ack              <= 1'b0;
            tape_data_ack_d            <= 1'b0;
            target_dataslot_id         <= SLOT_TAPE;
            target_dataslot_slotoffset <= 32'd0;
            target_dataslot_bridgeaddr <= BRIDGE_RAM_ADDR;
            target_dataslot_length     <= (dataslot_update_size > CHUNK_BYTES) ? CHUNK_BYTES : dataslot_update_size;
            cmd_request_flag           <= 1'b0;
            tape_reset                 <= 1'b1;
        end else if (restart) begin
            play_addr                  <= 32'd0;
            current_valid              <= 1'b0;
            current_base               <= 32'd0;
            current_len                <= 13'd0;
            current_bank               <= 1'b0;
            next_valid                 <= 1'b0;
            next_base                  <= 32'd0;
            next_len                   <= 13'd0;
            next_bank                  <= 1'b1;
            fetch_base                 <= 32'd0;
            fetch_len                  <= chunk_len13(tape_size);
            fetch_bank                 <= 1'b0;
            fetch_to_next              <= 1'b0;
            serve_state                <= SV_IDLE;
            fetch_state                <= |tape_size ? FT_REQUEST : FT_IDLE;
            tape_data_ack              <= 1'b0;
            tape_data_ack_d            <= 1'b0;
            target_dataslot_id         <= SLOT_TAPE;
            target_dataslot_slotoffset <= 32'd0;
            target_dataslot_bridgeaddr <= BRIDGE_RAM_ADDR;
            target_dataslot_length     <= (tape_size > CHUNK_BYTES) ? CHUNK_BYTES : tape_size;
            cmd_request_flag           <= 1'b0;
            tape_reset                 <= 1'b1;
        end else begin
            if (prefetch_needed) begin
                prefetch_base = current_limit;
                prefetch_remaining = tape_size - prefetch_base;
                prefetch_bank = ~current_bank;
                fetch_base <= prefetch_base;
                fetch_len  <= chunk_len13(prefetch_remaining);
                fetch_bank <= prefetch_bank;
                fetch_to_next <= 1'b1;
                fetch_state <= FT_REQUEST;
            end

            case (serve_state)
                SV_IDLE: begin
                    if (enable && (tape_size != 32'd0) && tape_rd && (play_addr < tape_size)) begin
                        if (current_hit) begin
                            serve_offset   <= current_offset;
                            serve_bank     <= current_bank;
                            serve_byte_sel <= current_offset[1:0];
                            serve_state    <= SV_BRAM_ADDR;
                        end else if (next_hit) begin
                            current_valid  <= 1'b1;
                            current_base   <= next_base;
                            current_len    <= next_len;
                            current_bank   <= next_bank;
                            next_valid     <= 1'b0;
                            serve_offset   <= next_offset;
                            serve_bank     <= next_bank;
                            serve_byte_sel <= next_offset[1:0];
                            serve_state    <= SV_BRAM_ADDR;
                        end else if (!fetch_busy) begin
                            miss_remaining = remaining_bytes;
                            miss_bank = current_valid ? ~current_bank : 1'b0;
                            current_valid  <= 1'b0;
                            next_valid     <= 1'b0;
                            fetch_base     <= play_addr;
                            fetch_len      <= chunk_len13(miss_remaining);
                            fetch_bank     <= miss_bank;
                            fetch_to_next  <= 1'b0;
                            fetch_state    <= FT_REQUEST;
                        end
                    end
                end

                SV_BRAM_ADDR: begin
                    bram_rd_addr <= {serve_bank, serve_offset[11:2]};
                    serve_state  <= SV_BRAM_WAIT;
                end

                SV_BRAM_WAIT: begin
                    serve_state <= SV_RESPOND;
                end

                SV_RESPOND: begin
                    tape_dout     <= bridge_byte(bram_rd_data, serve_byte_sel);
                    tape_data_ack <= ~tape_data_ack;
                    serve_state   <= SV_IDLE;
                end

                default: begin
                    serve_state <= SV_IDLE;
                end
            endcase

            case (fetch_state)
                FT_IDLE: begin
                    target_dataslot_read <= 1'b0;
                    cmd_request_flag     <= 1'b0;
                end

                FT_REQUEST: begin
                    target_dataslot_id         <= SLOT_TAPE;
                    target_dataslot_slotoffset <= fetch_base;
                    target_dataslot_bridgeaddr <= chunk_bridge_addr(fetch_bank);
                    target_dataslot_length     <= (fetch_base + {19'd0, fetch_len} < tape_size) ? CHUNK_BYTES : {19'd0, fetch_len};
                    target_dataslot_read       <= 1'b1;
                    cmd_request_flag           <= 1'b1;
                    cmd_write_strobe           <= 1'b1;
                    fetch_state                <= FT_REQUEST_HOLD;
                end

                FT_REQUEST_HOLD: begin
                    target_dataslot_read <= 1'b1;
                    cmd_request_flag     <= 1'b1;
                    cmd_write_strobe     <= 1'b1;
                    if (cmd_ack_flag) begin
                        cmd_write_strobe <= 1'b0;
                        cmd_request_flag <= 1'b0;
                        fetch_state      <= FT_WAIT_ACK;
                    end
                end

                FT_WAIT_ACK: begin
                    if (target_dataslot_ack) begin
                        target_dataslot_read <= 1'b0;
                        fetch_state          <= FT_WAIT_DONE;
                    end
                end

                FT_WAIT_DONE: begin
                    if (target_dataslot_done) begin
                        if (target_dataslot_err != 3'd0) begin
                            current_valid <= 1'b0;
                            next_valid    <= 1'b0;
                        end else if (fetch_to_next) begin
                            next_valid <= 1'b1;
                            next_base  <= fetch_base;
                            next_len   <= fetch_len;
                            next_bank  <= fetch_bank;
                        end else begin
                            current_valid <= 1'b1;
                            current_base  <= fetch_base;
                            current_len   <= fetch_len;
                            current_bank  <= fetch_bank;
                        end
                        fetch_state <= FT_IDLE;
                    end
                end

                default: begin
                    fetch_state <= FT_IDLE;
                end
            endcase
        end
    end
end

endmodule

`default_nettype wire
