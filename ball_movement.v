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
/*
*/
module ball_movement
(
	iColour, iResetn, iClock, iBlack, iEnable, 
	lhs_paddle_y, rhs_paddle_y,
	oX, oY, oColour, oPlot, 
	oBall_X, oBall_Y, lhs_score, rhs_score, boundaryHit
	);
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
		PADDLE_X = 'd4,
		PADDLE_Y = 'd15,
		PADDLE_OFFSET = 'd2,
		PADDLE_MAX_Y = Y_SCREEN_PIXELS - 1 - PADDLE_Y,

		X_MAX = X_SCREEN_PIXELS - 1 - X_BOXSIZE - PADDLE_X - PADDLE_OFFSET, // 0-based and account for box width
		Y_MAX = Y_SCREEN_PIXELS - 1 - Y_BOXSIZE,

    	FRAMES_PER_UPDATE = 'd15,
    	PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60,
		RATE = 'd1,
		MAX_RATE = 'd5,
		TIME_TILL_ACCEL = 'd2;
		
	//
	// Your code goes here
	//
	wire[($clog2(X_MAX)):0] ball_x;
	wire[($clog2(Y_MAX)):0] ball_y;

	wire[($clog2(X_MAX)):0] old_x;
	wire[($clog2(Y_MAX)):0] old_y;

	wire[($clog2(FRAMES_PER_UPDATE)):0] frameCount;
	wire frameTick;

	wire x_dir, y_dir;
	wire rendered;
	
	wire clearOld_pulse, drawNew_pulse, cleanScreen_pulse;
	wire done_clearOld, done_drawNew, done_cleanScreen;
	wire [($clog2(MAX_RATE)):0]	actual_rate;

	rateDivider #(CLOCKS_PER_SECOND, 
				FRAMES_PER_UPDATE) 
				rateDiv (iClock, iResetn, iEnable, frameTick, frameCount);

	control #(RATE, X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MAX, X_BOXSIZE, Y_BOXSIZE, MAX_RATE,
				PADDLE_X, PADDLE_Y, PADDLE_OFFSET, PADDLE_MAX_Y) 
			c0 
			(iClock, iResetn, iEnable, iBlack, frameTick,
			done_clearOld, done_drawNew, done_cleanScreen,
			ball_x, ball_y, actual_rate,
			lhs_paddle_y, rhs_paddle_y,
			x_dir, y_dir,
			clearOld_pulse, drawNew_pulse, cleanScreen_pulse,
			lhs_score, rhs_score, boundaryHit);

	/*datapath #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MAX,
				X_BOXSIZE, Y_BOXSIZE, 
				FRAMES_PER_UPDATE, RATE, MAX_RATE)
			d0
			(iClock, iResetn, iColour, iEnable,
			frameTick, frameCount,
			x_dir, y_dir, 
			clearOld_pulse, drawNew_pulse, cleanScreen_pulse,
			done_clearOld, done_drawNew, done_cleanScreen,
			ball_x, ball_y, actual_rate,
			oX, oY, oColour, rendered);
	*/

	ball_physics #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MAX,
				X_BOXSIZE, Y_BOXSIZE, 
				FRAMES_PER_UPDATE, RATE, MAX_RATE)
				ball_phys1
				(iClock, iResetn, iEnable, // testing unique reset method based on scoring***
				frameTick, frameCount,
				x_dir, y_dir, cleanScreen_pulse,
				ball_x, ball_y,
				old_x, old_y,
				actual_rate);

	ball_render #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MAX,
				X_BOXSIZE, Y_BOXSIZE, 
				FRAMES_PER_UPDATE, RATE, MAX_RATE)
				ball_rend1
				(iClock, iResetn, iColour, iEnable, //testing unique reset method***
				frameTick, frameCount,
				ball_x, ball_y, old_x, old_y,
				clearOld_pulse, drawNew_pulse, cleanScreen_pulse,
				done_clearOld, done_drawNew, done_cleanScreen,
				oX, oY, oColour, rendered);

	assign oPlot = !rendered;
	assign oBall_X = ball_x;
	assign oBall_Y = ball_y;

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


module control
#(
	parameter 	RATE = 1,
				SCREEN_X = 'd640,
				SCREEN_Y = 'd480,
				X_MAX = 'd640,
				Y_MAX = 'd480,
				X_BOXSIZE = 8'd4,	// Box X dimension
				Y_BOXSIZE = 7'd4,  	// Box Y dimension
				MAX_RATE = 'd15,

				PADDLE_X = 'd4,
				PADDLE_Y = 'd15,
				PADDLE_OFFSET = 'd2,
				PADDLE_MAX_Y = 'd480

)
(
	input clk,
	input resetn,
	input enable,
	input blackScreen,
	input frameTick,

	input done_clearOld,
	input done_drawNew,
	input done_blackScreen,

	input[($clog2(X_MAX)):0] x_pos,
	input[($clog2(Y_MAX)):0] y_pos,
	input[($clog2(MAX_RATE)):0]	actual_rate,

	input[($clog2(PADDLE_MAX_Y)):0] left_paddle_pos_y,
	input[($clog2(PADDLE_MAX_Y)):0] right_paddle_pos_y,

	output reg x_dir,
	output reg y_dir,

	output reg clearOld_pulse,
	output reg drawNew_pulse,
	output reg blackScreen_pulse,
	
	output reg lhs_scored,
	output reg rhs_scored,
	output reg boundary_contact
);
	// bit 1 is X direction, bit 2 is Y direction
	reg[1:0] current_move_state, next_move_state;

	// score registers (0 = nothing, 1 = left scored, 2 = right scored, 4 = vert bound hit)
	reg[1:0] current_score_state, next_score_state;

	// movement state variable declarations
	localparam  S_LEFT   = 1'b0,
				S_RIGHT   	= 1'b1,
				S_UP        = 1'b0,
				S_DOWN   	= 1'b1;

	localparam 	X_MIN = 1 + PADDLE_X + PADDLE_OFFSET,
				Y_MIN = 1;
	
	localparam 	S_PLAY = 2'd0,
				S_LEFT_SCORED = 2'd1,
				S_RIGHT_SCORED = 2'd2,
				S_BOUND_HIT = 2'd3;

	wire leftHit, rightHit;
	wire scored = lhs_scored||rhs_scored; // used for draw state table
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
			/*
			*** IMPLEMENT PADDLE WIDTH INTO LEFT AND RIGHT BOUNDS (X_MAX )
			CHECK BOT X/TOP X coordinate depending on which bound we are approaching
			based on the coordinate of the paddle, and its width, check if we will hit the paddle
			if it does, fire the score signal, based on which side it went in
			*/

			// NOTE: DO VERT CHECKS FIRST SO SCORE STATES ARE NOT OVERWRITTEN

			// VERTICAL BOUNDARY HANDLING
			if(current_move_state[0] == S_DOWN) begin
				// going down
				if(y_pos > Y_MAX - actual_rate) begin
					// if we go more down, we will hit the wall
					next_move_state[0] <= S_UP;
					next_score_state <= S_BOUND_HIT;
				end
				else begin
					next_move_state[0] <= S_DOWN;
					// DO NOT OVERWRITE IF A SCORE HAS OCCURED!
					next_score_state <= S_PLAY;
				end
			end	
			else begin
				// must be going upward
				if(y_pos < Y_MIN + actual_rate) begin
					// if we go more down, we will hit the wall
					next_move_state[0] <= S_DOWN;
					next_score_state <= S_BOUND_HIT;
				end
				else begin
					next_move_state[0] <= S_UP;
					// DO NOT OVERWRITE IF A SCORE HAS OCCURED!
					next_score_state <= S_PLAY;
				end
			end
			
			// HORIZONTAL BOUNDARY HANDLING
			// check if a score occured, and who did it
			if(current_score_state == S_LEFT_SCORED) begin
				// left player got a goal, move to right at new round
				next_move_state[1] <= S_LEFT;
				// if we are still in the net, keep score signal on
				next_score_state <= (x_pos > X_MAX - actual_rate)?S_LEFT_SCORED:S_PLAY;
			end
			else if(current_score_state == S_RIGHT_SCORED) begin
				// right player got a goal, move to left at new round
				next_move_state[1] <= S_RIGHT;
				// if we are still in the net, keep score signal on
				next_score_state <= (x_pos < X_MIN + actual_rate)?S_RIGHT_SCORED:S_PLAY;
			end
			// no score occured, do normal checks
			else begin
				if(current_move_state[1] == S_LEFT) begin
					// going left
					if(x_pos < X_MIN + actual_rate) begin
						// if we go more left, we will hit the wall. DO PADDLE CHECK***
						next_move_state[1] <= S_RIGHT;
						if(leftHit) begin
							// hit paddle
							next_score_state <= S_BOUND_HIT;
						end
						else begin
							// no hit, right player scored
							next_score_state <= S_RIGHT_SCORED;
						end
					end
					else begin 
						next_move_state[1] <= S_LEFT;
						// if no event occurs, keep doing no event. otherwise, keep the event
					end
				end
				else begin
					// must be going right
					if(x_pos > X_MAX - actual_rate) begin
						// if we go more right, we will hit the wall. DO PADDLE CHECK***
						next_move_state[1] <= S_LEFT;
						if(rightHit) begin
							// paddle hit
							next_score_state <= S_BOUND_HIT;
						end
						else begin
							// no hit, left player scored
							next_score_state <= S_LEFT_SCORED;
						end
					end
					// no bound needed
					else begin
						next_move_state[1] <= S_RIGHT;
						// if no event occurs, keep doing no event. otherwise, keep the event
					end 
				end
			end
			
		end
	end // end of movement state table

	reg[2:0] current_draw_state, next_draw_state;

	// draw states
	localparam 	S_WAIT = 3'd0,
				S_CLEAROLD_START = 3'd1,
				S_CLEAROLD_WAIT = 3'd2,
				S_DRAWNEW_START = 3'd3,
				S_DRAWNEW_WAIT = 3'd4,
				S_BLACKSCREEN_START = 3'd5,
				S_BLACKSCREEN_WAIT = 3'd6;

	// draw state table
	// *** implement STATES when SCORE occurs!!!
	always@(*)
	begin 
		if(!enable) begin
			// do nothing with states...
		end
		else begin
			case(current_draw_state)
				S_WAIT:begin
					// wait for frame tick to occur
					if(blackScreen || scored) next_draw_state <= S_BLACKSCREEN_START;
					else next_draw_state <= (frameTick)?S_CLEAROLD_START:S_WAIT;
				end
				S_CLEAROLD_START: begin
					// set up pulse to kickstart clear old module
					if(blackScreen || scored) next_draw_state <= S_BLACKSCREEN_START;
					// if the frame has ticked, start clearing, otherwise wait...
					else next_draw_state <= S_CLEAROLD_WAIT;
				end
				S_CLEAROLD_WAIT: begin
					// set the pulse to 0, and only go next when the done signal is given
					if(blackScreen || scored) next_draw_state <= S_BLACKSCREEN_START;
					// while clearing, keep clearing until it is done
					else next_draw_state <= (done_clearOld)?S_DRAWNEW_START:S_CLEAROLD_WAIT;
				end

				S_DRAWNEW_START: begin
					// set up pulse to kickstart the draw new module
					if(blackScreen || scored) next_draw_state <= S_BLACKSCREEN_START;
					// start drawing asap
					else next_draw_state <= S_DRAWNEW_WAIT;
				end

				S_DRAWNEW_WAIT: begin
					// set the pulse to 0, and only go next when the done signal is given
					if(blackScreen || scored) next_draw_state <= S_BLACKSCREEN_START;
					// keep drawing until it is done. if it is done, go back to waiting till next frame and clear old
					else next_draw_state <= (done_drawNew)?S_WAIT:S_DRAWNEW_WAIT;
				end

				S_BLACKSCREEN_START: begin
					// set pulse to 0
					next_draw_state <= S_BLACKSCREEN_WAIT;
				end

				S_BLACKSCREEN_WAIT: begin
					// clear screen until it is done
					// once it is done, go to normal behaviour!
					/*
					d, r, behaviour
					0, 0, shouldnt occur... if it does, reset takes prio, stay here
					0, 1, drawing, stay here
					1, 0, resetting, stay here
					1, 1, done drawing, go next
					*/
					next_draw_state <= (done_blackScreen&&resetn)?S_WAIT:S_BLACKSCREEN_WAIT;
				end

			endcase
		end
	end // end of drawing state table

	// Output logic aka all of our datapath control signals
	always@(*)
	begin
		//
		x_dir <= current_move_state[1];
		y_dir <= current_move_state[0];	

		// draw stuff	
		drawNew_pulse <= 0;
		clearOld_pulse <= 0;
		blackScreen_pulse <= 0;

		case(current_draw_state)
			S_CLEAROLD_START: begin
			end

			S_CLEAROLD_WAIT: begin
				// hold enable
				clearOld_pulse <= 1;
			end

			S_DRAWNEW_START: begin
			end

			S_DRAWNEW_WAIT: begin
				// hold enable
				drawNew_pulse <= 1;
			end

			S_BLACKSCREEN_START: begin
			end

			S_BLACKSCREEN_WAIT: begin
				// hold enable
				blackScreen_pulse <= 1;
			end
		endcase

		// score stuff
		lhs_scored <= 0;
		rhs_scored <= 0;
		boundary_contact <= 0;
		case(current_score_state)
			S_PLAY: begin
				// no change
			end

			S_LEFT_SCORED: begin
				lhs_scored <= 1;
			end

			S_RIGHT_SCORED: begin
				rhs_scored <= 1;
			end

			S_BOUND_HIT: begin
				boundary_contact <= 1;
			end
		endcase
	end 


	// set state registers to next state
	always@(posedge clk)
	begin 
		if(!resetn) begin
			// reset to be unpaused, moving down right
			current_move_state <= 2'b11;
			current_draw_state <= S_BLACKSCREEN_START; //*** testing clear screen upon reset first!
			current_score_state <= S_PLAY;
		end
		else begin
			current_move_state <= next_move_state;
			current_draw_state <= next_draw_state;
			current_score_state <= next_score_state;
		end
	end


	// instantiate hitbox modules
	hitDetect 	#(Y_BOXSIZE, Y_MAX,
				PADDLE_Y, PADDLE_MAX_Y)
		left_bound
				(y_pos, left_paddle_pos_y, leftHit);

	hitDetect 	#(Y_BOXSIZE, Y_MAX,
				PADDLE_Y, PADDLE_MAX_Y)
		right_bound
				(y_pos, right_paddle_pos_y, rightHit);

endmodule

/*
using the ball position and height, check if the top most Y and bottom most Y are in the range of the paddle Y

*/
module hitDetect
#(
parameter 	Y_BOXSIZE = 7'd4,   // Box Y dimension
			Y_MAX = 'd480,
			PADDLE_Y = 'd15, 	// Paddle Y dimension
			PADDLE_MAX_Y = 'd480

)
(
	input [($clog2(Y_MAX)):0] ball_y,
	input [($clog2(PADDLE_MAX_Y)):0] paddle_y,
	output contact
);
	wire topCheck = (ball_y < (paddle_y + PADDLE_Y)); // top of ball is above bottom of paddle
	wire botCheck = ((ball_y) > paddle_y - Y_BOXSIZE); // bottom of ball is below top of paddle
	assign contact = (topCheck || botCheck);
endmodule

module ball_physics
#(
parameter 	SCREEN_X = 10'd640,
			SCREEN_Y = 9'd480,
			X_MAX = 'd640,
			Y_MAX = 'd480,
			X_BOXSIZE = 8'd4,	// Box X dimension
			Y_BOXSIZE = 7'd4,   // Box Y dimension
			FRAME_RATE = 15,
			RATE = 1,
			MAX_RATE = 15,
			TIME_TILL_ACCEL = 'd2,
			PADDLE_WIDTH = 'd4,
			PADDLE_HEIGHT = 'd15,
			PADDLE_OFFSET = 'd2	
)
(
	input clk,
	input resetn,
	input enable,
	
	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// move states
	input x_dir, 	//left = 0, right = 1
	input y_dir,	//up = 0, down = 1
	
	input blackScreen_pulse,

	// ball data
	output reg [($clog2(X_MAX)):0] ball_x,
	output reg [($clog2(Y_MAX)):0] ball_y,

	output reg [($clog2(X_MAX)):0] old_x,
	output reg [($clog2(Y_MAX)):0] old_y,

	output reg [($clog2(MAX_RATE)):0] actual_rate
);
	localparam 	resetPos_X = SCREEN_X/2,
				resetPos_Y = SCREEN_Y/2;

	// use this secondCounter to increase rate
	// after x seconds, increase rate!
	reg[($clog2(TIME_TILL_ACCEL)):0] secondCounter;

	// actually draw the ball on the updated position
	always@(posedge clk) begin   
		// Active Low Synchronous Reset
		if(!resetn) begin
			old_x <= ball_x;
			old_y <= ball_y;
			ball_x <= resetPos_X;
			ball_y <= resetPos_Y;
		end
		else begin
			if(!enable) begin
				// dont move the ball
			end
			else begin
				// actually move the ball on a frame tick!
				//*** frameTick == 1 was used here before, need to test if new implementation works
				if(frameTick) begin
					old_x <= ball_x;
					old_y <= ball_y;
					if(blackScreen_pulse) begin
						// reset ball position upon black screening
						ball_x <= resetPos_X;
						ball_y <= resetPos_Y;
					end
					else begin
						// otherwise, just update the ball!
						ball_x <= (x_dir)?(ball_x + actual_rate):(ball_x - actual_rate);
						ball_y <= (y_dir)?(ball_y + actual_rate):(ball_y - actual_rate);
					end
				end
			end
		end
	end

	// increase speed of the ball
	always@(posedge clk) begin // must be on clock edge... figure out a way such that it only occurs when it has JUST become frameCount == frame_rate, rather than occuring every clock tick whilst frameCount == frame_rate
		if(!resetn) begin
			secondCounter <= 0;
			actual_rate <= RATE;
		end
		else begin
			if(blackScreen_pulse) begin
				// reset upon screen clear as well!
				actual_rate <= RATE;
				secondCounter <= 0;
			end
			if(secondCounter == TIME_TILL_ACCEL && frameTick) begin
				// if the specified time till acceleration has passed, increase the rate of movement!
				actual_rate <= (actual_rate < MAX_RATE)?actual_rate + 1:MAX_RATE;
				secondCounter <= 0;
			end
			else if(frameCount == FRAME_RATE && frameTick) begin
				// just increase the second counter
				secondCounter <= secondCounter + 1;
			end
		end
	end
endmodule

module ball_render
#(
parameter 	SCREEN_X = 10'd640,
			SCREEN_Y = 9'd480,
			X_MAX = 'd640,
			Y_MAX = 'd480,
			X_BOXSIZE = 8'd4,	// Box X dimension
			Y_BOXSIZE = 7'd4,   // Box Y dimension
			FRAME_RATE = 15,
			RATE = 1,
			MAX_RATE = 15
)
(
	input clk,
	input resetn,
	input [2:0] color,
	input enable,
	
	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// need old and new ball positions
	input [($clog2(X_MAX)):0] ball_x,
	input [($clog2(Y_MAX)):0] ball_y,

	input [($clog2(X_MAX)):0] old_x,
	input [($clog2(Y_MAX)):0] old_y,
	
	// draw states and pulses
	input clearOld_pulse,
	input drawNew_pulse,
	input blackScreen_pulse,

	output done_clearOld,
	output done_drawNew,
	output done_blackScreen,
	
	// VGA outputs
	output reg [($clog2(SCREEN_X)):0] render_x,
	output reg [($clog2(SCREEN_Y)):0] render_y,
	output reg [2:0] col_out,
	output reg rendered
);

	// auxilary wires/signals
	// registers for clear box 
	wire [($clog2(SCREEN_X)):0] pt_clear_x;
	wire [($clog2(SCREEN_Y)):0] pt_clear_y;
		
	// registers for drawing new box
	wire [($clog2(SCREEN_X)):0] pt_draw_x;
	wire [($clog2(SCREEN_Y)):0] pt_draw_y;

	// registers for cleaning the screen
	wire [($clog2(SCREEN_X)):0] blk_x;
	wire [($clog2(SCREEN_Y)):0] blk_y;

	always@(posedge clk) begin   
		// Active Low Synchronous Reset
		if(!resetn) begin
			render_x <= blk_x;
			render_y <= blk_y;
			col_out <= 3'd0;
			
			rendered <= 0;
			// clear and drawing counters reset in their modules
		end
		else begin
			if(!enable) begin
				// dont move the ball
			end
			else begin
				// handle drawing the ball
				// on the start of a frame, draw it, and dont stop until it is done
				
				// need to determine which points are outputted to be rendered!
				if(clearOld_pulse) begin
					// output the clearOld points
					render_x <= pt_clear_x;
					render_y <= pt_clear_y;
					col_out <= 3'b000;
					rendered <= 0;
				end
				else if(drawNew_pulse) begin
					// output the drawNew points
					render_x <= pt_draw_x;
					render_y <= pt_draw_y;
					col_out <= color;
					rendered <= 0;
				end
				else if(blackScreen_pulse) begin
					// has to be outputting the clean screen points
					render_x <= blk_x;
					render_y <= blk_y;
					col_out <= 3'b000;
					rendered <= 0;
				end
				else begin
					// DONE RENDERING!!!
					render_x <= 'd0;
					render_y <= 'd0;
					col_out <= 3'b000;	
					rendered <= 1;
				end
			end
		end
	end

	// instantiate drawing modules
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_MAX,
		Y_MAX,
		X_BOXSIZE,
		Y_BOXSIZE
	) clearOld (
		clk,
		resetn,
		clearOld_pulse,
		
		old_x,	//(x_dir)?(ball_x - RATE):(ball_x + RATE), 	// flip signs since we want the prior point
		old_y,	//(y_dir)?(ball_y - RATE):(ball_y + RATE), 	// same here

		pt_clear_x,
		pt_clear_y,
		
		done_clearOld
	);

	// use startDraw pulse to kickstart the drawNew cycle
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_MAX,
		Y_MAX,
		X_BOXSIZE,
		Y_BOXSIZE
	) drawNew (
		clk,
		resetn,
		done_clearOld||drawNew_pulse,

		ball_x,
		ball_y,

		pt_draw_x,
		pt_draw_y,
		done_drawNew
	);

	wire blk_complete;

	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_MAX,
		Y_MAX,
		SCREEN_X, // our "box" is the screen!
		SCREEN_Y
	) black_screen (
		clk,
		resetn,
		blackScreen_pulse,
		
		'd0, // set coordinates to be the top left most pixel to clear full screen
		'd0,	

		blk_x,
		blk_y,
		
		blk_complete
	);
	// while reset is low, pass to control that we are NOT done clearing
	// if its high, normal stuff
	assign done_blackScreen = (resetn)?blk_complete:0;
endmodule

module drawBox_signal
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
	input enable,

	input [($clog2(X_MAX)):0] x_orig,
	input [($clog2(Y_MAX)):0] y_orig,

	output reg [($clog2(SCREEN_X)):0] pt_x,
	output reg [($clog2(SCREEN_Y)):0] pt_y,

	output reg done
);

	reg [($clog2(X_BOXSIZE)):0] x_counter;
	reg [($clog2(Y_BOXSIZE)):0] y_counter;

	always@(posedge clk)
	begin
		// reset counters and status
		if(!resetn)begin
			x_counter <= 0;
			y_counter <= 0;
			pt_x <= x_orig;
			pt_y <= y_orig;
			done <= 1;
		end
		else begin
			if(enable) begin
				// whilst enabled...
				pt_x <= x_orig + x_counter;
				pt_y <= y_orig + y_counter;

				if(y_counter == Y_BOXSIZE - 1 && x_counter == X_BOXSIZE - 1) begin
					// done counting the box, send pulse
					x_counter <= 'd0;
					y_counter <= 'd0;
					done <= 1;
				end
				else if(x_counter < X_BOXSIZE - 1) begin
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

