# set the working dir, where all compiled verilog goes
vlib work
vlog part1.v
vsim rateDivider -gCLK_FREQ=30 -gFRAME_RATE=3

# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
add wave -unsigned {/*}
delete wave {/rateDivider/reset}
delete wave {/rateDivider/clk}
delete wave {/rateDivider/counter}
add wave -unsigned -color orange {reset}
add wave -unsigned -color orange {clk}
add wave -unsigned -color magenta {counter}
add wave -unsigned {CLK_FREQ}
add wave -unsigned {FRAME_RATE}

# Clock w/ 10ps period
force {clk} 0 0ps , 1 {5ps} -r 10ps

#test case 1: reset then let it count
#given frequency of 30 ticks/s and frame rate of 3 frames/s...
# should take 10 ticks/frame, which would be 100ps with the clock period


# reset
force {enable} 1
force {reset} 1
run 20ps

force {reset} 0
run 500ps