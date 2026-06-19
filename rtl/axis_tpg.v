// axis_tpg.v
// AXI4-Stream test-pattern generator for the SiI9134 demo.
//
// Outputs a single animated pattern: expanding concentric color-bar rings
// centered on the screen.  All pixel math uses shifts/adds/compares only,
// avoiding division/modulo.  A one-stage output pipeline is included to meet
// the 148.5 MHz pixel-clock timing budget.
//
// AXI4-Stream sideband:
//   - tvalid is asserted during active video (de == 1)
//   - tlast  is asserted on the last pixel of each active line
//   - tuser  is asserted on the first pixel of each frame

`timescale 1ns / 1ps

module axis_tpg #(
    parameter H_ACTIVE = 1920,
    parameter V_ACTIVE = 1080
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

    //-------------------------------------------------------------------------
    // Frame counter for the animated rings
    //-------------------------------------------------------------------------
    reg [15:0] frame_cnt;
    reg        vsync_prev;

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            frame_cnt  <= 16'd0;
            vsync_prev <= 1'b0;
        end else begin
            vsync_prev <= vsync;
            if (!vsync_prev && vsync) begin // rising edge of vsync
                frame_cnt <= frame_cnt + 1'b1;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Color constants (12-bit per channel)
    //-------------------------------------------------------------------------
    localparam [11:0] C_MAX = 12'hFFF; // full intensity
    localparam [11:0] C_MIN = 12'h000; // black level

    //-------------------------------------------------------------------------
    // Expanding concentric color-bar rings centered on the screen.
    // Uses Manhattan distance plus a frame counter to make the rings move.
    //-------------------------------------------------------------------------
    localparam H_CENTER = H_ACTIVE / 2;
    localparam V_CENTER = V_ACTIVE / 2;

    wire [15:0] dx = (x > H_CENTER) ? (x - H_CENTER) : (H_CENTER - x);
    wire [15:0] dy = (y > V_CENTER) ? (y - V_CENTER) : (V_CENTER - y);
    wire [15:0] ring_dist = dx + dy;
    wire [15:0] ring_pos = ring_dist + {frame_cnt[8:1], 2'd0};
    wire [2:0]  ring_idx = ring_pos[7:5]; // 32-pixel wide rings

    reg [35:0] pixel_rgb;
    always @(*) begin
        case (ring_idx)
            3'd0: pixel_rgb = {C_MAX, C_MIN, C_MIN}; // red
            3'd1: pixel_rgb = {C_MAX, C_MAX, C_MIN}; // yellow
            3'd2: pixel_rgb = {C_MIN, C_MAX, C_MIN}; // green
            3'd3: pixel_rgb = {C_MIN, C_MAX, C_MAX}; // cyan
            3'd4: pixel_rgb = {C_MIN, C_MIN, C_MAX}; // blue
            3'd5: pixel_rgb = {C_MAX, C_MIN, C_MAX}; // magenta
            3'd6: pixel_rgb = {C_MAX, C_MAX, C_MAX}; // white
            3'd7: pixel_rgb = {C_MIN, C_MIN, C_MIN}; // black
        endcase
    end

    //-------------------------------------------------------------------------
    // AXI4-Stream output pipeline (one stage)
    //-------------------------------------------------------------------------
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 36'd0;
            m_axis_tuser  <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            m_axis_tvalid <= de;
            m_axis_tdata  <= pixel_rgb;
            m_axis_tuser  <= frame_start;
            m_axis_tlast  <= de && (x == H_ACTIVE - 1);
        end
    end

endmodule
