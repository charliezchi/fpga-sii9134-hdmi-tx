// axis_tpg.v
// AXI4-Stream test-pattern generator for the SiI9134 demo.
//
// Produces a standard eight-bar color bar pattern at 1920x1080 @ 60 Hz.
// The module expects video timing signals from an external source (typically
// the same video_timing_gen used by axis_to_video), ensuring the AXI-Stream
// output is perfectly aligned with the downstream converter.
//
// AXI4-Stream sideband:
//   - tvalid is asserted during active video (de == 1)
//   - tlast  is asserted on the last pixel of each active line
//   - tuser  is asserted on the first pixel of each frame

`timescale 1ns / 1ps

module axis_tpg #(
    parameter H_ACTIVE = 1920
)(
    input  wire        pclk,         // Pixel clock
    input  wire        rst_n,        // Active-low reset

    // Video timing input (from video_timing_gen)
    input  wire        hsync,
    input  wire        vsync,
    input  wire        de,
    input  wire [15:0] x,
    input  wire [15:0] y,
    input  wire        frame_start,

    // AXI4-Stream master interface (36-bit RGB 12-12-12)
    output reg         m_axis_tvalid,
    output reg  [35:0] m_axis_tdata,
    output reg         m_axis_tuser,
    output reg         m_axis_tlast
);

    // Use threshold comparisons instead of division to keep the bar index
    // computation fast.  H_ACTIVE / 8 = 240 for the default 1920x1080 mode.
    localparam BAR_WIDTH = H_ACTIVE / 8;

    reg [2:0] bar_idx;
    reg [35:0] color_bar;

    //-------------------------------------------------------------------------
    // Combinational bar-index generation (compare x against bar boundaries)
    //-------------------------------------------------------------------------
    always @(*) begin
        if      (x < BAR_WIDTH * 1) bar_idx = 3'd0;
        else if (x < BAR_WIDTH * 2) bar_idx = 3'd1;
        else if (x < BAR_WIDTH * 3) bar_idx = 3'd2;
        else if (x < BAR_WIDTH * 4) bar_idx = 3'd3;
        else if (x < BAR_WIDTH * 5) bar_idx = 3'd4;
        else if (x < BAR_WIDTH * 6) bar_idx = 3'd5;
        else if (x < BAR_WIDTH * 7) bar_idx = 3'd6;
        else                        bar_idx = 3'd7;
    end

    //-------------------------------------------------------------------------
    // Combinational color-bar generation (8-bit to 12-bit, LSB padded with 1)
    //-------------------------------------------------------------------------
    always @(*) begin
        case (bar_idx)
            3'd0: color_bar = {12'hFFF, 12'hFFF, 12'hFFF}; // White
            3'd1: color_bar = {12'hFFF, 12'hFFF, 12'h000}; // Yellow
            3'd2: color_bar = {12'h000, 12'hFFF, 12'hFFF}; // Cyan
            3'd3: color_bar = {12'h000, 12'hFFF, 12'h000}; // Green
            3'd4: color_bar = {12'hFFF, 12'h000, 12'hFFF}; // Magenta
            3'd5: color_bar = {12'hFFF, 12'h000, 12'h000}; // Red
            3'd6: color_bar = {12'h000, 12'h000, 12'hFFF}; // Blue
            3'd7: color_bar = {12'h000, 12'h000, 12'h000}; // Black
        endcase
    end

    //-------------------------------------------------------------------------
    // Combinational AXI4-Stream outputs aligned to active video
    // Using combinational outputs keeps tvalid/tready in the same cycle as
    // the timing generator's de, avoiding a one-cycle latency mismatch.
    //-------------------------------------------------------------------------
    always @(*) begin
        m_axis_tvalid = de;
        m_axis_tdata  = color_bar;
        m_axis_tuser  = frame_start;
        m_axis_tlast  = de && (x == H_ACTIVE - 1);
    end

endmodule
