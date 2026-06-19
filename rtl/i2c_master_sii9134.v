// i2c_master_sii9134.v
// SiI9134 I2C initialization master.
// Merges the reference OpenCores I2C controller, config sequencer and LUT
// into a single file.

`timescale 1ns / 1ps

//
// OpenCores I2C command macros
//
`define I2C_CMD_NOP   4'b0000
`define I2C_CMD_START 4'b0001
`define I2C_CMD_STOP  4'b0010
`define I2C_CMD_WRITE 4'b0100
`define I2C_CMD_READ  4'b1000

//
// OpenCores I2C bit controller
//
module i2c_master_bit_ctrl (
    input             clk,
    input             rst,
    input             nReset,
    input             ena,
    input      [15:0] clk_cnt,
    input      [ 3:0] cmd,
    output reg        cmd_ack,
    output reg        busy,
    output reg        al,
    input             din,
    output reg        dout,
    input             scl_i,
    output            scl_o,
    output reg        scl_oen,
    input             sda_i,
    output            sda_o,
    output reg        sda_oen
);

    reg [1:0] cSCL, cSDA;
    reg [2:0] fSCL, fSDA;
    reg       sSCL, sSDA;
    reg       dSCL, dSDA;
    reg       dscl_oen;
    reg       sda_chk;
    reg       clk_en;
    reg       slave_wait;
    reg [15:0] cnt;
    reg [13:0] filter_cnt;

    reg [17:0] c_state;

    always @(posedge clk)
        dscl_oen <= #1 scl_oen;

    always @(posedge clk or negedge nReset)
        if (!nReset) slave_wait <= 1'b0;
        else         slave_wait <= (scl_oen & ~dscl_oen & ~sSCL) | (slave_wait & ~sSCL);

    wire scl_sync = dSCL & ~sSCL & scl_oen;

    always @(posedge clk or negedge nReset)
        if (~nReset)
        begin
            cnt    <= #1 16'h0;
            clk_en <= #1 1'b1;
        end
        else if (rst || ~|cnt || !ena || scl_sync)
        begin
            cnt    <= #1 clk_cnt;
            clk_en <= #1 1'b1;
        end
        else if (slave_wait)
        begin
            cnt    <= #1 cnt;
            clk_en <= #1 1'b0;
        end
        else
        begin
            cnt    <= #1 cnt - 16'h1;
            clk_en <= #1 1'b0;
        end

    always @(posedge clk or negedge nReset)
        if (!nReset)
        begin
            cSCL <= #1 2'b00;
            cSDA <= #1 2'b00;
        end
        else if (rst)
        begin
            cSCL <= #1 2'b00;
            cSDA <= #1 2'b00;
        end
        else
        begin
            cSCL <= {cSCL[0],scl_i};
            cSDA <= {cSDA[0],sda_i};
        end

    always @(posedge clk or negedge nReset)
        if      (!nReset     ) filter_cnt <= 14'h0;
        else if (rst || !ena ) filter_cnt <= 14'h0;
        else if (~|filter_cnt) filter_cnt <= clk_cnt >> 2;
        else                   filter_cnt <= filter_cnt -1;

    always @(posedge clk or negedge nReset)
        if (!nReset)
        begin
            fSCL <= 3'b111;
            fSDA <= 3'b111;
        end
        else if (rst)
        begin
            fSCL <= 3'b111;
            fSDA <= 3'b111;
        end
        else if (~|filter_cnt)
        begin
            fSCL <= {fSCL[1:0],cSCL[1]};
            fSDA <= {fSDA[1:0],cSDA[1]};
        end

    always @(posedge clk or negedge nReset)
        if (~nReset)
        begin
            sSCL <= #1 1'b1;
            sSDA <= #1 1'b1;
            dSCL <= #1 1'b1;
            dSDA <= #1 1'b1;
        end
        else if (rst)
        begin
            sSCL <= #1 1'b1;
            sSDA <= #1 1'b1;
            dSCL <= #1 1'b1;
            dSDA <= #1 1'b1;
        end
        else
        begin
            sSCL <= #1 &fSCL[2:1] | &fSCL[1:0] | (fSCL[2] & fSCL[0]);
            sSDA <= #1 &fSDA[2:1] | &fSDA[1:0] | (fSDA[2] & fSDA[0]);
            dSCL <= #1 sSCL;
            dSDA <= #1 sSDA;
        end

    reg sta_condition;
    reg sto_condition;
    always @(posedge clk or negedge nReset)
        if (~nReset)
        begin
            sta_condition <= #1 1'b0;
            sto_condition <= #1 1'b0;
        end
        else if (rst)
        begin
            sta_condition <= #1 1'b0;
            sto_condition <= #1 1'b0;
        end
        else
        begin
            sta_condition <= #1 ~sSDA &  dSDA & sSCL;
            sto_condition <= #1  sSDA & ~dSDA & sSCL;
        end

    always @(posedge clk or negedge nReset)
        if      (!nReset) busy <= #1 1'b0;
        else if (rst    ) busy <= #1 1'b0;
        else              busy <= #1 (sta_condition | busy) & ~sto_condition;

    reg cmd_stop;
    always @(posedge clk or negedge nReset)
        if (~nReset)
            cmd_stop <= #1 1'b0;
        else if (rst)
            cmd_stop <= #1 1'b0;
        else if (clk_en)
            cmd_stop <= #1 cmd == `I2C_CMD_STOP;

    always @(posedge clk or negedge nReset)
        if (~nReset)
            al <= #1 1'b0;
        else if (rst)
            al <= #1 1'b0;
        else
            al <= #1 (sda_chk & ~sSDA & sda_oen) | (|c_state & sto_condition & ~cmd_stop);

    always @(posedge clk)
        if (sSCL & ~dSCL) dout <= #1 sSDA;

    parameter [17:0] idle    = 18'b0_0000_0000_0000_0000;
    parameter [17:0] start_a = 18'b0_0000_0000_0000_0001;
    parameter [17:0] start_b = 18'b0_0000_0000_0000_0010;
    parameter [17:0] start_c = 18'b0_0000_0000_0000_0100;
    parameter [17:0] start_d = 18'b0_0000_0000_0000_1000;
    parameter [17:0] start_e = 18'b0_0000_0000_0001_0000;
    parameter [17:0] stop_a  = 18'b0_0000_0000_0010_0000;
    parameter [17:0] stop_b  = 18'b0_0000_0000_0100_0000;
    parameter [17:0] stop_c  = 18'b0_0000_0000_1000_0000;
    parameter [17:0] stop_d  = 18'b0_0000_0001_0000_0000;
    parameter [17:0] rd_a    = 18'b0_0000_0010_0000_0000;
    parameter [17:0] rd_b    = 18'b0_0000_0100_0000_0000;
    parameter [17:0] rd_c    = 18'b0_0000_1000_0000_0000;
    parameter [17:0] rd_d    = 18'b0_0001_0000_0000_0000;
    parameter [17:0] wr_a    = 18'b0_0010_0000_0000_0000;
    parameter [17:0] wr_b    = 18'b0_0100_0000_0000_0000;
    parameter [17:0] wr_c    = 18'b0_1000_0000_0000_0000;
    parameter [17:0] wr_d    = 18'b1_0000_0000_0000_0000;

    always @(posedge clk or negedge nReset)
        if (!nReset)
        begin
            c_state <= #1 idle;
            cmd_ack <= #1 1'b0;
            scl_oen <= #1 1'b1;
            sda_oen <= #1 1'b1;
            sda_chk <= #1 1'b0;
        end
        else if (rst | al)
        begin
            c_state <= #1 idle;
            cmd_ack <= #1 1'b0;
            scl_oen <= #1 1'b1;
            sda_oen <= #1 1'b1;
            sda_chk <= #1 1'b0;
        end
        else
        begin
            cmd_ack <= #1 1'b0;

            if (clk_en)
                case (c_state)
                    idle:
                    begin
                        case (cmd)
                             `I2C_CMD_START: c_state <= #1 start_a;
                             `I2C_CMD_STOP:  c_state <= #1 stop_a;
                             `I2C_CMD_WRITE: c_state <= #1 wr_a;
                             `I2C_CMD_READ:  c_state <= #1 rd_a;
                             default:        c_state <= #1 idle;
                        endcase

                        scl_oen <= #1 scl_oen;
                        sda_oen <= #1 sda_oen;
                        sda_chk <= #1 1'b0;
                    end

                    start_a:
                    begin
                        c_state <= #1 start_b;
                        scl_oen <= #1 scl_oen;
                        sda_oen <= #1 1'b1;
                        sda_chk <= #1 1'b0;
                    end

                    start_b:
                    begin
                        c_state <= #1 start_c;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 1'b1;
                        sda_chk <= #1 1'b0;
                    end

                    start_c:
                    begin
                        c_state <= #1 start_d;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 1'b0;
                        sda_chk <= #1 1'b0;
                    end

                    start_d:
                    begin
                        c_state <= #1 start_e;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 1'b0;
                        sda_chk <= #1 1'b0;
                    end

                    start_e:
                    begin
                        c_state <= #1 idle;
                        cmd_ack <= #1 1'b1;
                        scl_oen <= #1 1'b0;
                        sda_oen <= #1 1'b0;
                        sda_chk <= #1 1'b0;
                    end

                    stop_a:
                    begin
                        c_state <= #1 stop_b;
                        scl_oen <= #1 1'b0;
                        sda_oen <= #1 1'b0;
                        sda_chk <= #1 1'b0;
                    end

                    stop_b:
                    begin
                        c_state <= #1 stop_c;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 1'b0;
                        sda_chk <= #1 1'b0;
                    end

                    stop_c:
                    begin
                        c_state <= #1 stop_d;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 1'b0;
                        sda_chk <= #1 1'b0;
                    end

                    stop_d:
                    begin
                        c_state <= #1 idle;
                        cmd_ack <= #1 1'b1;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 1'b1;
                        sda_chk <= #1 1'b0;
                    end

                    rd_a:
                    begin
                        c_state <= #1 rd_b;
                        scl_oen <= #1 1'b0;
                        sda_oen <= #1 1'b1;
                        sda_chk <= #1 1'b0;
                    end

                    rd_b:
                    begin
                        c_state <= #1 rd_c;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 1'b1;
                        sda_chk <= #1 1'b0;
                    end

                    rd_c:
                    begin
                        c_state <= #1 rd_d;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 1'b1;
                        sda_chk <= #1 1'b0;
                    end

                    rd_d:
                    begin
                        c_state <= #1 idle;
                        cmd_ack <= #1 1'b1;
                        scl_oen <= #1 1'b0;
                        sda_oen <= #1 1'b1;
                        sda_chk <= #1 1'b0;
                    end

                    wr_a:
                    begin
                        c_state <= #1 wr_b;
                        scl_oen <= #1 1'b0;
                        sda_oen <= #1 din;
                        sda_chk <= #1 1'b0;
                    end

                    wr_b:
                    begin
                        c_state <= #1 wr_c;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 din;
                        sda_chk <= #1 1'b0;
                    end

                    wr_c:
                    begin
                        c_state <= #1 wr_d;
                        scl_oen <= #1 1'b1;
                        sda_oen <= #1 din;
                        sda_chk <= #1 1'b1;
                    end

                    wr_d:
                    begin
                        c_state <= #1 idle;
                        cmd_ack <= #1 1'b1;
                        scl_oen <= #1 1'b0;
                        sda_oen <= #1 din;
                        sda_chk <= #1 1'b0;
                    end
                endcase
        end

    assign scl_o = 1'b0;
    assign sda_o = 1'b0;

endmodule


//
// OpenCores I2C byte controller
//
module i2c_master_byte_ctrl (
    input       clk,
    input       rst,
    input       nReset,
    input       ena,
    input [15:0] clk_cnt,
    input       start,
    input       stop,
    input       read,
    input       write,
    input       ack_in,
    input [7:0] din,
    output reg  cmd_ack,
    output reg  ack_out,
    output [7:0] dout,
    output       i2c_busy,
    output       i2c_al,
    input        scl_i,
    output       scl_o,
    output       scl_oen,
    input        sda_i,
    output       sda_o,
    output       sda_oen
);

    parameter [4:0] ST_IDLE  = 5'b0_0000;
    parameter [4:0] ST_START = 5'b0_0001;
    parameter [4:0] ST_READ  = 5'b0_0010;
    parameter [4:0] ST_WRITE = 5'b0_0100;
    parameter [4:0] ST_ACK   = 5'b0_1000;
    parameter [4:0] ST_STOP  = 5'b1_0000;

    reg  [3:0] core_cmd;
    reg        core_txd;
    wire       core_ack, core_rxd;

    reg [7:0] sr;
    reg       shift, ld;

    wire      go;
    reg [2:0] dcnt;
    wire      cnt_done;

    i2c_master_bit_ctrl bit_controller (
        .clk     ( clk      ),
        .rst     ( rst      ),
        .nReset  ( nReset   ),
        .ena     ( ena      ),
        .clk_cnt ( clk_cnt  ),
        .cmd     ( core_cmd ),
        .cmd_ack ( core_ack ),
        .busy    ( i2c_busy ),
        .al      ( i2c_al   ),
        .din     ( core_txd ),
        .dout    ( core_rxd ),
        .scl_i   ( scl_i    ),
        .scl_o   ( scl_o    ),
        .scl_oen ( scl_oen  ),
        .sda_i   ( sda_i    ),
        .sda_o   ( sda_o    ),
        .sda_oen ( sda_oen  )
    );

    assign go = (read | write | stop) & ~cmd_ack;
    assign dout = sr;

    always @(posedge clk or negedge nReset)
        if (!nReset)
            sr <= #1 8'h0;
        else if (rst)
            sr <= #1 8'h0;
        else if (ld)
            sr <= #1 din;
        else if (shift)
            sr <= #1 {sr[6:0], core_rxd};

    always @(posedge clk or negedge nReset)
        if (!nReset)
            dcnt <= #1 3'h0;
        else if (rst)
            dcnt <= #1 3'h0;
        else if (ld)
            dcnt <= #1 3'h7;
        else if (shift)
            dcnt <= #1 dcnt - 3'h1;

    assign cnt_done = ~(|dcnt);

    reg [4:0] c_state;

    always @(posedge clk or negedge nReset)
        if (!nReset)
        begin
            core_cmd <= #1 `I2C_CMD_NOP;
            core_txd <= #1 1'b0;
            shift    <= #1 1'b0;
            ld       <= #1 1'b0;
            cmd_ack  <= #1 1'b0;
            c_state  <= #1 ST_IDLE;
            ack_out  <= #1 1'b0;
        end
        else if (rst | i2c_al)
        begin
            core_cmd <= #1 `I2C_CMD_NOP;
            core_txd <= #1 1'b0;
            shift    <= #1 1'b0;
            ld       <= #1 1'b0;
            cmd_ack  <= #1 1'b0;
            c_state  <= #1 ST_IDLE;
            ack_out  <= #1 1'b0;
        end
        else
        begin
            core_txd <= #1 sr[7];
            shift    <= #1 1'b0;
            ld       <= #1 1'b0;
            cmd_ack  <= #1 1'b0;

            case (c_state)
                ST_IDLE:
                    if (go)
                    begin
                        if (start)
                        begin
                            c_state  <= #1 ST_START;
                            core_cmd <= #1 `I2C_CMD_START;
                        end
                        else if (read)
                        begin
                            c_state  <= #1 ST_READ;
                            core_cmd <= #1 `I2C_CMD_READ;
                        end
                        else if (write)
                        begin
                            c_state  <= #1 ST_WRITE;
                            core_cmd <= #1 `I2C_CMD_WRITE;
                        end
                        else
                        begin
                            c_state  <= #1 ST_STOP;
                            core_cmd <= #1 `I2C_CMD_STOP;
                        end

                        ld <= #1 1'b1;
                    end

                ST_START:
                    if (core_ack)
                    begin
                        if (read)
                        begin
                            c_state  <= #1 ST_READ;
                            core_cmd <= #1 `I2C_CMD_READ;
                        end
                        else
                        begin
                            c_state  <= #1 ST_WRITE;
                            core_cmd <= #1 `I2C_CMD_WRITE;
                        end

                        ld <= #1 1'b1;
                    end

                ST_WRITE:
                    if (core_ack)
                        if (cnt_done)
                        begin
                            c_state  <= #1 ST_ACK;
                            core_cmd <= #1 `I2C_CMD_READ;
                        end
                        else
                        begin
                            c_state  <= #1 ST_WRITE;
                            core_cmd <= #1 `I2C_CMD_WRITE;
                            shift    <= #1 1'b1;
                        end

                ST_READ:
                    if (core_ack)
                    begin
                        if (cnt_done)
                        begin
                            c_state  <= #1 ST_ACK;
                            core_cmd <= #1 `I2C_CMD_WRITE;
                        end
                        else
                        begin
                            c_state  <= #1 ST_READ;
                            core_cmd <= #1 `I2C_CMD_READ;
                        end

                        shift    <= #1 1'b1;
                        core_txd <= #1 ack_in;
                    end

                ST_ACK:
                    if (core_ack)
                    begin
                        if (stop)
                        begin
                            c_state  <= #1 ST_STOP;
                            core_cmd <= #1 `I2C_CMD_STOP;
                        end
                        else
                        begin
                            c_state  <= #1 ST_IDLE;
                            core_cmd <= #1 `I2C_CMD_NOP;
                            cmd_ack  <= #1 1'b1;
                        end

                        ack_out <= #1 core_rxd;
                        core_txd <= #1 1'b1;
                    end
                    else
                        core_txd <= #1 ack_in;

                ST_STOP:
                    if (core_ack)
                    begin
                        c_state  <= #1 ST_IDLE;
                        core_cmd <= #1 `I2C_CMD_NOP;
                        cmd_ack  <= #1 1'b1;
                    end
            endcase
        end

endmodule


//
// OpenCores I2C top-level with register read/write interface
//
module i2c_master_top (
    input        rst,
    input        clk,
    input [15:0] clk_div_cnt,

    input  scl_pad_i,
    output scl_pad_o,
    output scl_padoen_o,

    input  sda_pad_i,
    output sda_pad_o,
    output sda_padoen_o,

    input        i2c_addr_2byte,
    input        i2c_read_req,
    output       i2c_read_req_ack,
    input        i2c_write_req,
    output       i2c_write_req_ack,
    input  [7:0] i2c_slave_dev_addr,
    input  [15:0] i2c_slave_reg_addr,
    input  [7:0] i2c_write_data,
    output reg [7:0] i2c_read_data,
    output reg   error
);

    localparam S_IDLE             =  0;
    localparam S_WR_DEV_ADDR      =  1;
    localparam S_WR_REG_ADDR      =  2;
    localparam S_WR_DATA          =  3;
    localparam S_WR_ACK           =  4;
    localparam S_WR_ERR_NACK      =  5;
    localparam S_RD_DEV_ADDR0     =  6;
    localparam S_RD_REG_ADDR      =  7;
    localparam S_RD_DEV_ADDR1     =  8;
    localparam S_RD_DATA          =  9;
    localparam S_RD_STOP          = 10;
    localparam S_WR_STOP          = 11;
    localparam S_WAIT             = 12;
    localparam S_WR_REG_ADDR1     = 13;
    localparam S_RD_REG_ADDR1     = 14;
    localparam S_RD_ACK           = 15;

    reg start;
    reg stop;
    reg read;
    reg write;
    reg ack_in;
    reg [7:0] txr;
    wire [7:0] rxr;
    wire i2c_busy;
    wire i2c_al;
    wire done;
    wire irxack;
    reg [3:0] state;
    reg [3:0] next_state;

    assign i2c_read_req_ack  = (state == S_RD_ACK);
    assign i2c_write_req_ack = (state == S_WR_ACK);

    always @(posedge clk or posedge rst)
        if (rst)
            state <= S_IDLE;
        else
            state <= next_state;

    always @(*)
        case (state)
            S_IDLE:
                if (i2c_write_req)
                    next_state = S_WR_DEV_ADDR;
                else if (i2c_read_req)
                    next_state = S_RD_DEV_ADDR0;
                else
                    next_state = S_IDLE;

            S_WR_DEV_ADDR:
                if (done && irxack)
                    next_state = S_WR_ERR_NACK;
                else if (done)
                    next_state = S_WR_REG_ADDR;
                else
                    next_state = S_WR_DEV_ADDR;

            S_WR_REG_ADDR:
                if (done)
                    next_state = i2c_addr_2byte ? S_WR_REG_ADDR1 : S_WR_DATA;
                else
                    next_state = S_WR_REG_ADDR;

            S_WR_REG_ADDR1:
                if (done)
                    next_state = S_WR_DATA;
                else
                    next_state = S_WR_REG_ADDR1;

            S_WR_DATA:
                if (done)
                    next_state = S_WR_STOP;
                else
                    next_state = S_WR_DATA;

            S_WR_ERR_NACK:
                next_state = S_WR_STOP;

            S_RD_ACK, S_WR_ACK:
                next_state = S_WAIT;

            S_WAIT:
                next_state = S_IDLE;

            S_RD_DEV_ADDR0:
                if (done && irxack)
                    next_state = S_WR_ERR_NACK;
                else if (done)
                    next_state = S_RD_REG_ADDR;
                else
                    next_state = S_RD_DEV_ADDR0;

            S_RD_REG_ADDR:
                if (done)
                    next_state = i2c_addr_2byte ? S_RD_REG_ADDR1 : S_RD_DEV_ADDR1;
                else
                    next_state = S_RD_REG_ADDR;

            S_RD_REG_ADDR1:
                if (done)
                    next_state = S_RD_DEV_ADDR1;
                else
                    next_state = S_RD_REG_ADDR1;

            S_RD_DEV_ADDR1:
                if (done)
                    next_state = S_RD_DATA;
                else
                    next_state = S_RD_DEV_ADDR1;

            S_RD_DATA:
                if (done)
                    next_state = S_RD_STOP;
                else
                    next_state = S_RD_DATA;

            S_RD_STOP:
                if (done)
                    next_state = S_RD_ACK;
                else
                    next_state = S_RD_STOP;

            S_WR_STOP:
                if (done)
                    next_state = S_WR_ACK;
                else
                    next_state = S_WR_STOP;

            default:
                next_state = S_IDLE;
        endcase

    always @(posedge clk or posedge rst)
        if (rst)
            error <= 1'b0;
        else if (state == S_IDLE)
            error <= 1'b0;
        else if (state == S_WR_ERR_NACK)
            error <= 1'b1;

    always @(posedge clk or posedge rst)
        if (rst)
            start <= 1'b0;
        else if (done)
            start <= 1'b0;
        else if (state == S_WR_DEV_ADDR || state == S_RD_DEV_ADDR0 || state == S_RD_DEV_ADDR1)
            start <= 1'b1;

    always @(posedge clk or posedge rst)
        if (rst)
            stop <= 1'b0;
        else if (done)
            stop <= 1'b0;
        else if (state == S_WR_STOP || state == S_RD_STOP)
            stop <= 1'b1;

    always @(posedge clk or posedge rst)
        if (rst)
            ack_in <= 1'b0;
        else
            ack_in <= 1'b1;

    always @(posedge clk or posedge rst)
        if (rst)
            write <= 1'b0;
        else if (done)
            write <= 1'b0;
        else if (state == S_WR_DEV_ADDR || state == S_WR_REG_ADDR || state == S_WR_REG_ADDR1 || state == S_WR_DATA || state == S_RD_DEV_ADDR0 || state == S_RD_DEV_ADDR1 || state == S_RD_REG_ADDR || state == S_RD_REG_ADDR1)
            write <= 1'b1;

    always @(posedge clk or posedge rst)
        if (rst)
            read <= 1'b0;
        else if (done)
            read <= 1'b0;
        else if (state == S_RD_DATA)
            read <= 1'b1;

    always @(posedge clk or posedge rst)
        if (rst)
            i2c_read_data <= 8'h00;
        else if (state == S_RD_DATA && done)
            i2c_read_data <= rxr;

    always @(posedge clk or posedge rst)
        if (rst)
            txr <= 8'd0;
        else
            case (state)
                S_WR_DEV_ADDR, S_RD_DEV_ADDR0:
                    txr <= {i2c_slave_dev_addr[7:1], 1'b0};
                S_RD_DEV_ADDR1:
                    txr <= {i2c_slave_dev_addr[7:1], 1'b1};
                S_WR_REG_ADDR, S_RD_REG_ADDR:
                    txr <= (i2c_addr_2byte == 1'b1) ? i2c_slave_reg_addr[15:8] : i2c_slave_reg_addr[7:0];
                S_WR_REG_ADDR1, S_RD_REG_ADDR1:
                    txr <= i2c_slave_reg_addr[7:0];
                S_WR_DATA:
                    txr <= i2c_write_data;
                default:
                    txr <= 8'hff;
            endcase

    i2c_master_byte_ctrl byte_controller (
        .clk      ( clk          ),
        .rst      ( rst          ),
        .nReset   ( 1'b1         ),
        .ena      ( 1'b1         ),
        .clk_cnt  ( clk_div_cnt  ),
        .start    ( start        ),
        .stop     ( stop         ),
        .read     ( read         ),
        .write    ( write        ),
        .ack_in   ( ack_in       ),
        .din      ( txr          ),
        .cmd_ack  ( done         ),
        .ack_out  ( irxack       ),
        .dout     ( rxr          ),
        .i2c_busy ( i2c_busy     ),
        .i2c_al   ( i2c_al       ),
        .scl_i    ( scl_pad_i    ),
        .scl_o    ( scl_pad_o    ),
        .scl_oen  ( scl_padoen_o ),
        .sda_i    ( sda_pad_i    ),
        .sda_o    ( sda_pad_o    ),
        .sda_oen  ( sda_padoen_o )
    );

endmodule


//
// I2C configuration sequencer
//
module i2c_config (
    input              rst,
    input              clk,
    input [15:0]       clk_div_cnt,
    input              i2c_addr_2byte,
    output reg [9:0]   lut_index,
    input [7:0]        lut_dev_addr,
    input [15:0]       lut_reg_addr,
    input [7:0]        lut_reg_data,
    output reg         error,
    output             done,
    inout              i2c_scl,
    inout              i2c_sda
);

    wire scl_pad_i;
    wire scl_pad_o;
    wire scl_padoen_o;
    wire sda_pad_i;
    wire sda_pad_o;
    wire sda_padoen_o;

    assign sda_pad_i = i2c_sda;
    assign i2c_sda   = ~sda_padoen_o ? sda_pad_o : 1'bz;
    assign scl_pad_i = i2c_scl;
    assign i2c_scl   = ~scl_padoen_o ? scl_pad_o : 1'bz;

    reg  i2c_write_req;
    wire i2c_write_req_ack;
    wire i2c_read_req_ack;
    wire [7:0] i2c_read_data;
    wire err;
    reg [2:0] state;

    localparam S_IDLE         = 0;
    localparam S_WR_I2C_CHECK = 1;
    localparam S_WR_I2C       = 2;
    localparam S_WR_I2C_DONE  = 3;

    assign done = (state == S_WR_I2C_DONE);

    always @(posedge clk or posedge rst)
        if (rst)
        begin
            state       <= S_IDLE;
            error       <= 1'b0;
            lut_index   <= 8'd0;
            i2c_write_req <= 1'b0;
        end
        else
            case (state)
                S_IDLE:
                begin
                    state         <= S_WR_I2C_CHECK;
                    error         <= 1'b0;
                    lut_index     <= 8'd0;
                    i2c_write_req <= 1'b0;
                end
                S_WR_I2C_CHECK:
                begin
                    if (lut_dev_addr != 8'hff)
                    begin
                        i2c_write_req <= 1'b1;
                        state         <= S_WR_I2C;
                    end
                    else
                    begin
                        state <= S_WR_I2C_DONE;
                    end
                end
                S_WR_I2C:
                begin
                    if (i2c_write_req_ack)
                    begin
                        error         <= err ? 1'b1 : error;
                        lut_index     <= lut_index + 8'd1;
                        i2c_write_req <= 1'b0;
                        state         <= S_WR_I2C_CHECK;
                    end
                end
                S_WR_I2C_DONE:
                begin
                    state <= S_WR_I2C_DONE;
                end
                default:
                    state <= S_IDLE;
            endcase

    i2c_master_top i2c_master_top_m0 (
        .rst              (rst),
        .clk              (clk),
        .clk_div_cnt      (clk_div_cnt),
        .scl_pad_i        (scl_pad_i),
        .scl_pad_o        (scl_pad_o),
        .scl_padoen_o     (scl_padoen_o),
        .sda_pad_i        (sda_pad_i),
        .sda_pad_o        (sda_pad_o),
        .sda_padoen_o     (sda_padoen_o),
        .i2c_addr_2byte   (i2c_addr_2byte),
        .i2c_read_req     (1'b0),
        .i2c_read_req_ack (i2c_read_req_ack),
        .i2c_write_req    (i2c_write_req),
        .i2c_write_req_ack(i2c_write_req_ack),
        .i2c_slave_dev_addr(lut_dev_addr),
        .i2c_slave_reg_addr(lut_reg_addr),
        .i2c_write_data   (lut_reg_data),
        .i2c_read_data    (i2c_read_data),
        .error            (err)
    );

endmodule


//
// SiI9134 configuration LUT
//
module sii9134_lut (
    input  wire [9:0]  lut_index,
    output reg  [31:0] lut_data
);

    always @(*) begin
        case (lut_index)
            10'd0: lut_data = {8'h72, 16'h08, 8'h35};
            10'd1: lut_data = {8'h7A, 16'h2F, 8'h00};
            default: lut_data = {8'hff, 16'hff, 8'hff};
        endcase
    end

endmodule


//
// SiI9134 I2C initialization wrapper
//
module i2c_master_sii9134 #(
    parameter CLK_FREQ_HZ = 27_000_000,
    parameter I2C_FREQ_HZ = 100_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire init_req,
    output wire busy,
    output wire done,
    output wire error,
    inout  wire i2c_scl,
    inout  wire i2c_sda
);

    localparam [15:0] CLK_DIV_CNT = CLK_FREQ_HZ / (4 * I2C_FREQ_HZ) - 1;

    wire [9:0]  lut_index;
    wire [31:0] lut_data;

    sii9134_lut u_lut (
        .lut_index (lut_index),
        .lut_data  (lut_data)
    );

    i2c_config u_i2c_config (
        .rst            (~rst_n),
        .clk            (clk),
        .clk_div_cnt    (CLK_DIV_CNT),
        .i2c_addr_2byte (1'b0),
        .lut_index      (lut_index),
        .lut_dev_addr   (lut_data[31:24]),
        .lut_reg_addr   (lut_data[23:8]),
        .lut_reg_data   (lut_data[7:0]),
        .error          (error),
        .done           (done),
        .i2c_scl        (i2c_scl),
        .i2c_sda        (i2c_sda)
    );

    assign busy = ~done;

endmodule
