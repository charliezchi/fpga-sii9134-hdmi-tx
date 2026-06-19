// C:\hqv3_xist_3.1.1_FT053026_win64\build\ipcreator\sup_files\ipdepot\pll\pll_freq_30k\..\_ipgen_seal_\pll_seal.exe -meta_xml C:\hqv3_xist_3.1.1_FT053026_win64\build\ipcreator\sup_files\ipdepot\pll\pll_freq_30k\pll_freq_25k.xml -ini_file C:/hqws/project_1/ipcore_dir/pll_sii9134/pll_sii9134.hqip -lang chs


`timescale 1 ns / 1 ps
module pll_sii9134 (CLKI, CLKOP, LOCK)/* synthesis NGD_DRC_MASK=1 */;
    input wire CLKI;
    output wire CLKOP;
    output wire LOCK;

    supply0 RST;
    supply0 RESETM;
    supply0 RESETC;
    supply0 RESETD;
    supply0 STDBY;
    supply0 [1:0] PHASESEL;
    supply0 PHASEDIR;
    supply0 PHASESTEP;
    wire DPHSRC;
    wire CLKO5_t;
    wire CLKOS3_t;
    wire CLKOS2_t;
    wire CLKOP_t;
    wire CLKOS_t;

    supply0 ipgen_GND;

    wire REFCLK_t;
    wire CLKINTFB_t;
    wire CLKI_t;
    wire CLKI_rstreg;

    localparam       CLKI_FREQ           = 27                            ;//pll clk_in freq(MHz)
    localparam       DEVICE              = "SEAL"                     ;//device config("SEAL/SEALION")
    localparam       RST_CNT_WIDTH       = $clog2(11*CLKI_FREQ) + 1      ;//11us power on reset cnt width.
    localparam       DLY_CYCLE           = 5 ;
    
    reg     [RST_CNT_WIDTH-1:0]         rst_cnt         = 'd0               ;
    reg                                 rst_pre         = 'd1               ;
    wire    [DLY_CYCLE-1:0]             rst_reg                             ;//rst sync
    wire                                pll_arst                            ;
    wire                                lock_pre                            ;
    reg     [1:0]                       lock_sync                           ;//lock sync
    
    always @ (posedge CLKI_rstreg)
    begin
        if  (rst_cnt[RST_CNT_WIDTH-1]==1'd0)
            rst_cnt <=  rst_cnt + 1;
        else ;
    end
    always @ (posedge CLKI_rstreg)
    begin
        if  (rst_cnt[RST_CNT_WIDTH-1]==1'd0)
            rst_pre <=  1;
        else if(RST==1)
            rst_pre <=  1;
        else
            rst_pre <=  0 ;
    end
    generate
        if(DEVICE=="SEAL") begin
            defparam u_pll_rst_reg_sync0.INIT = 1'b1; xsDFFSA_K1 u_pll_rst_reg_sync0 (.C(CLKI_rstreg),.D(rst_pre),   .Q(rst_reg[0]));
            defparam u_pll_rst_reg_sync1.INIT = 1'b1; xsDFFSA_K1 u_pll_rst_reg_sync1 (.C(CLKI_rstreg),.D(rst_reg[0]),.Q(rst_reg[1]));
            defparam u_pll_rst_reg_sync2.INIT = 1'b1; xsDFFSA_K1 u_pll_rst_reg_sync2 (.C(CLKI_rstreg),.D(rst_reg[1]),.Q(rst_reg[2]));
            defparam u_pll_rst_reg_sync3.INIT = 1'b1; xsDFFSA_K1 u_pll_rst_reg_sync3 (.C(CLKI_rstreg),.D(rst_reg[2]),.Q(rst_reg[3]));
            defparam u_pll_rst_reg_sync4.INIT = 1'b1; xsDFFSA_K1 u_pll_rst_reg_sync4 (.C(CLKI_rstreg),.D(rst_reg[3]),.Q(rst_reg[4]));
        end
        else begin
            xsDFF_K1G1 u_pll_rst_reg_sync0(.D(rst_pre),   .CK(CLKI_rstreg),.Q(rst_reg[0]));
            xsDFF_K1G1 u_pll_rst_reg_sync1(.D(rst_reg[0]),.CK(CLKI_rstreg),.Q(rst_reg[1]));
            xsDFF_K1G1 u_pll_rst_reg_sync2(.D(rst_reg[1]),.CK(CLKI_rstreg),.Q(rst_reg[2]));
            xsDFF_K1G1 u_pll_rst_reg_sync3(.D(rst_reg[2]),.CK(CLKI_rstreg),.Q(rst_reg[3]));
            xsDFF_K1G1 u_pll_rst_reg_sync4(.D(rst_reg[3]),.CK(CLKI_rstreg),.Q(rst_reg[4]));
        end
    endgenerate
    assign  pll_arst = rst_reg[DLY_CYCLE-1];

    always @ (posedge CLKI_rstreg or negedge lock_pre)
    begin
        if (~lock_pre)
            lock_sync <=  2'b00;
        else
            lock_sync <=  {lock_sync[0], 1'b1};
    end
    assign  LOCK = lock_sync[1];

    assign CLKI_rstreg = CLKI;
    assign CLKI_t = CLKI;

    defparam PLLInst_0.CLKO5_SEL = "CLKO5" ;
    defparam PLLInst_0.CLKOPD_DLY = 0 ;
    defparam PLLInst_0.DDRST_ENA = "DISABLED" ;
    defparam PLLInst_0.DCRST_ENA = "DISABLED" ;
    defparam PLLInst_0.MRST_ENA = "ENABLED" ;
    defparam PLLInst_0.PLLRST_ENA = "ENABLED" ;
    defparam PLLInst_0.INTFB_WAKE = "DISABLED" ;
    defparam PLLInst_0.STDBY_ENABLE = "DISABLED" ;
    defparam PLLInst_0.DPHASE_SOURCE = "DISABLED" ;
    defparam PLLInst_0.PLL_USE_WB = "DISABLED" ;
    defparam PLLInst_0.PLL_LOCK_MODE = 0 ;
    defparam PLLInst_0.CLKOS_TRIM_DELAY = 0 ;
    defparam PLLInst_0.CLKOS_TRIM_POL = "RISING" ;
    defparam PLLInst_0.CLKOP_TRIM_DELAY = 0 ;
    defparam PLLInst_0.CLKOP_TRIM_POL = "RISING" ;
    defparam PLLInst_0.FRACN_DIV = 0 ;
    defparam PLLInst_0.FRACN_ENABLE = "DISABLED" ;
    defparam PLLInst_0.CLKO5_FPHASE = 0 ;
    defparam PLLInst_0.CLKO5_CPHASE = 0 ;
    defparam PLLInst_0.OUTDIVIDER_MUXE2 = "DIVE" ;
    defparam PLLInst_0.PREDIVIDER_MUXE1 = 0 ;
    defparam PLLInst_0.VCO_BYPASS_E0 = "DISABLED" ;
    defparam PLLInst_0.CLKO5_ENABLE = "DISABLED" ;
    defparam PLLInst_0.CLKO5_DIV = 0 ;
    defparam PLLInst_0.CLKO6_ENABLE = "DISABLED" ;
    defparam PLLInst_0.CLKO7_ENABLE = "DISABLED" ;
    defparam PLLInst_0.CLKOS3_FPHASE = 0 ;
    defparam PLLInst_0.CLKOS3_CPHASE = 0 ;
    defparam PLLInst_0.CLKOS2_FPHASE = 0 ;
    defparam PLLInst_0.CLKOS2_CPHASE = 0 ;
    defparam PLLInst_0.CLKOS_FPHASE = 0 ;
    defparam PLLInst_0.CLKOS_CPHASE = 0 ;
    defparam PLLInst_0.CLKOP_FPHASE = 0 ;
    defparam PLLInst_0.CLKOP_CPHASE = 4 ;
    defparam PLLInst_0.OUTDIVIDER_MUXD2 = "DIVD" ;
    defparam PLLInst_0.PREDIVIDER_MUXD1 = 0 ;
    defparam PLLInst_0.VCO_BYPASS_D0 = "DISABLED" ;
    defparam PLLInst_0.CLKOS3_ENABLE = "DISABLED" ;
    defparam PLLInst_0.OUTDIVIDER_MUXC2 = "DIVC" ;
    defparam PLLInst_0.PREDIVIDER_MUXC1 = 0 ;
    defparam PLLInst_0.VCO_BYPASS_C0 = "DISABLED" ;
    defparam PLLInst_0.CLKOS2_ENABLE = "DISABLED" ;
    defparam PLLInst_0.OUTDIVIDER_MUXB2 = "DIVB" ;
    defparam PLLInst_0.PREDIVIDER_MUXB1 = 0 ;
    defparam PLLInst_0.VCO_BYPASS_B0 = "DISABLED" ;
    defparam PLLInst_0.CLKOS_ENABLE = "DISABLED" ;
    defparam PLLInst_0.OUTDIVIDER_MUXA2 = "DIVA" ;
    defparam PLLInst_0.PREDIVIDER_MUXA1 = 0 ;
    defparam PLLInst_0.VCO_BYPASS_A0 = "DISABLED" ;
    defparam PLLInst_0.CLKOP_ENABLE = "ENABLED" ;
    defparam PLLInst_0.CLKOS3_DIV = 0 ;
    defparam PLLInst_0.CLKOS2_DIV = 0 ;
    defparam PLLInst_0.CLKOS_DIV = 0 ;
    defparam PLLInst_0.CLKOP_DIV = 5 ;
    defparam PLLInst_0.CLKFB_DIV = 11 ;
    defparam PLLInst_0.CLKI_DIV = 2 ;
    defparam PLLInst_0.FEEDBK_PATH = "INT_DIVA" ;
    defparam PLLInst_0.EN_PHI = "FALSE" ;
    xsPLLSA PLLInst_0 (.CLKI(CLKI_t), .CLKFB(CLKINTFB_t), .PHASESEL1(PHASESEL[1]), 
        .PHASESEL0(PHASESEL[0]), .PHASEDIR(PHASEDIR), .PHASESTEP(PHASESTEP), 
        .LOADREG(ipgen_GND), .STDBY(STDBY), .PLLWAKESYNC(ipgen_GND), 
        .RST(pll_arst), .RESETM(1'b0), .RESETC(1'b0), .RESETD(1'b0), 
        .ENCLKOP(ipgen_GND), .ENCLKOS(ipgen_GND), .ENCLKOS2(ipgen_GND), 
        .ENCLKOS3(ipgen_GND), .PLLCLK(ipgen_GND), .PLLRST(ipgen_GND), .PLLSTB(ipgen_GND), 
        .PLLWE(ipgen_GND), .PLLADDR4(ipgen_GND), .PLLADDR3(ipgen_GND), .PLLADDR2(ipgen_GND), 
        .PLLADDR1(ipgen_GND), .PLLADDR0(ipgen_GND), .PLLDATI7(ipgen_GND), 
        .PLLDATI6(ipgen_GND), .PLLDATI5(ipgen_GND), .PLLDATI4(ipgen_GND), 
        .PLLDATI3(ipgen_GND), .PLLDATI2(ipgen_GND), .PLLDATI1(ipgen_GND), 
        .PLLDATI0(ipgen_GND), .CLKOP(CLKOP_t), .CLKOS(CLKOS_t), .CLKOS2(CLKOS2_t), 
        .CLKOS3(CLKOS3_t), .LOCK(lock_pre), .INTLOCK(), .REFCLK(REFCLK_t), .CLKINTFB(CLKINTFB_t), 
        .DPHSRC(DPHSRC), .PLLACK(), .PLLDATO7(), .PLLDATO6(), .PLLDATO5(), .PLLDATO4(), 
        .PLLDATO3(), .PLLDATO2(), .PLLDATO1(), .PLLDATO0(), .CLKO5(CLKO5_t))
             /* synthesis FREQUENCY_PIN_CLKOP="148.500000" */
             /* synthesis FREQUENCY_PIN_CLKI="27.000000" */
             /* synthesis ICP_CURRENT="5" */
             /* synthesis LPF_RESISTOR="16" */
             /* synthesis FREQ_LOCK_ACCURACY="2" */;

    assign CLKOP = CLKOP_t;


    // exemplar begin
    // exemplar attribute PLLInst_0 FREQUENCY_PIN_CLKOP 148.500000
    // exemplar attribute PLLInst_0 FREQUENCY_PIN_CLKI 27.000000
    // exemplar attribute PLLInst_0 ICP_CURRENT 5
    // exemplar attribute PLLInst_0 LPF_RESISTOR 16
    // exemplar attribute PLLInst_0 FREQ_LOCK_ACCURACY 2
    // exemplar end

    // phase clkop  0.000000

endmodule
