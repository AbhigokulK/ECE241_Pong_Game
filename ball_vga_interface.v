module fill
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
		KEY,							// On Board Keys
		SW, 							//* on Board Switches
		LEDR,							//* on Board LEDs (for debugging)
		HEX0,
		HEX1,
		HEX2,
		HEX3,
		HEX4,
		HEX5,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input	[3:0]	KEY;			
	input [9:0] SW;						//*
	output [9:0] LEDR;					//*
	output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	parameter 	X_BOXSIZE = 8'd4,   // Box X dimension
				Y_BOXSIZE = 7'd4,   // Box Y dimension
				X_SCREEN_PIXELS = 'd320,  // X screen width for starting resolution and fake_fpga (was 9*)
				Y_SCREEN_PIXELS = 'd240,  // Y screen height for starting resolution and fake_fpga (was 7*)
				CLOCKS_PER_SECOND = 50000000, // 50 MHZ for fake_fpga (was 5KHz*)
				X_MAX = X_SCREEN_PIXELS - 1 - X_BOXSIZE, // 0-based and account for box width
				Y_MAX = Y_SCREEN_PIXELS - 1 - Y_BOXSIZE,
				
				PADDLE_X = 5,
				PADDLE_Y = 100,
				PADDLE_OFFSET = 10,
				PADDLE_MAX_Y = Y_SCREEN_PIXELS - 1 - PADDLE_Y,

				FRAME_RATE = 'd60,
				PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60,
				RATE = 'd1,
				MAX_RATE = 'd4,
				PULSE_HOLD_TIME = 1;

	// Create the colour, x, y and writeEn wires that are inputs to the controller.

	wire [2:0] colour;
	wire [9:0] x;
	wire [8:0] y;
	wire writeEn;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "320x240";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.
	
	/*
	FPGA MAPPING:
		resetn (reset active low) -> KEY[0]
		iColour -> SW[2:0]
		iBlack (active high clear screen) -> !KEY[3]
		iEnable -> SW[9]
		LEDR[7:5] -> oColour
		LEDR[9:8] -> {KEY[3], KEY[0]}
		
		LEDR[0] -> LHS Goal Hit (on for 1s)
		LEDR[1] -> RHS Goal Hit (on for 1s)
		LEDR[2] -> Boundary Hit (on for 1s)
		
		HEX0, HEX1, HEX2 -> ball_x_coordinate
		HEX3, HEX4, HEX5 -> ball_y_coordinate
	/*
	module ball_movement:
		input wire [2:0] 	iColour;
		input wire 	    	iResetn;
		input wire 	    	iClock;
		input wire			iBlack;
		input wire			iEnable;

		input[($clog2(PADDLE_MAX_Y)):0] lhs_paddle_y;
		input[($clog2(PADDLE_MAX_Y)):0] rhs_paddle_y;

		output wire [($clog2(X_SCREEN_PIXELS)):0] oX;         // VGA pixel coordinates
		output wire [($clog2(Y_SCREEN_PIXELS)):0] oY;

		output wire [2:0] 	oColour;     // VGA pixel colour (0-7)
		output wire 	    oPlot;       // Pixel drawn enable
		output wire [($clog2(X_MAX)):0] oBall_X;
		output wire [($clog2(Y_MAX)):0] oBall_Y;
		output wire lhs_score;
		output wire rhs_score;
		output wire boundaryHit;

	parameter
		X_BOXSIZE = 8'd4,   // Box X dimension
		Y_BOXSIZE = 7'd4,   // Box Y dimension
		X_SCREEN_PIXELS = 10'd320,  // X screen width for starting resolution and fake_fpga (was 9*)
		Y_SCREEN_PIXELS = 9'd240,  // Y screen height for starting resolution and fake_fpga (was 7*)
		CLOCKS_PER_SECOND = 50000000, // 50 MHZ for fake_fpga (was 5KHz*)
		X_MAX = X_SCREEN_PIXELS - 1 - X_BOXSIZE, // 0-based and account for box width
		Y_MAX = Y_SCREEN_PIXELS - 1 - Y_BOXSIZE,

    	FRAMES_PER_UPDATE = 'd15,
    	PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60,
		RATE = 'd1,
		MAX_RATE = 'd5,
		TIME_TILL_ACCEL = 'd2,
		PADDLE_X = 'd4,
		PADDLE_Y = 'd15,
		PADDLE_OFFSET = 'd2,
		PADDLE_MAX_Y = Y_SCREEN_PIXELS - 1 - PADDLE_Y;
	*/
	wire [($clog2(X_MAX)):0]ball_x_coord;
	wire [($clog2(X_MAX)):0]ball_y_coord;

	wire lhs_pulse, rhs_pulse, boundary_pulse;

	// KEYS ARE ACTIVE LOW (ie low when pushed down)
	ball_movement #(.X_BOXSIZE(X_BOXSIZE), .Y_BOXSIZE(Y_BOXSIZE), 
					.X_SCREEN_PIXELS(X_SCREEN_PIXELS), .Y_SCREEN_PIXELS(Y_SCREEN_PIXELS),
					.PADDLE_X(PADDLE_X), .PADDLE_Y(PADDLE_Y), 
					.PADDLE_OFFSET(PADDLE_OFFSET), .PADDLE_MAX_Y(PADDLE_MAX_Y),
					.FRAMES_PER_UPDATE(FRAME_RATE), .RATE(RATE), .MAX_RATE(MAX_RATE)) ball1
					(.iResetn(resetn), .iColour(SW[2:0]), .iClock(CLOCK_50),
					.iBlack(!KEY[3]), .iEnable(SW[9]), // IMPORTANT, SEE NOTE
					.lhs_paddle_y(1), .rhs_paddle_y(15), // these are for debugging!!!
					.oX(x), .oY(y), .oColour(colour), .oPlot(writeEn), .oBall_X(ball_x_coord), .oBall_Y(ball_y_coord),
					.lhs_score(lhs_pulse), .rhs_score(rhs_pulse), .boundaryHit(boundary_pulse));
					
	
	assign LEDR[7:5] = colour;
	assign LEDR[9:8] = {!KEY[3], !KEY[0]};
	
	holdPulse #(CLOCKS_PER_SECOND,
				PULSE_HOLD_TIME)
	lhs_LED(CLOCK_50,
			lhs_pulse,
			resetn,
			LEDR[0]);

	holdPulse #(CLOCKS_PER_SECOND,
				PULSE_HOLD_TIME)
			rhs_LED(CLOCK_50,
					rhs_pulse,
					resetn,
					LEDR[1]);

	holdPulse #(CLOCKS_PER_SECOND,
				PULSE_HOLD_TIME)
	boundary_LED(CLOCK_50,
				boundary_pulse,
				resetn,
				LEDR[2]);

	// Output coordinates
	hex_decoder hex0(ball_x_coord[3:0], HEX0);
	hex_decoder hex1(ball_x_coord[7:4], HEX1);
	hex_decoder hex2({2'b00, ball_x_coord[9:8]}, HEX2);
	
	hex_decoder hex3(ball_y_coord[3:0], HEX3);
	hex_decoder hex4(ball_y_coord[7:4], HEX4);
	hex_decoder hex5({3'b000, ball_y_coord[8]}, HEX5);
	
endmodule


module holdPulse
#(
	parameter 	CLOCK_FREQ = 50000000,
					HOLD_TIME = 1

)
(
	input clk, 
	input pulse, 
	input resetn, 
	output heldPulse
);
	
	reg[($clog2(HOLD_TIME*CLOCK_FREQ)):0] count;
	reg hold;

	localparam max_count = HOLD_TIME*CLOCK_FREQ;

	always@(posedge clk) begin
		if(!resetn) begin
			// END COUNT IMMEDIATELY, and stop counting
			count <= 0;
			hold <= 0;
		end
		else begin
			if(pulse) begin
				// reset counter on pulse
				count <= max_count;
				hold <= 1;
			end
			if(count > 0) begin
				// begin counting down! (should only occur AFTER pulse has been given)
				count <= count - 1;
				hold <= 1;
			end
			else begin
				// counter ends!
				hold <= 0;
			end
		end
	end

	assign heldPulse = hold;

endmodule


module hex_decoder(c, display);
	input[3:0] c;
	output[6:0] display;
	wire[6:0] w;
	
	calcD0 d_0(.c(c), .w(w[0]));
	calcD1 d_1(.c(c), .w(w[1]));
	calcD2 d_2(.c(c), .w(w[2]));
	calcD3 d_3(.c(c), .w(w[3]));
	calcD4 d_4(.c(c), .w(w[4]));
	calcD5 d_5(.c(c), .w(w[5]));
	calcD6 d_6(.c(c), .w(w[6]));
	
	assign display[0] = !w[0];
	assign display[1] = !w[1];
	assign display[2] = !w[2];
	assign display[3] = !w[3];
	assign display[4] = !w[4];
	assign display[5] = !w[5];
	assign display[6] = !w[6];
endmodule



/* 
Input: 4 bits
Output: 1 bit representing D_0 (D w/ subscript 0)
D_0 (D w/ subscript 0) = M1*M4*M11*M13 [maxterms, see end for exact expression]
*/
module calcD0(c, w);
	input[3:0] c;
	output w;
	
	assign w = (c[3] | c[2] | c[1] | !c[0])
					&(c[3] | !c[2] | c[1] | c[0])
					&(!c[3] | c[2] | !c[1] | !c[0])
					&(!c[3] | !c[2] | c[1] | !c[0]);

	
endmodule

/* 
Input: 4 bits
Output: 1 bit representing D_1
D_1 = M5*M6*M11*M12*M14*M15
*/
module calcD1(c, w);
	input[3:0] c;
	output w;
	
	assign w = (c[3] | !c[2] | c[1] | !c[0])
					&(c[3] | !c[2] | !c[1] | c[0])
					&(!c[3] | c[2] | !c[1] | !c[0])
					&(!c[3] | !c[2] | c[1] | c[0])
					&(!c[3] | !c[2] | !c[1] | c[0])
					&(!c[3] | !c[2] | !c[1] | !c[0]);
	
endmodule

/* 
Input: 4 bits
Output: 1 bit representing D_2
D_2 = M2*M12*M14*M15
*/
module calcD2(c, w);
	input[3:0] c;
	output w;
	
	assign w = (c[3] | c[2] | !c[1] | c[0])
					&(!c[3] | !c[2] | c[1] | c[0])
					&(!c[3] | !c[2] | !c[1] | c[0])
					&(!c[3] | !c[2] | !c[1] | !c[0]);
	
endmodule

/* 
Input: 4 bits
Output: 1 bit representing D_3
D_3 = M1*M4*M7*M10*M15
*/
module calcD3(c, w);
	input[3:0] c;
	output w;
	
	assign w = (c[3] | c[2] | c[1] | !c[0])
					&(c[3] | !c[2] | c[1] | c[0])
					&(c[3] | !c[2] | !c[1] | !c[0])
					&(!c[3] | c[2] | !c[1] | c[0])
					&(!c[3] | !c[2] | !c[1] | !c[0]);
	
endmodule

/* 
Input: 4 bits
Output: 1 bit representing D_4
D_4 = M1*M3*M4*M5*M7*M9
*/
module calcD4(c, w);
	input[3:0] c;
	output w;
	
	assign w = (c[3] | c[2] | c[1] | !c[0]) //M1
		&(c[3] | c[2] | !c[1] | !c[0]) //M3
		&(c[3] | !c[2] | c[1] | c[0]) //M4
		&(c[3] | !c[2] | c[1] | !c[0]) //M5
		&(c[3] | !c[2] | !c[1] | !c[0]) //M7
		&(!c[3] | c[2] | c[1] | !c[0]); //M9
	
endmodule

/* 
Input: 4 bits
Output: 1 bit representing D_5
D_5 = M1*M2*M3*M7*M13
*/
module calcD5(c, w);
	input[3:0] c;
	output w;
	
	assign w = (c[3] | c[2] | c[1] | !c[0])
					&(c[3] | c[2] | !c[1] | c[0])
					&(c[3] | c[2] | !c[1] | !c[0])
					&(c[3] | !c[2] | !c[1] | !c[0])
					&(!c[3] | !c[2] | c[1] | !c[0]);

	
endmodule

/* 
Input: 4 bits
Output: 1 bit representing D_6
D_6 = M0*M1*M7*M12
*/
module calcD6(c, w);
	input[3:0] c;
	output w;
	
	assign w = (c[3] | c[2] | c[1] | c[0])
					&(c[3] | c[2] | c[1] | !c[0])
					&(c[3] | !c[2] | !c[1] | !c[0])
					&(!c[3] | !c[2] | c[1] | c[0]);
	
endmodule 

