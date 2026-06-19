set DEV_FAMILY SEAL
set DEV_NAME   SA5Z-30-D1-8U213C
set TOP_MODULE sii9134_demo
set SDC_FILE   ../constraints/sii9134.sdc
set UPC_FILE   ../constraints/sii9134.upc

set RTL_FILES ""
lappend RTL_FILES ../rtl/axis_to_video.v
lappend RTL_FILES ../rtl/axis_tpg.v
lappend RTL_FILES ../rtl/i2c_master_sii9134.v
lappend RTL_FILES ../rtl/sii9134_demo.v
lappend RTL_FILES ../rtl/sii9134_top.v
lappend RTL_FILES ../rtl/video_timing_gen.v
lappend RTL_FILES ../ip/pll_sii9134/pll_sii9134.v

dv.setup $DEV_FAMILY $DEV_NAME
design.analyze $RTL_FILES
design.rtlsyn -top $TOP_MODULE
design.tdomap

sdc.read $SDC_FILE
upc.read $UPC_FILE

design.pack -effort std -area -ratio 100 -iob_dff 0
design.place -effort std 
design.route -effort std
design.bitgen sii9134_demo.bin -compress -bin
