// 64 MHz CPC system clock PLL for the Analogue Pocket 74.25 MHz input.

`default_nettype none

module cpc_pll (
    input  wire refclk,
    input  wire rst,
    output wire outclk_0,
    output wire locked
);

cpc_pll_0002 cpc_pll_inst (
    .refclk   ( refclk ),
    .rst      ( rst ),
    .outclk_0 ( outclk_0 ),
    .locked   ( locked )
);

endmodule

`default_nettype wire
