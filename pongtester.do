vlib work

vlog pong.v

vsim pong_game -gCLOCKS_PER_SECOND=1 -gX_SCREEN_PIXELS=50 -gY_SCREEN_PIXELS=50 -gY_PADDLE_SIZE=5


log {/*}
add wave -unsigned {/*}
add wave -unsigned {/pong_game/control_rend1/current_draw_state}
add wave -unsigned {/pong_game/control_rend1/scored}
add wave -unsigned {/pong_game/c_ball_move/lhs_scored}
add wave -unsigned {/pong_game/c_ball_move/rhs_scored}

#Test Case 1:
#A: Reset, then wait 200 ps
#B: Go, then try to input the following:
#C: A = 13, B = 8, C = 5, X = 2
# should yield 13*2^2 + 8*2 + 5 = 73// = 01001001
# set data to 9 after setting all registers

force -freeze {iClock} 1 0, 0 {50 ps} -r 100

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

