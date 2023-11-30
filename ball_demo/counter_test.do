# set the working dir, where all compiled verilog goes
vlib work
vlog ball_vga_interface.v
vsim holdPulse -gCLOCK_FREQ=10 -gFRAME_RATE=1 -gHOLD_TIME=1
# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
add wave -unsigned {/*}

# period of 10ps, frame rate of 1 per second, freq of 10 per "second" -> 1 frame every 1 periods
force {clk} 0 0ps , 1 {5ps} -r 10ps

#test case 1: reset then let it count
#given frequency of 30 ticks/s and frame rate of 3 frames/s...
# should take 10 ticks/frame, which would be 100ps with the clock period


# reset
force {resetn} 0
run 20ps

# start pulse
force {resetn} 1
force {pulse} 1
run 10ps

# end pulse after one clock tick
force {pulse} 0
run 200ps