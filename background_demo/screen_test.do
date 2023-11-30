vlog Back_VGA_interface.v

vsim -L altera_mf_ver VGA_interface -gCLK_FREQ=500
#module VGA_interface
#	(
#		CLOCK_50,						//	On Board 50 MHz
#		// Your inputs and outputs here
#		KEY,							// On Board Keys
#		SW, 							//* on Board Switches
#		LEDR,							//* on Board LEDs (for debugging)
#		HEX0,
#		HEX1,
#		HEX2,
#		HEX3,
#		HEX4,
#		HEX5,
#		// The ports below are for the VGA output.  Do not change.
#		VGA_CLK,   						//	VGA Clock
#		VGA_HS,							//	VGA H_SYNC
#		VGA_VS,							//	VGA V_SYNC
#		VGA_BLANK_N,						//	VGA BLANK
#		VGA_SYNC_N,						//	VGA SYNC
#		VGA_R,   						//	VGA Red[9:0]
#		VGA_G,	 						//	VGA Green[9:0]
#		VGA_B   						//	VGA Blue[9:0]
#	);

# resetn = KEY[0]

log {/*}
add wave -unsigned {CLOCK_50}
add wave -unsigned {KEY[0]}
add wave -unsigned {x}
add wave -unsigned {y}
add wave -unsigned {colour}
add wave -unsigned {writeEn}

add wave -unsigned -color cyan {/timer/*}
add wave -unsigned -color magenta {/edgeHandler/*}
add wave -unsigned -color orange {/edgeHandler/drawBorder/*}
add wave -unsigned -color blue {/edgeHandler/redrawBack/*}


force {CLOCK_50} 1 0, 0 {5ps} -r 10ps
force {KEY[0]} 0
force {SW[0]} 1
run 20ps

force {KEY[0]} 1
run 1000ps
