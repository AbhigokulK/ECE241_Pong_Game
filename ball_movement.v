//
// This is the template for Part 1 of Lab 8.
//
// Paul Chow
// November 2021
//

// iColour is the colour for the box
//
// oX, oY, oColour and oPlot should be wired to the appropriate ports on the VGA controller
//

// Some constants are set as parameters to accommodate the different implementations
// X_SCREEN_PIXELS, Y_SCREEN_PIXELS are the dimensions of the screen
//       Default is 160 x 120, which is size for fake_fpga and baseline for the DE1_SoC vga controller
// CLOCKS_PER_SECOND should be the frequency of the clock being used.

module part1(iColour,iResetn,iClock,oX,oY,oColour,oPlot,oNewFrame);
	input wire [2:0] 	iColour;
	input wire 	    	iResetn;
	input wire 	    	iClock;
	output wire [($clog2(X_SCREEN_PIXELS)):0] oX;         // VGA pixel coordinates
	output wire [($clog2(Y_SCREEN_PIXELS)):0] oY;

	output wire [2:0] 	oColour;     // VGA pixel colour (0-7)
	output wire 	     	oPlot;       // Pixel drawn enable
	output wire       	oNewFrame;

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
		RATE = 'd1;
	//
	// Your code goes here
	//
	wire frameTick;
	wire[($clog2(X_MAX)):0] ball_x;
	wire[($clog2(Y_MAX)):0] ball_y;
	wire[($clog2(FRAMES_PER_UPDATE)):0] frameCount;
	wire x_dir, y_dir;
	wire rendered;

	rateDivider #(CLOCKS_PER_SECOND, 
				FRAMES_PER_UPDATE) 
				rateDiv (iClock, iResetn, 1'b1, frameTick, frameCount);

	control #(RATE, X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MAX, X_BOXSIZE, Y_BOXSIZE) 
			c0 
			(iClock, iResetn, 1,
			ball_x, ball_y,
			x_dir, y_dir);

	datapath #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MAX,
				X_BOXSIZE, Y_BOXSIZE, 
				FRAMES_PER_UPDATE, RATE)
			d0
			(iClock, iResetn, iColour, 1'b1,
			frameTick, frameCount,
			x_dir, y_dir,
			ball_x, ball_y,
			oX, oY, oColour, rendered, oNewFrame);
	
	assign oPlot = !rendered;

endmodule // part1

/*
divide the input clk into the intended frame rate
seems to work as intended
input clk,
input resetn,
input enable,
output pulse

parameter CLK_FREQ = 50000000;
parameter FRAME_RATE = 15;
*/
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
				frameCount <= (frameCount < FRAME_RATE)?(frameCount + 1):0;
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


module control
#(
	parameter 	RATE = 1,
				SCREEN_X = 'd640,
				SCREEN_Y = 'd480,
				X_MAX = 'd640,
				Y_MAX = 'd480,
				X_BOXSIZE = 8'd4,	// Box X dimension
				Y_BOXSIZE = 7'd4   	// Box Y dimension

)
(
	input clk,
	input resetn,
	input enable,
	
	input[($clog2(X_MAX)):0] x_pos,
	input[($clog2(Y_MAX)):0] y_pos,

	output reg x_dir,
	output reg y_dir,
	output reg [1:0] drawState //  draw box, clear box, draw all black, ???
);
	// bit 1 is X direction, bit 2 is Y direction
	reg[1:0] current_move_state, next_move_state;

	// movement state variable declarations
	localparam  S_LEFT   = 1'b0,
				S_RIGHT   	= 1'b1,
				S_UP        = 1'b0,
				S_DOWN   	= 1'b1;
	
	// movement state table
	always@(*)
	begin 
		if(!enable) begin
			// do nothing with states...
		end
		else begin
			//NOTE REGARDING COORDINATE SYSTEM:
			// RIGHTWARD -> LARGER X VALUE
			// DOWNWARD -> LARGER Y VALUE
			// therefore, bottom bound is when y is at max value! (vice versa for top bound)
			// set next state based on whether the ball will hit the wall or not
			// HORIZONTAL BOUNDARY HANDLING
			if(current_move_state[1] == S_LEFT) begin
				// going left
				if(x_pos < RATE +'d1) begin
					// if we go more left, we will hit the wall
					next_move_state[1] <= S_RIGHT;
				end
				else next_move_state[1] <= S_LEFT;
			end
			else begin
				// must be going right
				if(x_pos > X_MAX - RATE) begin
					// if we go more right, we will hit the wall
					next_move_state[1] <= S_LEFT;
				end
				else next_move_state[1] <= S_RIGHT;
			end

			// VERTICAL BOUNDARY HANDLING
			if(current_move_state[0] == S_DOWN) begin
				// going down
				if(y_pos > Y_MAX - RATE) begin
					// if we go more down, we will hit the wall
					next_move_state[0] <= S_UP;
				end
				else next_move_state[0] <= S_DOWN;
			end	
			else begin
				// must be going upward
				if(y_pos < RATE + 'd1) begin
					// if we go more down, we will hit the wall
					next_move_state[0] <= S_DOWN;
				end
				else next_move_state[0] <= S_UP;
			end
		end
	end // end of movement state table

	// draw states
	localparam 	S_CLEAROLD_START = 'd0,
				S_CLEAROLD_WAIT = 'd1,
				S_DRAWNEW_START = 'd2,
				S_DRAWNEW_WAIT = 'd3,
				S_CLEANSCREEN_START = 'd4,
				S_CLEANSCREEN_WAIT = 'd5;

	// Output logic aka all of our datapath control signals
	always@(*)
	begin
		x_dir <= current_move_state[1];
		y_dir <= current_move_state[0];
	end 

	always@(posedge clk)
	begin 
		if(!resetn) begin
			// reset to be unpaused, moving down right
			current_move_state = 2'b11;
		end
		else begin
			current_move_state = next_move_state;
		end
	end
endmodule



/*
STATUS:
mostly functional, minor bugs...
done signal from draw Clear is too soon, doesnt clear out the final pixel...
similarly, done signal from draw box is too soon, doesnt actually draw final pixel
*/
module datapath
#(
parameter 	SCREEN_X = 10'd640,
			SCREEN_Y = 9'd480,
			X_MAX = 'd640,
			Y_MAX = 'd480,
			X_BOXSIZE = 8'd4,	// Box X dimension
			Y_BOXSIZE = 7'd4,   // Box Y dimension
			FRAME_RATE = 15,
			RATE = 1
)
(
	input clk,
	input resetn,
	input [2:0] color,
	input enable,

	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// states
	input x_dir, 	//left = 0, right = 1
	input y_dir,	//up = 0, down = 1
	 
	// ball data
	output reg [($clog2(X_MAX)):0] ball_x,
	output reg [($clog2(Y_MAX)):0] ball_y,

	// VGA outputs
	output reg [($clog2(SCREEN_X)):0] render_x,
	output reg [($clog2(SCREEN_Y)):0] render_y,
	output reg [2:0] col_out,
	output reg rendered,
	output reg frameFinished
);
	
	// registers for clear box 
	wire [($clog2(SCREEN_X)):0] pt_clear_x;
	wire [($clog2(SCREEN_Y)):0] pt_clear_y;
		
	// registers for drawing new box
	wire [($clog2(SCREEN_X)):0] pt_draw_x;
	wire [($clog2(SCREEN_Y)):0] pt_draw_y;

	// auxillary signals
	wire doneClear; 
	wire doneDraw;
	reg startDraw;
	reg [($clog2(X_MAX)):0] old_x;
	reg [($clog2(Y_MAX)):0] old_y;

	// actually draw the ball on the updated position
	always@(posedge clk) begin   
		// Active Low Synchronous Reset
		if(!resetn) begin
			ball_x <= 'd0;
			ball_y <= 'd0;
			
			old_x <= 'd0;
			old_y <= 'd0;

			render_x <= 'd0;
			render_y <= 'd0;
			col_out <= 3'd0;
			
			rendered <= 0;
			frameFinished <= 0;
			startDraw <= 0;
			// clear and drawing counters reset in their modules
			/*
				make a new module of drawBox called clearScreen, with size of the entire screen
				make a separate if statement aside from !resetn for this clearSceen module
				while clearScreen's done signal is false, do not do anything else
				this means that until the screen has been cleared, will we actually start the normal behaviour
				for background image, just match the color of pixel (i, j) to match with the (i, j) pixel color of the image
					
			*/
			// ***need to clear out entire screen/old ball stuff first
		end
		else begin
			if(!enable) begin
				// dont move the ball
			end
			else begin
				// handle drawing the ball
				// on the start of a frame, draw it, and dont stop until it is done
				
				if(!doneClear) begin
					// currently clearing the ball!
					render_x <= pt_clear_x;
					render_y <= pt_clear_y;
					col_out <= 3'b000;

					rendered <= 0;
					frameFinished <= 0;
					// set up startDraw pulse
					startDraw <= 1;
				end
				else if (!doneDraw)begin
					// done clearing the ball, draw new ball
					render_x <= pt_draw_x;
					render_y <= pt_draw_y;
					col_out <= color;

					rendered <= 0;
					frameFinished <= 0;
					
					// finish and keep startDraw low to actually start the drawing
					startDraw <= (startDraw)?0:startDraw;
				end
				else if(rendered) begin
					// already done rendering for a clock tick... 
					rendered <= 1;
					frameFinished <= 0;
				end
				else begin
					// just finished rendering!
					rendered <= 1;
					frameFinished <= 1;
				end
				
				/* CODE USED FOR drawBox ONLY (without clearing)
				if (!doneDraw)begin
					// done clearing the ball, draw new ball
					render_x <= pt_draw_x;
					render_y <= pt_draw_y;
					col_out <= color;
					rendered <= 0;
				end
				else if(rendered) begin
					// already done rendering for a clock tick... 
					rendered <= 1;
					frameFinished <= 0;
				end
				else begin
					// just finished rendering!
					rendered <= 1;
					frameFinished <= 1;
				end*/

				// actually move the ball on a frame tick!
				//*** frameTick == 1 was used here before, need to test if new implementation works
				
				if(frameTick) begin
					old_x <= ball_x;
					old_y <= ball_y;
					ball_x <= (x_dir)?(ball_x + RATE):(ball_x - RATE);
					ball_y <= (y_dir)?(ball_y + RATE):(ball_y - RATE);
				end
			end
		end
	end
	
	drawBox #(
		SCREEN_X,
		SCREEN_Y,
		X_MAX,
		Y_MAX,
		X_BOXSIZE,
		Y_BOXSIZE
	) clearOld (
		clk,
		resetn,
		frameTick,
		
		old_x,	//(x_dir)?(ball_x - RATE):(ball_x + RATE), 	// flip signs since we want the prior point
		old_y,	//(y_dir)?(ball_y - RATE):(ball_y + RATE), 	// same here

		pt_clear_x,
		pt_clear_y,
		
		doneClear
	);


	// use startDraw pulse to kickstart the drawNew cycle
	drawBox #(
		SCREEN_X,
		SCREEN_Y,
		X_MAX,
		Y_MAX,
		X_BOXSIZE,
		Y_BOXSIZE
	) drawNew (
		clk,
		resetn,
		startDraw,

		ball_x,
		ball_y,

		pt_draw_x,
		pt_draw_y,
		doneDraw
	);
endmodule

/* 
Module to draw a box of n by m size,
Module should be kickstarted by a draw signal, and keep going until each point has been outputted once
when complete, continuously output a done signal
colour will be handled by the data path which uses this module
this only gives coordinates more compactly

*plan is to use two of these:
	one to erase the old box upon the frameTick signal
	another to draw the new box upon the done signal of the eraser

STATUS: seems complete
*** check if fin register is not needed...
*/
module drawBox 
#(
parameter 	SCREEN_X = 10'd640,
			SCREEN_Y = 9'd480,
			X_MAX = 'd640,
			Y_MAX = 'd480,
			X_BOXSIZE = 8'd4,	// Box X dimension
			Y_BOXSIZE = 7'd4   	// Box Y dimension
)
(
	input clk,
	input resetn,
	input start,

	input [($clog2(X_MAX)):0] x_orig,
	input [($clog2(Y_MAX)):0] y_orig,

	output reg [($clog2(SCREEN_X)):0] pt_x,
	output reg [($clog2(SCREEN_Y)):0] pt_y,

	output reg done
);

	reg [($clog2(X_BOXSIZE)):0] x_counter;
	reg [($clog2(Y_BOXSIZE)):0] y_counter;
	reg fin;

	always@(posedge clk)
	begin
		// reset counters and status
		if(!resetn)begin
			x_counter <= 0;
			y_counter <= 0;
			pt_x <= 0;
			pt_y <= 0;
			fin <= 1;
		end
		else begin
			if(start) begin
				// start counter
				pt_x <= x_orig;
				pt_y <= y_orig;
				//x_counter <= x_counter + 1;
				fin <= 0;
			end
			else if(!fin) begin
				if(y_counter == Y_BOXSIZE - 1 && x_counter == X_BOXSIZE - 1) begin
					// done counting the box, send pulse
					x_counter <= 0;
					y_counter <= 0;
					fin <= 1;
				end
				else if(x_counter < X_BOXSIZE - 1) begin
					// just count normally if we already started
					x_counter <= x_counter + 1;
					fin <= 0;
				end 
				else begin
					// completed row, go to new row and start on left
					x_counter <= 0;
					y_counter <= y_counter + 1;
					fin <= 0;
				end
				
			end
			pt_x <= x_orig + x_counter;
			pt_y <= y_orig + y_counter;
			done <= fin;
		end
	end
endmodule