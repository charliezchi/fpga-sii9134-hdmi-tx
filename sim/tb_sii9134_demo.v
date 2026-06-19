// tb_sii9134_demo.v
// Testbench for the stand-alone SiI9134 demo top-level.
//
// The demo contains the AXI4-Stream test-pattern generator internally, so
// this testbench only needs to provide the 27 MHz clock, reset, and I2C
// pull-ups.  It verifies I2C initialization and video timing integrity.

`timescale 1ns / 1ps

module tb_sii9134_demo;

    localparam SYS_CLK_PERIOD_NS = 1000.0 / 27.0;  // ~37.037 ns
    localparam SIM_TIMEOUT_US    = 50_000;          // 50 ms watchdog

    // Board interface
    reg  clk_27m;
    reg  rst_n;

    // SiI9134 video interface
    wire        sii_pclk;
    wire        sii_hsync;
    wire        sii_vsync;
    wire        sii_de;
    wire [35:0] sii_data;

    // SiI9134 I2C interface
    wire        sii_scl;
    wire        sii_sda;

    // Status
    wire        i2c_busy;
    wire        i2c_done;
    wire        i2c_error;

    // Internal probe
    wire        underflow;
    assign underflow = u_dut.u_sii9134_top.u_axis_to_video.underflow_o;

    // Clock and reset generation
    initial begin
        clk_27m = 1'b0;
        forever #(SYS_CLK_PERIOD_NS / 2.0) clk_27m = ~clk_27m;
    end

    initial begin
        rst_n = 1'b0;
        #(SYS_CLK_PERIOD_NS * 50);
        rst_n = 1'b1;
    end

    // I2C pull-up resistors
    pullup(sii_scl);
    pullup(sii_sda);

    // I2C slave model (acknowledges all writes)
    wire [7:0] slave_received_byte;
    wire       slave_byte_valid;
    wire       slave_transaction_done;

    i2c_slave_model u_i2c_slave (
        .clk              (clk_27m),
        .rst_n            (rst_n),
        .scl              (sii_scl),
        .sda              (sii_sda),
        .received_byte    (slave_received_byte),
        .byte_valid       (slave_byte_valid),
        .transaction_done (slave_transaction_done)
    );

    // DUT: stand-alone demo top-level
    sii9134_demo #(
        .SYS_CLK_HZ (27_000_000)
    ) u_dut (
        .clk_27m   (clk_27m),
        .rst_n     (rst_n),
        .sii_pclk  (sii_pclk),
        .sii_hsync (sii_hsync),
        .sii_vsync (sii_vsync),
        .sii_de    (sii_de),
        .sii_data  (sii_data),
        .sii_scl   (sii_scl),
        .sii_sda   (sii_sda),
        .i2c_busy  (i2c_busy),
        .i2c_done  (i2c_done),
        .i2c_error (i2c_error)
    );

    //-------------------------------------------------------------------------
    // Video timing checks (skip first partial frame)
    //-------------------------------------------------------------------------
    reg        prev_hsync;
    reg        prev_vsync;
    integer    h_period_cnt;
    integer    v_line_cnt;
    integer    h_period_num;
    integer    v_frame_num;
    integer    timing_errors;

    initial begin
        prev_hsync    = 1'b0;
        prev_vsync    = 1'b0;
        h_period_cnt  = 0;
        v_line_cnt    = 0;
        h_period_num  = 0;
        v_frame_num   = 0;
        timing_errors = 0;
    end

    always @(posedge sii_pclk) begin
        if (rst_n) begin
            prev_hsync <= sii_hsync;
            prev_vsync <= sii_vsync;

            if (prev_hsync && !sii_hsync) begin
                h_period_num <= h_period_num + 1;
                if (h_period_num > 0 && h_period_cnt != 2200) begin
                    $error("Time %0t: horizontal period mismatch, got %0d, expected 2200",
                           $time, h_period_cnt);
                    timing_errors <= timing_errors + 1;
                end
                h_period_cnt <= 1;
            end else begin
                h_period_cnt <= h_period_cnt + 1;
            end

            if (prev_vsync && !sii_vsync) begin
                v_frame_num <= v_frame_num + 1;
                if (v_frame_num > 0 && v_line_cnt != 1126) begin
                    $error("Time %0t: vertical line count mismatch, got %0d, expected 1126",
                           $time, v_line_cnt);
                    timing_errors <= timing_errors + 1;
                end
                v_line_cnt <= 1;
            end else if (prev_hsync && !sii_hsync) begin
                v_line_cnt <= v_line_cnt + 1;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Underflow monitor
    //-------------------------------------------------------------------------
    integer underflow_cnt;
    initial underflow_cnt = 0;

    always @(posedge sii_pclk) begin
        if (rst_n && underflow) begin
            underflow_cnt <= underflow_cnt + 1;
        end
    end

    //-------------------------------------------------------------------------
    // End-of-simulation checks
    //-------------------------------------------------------------------------
    initial begin
        wait(rst_n);
        wait(i2c_done);
        #(SYS_CLK_PERIOD_NS * 100);

        repeat (3) @(negedge sii_vsync);
        #(SYS_CLK_PERIOD_NS * 100);

        if (!i2c_error && timing_errors == 0 && underflow_cnt == 0) begin
            $display("Simulation PASSED.");
            $display("  - I2C init completed without error");
            $display("  - Video timing within expected limits");
            $display("  - AXIS underflow count = %0d", underflow_cnt);
        end else begin
            $display("Simulation FAILED.");
            $display("  - i2c_error = %b", i2c_error);
            $display("  - timing_errors = %0d", timing_errors);
            $display("  - underflow_cnt = %0d", underflow_cnt);
        end

        $finish;
    end

    // Watchdog timeout
    initial begin
        #(SIM_TIMEOUT_US * 1000);
        $display("WATCHDOG TIMEOUT. i2c_done=%b i2c_error=%b", i2c_done, i2c_error);
        $finish;
    end

endmodule
