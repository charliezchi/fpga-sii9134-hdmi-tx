# run_sii9134_demo.do
# ModelSim / QuestaSim script for sii9134_demo.
# Uses the behavioral PLL model (sim/pll_sii9134_sim.v).

vlib work
vmap work work

vlog -work work -sv ../rtl/video_timing_gen.v
vlog -work work -sv ../rtl/axis_to_video.v
vlog -work work -sv ../rtl/axis_tpg.v
vlog -work work -sv ../rtl/sii9134_top.v
vlog -work work -sv ../rtl/i2c_master_sii9134.v
vlog -work work -sv ../rtl/sii9134_demo.v

vlog -work work -sv ../sim/pll_sii9134_sim.v
vlog -work work -sv ../sim/i2c_slave_model.v
vlog -work work -sv tb_sii9134_demo.v

vsim -c -voptargs="+acc" work.tb_sii9134_demo
run -all
