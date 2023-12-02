module pong_vga_interface
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
	
	parameter 			
		X_BOXSIZE = 8'd4,   // Box X dimension
		Y_BOXSIZE = 7'd4,   // Box Y dimension
		X_SCREEN_PIXELS = 10'd320,  // X screen width for starting resolution and fake_fpga (was 9*)
		Y_SCREEN_PIXELS = 9'd240,  // Y screen height for starting resolution and fake_fpga (was 7*)
		CLOCKS_PER_SECOND = 50000000, // 50 MHZ for fake_fpga (was 5KHz*)
		X_PADDLE_SIZE = 8'd5,   // Paddle X dimension
		Y_PADDLE_SIZE = 7'd40,   // Paddle Y dimension
		Y_MARGIN = 20,

		// game physics parameters
		FRAMES_PER_UPDATE = 'd15,
		RATE = 'd1,
		MAX_RATE = 'd5,
		TIME_TILL_ACCEL = 'd2,
		
		MAX_SCORE = 3,
		
		// dependent parameters
		X_SET = 'd2, 
		X_SET2 = X_SCREEN_PIXELS - X_PADDLE_SIZE,
		PADDLE_MAX_Y = Y_SCREEN_PIXELS - 1 - Y_PADDLE_SIZE,

		
		Y_MIN = Y_MARGIN,
		X_MAX = (X_SCREEN_PIXELS - 1 - X_BOXSIZE - X_PADDLE_SIZE - X_SET2), // 0-based and account for box width
		Y_MAX = (Y_SCREEN_PIXELS - 1 - Y_BOXSIZE - Y_MARGIN),

		PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60;

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
		defparam VGA.BACKGROUND_IMAGE = "stars_colour.mif"; //test image loaded, was black.mif
	// Put your code here. Your code should produce signals x,y,colour and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.
	
	/*

	*/
	wire lhs_pulse, rhs_pulse, boundary_pulse;

	// KEYS ARE ACTIVE LOW (ie low when pushed down)
	pong_game #(.X_BOXSIZE(X_BOXSIZE), .Y_BOXSIZE(Y_BOXSIZE), 
					.X_SCREEN_PIXELS(X_SCREEN_PIXELS), .Y_SCREEN_PIXELS(Y_SCREEN_PIXELS),
					.PADDLE_X(PADDLE_X), .PADDLE_Y(PADDLE_Y), 
					.Y_MARGIN(Y_MARGIN), .PADDLE_OFFSET(PADDLE_OFFSET), .PADDLE_MAX_Y(PADDLE_MAX_Y),
					.FRAMES_PER_UPDATE(FRAME_RATE), .RATE(RATE), .MAX_RATE(MAX_RATE)) 
					
					pong
					(.iResetn(resetn), .iColour(SW[8:7]), .iClock(CLOCK_50),
					.iBlack(!KEY[3]), .iEnable(SW[9]), // IMPORTANT, SEE NOTE
					.iUp(SW[1], .iDown(SW[0], .iUp2(SW[3]), .iDown2(SW[2]),
					.oX(x), .oY(y), .oColour(colour), .oPlot(writeEn),
					.lhs_score(lhs_pulse), .rhs_score(rhs_pulse), .boundaryHit(boundary_pulse));
					
	wire [($clog2(MAX_SCORE)):0] lhs_count;
	wire [($clog2(MAX_SCORE)):0] rhs_count;

	scoreHandler #(
		.MAX_SCORE(MAX_SCORE)
	) 
	scoreHandle(	
		.clk(CLOCK_50), 
		.resetn(resetn),
		.lhs_scored(lhs_pulse),
		.rhs_scored(rhs_pulse),
		.lhs_score_count(lhs_count),
		.rhs_score_count(rhs_count)
	);

	assign LEDR[2:1] = lhs_count;
	assign LEDR[5:4] = rhs_count;
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
					LEDR[3]);

	holdPulse #(CLOCKS_PER_SECOND,
				PULSE_HOLD_TIME)
	boundary_LED(CLOCK_50,
				boundary_pulse,
				resetn,
				LEDR[6]);

	// Output coordinates
	hex_decoder hex0(ball_x_coord[3:0], HEX0);
	hex_decoder hex1(ball_x_coord[7:4], HEX1);
	hex_decoder hex2({2'b00, ball_x_coord[9:8]}, HEX2);
	
	hex_decoder hex3(ball_y_coord[3:0], HEX3);
	hex_decoder hex4(ball_y_coord[7:4], HEX4);
	hex_decoder hex5({3'b000, ball_y_coord[8]}, HEX5);
	
endmodule

module scoreHandler
#(
	parameter MAX_SCORE = 5
)
(
	input clk,
	input resetn,
	input lhs_scored, 
	input rhs_scored,
	output reg [($clog2(MAX_SCORE)):0] lhs_score_count,
	output reg [($clog2(MAX_SCORE)):0] rhs_score_count
);	

	wire lhs_pulse, rhs_pulse;
	always@(posedge clk)
	begin
		if(!resetn) begin
			lhs_score_count <= 0;
			rhs_score_count <= 0;
		end
		else begin
			if(lhs_pulse) begin
				lhs_score_count <= lhs_score_count + 1;
			end
			else if(rhs_pulse) begin
				rhs_score_count <= rhs_score_count + 1;
			end
		end
	end
	signalToPulse left_pulse(clk, resetn, lhs_scored, lhs_pulse);
	signalToPulse right_pulse(clk, resetn, rhs_scored, rhs_pulse);
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
