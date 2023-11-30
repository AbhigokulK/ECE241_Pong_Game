# set the working dir, where all compiled verilog goes
vlib work
vlog part1.v
vsim part1 -gCLOCKS_PER_SECOND=30 -gFRAMES_PER_UPDATE=3

# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
add wave -unsigned {/*}

# Clock w/ 10ps period
force {iClock} 0 0ps , 1 {5ps} -r 10ps

#test case 1: reset then let it count
#given frequency of 30 ticks/s and frame rate of 3 frames/s...
# should take 10 ticks/frame, which would be 100ps with the clock period


# reset
force {iResetn} 1
run 20ps

force {iResetn} 0
run 500ps