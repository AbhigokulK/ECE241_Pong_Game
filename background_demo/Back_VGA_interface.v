module Back_VGA_interface
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
		defparam VGA.BACKGROUND_IMAGE = "stars_colour.mif";
	
	// Put your code here. Your code should produce signals x,y,colour and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.
	
	/*
	Part 2 FPGA mapping:
	iClock -> Clock_50
	iResetn -> KEY[0]
	iColour[2:0] -> SW[2:0]
	
	oColour[2:0] -> LEDR[9:7]
	oNewFrame -> LEDR[0]
	oPlot -> LEDR[1]
	oX[9:0] -> HEX2, 1, 0
	oY[8:0] -> HEX3, 4, 5
	*/
	
	parameter 	SCREEN_X = 320,
				SCREEN_Y = 240,
				BORDER_X = 320,
				BORDER_Y = 30;

    wire doneBorder;
	wire fireBorder;
	wire fireClean;
	wire doneClean;

	

	parameter 	CLK_FREQ = 50000000,
				DURATION = 1;

	holdPulse #(
		CLK_FREQ,
		DURATION
	)holdBorder (
		.clk(CLOCK_50),
		.resetn(resetn),
		.pulse(doneBorder),
		.heldPulse(fireClean)
	);
	
	/*
	countDown  #(
		CLK_FREQ,
		DURATION
	)holdClean(
		.clk(CLOCK_50),
		.resetn(resetn),
		.startUp(doneClean),
		.done(fireBorder)
	);*/
	//***** CHECK PARAMETERS!!!
	
	// manipulate enable signals to follow timer given by parameter
	wire blink;

	countDown #(
		CLK_FREQ,
		DURATION
	) timer(
		CLOCK_50,
		resetn,
		1'b1,
		blink
	);

	control #(
		CLK_FREQ,
		SCREEN_X,
		SCREEN_Y,
		BORDER_X,
		BORDER_Y
	) edgeHandler(
		CLOCK_50,
		resetn,
		blink,
		SW[0],
		x,
		y,
		colour,
		writeEn
	);
	assign LEDR[0] = SW[0];
	assign LEDR[1] = blink;
	assign LEDR[2] = resetn;
endmodule

module control
#(
	parameter	CLK_FREQ = 50000000,
				X_SIZE = 320,
				Y_SIZE = 240,
				BORDER_X = 320,
				BORDER_Y = 30
)
(
	input clk,
	input resetn,
	input blink,
	input mux,

	output reg[9:0] x,
	output reg[8:0] y,
	output reg [2:0] colour,
	output reg plot
);
	wire [2:0] border_colour;
	wire [9:0] border_x;
	wire [5:0] border_y;
	reg border_on;
	wire border_plot;
	wire doneBorder;

	wire [2:0] back_colour;
	wire [9:0] back_x;
	wire [5:0] back_y;
	reg back_on;
	wire back_plot;
	wire doneBack;


	border_anim  #(
		BORDER_X, BORDER_Y
	)
	drawBorder(
		clk, resetn, border_on, 'd0, 'd0,
		border_x, border_y, border_colour, border_plot, doneBorder
	);


	background_anim #(
		X_SIZE, Y_SIZE, 1'd1
	)
	redrawBack(
		clk, resetn, back_on, mux, 0, 0,
		back_x, back_y, back_colour, back_plot, doneBack
	);

	reg [1:0] currentDraw, nextDraw;

	localparam 	S_CLEAR = 2'd0,
				S_CLEAR_DONE = 2'd1,
				S_DRAW = 2'd2,
				S_DRAW_DONE = 2'd3;
	/*
	CLEAR: clear stuff out, when done, go to CLEAR_WAIT
	CLEAR_WAIT: wait until blink, then go to DRAW
	DRAW: draw stuff in, when done, go to DRAW_WAIT
	DRAW_WAIT: wait until blink, then go to clear
	*/
	// STATE TABLE!
	always@(*) begin
		case(currentDraw)
			S_CLEAR: begin
				if(doneBack) nextDraw <= S_CLEAR_DONE;
				else nextDraw <= S_CLEAR;
			end

			S_CLEAR_DONE: begin
				if(blink) nextDraw <= S_DRAW;
				else nextDraw <= S_CLEAR_DONE;
			end

			S_DRAW: begin
				if(doneBorder) nextDraw <= S_DRAW_DONE;
				else nextDraw <= S_DRAW;
			end
			S_DRAW_DONE: begin
				if(blink) nextDraw <= S_CLEAR;
				else nextDraw <= S_DRAW_DONE;
			end
		endcase
	end

	// apply current state info
	always@(*) begin
		x <= 0;
		y <= 0;
		colour <= 0;
		plot <= 0;

		back_on <= 0;
		border_on <= 0;

		case(currentDraw)
			S_CLEAR: begin
				back_on <= 1;
				x <= back_x;
				y <= back_y;
				colour <= back_colour;
				plot <= back_plot;				
			end

			S_CLEAR_DONE: begin

			end

			S_DRAW: begin
				border_on <= 1;
				x <= border_x;
				y <= border_y;
				colour <= border_colour;
				plot <= border_plot;				
			end

			S_DRAW_DONE: begin

			end
		endcase
	end

	always@(posedge clk) begin
		if(!resetn) begin
			currentDraw <= S_DRAW_DONE;
		end
		else begin
			currentDraw <= nextDraw;
		end
	end	
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

/*
RAM ACCESS MODULE 
	input	[14:0]  address;
	input	  clock;
	input	[2:0]  data;
	input	  wren;
	output	[2:0]  q;
*/
module border_anim
#(
parameter 	X_SIZE = 320,
			Y_SIZE = 30,
			TRANSPARENT = 3'b000

)
(
	input clk,
	input resetn,
	input enable,
	input [($clog2(X_SIZE)):0] x_orig,
	input [($clog2(Y_SIZE)):0] y_orig,
	output reg [($clog2(X_SIZE)):0] pt_x,
	output reg [($clog2(Y_SIZE)):0] pt_y,
	output reg [2:0] outColour,
	output reg plot,
	output reg done
);
	reg [($clog2(X_SIZE)):0] x_counter;
	reg [($clog2(Y_SIZE)):0] y_counter;
	wire [2:0]pixel_colour;
	// output the colour of the current pixel on the stored image

	borderRAM borderMemory(
		.address((x_counter + (X_SIZE * y_counter))),
		.clock(clk),
		.data(3'd0),
		.wren(1'd0),
		.q(pixel_colour)
	);

	// actually move the pixels
	always@(posedge clk)
	begin
		// reset counters and status
		if(!resetn)begin
			x_counter <= 0;
			y_counter <= 0;
			pt_x <= x_orig;
			pt_y <= y_orig;
			plot <= 0;
			outColour <= 0;	
			done <= 1;
		end
		else begin
			if(enable) begin
				// whilst enabled...
				pt_x <= x_orig + x_counter;
				pt_y <= y_orig + y_counter;
				outColour <= pixel_colour;
				if(pixel_colour == TRANSPARENT) begin
					// DO NOT DRAW THIS PIXEL!
					plot <= 0;
				end
				else begin
					plot <= 1;
				end

				if(y_counter == Y_SIZE - 1 && x_counter == X_SIZE - 1) begin
					// done counting the box, send pulse
					x_counter <= 'd0;
					y_counter <= 'd0;
					done <= 1;
				end
				else if(x_counter < X_SIZE - 1) begin
					// just count normally if we already started
					x_counter <= x_counter + 1;
					done <= 0;
				end 
				else begin
					// completed row, go to new row and start on left
					x_counter <= 'd0;
					y_counter <= y_counter + 1;
					done <= 0;
				end
			end
			else begin
				done <= 0;
				x_counter <= 'd0;
				y_counter <= 'd0;
			end
		end
	end
endmodule

module background_anim
#(
parameter 	X_SIZE = 320,
			Y_SIZE = 30,
			IS_BACK = 1'b1,
			TRANSPARENT = 3'b000
			
)
(
	input clk,
	input resetn,
	input enable,
	input mux,
	
	input [($clog2(X_SIZE)):0] x_orig,
	input [($clog2(Y_SIZE)):0] y_orig,

	output reg [($clog2(X_SIZE)):0] pt_x,
	output reg [($clog2(Y_SIZE)):0] pt_y,

	output reg [2:0] outColour,
	output reg plot,
	output reg done
);
	reg [($clog2(X_SIZE)):0] x_counter;
	reg [($clog2(Y_SIZE)):0] y_counter;
	wire [2:0] back1_col;
	wire [2:0] crew_col;
	
	wire [2:0]pixel_colour;
	// output the colour of the current pixel on the stored image

	background_RAM1 backMemory(
		.address((x_counter + (X_SIZE * y_counter))),
		.clock(clk),
		.data(3'd0),
		.wren(1'd0),
		.q(back1_col)
	);

	crewmate_RAM crewmate_Mem(
		.address((x_counter + (X_SIZE * y_counter))),
		.clock(clk),
		.data(3'd0),
		.wren(1'd0),
		.q(crew_col)
	);

	assign pixel_colour = (mux)?crew_col:back1_col;

	// actually move the pixels
	always@(posedge clk)
	begin
		// reset counters and status
		if(!resetn)begin
			x_counter <= 0;
			y_counter <= 0;
			pt_x <= x_orig;
			pt_y <= y_orig;
			plot <= 0;
			outColour <= 0;	
			done <= 1;
		end
		else begin
			if(enable) begin
				// whilst enabled...
				pt_x <= x_orig + x_counter;
				pt_y <= y_orig + y_counter;
				outColour <= pixel_colour;
				if(IS_BACK) begin
					plot <= 1;
				end
				else begin
					if(pixel_colour == TRANSPARENT) begin
						// DO NOT DRAW THIS PIXEL!
						plot <= 0;
					end
					else begin
						plot <= 1;
					end
				end
				

				if(y_counter == Y_SIZE - 1 && x_counter == X_SIZE - 1) begin
					// done counting the box, send pulse
					x_counter <= 'd0;
					y_counter <= 'd0;
					done <= 1;
				end
				else if(x_counter < X_SIZE - 1) begin
					// just count normally if we already started
					x_counter <= x_counter + 1;
					done <= 0;
				end 
				else begin
					// completed row, go to new row and start on left
					x_counter <= 'd0;
					y_counter <= y_counter + 1;
					done <= 0;
				end
			end
			else begin
				done <= 0;
				x_counter <= 'd0;
				y_counter <= 'd0;
			end
		end
	end
endmodule



module countDown
#(
	parameter 	CLK_FREQ = 50000000,
				DURATION = 1
)
(
	input clk,
	input resetn,
	input startUp,
	output reg done
);
	localparam maxCount = CLK_FREQ*DURATION;

	// should count in a way such that we go to 0 after DURATION
	reg[($clog2(maxCount)):0] counter;

	// on the main clock tick...
	always@(posedge clk)
	begin
		// reset counter from reset signal
		if(!resetn) begin
			counter <= (maxCount - 1);
			done <= 0;
		end
		// normal operation
		else
		begin
			// reset counter when it reaches 0, implying one frame has passed!
			if(counter == 0)
			begin
				counter <= (maxCount - 1);
				done <= 1;
			end
			// decrement counter if enable is on
			else if(counter != maxCount - 1) begin
				counter <= counter - 1;
				done <= 0;
			end
			// upon startup, begin the count down
			else if(startUp) begin
				counter <= counter - 1;
				done <= 0;
			end
		end
   	end
endmodule

module rateDivider
#(
	parameter 	CLK_FREQ = 50000000,
				FRAME_RATE = 15
)
(
	input clk,
	input resetn,
	input enable,
	output reg pulse,
	output reg [($clog2(FRAME_RATE)):0] frameCount
);

	localparam maxCount = CLK_FREQ/FRAME_RATE;

	// should count in such a way that we have x pulses per second, where x is the frameRate
	// to do this, we need to count from (CLK_FREQ/FRAME_RATE) = maxCount to 0
	// (clocks ticks/s) / (frames/s) -> clocks ticks / frame
	reg[($clog2(CLK_FREQ/FRAME_RATE)):0] counter;

	// on the main clock tick...
	always@(posedge clk)
	begin
		// reset counter from reset signal
		if(!resetn)
		begin
			counter <= (maxCount - 1);
			frameCount <= 0;
			pulse <= 0;
		end
		// normal operation
		else
		begin
			// reset counter when it reaches 0, implying one frame has passed!
			if(counter == 0)
			begin
				counter <= (maxCount - 1);
				pulse <= 1;
				frameCount <= (frameCount == FRAME_RATE)?0:(frameCount + 1);
			end
			// decrement counter if enable is on
			else
			begin
				counter <= (enable == 1)?(counter - 1):counter;
				pulse <= 0;
			end
		end
   	end
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

