vlib work

vlog pong.v

vsim -L altera_mf_ver pong_game -gCLOCKS_PER_SECOND=500 -gX_SCREEN_PIXELS=50 -gY_SCREEN_PIXELS=50 -gY_PADDLE_SIZE=5 -gX_PADDLE_SIZE=2 -gFRAMES_PER_UPDATE=1 -gWARNING_LEVEL=0


log {/*}
add wave -unsigned {/*}
add wave -unsigned {/pong_game/control_rend1/current_draw_state}
add wave -unsigned {/pong_game/control_rend1/scored}
#add wave -unsigned {/pong_game/c_ball_move/*}
add wave -unsigned -color cyan {/pong_game/control_rend1/*}
add wave -unsigned {/pong_game/drawBorder/*}
add wave -unsigned -color orange {/pong_game/ball_rend1/*}
add wave -unsigned {/pong_game/ball_rend1/*}
add wave -unsigned -color magenta {/pong_game/ball_rend1/*}
add wave -unsigned -color magenta {/pong_game/ball_rend1/black_screen/*}

#Test Case 1:
force -freeze {iClock} 1 0, 0 {5 ps} -r 10

force {iResetn} 0
force {iDown} 0
force {iUp} 0
force {iDown2} 0
force {iUp2} 0

force {iEnable} 1
force {iBlack} 0
force {iColour} 3'b000
run 1000ps

force {iResetn} 1
run 5000ps

force {iUp} 1
force {iUp2} 1 
run 100000ps

