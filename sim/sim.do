vlib work
vmap work work

vlog ../rtl/BrLitePkg.sv
vlog ../rtl/BrLiteRouter.sv
vlog BrLiteNoC.sv
vlog scenario.sv
vlog testbench.sv

vsim work.testbench -voptargs=+acc
#do wave.do
run -all
