// video_timing_gen.v
// Generic CEA/VESA video timing generator.
// Default parameters produce 1920x1080 @ 60 Hz (CEA-861-F).
// All outputs are registered to provide clean timing for downstream logic.

`timescale 1ns / 1ps

module video_timing_gen #(
    // Horizontal timing parameters
    parameter H_ACTIVE = 1920,
    parameter H_FRONT  = 88,
    parameter H_SYNC   = 44,
    parameter H_BACK   = 148,
    parameter H_TOTAL  = 2200,

    // Vertical timing parameters
    parameter V_ACTIVE = 1080,
    parameter V_FRONT  = 4,
    parameter V_SYNC   = 5,
    parameter V_BACK   = 36,
    parameter V_TOTAL  = 1125,

    // Sync polarities: 1 = active high, 0 = active low
    parameter H_SYNC_POLARITY = 1'b1,
    parameter V_SYNC_POLARITY = 1'b1
)(
    input  wire        clk,         // Pixel clock
    input  wire        rst_n,       // Active-low asynchronous reset

    output reg         hsync,       // Horizontal sync output
    output reg         vsync,       // Vertical sync output
    output reg         de,          // Data enable (active during visible pixels)
    output wire        pixel_valid, // Alias of de for downstream convenience
    output reg  [15:0] x,           // Horizontal counter: 0 .. H_TOTAL-1
    output reg  [15:0] y,           // Vertical counter:   0 .. V_TOTAL-1
    output reg         frame_start, // One-cycle pulse at start of frame
    output reg         line_start   // One-cycle pulse at start of each line
);

    // Sync start positions (exclusive end)
    localparam H_SYNC_START = H_ACTIVE + H_FRONT;
    localparam H_SYNC_END   = H_SYNC_START + H_SYNC;
    localparam V_SYNC_START = V_ACTIVE + V_FRONT;
    localparam V_SYNC_END   = V_SYNC_START + V_SYNC;

    // Internal counters
    reg [15:0] h_cnt;
    reg [15:0] v_cnt;

    // Pixel valid is a combinational alias of de
    assign pixel_valid = de;

    //-------------------------------------------------------------------------
    // Pixel counters
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 16'd0;
            v_cnt <= 16'd0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 16'd0;
                if (v_cnt == V_TOTAL - 1) begin
                    v_cnt <= 16'd0;
                end else begin
                    v_cnt <= v_cnt + 1'b1;
                end
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Registered timing outputs
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync       <= ~H_SYNC_POLARITY;
            vsync       <= ~V_SYNC_POLARITY;
            de          <= 1'b0;
            x           <= 16'd0;
            y           <= 16'd0;
            frame_start <= 1'b0;
            line_start  <= 1'b0;
        end else begin
            x <= h_cnt;
            y <= v_cnt;

            // Horizontal sync pulse
            hsync <= ((h_cnt >= H_SYNC_START) && (h_cnt < H_SYNC_END))
                     ? H_SYNC_POLARITY : ~H_SYNC_POLARITY;

            // Vertical sync pulse
            vsync <= ((v_cnt >= V_SYNC_START) && (v_cnt < V_SYNC_END))
                     ? V_SYNC_POLARITY : ~V_SYNC_POLARITY;

            // Data enable is high only during active video
            de <= (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

            // Start pulses
            frame_start <= (h_cnt == 16'd0) && (v_cnt == 16'd0);
            line_start  <= (h_cnt == 16'd0);
        end
    end

endmodule
