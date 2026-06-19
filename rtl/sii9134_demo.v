// sii9134_demo.v
// Stand-alone SiI9134 demo top-level for board bring-up.
//
// This module combines the SiI9134 driver (sii9134_top) with an internal
// AXI4-Stream test-pattern generator (axis_tpg).  It is intended for direct
// synthesis onto the target board: connect a 27 MHz oscillator and the
// SiI9134 device, and the demo will output a 1080p60 color-bar pattern.
//
// The on-chip PLL is instantiated inside sii9134_top; the demo only needs
// the reference clock from the board.
//
// NOTE: SiI9134 RESET# is not driven by this module.  The board must keep
// RESET# high (released) through an external pull-up or a dedicated reset
// circuit.

`timescale 1ns / 1ps

module sii9134_demo #(
    parameter SYS_CLK_HZ = 27_000_000
)(
    // Board reference
    input  wire        clk_27m,  // 27 MHz board oscillator
    input  wire        rst_n,    // Active-low reset (board button or POR)

    // SiI9134 parallel video interface
    output wire        sii_pclk,
    output wire        sii_hsync,
    output wire        sii_vsync,
    output wire        sii_de,
    output wire [35:0] sii_data, // RGB 12-12-12

    // SiI9134 I2C interface (open-drain, external pull-ups required)
    inout  wire        sii_scl,
    inout  wire        sii_sda,

    // I2C initialization status
    output wire        i2c_busy,
    output wire        i2c_done,
    output wire        i2c_error
);

    //-------------------------------------------------------------------------
    // Internal AXI4-Stream interface between the test pattern generator
    // and the SiI9134 driver.
    //-------------------------------------------------------------------------
    wire        axis_aclk;
    wire        axis_tvalid;
    wire        axis_tready;
    wire [35:0] axis_tdata;
    wire        axis_tuser;
    wire        axis_tlast;

    //-------------------------------------------------------------------------
    // Video timing feedback from the driver to the pattern generator.
    // Both modules run from the same pixel clock, so this loop is safe.
    //-------------------------------------------------------------------------
    wire        video_hsync;
    wire        video_vsync;
    wire        video_de;
    wire [15:0] video_x;
    wire [15:0] video_y;
    wire        video_frame_start;

    //-------------------------------------------------------------------------
    // SiI9134 driver: PLL, video timing, AXI4-Stream to parallel video,
    // and I2C initialization.
    //-------------------------------------------------------------------------
    sii9134_top #(
        .SYS_CLK_HZ (SYS_CLK_HZ)
    ) u_sii9134_top (
        .clk_27m          (clk_27m),
        .rst_n            (rst_n),

        .s_axis_aclk      (axis_aclk),
        .s_axis_tvalid    (axis_tvalid),
        .s_axis_tready    (axis_tready),
        .s_axis_tdata     (axis_tdata),
        .s_axis_tuser     (axis_tuser),
        .s_axis_tlast     (axis_tlast),

        .sii_pclk         (sii_pclk),
        .sii_hsync        (sii_hsync),
        .sii_vsync        (sii_vsync),
        .sii_de           (sii_de),
        .sii_data         (sii_data),

        .video_hsync      (video_hsync),
        .video_vsync      (video_vsync),
        .video_de         (video_de),
        .video_x          (video_x),
        .video_y          (video_y),
        .video_frame_start(video_frame_start),

        .sii_scl          (sii_scl),
        .sii_sda          (sii_sda),

        .i2c_busy         (i2c_busy),
        .i2c_done         (i2c_done),
        .i2c_error        (i2c_error)
    );

    //-------------------------------------------------------------------------
    // AXI4-Stream test-pattern generator
    //-------------------------------------------------------------------------
    axis_tpg u_axis_tpg (
        .pclk          (axis_aclk),
        .rst_n         (rst_n),
        .hsync         (video_hsync),
        .vsync         (video_vsync),
        .de            (video_de),
        .x             (video_x),
        .y             (video_y),
        .frame_start   (video_frame_start),
        .m_axis_tvalid (axis_tvalid),
        .m_axis_tdata  (axis_tdata),
        .m_axis_tuser  (axis_tuser),
        .m_axis_tlast  (axis_tlast)
    );

    assign axis_aclk = sii_pclk;

endmodule
