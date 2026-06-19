//
// Pocket APF data-slot reader for CPC snapshot files.
//
// First pass intentionally tracks the MiSTer CPC snapshot register/header
// layout and supports standard contiguous memory-dump .SNA files. Extension
// chunks such as MEM0/MEM1 are ignored for now.
//

`default_nettype none

module pocket_sna_dataslot (
    input  wire         clk,
    input  wire         bridge_clk,
    input  wire         reset_n,
    input  wire         enable,

    input  wire [31:0]  bridge_addr,
    input  wire         bridge_wr,
    input  wire [31:0]  bridge_wr_data,

    input  wire         dataslot_update,
    input  wire [15:0]  dataslot_update_id,
    input  wire [31:0]  dataslot_update_size,

    output reg          target_dataslot_read,
    output reg  [15:0]  target_dataslot_id,
    output reg  [31:0]  target_dataslot_slotoffset,
    output reg  [31:0]  target_dataslot_bridgeaddr,
    output reg  [31:0]  target_dataslot_length,
    output reg          cmd_request_flag,
    output reg          cmd_write_strobe,
    input  wire         cmd_ack_flag,
    input  wire         target_dataslot_ack,
    input  wire         target_dataslot_done,
    input  wire [2:0]   target_dataslot_err,
    output wire         target_active,

    output reg          snapshot_mem_wr,
    output reg  [16:0]  snapshot_mem_addr,
    output reg  [7:0]   snapshot_mem_data,
    output wire         snapshot_busy_reset,
    output wire         sna_load,
    output reg  [211:0] sna_cpu_dir,
    output reg  [4:0]   sna_crtc_addr,
    output reg  [143:0] sna_crtc_regs,
    output reg  [4:0]   sna_ga_inksel,
    output reg  [135:0] sna_ga_palette,
    output reg  [7:0]   sna_ga_config,
    output reg  [7:0]   sna_ram_config,
    output reg  [7:0]   sna_rom_select,
    output reg  [7:0]   sna_ppi_a,
    output reg  [7:0]   sna_ppi_b,
    output reg  [7:0]   sna_ppi_c,
    output reg  [7:0]   sna_ppi_control,
    output reg  [3:0]   sna_psg_addr,
    output reg  [127:0] sna_psg_regs
);

localparam [15:0] SLOT_SNAPSHOT     = 16'h0004;
localparam [31:0] BRIDGE_RAM_ADDR   = 32'h8000_0000;
localparam [31:0] CHUNK_BYTES       = 32'd1024;
localparam [31:0] SNAPSHOT_HDR_SIZE = 32'h0000_0100;

localparam [3:0] ST_IDLE         = 4'd0;
localparam [3:0] ST_REQUEST      = 4'd1;
localparam [3:0] ST_REQUEST_HOLD = 4'd2;
localparam [3:0] ST_WAIT_ACK     = 4'd3;
localparam [3:0] ST_WAIT_DONE    = 4'd4;
localparam [3:0] ST_STREAM_ADDR  = 4'd5;
localparam [3:0] ST_STREAM_WAIT  = 4'd6;
localparam [3:0] ST_STREAM_DATA  = 4'd7;
localparam [3:0] ST_NEXT_CHUNK   = 4'd8;
localparam [3:0] ST_APPLY_WAIT   = 4'd9;

reg [3:0]  state = ST_IDLE;
reg        pending_load = 1'b0;
reg [31:0] pending_size = 32'd0;
reg [31:0] file_offset = 32'd0;
reg [31:0] file_size = 32'd0;
reg [31:0] remaining = 32'd0;
reg [10:0] chunk_len = 11'd0;
reg [10:0] stream_index = 11'd0;
reg [7:0]  bram_rd_addr = 8'd0;
reg [2:0]  sna_apply_cnt = 3'd0;
wire [31:0] bram_rd_data;
wire [31:0] current_byte_addr = file_offset + {21'd0, stream_index};
wire [7:0]  current_byte_addr_lo = current_byte_addr[7:0];
wire [15:0] sna_std_mem_size = (sna_mem_size > 16'd128) ? 16'd128 : sna_mem_size;
wire [31:0] sna_std_mem_bytes = ({16'd0, sna_std_mem_size} << 10);
wire        memory_byte = (current_byte_addr >= SNAPSHOT_HDR_SIZE) &&
                          (current_byte_addr < (SNAPSHOT_HDR_SIZE + sna_std_mem_bytes));

reg  [15:0] sna_mem_size = 16'd64;

assign target_active = (state != ST_IDLE) && (state != ST_APPLY_WAIT);
assign snapshot_busy_reset = target_active | (sna_apply_cnt > 3'd2);
assign sna_load = (sna_apply_cnt == 3'd1);

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

bram_block_dp #(
    .DATA(32),
    .ADDR(8)
) snapshot_bridge_ram (
    .a_clk  ( bridge_clk ),
    .a_wr   ( bridge_wr && (bridge_addr[31:28] == 4'h8) ),
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
        state                      <= ST_IDLE;
        pending_load               <= 1'b0;
        pending_size               <= 32'd0;
        file_offset                <= 32'd0;
        file_size                  <= 32'd0;
        remaining                  <= 32'd0;
        chunk_len                  <= 11'd0;
        stream_index               <= 11'd0;
        bram_rd_addr               <= 8'd0;
        sna_apply_cnt              <= 3'd0;
        target_dataslot_read       <= 1'b0;
        target_dataslot_id         <= SLOT_SNAPSHOT;
        target_dataslot_slotoffset <= 32'd0;
        target_dataslot_bridgeaddr <= BRIDGE_RAM_ADDR;
        target_dataslot_length     <= 32'd0;
        cmd_request_flag           <= 1'b0;
        cmd_write_strobe           <= 1'b0;
        snapshot_mem_wr            <= 1'b0;
        snapshot_mem_addr          <= 17'd0;
        snapshot_mem_data          <= 8'd0;
        sna_cpu_dir                <= 212'd0;
        sna_crtc_addr              <= 5'd0;
        sna_crtc_regs              <= 144'd0;
        sna_ga_inksel              <= 5'd0;
        sna_ga_palette             <= 136'd0;
        sna_ga_config              <= 8'd0;
        sna_ram_config             <= 8'd0;
        sna_rom_select             <= 8'd0;
        sna_ppi_a                  <= 8'd0;
        sna_ppi_b                  <= 8'd0;
        sna_ppi_c                  <= 8'd0;
        sna_ppi_control            <= 8'h9b;
        sna_psg_addr               <= 4'd0;
        sna_psg_regs               <= 128'd0;
        sna_mem_size               <= 16'd64;
    end else begin
        snapshot_mem_wr  <= 1'b0;
        cmd_write_strobe <= 1'b0;

        if (dataslot_update && (dataslot_update_id == SLOT_SNAPSHOT)) begin
            pending_load <= |dataslot_update_size;
            pending_size <= dataslot_update_size;
        end

        if (sna_apply_cnt != 3'd0) begin
            sna_apply_cnt <= sna_apply_cnt - 3'd1;
        end

        case (state)
            ST_IDLE: begin
                target_dataslot_read <= 1'b0;
                cmd_request_flag     <= 1'b0;
                if (enable && pending_load) begin
                    pending_load      <= 1'b0;
                    file_offset       <= 32'd0;
                    file_size         <= pending_size;
                    remaining         <= pending_size;
                    sna_cpu_dir       <= 212'd0;
                    sna_crtc_addr     <= 5'd0;
                    sna_crtc_regs     <= 144'd0;
                    sna_ga_inksel     <= 5'd0;
                    sna_ga_palette    <= 136'd0;
                    sna_ga_config     <= 8'd0;
                    sna_ram_config    <= 8'd0;
                    sna_rom_select    <= 8'd0;
                    sna_ppi_a         <= 8'd0;
                    sna_ppi_b         <= 8'd0;
                    sna_ppi_c         <= 8'd0;
                    sna_ppi_control   <= 8'h9b;
                    sna_psg_addr      <= 4'd0;
                    sna_psg_regs      <= 128'd0;
                    sna_mem_size      <= 16'd64;
                    state             <= ST_REQUEST;
                end
            end

            ST_REQUEST: begin
                target_dataslot_id         <= SLOT_SNAPSHOT;
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
                        state <= ST_IDLE;
                    end else begin
                        stream_index <= 11'd0;
                        bram_rd_addr <= 8'd0;
                        state        <= ST_STREAM_WAIT;
                    end
                end
            end

            ST_STREAM_ADDR: begin
                bram_rd_addr <= stream_index[9:2];
                state        <= ST_STREAM_WAIT;
            end

            ST_STREAM_WAIT: begin
                state <= ST_STREAM_DATA;
            end

            ST_STREAM_DATA: begin
                reg [7:0] current_byte;
                current_byte = bridge_byte(bram_rd_data, stream_index[1:0]);

                if (current_byte_addr < SNAPSHOT_HDR_SIZE) begin
                    case (current_byte_addr_lo)
                        8'h11: sna_cpu_dir[15:8]    <= current_byte;
                        8'h12: sna_cpu_dir[7:0]     <= current_byte;
                        8'h13: sna_cpu_dir[87:80]   <= current_byte;
                        8'h14: sna_cpu_dir[95:88]   <= current_byte;
                        8'h15: sna_cpu_dir[103:96]  <= current_byte;
                        8'h16: sna_cpu_dir[111:104] <= current_byte;
                        8'h17: sna_cpu_dir[119:112] <= current_byte;
                        8'h18: sna_cpu_dir[127:120] <= current_byte;
                        8'h19: sna_cpu_dir[47:40]   <= current_byte;
                        8'h1a: sna_cpu_dir[39:32]   <= current_byte;
                        8'h1b: sna_cpu_dir[210]     <= current_byte[0];
                        8'h1c: sna_cpu_dir[211]     <= current_byte[0];
                        8'h1d: sna_cpu_dir[135:128] <= current_byte;
                        8'h1e: sna_cpu_dir[143:136] <= current_byte;
                        8'h1f: sna_cpu_dir[199:192] <= current_byte;
                        8'h20: sna_cpu_dir[207:200] <= current_byte;
                        8'h21: sna_cpu_dir[55:48]   <= current_byte;
                        8'h22: sna_cpu_dir[63:56]   <= current_byte;
                        8'h23: sna_cpu_dir[71:64]   <= current_byte;
                        8'h24: sna_cpu_dir[79:72]   <= current_byte;
                        8'h25: sna_cpu_dir[209:208] <= current_byte[1:0];
                        8'h26: sna_cpu_dir[31:24]   <= current_byte;
                        8'h27: sna_cpu_dir[23:16]   <= current_byte;
                        8'h28: sna_cpu_dir[151:144] <= current_byte;
                        8'h29: sna_cpu_dir[159:152] <= current_byte;
                        8'h2a: sna_cpu_dir[167:160] <= current_byte;
                        8'h2b: sna_cpu_dir[175:168] <= current_byte;
                        8'h2c: sna_cpu_dir[183:176] <= current_byte;
                        8'h2d: sna_cpu_dir[191:184] <= current_byte;
                        8'h2e: sna_ga_inksel        <= current_byte[4:0];
                        8'h40: sna_ga_config        <= current_byte;
                        8'h41: sna_ram_config       <= current_byte;
                        8'h42: sna_crtc_addr        <= current_byte[4:0];
                        8'h55: sna_rom_select       <= current_byte;
                        8'h56: sna_ppi_a            <= current_byte;
                        8'h57: sna_ppi_b            <= current_byte;
                        8'h58: sna_ppi_c            <= current_byte;
                        8'h59: sna_ppi_control      <= current_byte;
                        8'h5a: sna_psg_addr         <= current_byte[3:0];
                        8'h6b: sna_mem_size[7:0]    <= current_byte;
                        8'h6c: sna_mem_size[15:8]   <= current_byte;
                        default: begin end
                    endcase

                    if ((current_byte_addr_lo >= 8'h2f) && (current_byte_addr_lo <= 8'h3f)) begin
                        sna_ga_palette[((current_byte_addr_lo - 8'h2f) * 8) +: 8] <= current_byte;
                    end
                    if ((current_byte_addr_lo >= 8'h43) && (current_byte_addr_lo <= 8'h54)) begin
                        sna_crtc_regs[((current_byte_addr_lo - 8'h43) * 8) +: 8] <= current_byte;
                    end
                    if ((current_byte_addr_lo >= 8'h5b) && (current_byte_addr_lo <= 8'h6a)) begin
                        sna_psg_regs[((current_byte_addr_lo - 8'h5b) * 8) +: 8] <= current_byte;
                    end
                end

                if (memory_byte) begin
                    snapshot_mem_wr   <= 1'b1;
                    snapshot_mem_addr <= current_byte_addr[16:0] - 17'h00100;
                    snapshot_mem_data <= current_byte;
                end

                if (stream_index == chunk_len - 11'd1) begin
                    state <= ST_NEXT_CHUNK;
                end else begin
                    stream_index <= stream_index + 11'd1;
                    state        <= ST_STREAM_ADDR;
                end
            end

            ST_NEXT_CHUNK: begin
                file_offset <= file_offset + {21'd0, chunk_len};
                remaining   <= remaining - {21'd0, chunk_len};
                if (remaining == {21'd0, chunk_len}) begin
                    sna_apply_cnt <= 3'd5;
                    state         <= ST_APPLY_WAIT;
                end else begin
                    state <= ST_REQUEST;
                end
            end

            ST_APPLY_WAIT: begin
                if (sna_apply_cnt == 3'd0) begin
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
