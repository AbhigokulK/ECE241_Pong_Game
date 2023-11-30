vlog VGA_interface.v

vsim countDown -gCLK_FREQ=20
#module countDown
#(
#	parameter 	CLK_FREQ = 50000000,
#				DURATION = 1
#)
#(
#	input clk,
#	input resetn,
#	input startUp,
#	output reg done,
#);

log {/*}
add wave -unsigned {/*}
force {clk} 1 0, 0 {5ps} -r 10ps
force {resetn} 0
force {startUp} 0
run 20ps

force {resetn} 1
run 100ps

force {startUp} 1
run 50ps

force {startUp} 0
run 1000ps

force {startUp} 1
run 1000ps