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
