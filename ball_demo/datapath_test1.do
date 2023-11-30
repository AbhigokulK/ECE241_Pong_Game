# set the working dir, where all compiled verilog goes
vlib work
vlog part1.v
vsim datapath -gSCREEN_X=40 -gSCREEN_Y=10 -gX_BOXSIZE=2 -gY_BOXSIZE=2 -gRATE=1

# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
add wave -unsigned -color orange {clk}
add wave -unsigned -color orange {resetn}
add wave -unsigned -color orange {enable}
add wave -unsigned -color orange {frameTick}
add wave -unsigned -color orange {x_dir}
add wave -unsigned -color orange {y_dir}
add wave -unsigned -color orange {doneClear}
add wave -unsigned -color orange {doneClear}
add wave -unsigned {ball_x}
add wave -unsigned {ball_y}
add wave -unsigned {render_x}
add wave -unsigned {render_y}
add wave -unsigned {col_out}
add wave -unsigned {rendered}
add wave -unsigned {frameFinished}
# add wave -unsigned -color cyan {/datapath/clearOld/*}
add wave -unsigned -color magenta {/datapath/drawNew/*}

# Clock w/ 10ps period
force {clk} 0 0ps , 1 {5ps} -r 10ps

run 5ps

# FrameRate every 200ps
force {frameTick} 1 0, 0 {10ps} -r 200ps

#test case 1: 

# reset
force {color} 111
force {enable} 1
force {x_dir} 1
force {y_dir} 1
force {resetn} 0
run 20ps

force {resetn} 1
run 500ps