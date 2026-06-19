// axis_to_video.v
// AXI4-Stream to parallel video converter.
//
// Assumption:
//   s_axis_aclk and pclk must be in the same clock domain (typically tied
//   together at the top level). This keeps the first implementation simple
//   and avoids the need for an asynchronous FIFO. Cross-clock-domain support
//   can be added later if required.
//
// Behavior:
//   - s_axis_tready is asserted whenever the timing generator requests an
//     active pixel (de_i == 1).
//   - Output data/hsync/vsync/de are registered, producing a one-cycle
//     latency relative to the timing-generator inputs.
//   - If the AXI-Stream source cannot provide a pixel when required, the
//     output is forced to black and underflow_o is asserted.

`timescale 1ns / 1ps

module axis_to_video #(
    parameter DATA_WIDTH = 36
)(
    input  wire                  pclk,          // Pixel/video clock
    input  wire                  rst_n,         // Active-low reset (synchronous to pclk)

    // AXI4-Stream slave interface
    input  wire                  s_axis_aclk,   // Must be synchronous/identical to pclk
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tuser,  // Start-of-frame (reserved for future use)
    input  wire                  s_axis_tlast,  // End-of-line (reserved for future use)

    // Video timing input (from video_timing_gen)
    input  wire                  hsync_i,
    input  wire                  vsync_i,
    input  wire                  de_i,
    input  wire [15:0]           x_i,           // Reserved for future use
    input  wire [15:0]           y_i,           // Reserved for future use
    input  wire                  frame_start_i, // Reserved for future use
    input  wire                  line_start_i,  // Reserved for future use

    // Parallel video output
    output reg  [DATA_WIDTH-1:0] data_o,
    output reg                   hsync_o,
    output reg                   vsync_o,
    output reg                   de_o,
    output reg                   underflow_o
);

    // Accept a pixel exactly when the timing generator needs one.
    assign s_axis_tready = de_i;

    //-------------------------------------------------------------------------
    // Registered video output with one-cycle latency
    //-------------------------------------------------------------------------
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            data_o      <= {DATA_WIDTH{1'b0}};
            hsync_o     <= 1'b0;
            vsync_o     <= 1'b0;
            de_o        <= 1'b0;
            underflow_o <= 1'b0;
        end else begin
            // Register timing signals to align with data_o latency
            hsync_o <= hsync_i;
            vsync_o <= vsync_i;
            de_o    <= de_i;

            if (de_i) begin
                if (s_axis_tvalid && s_axis_tready) begin
                    data_o      <= s_axis_tdata;
                    underflow_o <= 1'b0;
                end else begin
                    // Source did not provide a pixel when required
                    data_o      <= {DATA_WIDTH{1'b0}}; // black
                    underflow_o <= 1'b1;
                end
            end else begin
                // Blank interval: drive black for safety
                data_o      <= {DATA_WIDTH{1'b0}};
                underflow_o <= 1'b0;
            end
        end
    end

endmodule
