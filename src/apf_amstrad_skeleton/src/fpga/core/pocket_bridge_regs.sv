// Pocket-facing register block for the Amstrad CPC core.
//
// This is the first replacement layer for MiSTer hps_io/status/ioctl wiring.
// It intentionally implements only stable control/status registers plus loader
// bookkeeping; streaming ROM/DSK storage will be connected in a later phase.

`default_nettype none

module pocket_bridge_regs (
    input  wire        clk,
    input  wire        reset_n,

    input  wire [31:0] bridge_addr,
    input  wire        bridge_rd,
    output reg  [31:0] bridge_rd_data,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    input  wire [31:0] cont1_key,

    output reg  [31:0] control,
    output reg  [31:0] model_config,
    output reg  [31:0] av_config,
    output reg  [31:0] interact_config,
    output reg  [31:0] media_flags,
    output reg  [31:0] loader_slot,
    output reg  [31:0] loader_addr,
    output reg  [31:0] loader_data,
    output reg  [31:0] loader_command,
    output reg         restart_request_toggle,
    output wire [31:0] status
);

localparam [31:0] CORE_ID       = 32'h4350_4301; // "CPC", version 1
localparam [31:0] STATUS_DUMMY  = 32'h0000_0001;
localparam [31:0] STATUS_ROM_OK = 32'h0000_0002;

assign status = STATUS_DUMMY;

wire [15:0] reg_addr = bridge_addr[15:0];
wire        regs_selected = (bridge_addr[31:16] == 16'h0000);

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        control        <= 32'h0000_0001;
        model_config   <= 32'h0000_0002; // MVP default: CPC 6128
        av_config      <= 32'h0000_0000;
        interact_config <= 32'h0000_0000;
        media_flags    <= 32'h0000_0000;
        loader_slot    <= 32'h0000_0000;
        loader_addr    <= 32'h0000_0000;
        loader_data    <= 32'h0000_0000;
        loader_command <= 32'h0000_0000;
        restart_request_toggle <= 1'b0;
    end else if (bridge_wr && regs_selected) begin
        if (reg_addr == 16'h0034) begin
            interact_config <= bridge_wr_data;
        end else if (reg_addr == 16'h0038) begin
            restart_request_toggle <= ~restart_request_toggle;
        end else begin
            case (reg_addr)
                16'h0004: control        <= bridge_wr_data;
                16'h0008: model_config   <= bridge_wr_data;
                16'h000c: av_config      <= bridge_wr_data;
                16'h0010: media_flags    <= bridge_wr_data;
                16'h0020: loader_slot    <= bridge_wr_data;
                16'h0024: loader_addr    <= bridge_wr_data;
                16'h0028: loader_data    <= bridge_wr_data;
                16'h002c: loader_command <= bridge_wr_data;
                default: begin
                end
            endcase
        end
    end
end

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        bridge_rd_data <= 32'h0000_0000;
    end else begin
        if (!regs_selected) begin
            bridge_rd_data <= 32'h0000_0000;
        end else if (reg_addr == 16'h0034) begin
            bridge_rd_data <= interact_config;
        end else begin
            case (reg_addr)
                16'h0000: bridge_rd_data <= CORE_ID;
                16'h0004: bridge_rd_data <= control;
                16'h0008: bridge_rd_data <= model_config;
                16'h000c: bridge_rd_data <= av_config;
                16'h0010: bridge_rd_data <= media_flags;
                16'h0014: bridge_rd_data <= status | ((media_flags[0]) ? STATUS_ROM_OK : 32'h0);
                16'h0020: bridge_rd_data <= loader_slot;
                16'h0024: bridge_rd_data <= loader_addr;
                16'h0028: bridge_rd_data <= loader_data;
                16'h002c: bridge_rd_data <= loader_command;
                16'h0030: bridge_rd_data <= 32'h0000_0001; // ready
                16'h0038: bridge_rd_data <= 32'h0000_0000;
                16'h0040: bridge_rd_data <= cont1_key;
                default:  bridge_rd_data <= 32'h0000_0000;
            endcase
        end
    end
end

endmodule

`default_nettype wire
