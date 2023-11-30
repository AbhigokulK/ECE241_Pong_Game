# set the working dir, where all compiled verilog goes
vlib work
vlog part1.v
vsim drawBox -gSCREEN_X=40 -gSCREEN_Y=30 -gX_BOXSIZE=2 -gY_BOXSIZE=3

# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
add wave -unsigned {/*}
add wave -unsigned -color orange {/drawBox/SCREEN_X}
add wave -unsigned -color orange {/drawBox/SCREEN_Y}
add wave -unsigned -color orange {/drawBox/X_BOXSIZE}
add wave -unsigned -color orange {/drawBox/Y_BOXSIZE}

# Clock w/ 10ps period
force {clk} 0 0ps , 1 {5ps} -r 10ps

#test case 1: reset then let it count
#given frequency of 30 ticks/s and frame rate of 3 frames/s...
# should take 10 ticks/frame, which would be 100ps with the clock period


# reset
force {resetn} 0
force {start} 0 
run 20ps

force {resetn} 1
force {x_orig} 'd5
force {y_orig} 'd2
run 20ps

force {start} 1
run 50ps

force {start} 0
run 100ps

force {resetn} 0
run 100ps

force {resetn} 1
run 200ps