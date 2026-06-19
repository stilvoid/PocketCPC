//
// APF data-slot block reader for the MiSTer CPC u765 FDC.
//
// The MiSTer u765 asks for 512-byte blocks using sd_lba/sd_rd. This adapter
// translates those requests into Analogue Pocket target data-slot reads and
// streams the returned bridge RAM block into the u765 sector buffer.
//

`default_nettype none

module pocket_fdc_dataslot (
    input  wire        clk,
    input  wire        bridge_clk,
    input  wire        reset_n,
    input  wire        enable,

    input  wire [31:0] bridge_addr,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    input  wire        dataslot_update,
    input  wire [15:0] dataslot_update_id,
    input  wire [31:0] dataslot_update_size,

    input  wire [31:0] sd_lba,
    input  wire [1:0]  sd_rd,
    input  wire [1:0]  sd_wr,
    output reg         sd_ack,
    output reg  [8:0]  sd_buff_addr,
    output reg  [7:0]  sd_buff_dout,
    input  wire [7:0]  sd_buff_din,
    output reg         sd_buff_wr,

    output reg  [1:0]  img_mounted,
    output reg  [31:0] img_size,
    output wire        img_wp,
    output reg  [1:0]  ready,

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

localparam [15:0] SLOT_DRIVE_A = 16'h0001;
localparam [15:0] SLOT_DRIVE_B = 16'h0002;
localparam [31:0] BRIDGE_RAM_ADDR = 32'h7000_0000;
localparam [31:0] BLOCK_BYTES = 32'd512;
localparam [23:0] SETTLE_CYCLES = 24'd8_000_000;

localparam [3:0] ST_IDLE         = 4'd0;
localparam [3:0] ST_REQUEST      = 4'd1;
localparam [3:0] ST_REQUEST_HOLD = 4'd2;
localparam [3:0] ST_WAIT_ACK     = 4'd5;
localparam [3:0] ST_WAIT_DONE    = 4'd6;
localparam [3:0] ST_STREAM_ADDR  = 4'd7;
localparam [3:0] ST_STREAM_WAIT  = 4'd8;
localparam [3:0] ST_STREAM_DATA  = 4'd9;
localparam [3:0] ST_DROP_ACK     = 4'd10;
localparam [3:0] ST_WRITE_ACK    = 4'd11;
localparam [3:0] ST_WAIT_RELEASE = 4'd12;

reg [3:0] state = ST_IDLE;
reg [8:0] stream_index = 9'd0;
reg [6:0] bram_rd_addr = 7'd0;
reg [3:0] write_ack_count = 4'd0;
reg [23:0] settle_count = 24'd0;
reg        runtime_ready = 1'b0;
reg [31:0] drive_size [0:1];
reg [31:0] pending_size [0:1];
reg [1:0]  pending_mount = 2'b00;
reg [3:0]  mount_pulse [0:1];
wire [31:0] bram_rd_data;

assign img_wp = 1'b1;
assign target_active = (state != ST_IDLE);

bram_block_dp #(
    .DATA(32),
    .ADDR(7)
) sector_bridge_ram (
    .a_clk  ( bridge_clk ),
    .a_wr   ( bridge_wr && (bridge_addr[31:28] == 4'h7) ),
    .a_addr ( bridge_addr[8:2] ),
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
        state                      <= ST_IDLE;
        stream_index               <= 9'd0;
        bram_rd_addr               <= 7'd0;
        write_ack_count            <= 4'd0;
        settle_count               <= 24'd0;
        runtime_ready              <= 1'b0;
        drive_size[0]              <= 32'd0;
        drive_size[1]              <= 32'd0;
        pending_size[0]            <= 32'd0;
        pending_size[1]            <= 32'd0;
        pending_mount              <= 2'b00;
        mount_pulse[0]             <= 4'd0;
        mount_pulse[1]             <= 4'd0;
        ready                      <= 2'b00;
        img_mounted                <= 2'b00;
        img_size                   <= 32'd0;
        sd_ack                     <= 1'b0;
        sd_buff_addr               <= 9'd0;
        sd_buff_dout               <= 8'd0;
        sd_buff_wr                 <= 1'b0;
        target_dataslot_read       <= 1'b0;
        target_dataslot_id         <= SLOT_DRIVE_A;
        target_dataslot_slotoffset <= 32'd0;
        target_dataslot_bridgeaddr <= BRIDGE_RAM_ADDR;
        target_dataslot_length     <= BLOCK_BYTES;
        cmd_request_flag           <= 1'b0;
        cmd_write_strobe           <= 1'b0;
    end else begin
        img_mounted[0]   <= |mount_pulse[0];
        img_mounted[1]   <= |mount_pulse[1];
        sd_buff_wr       <= 1'b0;
        cmd_write_strobe <= 1'b0;

        if (mount_pulse[0] != 4'd0) mount_pulse[0] <= mount_pulse[0] - 4'd1;
        if (mount_pulse[1] != 4'd0) mount_pulse[1] <= mount_pulse[1] - 4'd1;

        if (!enable) begin
            settle_count  <= 24'd0;
            runtime_ready <= 1'b0;
        end else if (!runtime_ready) begin
            settle_count <= settle_count + 24'd1;
            if (settle_count == SETTLE_CYCLES) begin
                runtime_ready <= 1'b1;
            end
        end

        if (dataslot_update && dataslot_update_id == SLOT_DRIVE_A) begin
            pending_size[0] <= dataslot_update_size;
            pending_mount[0] <= 1'b1;
        end else if (dataslot_update && dataslot_update_id == SLOT_DRIVE_B) begin
            pending_size[1] <= dataslot_update_size;
            pending_mount[1] <= 1'b1;
        end

        if (runtime_ready && pending_mount[0]) begin
            drive_size[0]   <= pending_size[0];
            ready[0]        <= |pending_size[0];
            img_size        <= pending_size[0];
            mount_pulse[0]  <= 4'hf;
            pending_mount[0] <= 1'b0;
        end else if (runtime_ready && pending_mount[1]) begin
            drive_size[1]   <= pending_size[1];
            ready[1]        <= |pending_size[1];
            img_size        <= pending_size[1];
            mount_pulse[1]  <= 4'hf;
            pending_mount[1] <= 1'b0;
        end

        case (state)
            ST_IDLE: begin
                target_dataslot_read <= 1'b0;
                cmd_request_flag     <= 1'b0;
                sd_ack               <= 1'b0;
                if (runtime_ready && enable && (sd_rd[0] || sd_rd[1])) begin
                    target_dataslot_id         <= sd_rd[0] ? SLOT_DRIVE_A : SLOT_DRIVE_B;
                    target_dataslot_slotoffset <= sd_lba << 9;
                    target_dataslot_bridgeaddr <= BRIDGE_RAM_ADDR;
                    target_dataslot_length     <= BLOCK_BYTES;
                    state                      <= ST_REQUEST;
                end else if (runtime_ready && enable && (sd_wr[0] || sd_wr[1])) begin
                    // First milestone is read-only. Acknowledge writes so the
                    // u765 state machine does not hang, but do not persist them.
                    write_ack_count <= 4'd0;
                    sd_ack          <= 1'b1;
                    state           <= ST_WRITE_ACK;
                end
            end

            ST_REQUEST: begin
                target_dataslot_read <= 1'b1;
                cmd_request_flag     <= 1'b1;
                cmd_write_strobe     <= 1'b1;
                state                <= ST_REQUEST_HOLD;
            end

            ST_REQUEST_HOLD: begin
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
                if (target_dataslot_ack) begin
                    target_dataslot_read <= 1'b0;
                    state                <= ST_WAIT_DONE;
                end
            end

            ST_WAIT_DONE: begin
                if (target_dataslot_done) begin
                    if (target_dataslot_err != 3'd0) begin
                        state <= ST_DROP_ACK;
                    end else begin
                        sd_ack       <= 1'b1;
                        stream_index <= 9'd0;
                        bram_rd_addr <= 7'd0;
                        state        <= ST_STREAM_WAIT;
                    end
                end
            end

            ST_STREAM_ADDR: begin
                bram_rd_addr <= stream_index[8:2];
                state        <= ST_STREAM_WAIT;
            end

            ST_STREAM_WAIT: begin
                state <= ST_STREAM_DATA;
            end

            ST_STREAM_DATA: begin
                sd_buff_wr   <= 1'b1;
                sd_buff_addr <= stream_index;
                case (stream_index[1:0])
                    2'b11:   sd_buff_dout <= bram_rd_data[31:24];
                    2'b10:   sd_buff_dout <= bram_rd_data[23:16];
                    2'b01:   sd_buff_dout <= bram_rd_data[15:8];
                    default: sd_buff_dout <= bram_rd_data[7:0];
                endcase

                if (&stream_index) begin
                    state <= ST_DROP_ACK;
                end else begin
                    stream_index <= stream_index + 9'd1;
                    state        <= ST_STREAM_ADDR;
                end
            end

            ST_DROP_ACK: begin
                sd_ack <= 1'b0;
                state  <= ST_WAIT_RELEASE;
            end

            ST_WRITE_ACK: begin
                write_ack_count <= write_ack_count + 4'd1;
                if (&write_ack_count) begin
                    sd_ack <= 1'b0;
                    state  <= ST_WAIT_RELEASE;
                end
            end

            ST_WAIT_RELEASE: begin
                sd_ack <= 1'b0;
                target_dataslot_read <= 1'b0;
                cmd_request_flag <= 1'b0;
                if ((sd_rd == 2'b00) && (sd_wr == 2'b00)) begin
                    state <= ST_IDLE;
                end
            end

            default: begin
                state <= ST_IDLE;
            end
        endcase
    end
end

endmodule

`default_nettype wire
