# set the working dir, where all compiled verilog goes
vlib work
vlog ball_movement.v
vsim scoreHandler -gMAX_SCORE=3

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
force {lhs_scored} 0
force {rhs_scored} 0
run 40ps

force {lhs_scored} 1
run 100ps

force {lhs_scored} 0
run 20ps

force {rhs_scored} 1
run 50ps

force {rhs_scored} 0
run 20ps

force {lhs_scored} 1
run 20ps

force {lhs_scored} 0
run 20ps

force {lhs_scored} 1
run 20ps