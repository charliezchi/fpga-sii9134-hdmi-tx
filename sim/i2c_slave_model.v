// i2c_slave_model.v
// Simple I2C slave model for simulation, clocked by a system clock.
// Supports write transactions only. ACKs every received byte.
// Detects START/STOP conditions and outputs each received byte with a
// one-cycle valid pulse.

`timescale 1ns / 1ps

module i2c_slave_model (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        scl,
    inout  wire        sda,

    output reg  [7:0]  received_byte,
    output reg         byte_valid,
    output reg         transaction_done
);

    localparam [2:0]
        ST_IDLE         = 3'd0,
        ST_RECV         = 3'd1,
        ST_WAIT_ACK     = 3'd2,
        ST_ACK          = 3'd3,
        ST_ACK_RELEASE  = 3'd4;

    reg [2:0] state;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    reg       sda_oe;
    reg       sda_o;

    // Synchronize and edge-detect SCL/SDA
    reg [2:0] scl_sync;
    reg [2:0] sda_sync;
    wire      scl_rising  = !scl_sync[2] && scl_sync[1];
    wire      scl_falling = scl_sync[2] && !scl_sync[1];
    wire      sda_rising  = !sda_sync[2] && sda_sync[1];
    wire      sda_falling = sda_sync[2] && !sda_sync[1];
    wire      start_cond  = scl_sync[1] && sda_falling;
    wire      stop_cond   = scl_sync[1] && sda_rising;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
        end else begin
            scl_sync <= {scl_sync[1:0], scl};
            sda_sync <= {sda_sync[1:0], sda};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_IDLE;
            bit_cnt          <= 3'd0;
            sda_oe           <= 1'b0;
            sda_o            <= 1'b1;
            received_byte    <= 8'd0;
            byte_valid       <= 1'b0;
            transaction_done <= 1'b0;
        end else begin
            byte_valid       <= 1'b0;
            transaction_done <= 1'b0;

            if (start_cond) begin
                state   <= ST_RECV;
                bit_cnt <= 3'd0;
                sda_oe  <= 1'b0;
            end else if (stop_cond) begin
                sda_oe <= 1'b0;
                if (state != ST_IDLE) begin
                    transaction_done <= 1'b1;
                end
                state <= ST_IDLE;
            end else begin
                case (state)
                    ST_IDLE: begin
                        sda_oe <= 1'b0;
                    end

                    ST_RECV: begin
                        sda_oe <= 1'b0;
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda_sync[1]};
                            if (bit_cnt == 3'd7) begin
                                received_byte <= {shift_reg[6:0], sda_sync[1]};
                                byte_valid    <= 1'b1;
                                state         <= ST_WAIT_ACK;
                                bit_cnt       <= 3'd0;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end

                    ST_WAIT_ACK: begin
                        // 8th data bit received; wait for SCL to fall,
                        // then drive ACK low during the 9th bit.
                        sda_oe <= 1'b0;
                        if (scl_falling) begin
                            sda_oe <= 1'b1;
                            sda_o  <= 1'b0;
                            state  <= ST_ACK;
                        end
                    end

                    ST_ACK: begin
                        // Hold SDA low for the entire ACK cycle
                        sda_oe <= 1'b1;
                        sda_o  <= 1'b0;
                        if (scl_falling) begin
                            sda_oe <= 1'b0;
                            state  <= ST_ACK_RELEASE;
                        end
                    end

                    ST_ACK_RELEASE: begin
                        // Release SDA and capture the first bit of the next byte
                        sda_oe <= 1'b0;
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda_sync[1]};
                            bit_cnt   <= 3'd1;
                            state     <= ST_RECV;
                        end
                    end

                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

    // Open-drain SDA driver
    assign sda = sda_oe ? sda_o : 1'bz;

endmodule
