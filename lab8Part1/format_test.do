# set the working dir, where all compiled verilog goes
vlib work
vlog part2.v
vsim part2

# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
add wave -unsigned {/*}
delete wave {/part2/iResetn}
delete wave {/part2/iClock}
add wave -unsigned -color orange {/part2/iResetn}
add wave -unsigned -color orange {/part2/iClock}
add wave -unsigned -color magenta {/part2/C0/next_state}
add wave -unsigned -color magenta {/part2/C0/current_state}
add wave -unsigned {/part2/C0/load_ix}
add wave -unsigned {/part2/C0/load_y_plot}
add wave -unsigned {/part2/C0/blk}
add wave -unsigned {/part2/C0/ld_x}
add wave -unsigned {/part2/C0/ld_y}
add wave -unsigned {/part2/C0/ld_c}
add wave -unsigned {/part2/C0/plot}
add wave -unsigned {/part2/D0/pt_x}
add wave -unsigned {/part2/D0/x_orig}
add wave -unsigned {/part2/D0/pt_y}
add wave -unsigned {/part2/D0/y_orig}

# The first commands sets clk to after 0ns, then sets it to 1 after 50ns. This cycle repeats after 100ns.
# Clock w/ 100ps period
force {iClock} 0 0ps , 1 {5ps} -r 10ps

#Test Case 2: interupt inputs with a reset partway through
# 		then draw at (5,10), colour (1,1,0)
# States:
#S_LOAD_X        = 3'b000,
#S_LOAD_X_WAIT   = 3'b001
#S_LOAD_Y        = 3'b010,
#S_LOAD_Y_WAIT   = 3'b011 *Try to interupt here!
#S_DRAW          = 3'b100
#S_BLK_WAIT      = 3'b101
#S_BLK           = 3'b110
#S_DONE          = 3'b111;

# reset
# iLoadX = 1, XY coord = 4
# iLoadX = 0
# iPlotBox = 1, XY coord = 1, colour = 4

# Reset, 10 cycles + 5
force {iResetn} 0
force {iPlotBox} 0
force {iBlack} 0
force {iLoadX} 0
force {iColour} 0
force {iXY_Coord} 0
run 100ps

# Initialize (S: Load_X), 5+5 cycles
force {iResetn} 1
force {iXY_Coord} 6'd4
force {iBlack} 0
force {iPlotBox} 0
run 150ps

#S: Load_X_Wait, 
force {iLoadX} 1
run 50ps

#S: Load_Y
force {iLoadX} 0
run 50ps

#S: Load_Y_Wait (includes loading the colour as well) 5+5
force {iXY_Coord} 6'd1
force {iColour} 100
force {iPlotBox} 1
run 100 ps

# Draw
force {iPlotBox} 0
run 200ps

