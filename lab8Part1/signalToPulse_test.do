# set the working dir, where all compiled verilog goes
vlib work
vlog ball_movement.v
vsim signalToPulse

# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
add wave -unsigned {/*}
force {clk} 0 0ps , 1 {5ps} -r 10ps
#period of 10ps

#reset
force {resetn} 0
run 20ps

force {resetn} 1
force {signal} 0
run 20ps

force {signal} 1
run 100ps

force {signal} 0
run 20ps

force {signal} 1
run 50ps

force {signal} 0
run 15ps

force {signal} 0 0ps , 1 {5ps} -r 15ps
run 100ps