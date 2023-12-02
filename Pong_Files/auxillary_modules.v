/*
=======================================================
*******************************************************
Auxillary Modules

scoreHandler - takes in score signals and keeps track of points!

signalToPulse - converts a long signal into a single pulse
	Inputs:
		clk
		resetn
		signal
	Outputs:
		pulse (lasts for 1 clock tick)

	
holdPulse - converts a short pulse into a long signal
	Parameters:
		CLOCK_FREQ
		HOLD_TIME (how long the pulse is held for)
	Inputs:
		clk
		pulse
		resetn
	Outputs:
		heldPulse

rateDivider:
	Parameters:
		CLK_FREQ
		FRAME_RATE (Frames per second)
	Inputs:
		clk
		resetn
		enable
	Outputs:
		reg pulse
		reg [$clog2(FRAME_RATE):0] frameCount

drawBox_signal
	Parameters:
		SCREEN_X
		SCREEN_Y
		X_MAX
		Y_MAX
		X_BOXSIZE
		Y_BOXSIZE
	Inputs:
		clk
		resetn
		enable
		[($clog2(X_MAX)):0] x_orig,
		[($clog2(Y_MAX)):0] y_orig,
	Outputs:
		reg [($clog2(SCREEN_X)):0] pt_x
		reg [($clog2(SCREEN_Y)):0] pt_y
		reg done

*** note, this seems to be a modified version of the flexible one above...
to be determined if this is needed, currently may be a band-aid fix...
drawBox_signal_paddle 
	Parameters:
		SCREEN_X = 10'd640,
		SCREEN_Y = 9'd480,
		X_SET = 'd10, 
		Y_MAX = 'd480,
		X_PADDLE_SIZE = 8'd5,	
		Y_PADDLE_SIZE = 7'd40,  
		FRAME_RATE = 15,
		RATE = 1
	Inputs:
		input clk,
		input resetn,
		input enable,

		input [($clog2(X_SET)):0] x_orig,
		input [($clog2(Y_MAX)):0] y_orig,
	Outputs:
		output reg [($clog2(SCREEN_X)):0] pt_x,
		output reg [($clog2(SCREEN_Y)):0] pt_y,
		output reg done
*******************************************************
=======================================================
*/


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

// converts a continous signal into a single pulse
// only fails when the signal happens to rise with the clock and fall before the next posedge
module signalToPulse
(
	input clk,
	input resetn,
	input signal,
	output pulse
);
	reg held;

	always@(posedge clk) begin
		if(!resetn) begin
			held <= 0;
		end
		else begin
			if(signal && !held) begin
				held <= 1;
			end
			else if(!signal) begin
				held <= 0;
			end
			// otherwise, keep holding to prevent pulse from coming out

		end
	end
	assign pulse = signal && !held;
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

module rateDivider
#(
	parameter 	CLK_FREQ = 50000000,
				FRAME_RATE = 60
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

// flexible version, used for the ball
module drawBox_signal
#(
	parameter 	SCREEN_X = 10'd640,
				SCREEN_Y = 9'd480,
				X_MAX = 10'd640,
				Y_MAX = 9'd480,
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

// used for the paddles*** should be replaced with flexible version...
module drawBox_signal_paddle
#(
	parameter 	SCREEN_X = 10'd640,
				SCREEN_Y = 9'd480,
				X_SET = 'd10, 
				Y_MAX = 'd480,
				X_PADDLE_SIZE = 8'd5,	
				Y_PADDLE_SIZE = 7'd40,  
				FRAME_RATE = 15,
				RATE = 1
)
(
	input clk,
	input resetn,
	input enable,

	input [($clog2(X_SET)):0] x_orig,
	input [($clog2(Y_MAX)):0] y_orig,

	output reg [($clog2(SCREEN_X)):0] pt_x,
	output reg [($clog2(SCREEN_Y)):0] pt_y,

	output reg done
);

	reg [($clog2(X_PADDLE_SIZE)):0] x_counter;
	reg [($clog2(Y_PADDLE_SIZE)):0] y_counter;

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

				if(y_counter == Y_PADDLE_SIZE - 1 && x_counter == X_PADDLE_SIZE - 1) begin
					// done counting the box, send pulse
					x_counter <= 'd0;
					y_counter <= 'd0;
					done <= 1;
				end
				else if(x_counter < X_PADDLE_SIZE - 1) begin
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

