// pll_sii9134_sim.v
// Behavioral simulation model for the SiI9134 pixel-clock PLL.
//
// This file is intended for RTL simulation only.  It replaces the vendor-
// specific PLL IP (ip/pll_sii9134/pll_sii9134.v) during simulation so that
// the design can be verified without requiring a matching XiST primitive
// library.  For synthesis, use the generated vendor IP instead.
//
// Port naming matches the generated vendor IP so the top-level instantiation
// can be shared between synthesis and simulation:
//   - CLKI  : 27 MHz reference clock
//   - CLKOP : 148.5 MHz pixel clock (1080p60)
//   - LOCK  : PLL lock indicator

`timescale 1ns / 1ps

module pll_sii9134 (
    input  wire CLKI,   // 27 MHz reference oscillator
    output wire CLKOP,  // 148.5 MHz pixel clock for 1080p60
    output wire LOCK    // Active-high PLL lock indicator
);

    // 148.5 MHz -> period = 1000 / 148.5 ns ~= 6.734 ns
    localparam real PCLK_HALF_PERIOD = 1000.0 / 148.5 / 2.0;

    reg clkop_r;
    reg lock_r;

    initial begin
        clkop_r = 1'b0;
        lock_r  = 1'b0;
    end

    always #(PCLK_HALF_PERIOD) clkop_r = ~clkop_r;

    // Assert lock after ~30 reference clock cycles (~1.1 us).
    initial begin
        repeat (30) @(posedge CLKI);
        lock_r = 1'b1;
    end

    assign CLKOP = clkop_r;
    assign LOCK  = lock_r;

endmodule
