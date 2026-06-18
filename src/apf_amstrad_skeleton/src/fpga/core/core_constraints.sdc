#
# Pocket CPC core constraints.
#
# The APF bridge is clocked directly by clk_74a, while the imported CPC logic is
# clocked by a PLL-derived 64 MHz domain, matching the structure used by the
# Pocket ZX Spectrum core. Treat those domains as asynchronous; explicit
# synchronizers/handshakes carry the small set of signals that cross between
# them.
#

derive_pll_clocks
derive_clock_uncertainty

set_clock_groups -asynchronous \
 -group { bridge_spiclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group { ic|cpc_pll_inst|cpc_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk }

# The APF scanout clocks are fabric-generated from the CPC PLL clock by the
# divider in core_top. Model them as generated clocks so Quartus understands
# their phase relationship to the 64 MHz CPC clock instead of treating them as
# unrelated user clocks.
set cpc_divclk_pin {ic|cpc_pll_inst|cpc_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}

create_generated_clock \
 -name {core_top:ic|cpc_apf_pixel_clk} \
 -source [get_pins $cpc_divclk_pin] \
 -edges {2 4 6} \
 [get_pins {ic|cpc_apf_pixel_clk|q}]

create_generated_clock \
 -name {core_top:ic|cpc_apf_pixel_clk_90} \
 -source [get_pins $cpc_divclk_pin] \
 -edges {3 5 7} \
 [get_pins {ic|cpc_apf_pixel_clk_90|q}]
