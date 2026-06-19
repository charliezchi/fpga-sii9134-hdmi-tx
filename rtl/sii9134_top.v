// sii9134_top.v
// Top-level SiI9134 HDMI TX driver.
//
// This module bridges an AXI4-Stream video source to the SiI9134 parallel
// RGB interface and performs I2C initialization of the SiI9134 transmitter.
// A 27 MHz board oscillator feeds an on-chip PLL that generates the 148.5 MHz
// pixel clock required for 1920x1080 @ 60 Hz.
//
// Assumptions:
//   - s_axis_aclk is synchronous to the internal pixel clock (pclk).
//   - The SiI9134 I2C slave address and register sequence in
//     i2c_master_sii9134 match the target hardware.

`timescale 1ns / 1ps

module sii9134_top #(
    parameter SYS_CLK_HZ = 27_000_000  // Frequency of clk_27m
)(
    // System reference
    input  wire        clk_27m,  // 27 MHz reference / system clock
    input  wire        rst_n,    // External active-low reset

    // AXI4-Stream slave video interface (user side)
    input  wire        s_axis_aclk,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire [35:0] s_axis_tdata,   // RGB 12-12-12
    input  wire        s_axis_tuser,   // Start-of-frame
    input  wire        s_axis_tlast,   // End-of-line

    // SiI9134 parallel video interface
    output wire        sii_pclk,
    output wire        sii_hsync,
    output wire        sii_vsync,
    output wire        sii_de,
    output wire [35:0] sii_data,       // RGB 12-12-12

    // Video timing output (for external AXI4-Stream source synchronization)
    output wire        video_hsync,
    output wire        video_vsync,
    output wire        video_de,
    output wire [15:0] video_x,
    output wire [15:0] video_y,
    output wire        video_frame_start,

    // SiI9134 I2C interface (open-drain)
    inout  wire        sii_scl,
    inout  wire        sii_sda,

    // I2C init status
    output wire        i2c_busy,
    output wire        i2c_done,
    output wire        i2c_error
);

    //-------------------------------------------------------------------------
    // Clock generation
    //-------------------------------------------------------------------------
    wire pclk;
    wire pll_locked;

    pll_sii9134 u_pll (
        .CLKI (clk_27m),
        .CLKOP(pclk),
        .LOCK (pll_locked)
    );

    //-------------------------------------------------------------------------
    // Reset synchronization
    // Asynchronous assertion (external reset), synchronous release (PLL lock).
    // Two-stage synchronizers produce glitch-free reset signals per clock
    // domain and eliminate NCHK315 warnings from combinational reset gating.
    //-------------------------------------------------------------------------
    reg [1:0] rst_27m_sync_ff;
    reg [1:0] rst_pclk_sync_ff;

    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n)
            rst_27m_sync_ff <= 2'b00;
        else
            rst_27m_sync_ff <= {rst_27m_sync_ff[0], pll_locked};
    end

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n)
            rst_pclk_sync_ff <= 2'b00;
        else
            rst_pclk_sync_ff <= {rst_pclk_sync_ff[0], pll_locked};
    end

    wire rst_n_27m  = rst_27m_sync_ff[1];
    wire rst_n_pclk = rst_pclk_sync_ff[1];

    //-------------------------------------------------------------------------
    // 1080p60 video timing generation
    //-------------------------------------------------------------------------
    wire        hsync;
    wire        vsync;
    wire        de;
    wire [15:0] x;
    wire [15:0] y;
    wire        frame_start;
    wire        line_start;

    video_timing_gen u_timing_gen (
        .clk         (pclk),
        .rst_n       (rst_n_pclk),
        .hsync       (hsync),
        .vsync       (vsync),
        .de          (de),
        .pixel_valid (video_de), // Same as de; avoids unconnected-port warning
        .x           (x),
        .y           (y),
        .frame_start (frame_start),
        .line_start  (line_start)
    );

    //-------------------------------------------------------------------------
    // AXI4-Stream to parallel video conversion
    //-------------------------------------------------------------------------
    wire [35:0] video_data;
    wire        axis_to_video_hsync;
    wire        axis_to_video_vsync;
    wire        axis_to_video_de;
    wire        video_underflow;

    axis_to_video u_axis_to_video (
        .pclk          (pclk),
        .rst_n         (rst_n_pclk),
        .s_axis_aclk   (s_axis_aclk),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tuser  (s_axis_tuser),
        .s_axis_tlast  (s_axis_tlast),
        .hsync_i       (hsync),
        .vsync_i       (vsync),
        .de_i          (de),
        .x_i           (x),
        .y_i           (y),
        .frame_start_i (frame_start),
        .line_start_i  (line_start),
        .data_o        (video_data),
        .hsync_o       (axis_to_video_hsync),
        .vsync_o       (axis_to_video_vsync),
        .de_o          (axis_to_video_de),
        .underflow_o   (video_underflow)
    );

    //-------------------------------------------------------------------------
    // SiI9134 I2C initialization
    //-------------------------------------------------------------------------
    i2c_master_sii9134 #(
        .CLK_FREQ_HZ (SYS_CLK_HZ),
        .I2C_FREQ_HZ (100_000)
    ) u_i2c_master (
        .clk      (clk_27m),
        .rst_n    (rst_n_27m),
        .init_req (1'b0),           // Auto-start on reset release
        .busy     (i2c_busy),
        .done     (i2c_done),
        .error    (i2c_error),
        .i2c_scl  (sii_scl),
        .i2c_sda  (sii_sda)
    );

    //-------------------------------------------------------------------------
    // Output assignments
    //-------------------------------------------------------------------------
    assign sii_pclk         = pclk;
    assign sii_hsync        = axis_to_video_hsync;
    assign sii_vsync        = axis_to_video_vsync;
    assign sii_de           = axis_to_video_de;
    assign sii_data         = video_data;

    assign video_hsync      = hsync;
    assign video_vsync      = vsync;
    // video_de is driven by video_timing_gen.pixel_valid (alias of de)
    assign video_x          = x;
    assign video_y          = y;
    assign video_frame_start = frame_start;

endmodule
