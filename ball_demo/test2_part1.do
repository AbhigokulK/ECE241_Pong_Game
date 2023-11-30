# set the working dir, where all compiled verilog goes
vlib work
vlog ball_movement.v
vsim ball_movement -gX_SCREEN_PIXELS=20 -gY_SCREEN_PIXELS=15 -gCLOCKS_PER_SECOND=60 -gFRAMES_PER_UPDATE=3 -gX_BOXSIZE=2 -gY_BOXSIZE=2 -gPADDLE_Y=2 -gMAX_RATE=2 -gPADDLE_OFFSET=1 -gPADDLE_X=2 -gY_MARGIN=2
# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
add wave -unsigned -color orange {iClock}
add wave -unsigned -color orange {iResetn}
add wave -unsigned -color orange {iColour}
add wave -unsigned -color orange {iBlack}
add wave -unsigned -color orange {iEnable}
add wave -unsigned -color orange {lhs_paddle_y}
add wave -unsigned -color orange {rhs_paddle_y}
add wave -unsigned -color magenta {oX}
add wave -unsigned -color magenta {oY}
add wave -unsigned {oColour}
add wave -unsigned {oPlot}
add wave -unsigned {lhs_score}
add wave -unsigned {rhs_score}
add wave -unsigned {boundaryHit}
add wave -unsigned -color orange {frameTick}
add wave -unsigned -color orange {frameCount}
add wave -unsigned -color orange {ball_x}
add wave -unsigned -color orange {ball_y}
add wave -unsigned -color orange {x_dir}
add wave -unsigned -color orange {y_dir}
add wave -unsigned -color orange {rendered}

add wave -unsigned -color magenta {/rateDiv/*}
add wave -unsigned -color cyan {/c0/*}
add wave -unsigned -color magenta {/c0/left_bound/*}
add wave -unsigned -color cyan {/c0/right_bound/*}
add wave -unsigned {/ball_phys1/*}
add wave -unsigned -color orange {/ball_rend1/*}
add wave -unsigned -color magenta {/ball_rend1/clearOld/*}
add wave -unsigned {/ball_rend1/drawNew/*}
add wave -unsigned -color cyan {/ball_rend1/black_screen/*}

# Clock w/ 10ps period, labeled frequency of 20 ticks per second
force {iClock} 0 0ps , 1 {5ps} -r 10ps

# 1 frames per second, with 20 clock ticks per second -> 1 frame every 20 clock ticks!
#reset
force {iResetn} 0
force {iColour} 111
force {iBlack} 0
force {iEnable} 1
force {lhs_paddle_y} 'd0
force {rhs_paddle_y} 'd0
run 50ps

force {iResetn} 1
run 2000ps
