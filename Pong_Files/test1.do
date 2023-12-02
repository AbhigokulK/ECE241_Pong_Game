# set the working dir, where all compiled verilog goes
vlib work
vlog pong.v
vsim pong_game -gX_SCREEN_PIXELS=100 -gY_SCREEN_PIXELS=50 -gCLOCKS_PER_SECOND=60 -gFRAMES_PER_UPDATE=3 -gX_BOXSIZE=2 -gY_BOXSIZE=2 -gPADDLE_Y=25 -gMAX_RATE=3 -gPADDLE_OFFSET=5 -gPADDLE_X=4 -gY_MARGIN=5 
# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files

log -r /*
# INPUTS
add wave -unsigned -color orange {iClock}
add wave -unsigned -color orange {iResetn}
add wave -unsigned -color orange {iColour}
add wave -unsigned -color orange {iBlack}
add wave -unsigned -color orange {iEnable}
add wave -unsigned -color orange {iUp}
add wave -unsigned -color orange {iDown}
add wave -unsigned -color orange {iUp2}
add wave -unsigned -color orange {iDown2}

# VGA OUTPUTS
add wave -unsigned -color magenta {oX}
add wave -unsigned -color magenta {oY}
add wave -unsigned {oColour}
add wave -unsigned {oPlot}

#GAME OUTPUTS
add wave -unsigned {lhs_score}
add wave -unsigned {rhs_score}
add wave -unsigned {boundaryHit}
add wave -unsigned -color orange {frameTick}
add wave -unsigned -color orange {frameCount}
add wave -unsigned -color orange {oBall_X}
add wave -unsigned -color orange {oBall_Y}
add wave -unsigned -color orange {x_dir}
add wave -unsigned -color orange {y_dir}
add wave -unsigned -color orange {rendered}
add wave -unsigned {/*}

# ball info
add wave -unsigned -color blue {/c_ball_move/*}
add wave -unsigned -color turquoise {/ball_phys1/*}
add wave -unsigned -color cyan {/ball_rend1/*}

# paddle info
add wave -unsigned -color orchid {/c_paddleA_move/*}
add wave -unsigned -color magenta {/c_paddleB_move/*}
add wave -unsigned -color violet {/paddle_phys/*}
add wave -unsigned -color thistle {/paddle_rend/*}

# auxillary info
add wave -unsigned {/frameHandler/*}


# Clock w/ 10ps period, labeled frequency of 20 ticks per second
force {iClock} 0 0ps , 1 {5ps} -r 10ps

# 1 frames per second, with 20 clock ticks per second -> 1 frame every 20 clock ticks!
#reset
force {iResetn} 0
force {iColour} 111
force {iBlack} 0
force {iEnable} 1

run 50ps

force {iResetn} 1
run 2000ps
