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

module paddle(iResetn, iClock, 
	iUp, iDown, 
	iUp2, iDown2, 
	oX, oY, oColour, oPlot);
	
	input wire 	    	iResetn;
	input wire 	    	iClock;
	
	input wire 		iUp;
	input wire		iDown;
	input wire 		iUp2;
	input wire		iDown2;

	output wire [($clog2(X_SCREEN_PIXELS)):0] oX;         // VGA pixel coordinates
	output wire [($clog2(Y_SCREEN_PIXELS)):0] oY;


	output wire [2:0] 	oColour;     // VGA pixel colour (0-7)

	output wire 	     	oPlot;       // Pixel drawn enable

   	parameter 
		X_PADDLE_SIZE = 8'd5,   // Paddle X dimension
		Y_PADDLE_SIZE = 7'd40,   // Paddle Y dimension
		X_SCREEN_PIXELS = 10'd320,  // X screen width for starting resolution and fake_fpga (was 9*)
		Y_SCREEN_PIXELS = 9'd240,  // Y screen height for starting resolution and fake_fpga (was 7*)
		CLOCKS_PER_SECOND = 50000000, // 50 MHZ for fake_fpga (was 5KHz*)
		X_SET = X_SCREEN_PIXELS/32,
		X_SET2 = X_SCREEN_PIXELS - X_PADDLE_SIZE,
		Y_MAX = Y_SCREEN_PIXELS - 1 - Y_PADDLE_SIZE,

    	FRAMES_PER_UPDATE = 'd15,
    	PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60,
		RATE = 'd1;


	wire frameTick;
	wire[($clog2(X_SCREEN_PIXELS)):0] paddle_x;
	wire[($clog2(Y_MAX)):0] paddle_y;
	wire[($clog2(X_SCREEN_PIXELS)):0] paddle_x2;
	wire[($clog2(Y_MAX)):0] paddle_y2;

	wire[($clog2(X_SCREEN_PIXELS)):0] old_paddle_x;
	wire[($clog2(Y_MAX)):0] old_paddle_y;
	wire[($clog2(X_SCREEN_PIXELS)):0] old_paddle_x2;
	wire[($clog2(Y_MAX)):0] old_paddle_y2;

	wire[($clog2(FRAMES_PER_UPDATE)):0] frameCount;
	wire [1:0] y_dir;
	wire [1:0] y_dir2;
	wire rendered;

	rateDivider #(CLOCKS_PER_SECOND, 
		FRAMES_PER_UPDATE) 
		rateDiv (iClock, iResetn, 1'b1, frameTick, frameCount);


	wire done_clear1, done_draw1, done_clear2, done_draw2;
	wire pulse_clear1, pulse_draw1, pulse_clear2, pulse_draw2;

				
	//Paddle 1	
	control_paddle_move #(RATE, X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_SET, Y_MAX, X_PADDLE_SIZE, Y_PADDLE_SIZE) 
			c0 
			(iClock, iResetn, 1'b1,
			paddle_x, paddle_y,
			iUp, iDown, y_dir);

	//Paddle 2
	control_paddle_move #(RATE, X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_SET, Y_MAX, X_PADDLE_SIZE, Y_PADDLE_SIZE) 
			c1 
			(iClock, iResetn, 1'b1,
			paddle_x2, paddle_y2,
			iUp2, iDown2, y_dir2);

	//Draw State
	renderControl_paddle #(RATE, X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_SET2, Y_MAX, X_PADDLE_SIZE, Y_PADDLE_SIZE) 
			r1 
			(iClock, iResetn, 1'b1, frameTick,
			done_clear1, done_draw1, done_clear2, 
			done_draw2, pulse_clear1, pulse_draw1, 
			pulse_clear2, pulse_draw2);


	//Updates Location
	paddle_physics #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
			X_SET, X_SET2, Y_MAX,
			X_PADDLE_SIZE, Y_PADDLE_SIZE, 
			FRAMES_PER_UPDATE, RATE)
			
			p1
			(iClock, iResetn, 1'b1,
			frameTick, frameCount, y_dir, y_dir2,
			paddle_x, paddle_y, paddle_x2, paddle_y2,
			old_paddle_x, old_paddle_y, old_paddle_x2, old_paddle_y2);


	//Draws Paddles
	paddle_render #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
			X_SET, X_SET2, Y_MAX,
			X_PADDLE_SIZE, Y_PADDLE_SIZE, 
			FRAMES_PER_UPDATE, RATE)
			
			pr1
			(iClock, iResetn, 1'b1,
			frameTick, frameCount, paddle_x, paddle_y, paddle_x2,
			paddle_y2, old_paddle_x, old_paddle_y, old_paddle_x2,
			old_paddle_y2, pulse_clear1, pulse_draw1, pulse_clear2, 
			pulse_draw2, done_clear1, done_draw1, done_clear2, 
			done_draw2, oX, oY, oColour, rendered);

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


module control_paddle_move
#(
	parameter 	RATE = 1,
				SCREEN_X = 'd640,
				SCREEN_Y = 'd480,
				X_SET = 'd10,
				Y_MAX = 'd480,
				X_PADDLE_SIZE = 8'd5,   // Paddle X dimension
				Y_PADDLE_SIZE = 7'd40

)
(
	input clk,
	input resetn,
	input enable,
	
	input[($clog2(Y_MAX)):0] x_pos,
	input[($clog2(Y_MAX)):0] y_pos,

	input up, down,
	output reg [1:0] y_dir
);
	// bit 1 is X direction, bit 2 is Y direction
	reg[1:0] current_state, next_state;

		// state variable declarations
	localparam  S_STATIONARY   = 2'b00,
		    S_UP   	   = 2'b01,
		    S_DOWN   	   = 2'b10;

	
	always@(*)
	begin 
		if(!enable) begin
			// do nothing with states...
		end
		else begin

			// STATIONARY PADDLE 
			if(current_state == S_STATIONARY) begin
				if(up && !down && y_pos > RATE) next_state <= S_UP;
				else if(!up && down && y_pos < Y_MAX - RATE) next_state <= S_DOWN;
				else next_state <= S_STATIONARY;
			end

			// VERTICAL DOWN BOUNDARY HANDLING
			else if(current_state == S_DOWN) begin
				if(y_pos > Y_MAX - RATE) next_state <= (up)?S_UP:S_STATIONARY;
				else  if(down && !up)next_state <= S_DOWN;
				else  if(!down && up)next_state <= S_UP;
				else next_state <= S_STATIONARY;
			end

			// VERTICAL UP BOUNDARY HANDLING
			else if(current_state == S_UP) begin
				if( y_pos < RATE ) next_state <= (down)?S_DOWN:S_STATIONARY;
				else  if(down && !up) next_state <= S_DOWN;
				else  if(!down && up)next_state <= S_UP;
				else next_state <= S_STATIONARY;
			end		
			
			else next_state <= S_STATIONARY;

		end
	end // state_table for movement

	always@(*)
	begin
		y_dir <= current_state;
	end 

	always@(posedge clk)
	begin 
		if(!resetn) begin
			current_state = 2'b00;
		end
		else begin
			current_state = next_state;
		end
	end
endmodule


module renderControl_paddle
#(
	parameter 	RATE = 1,
				SCREEN_X = 'd640,
				SCREEN_Y = 'd480,
				X_SET = 'd10,
				Y_MAX = 'd480,
				X_PADDLE_SIZE = 8'd5,   // Paddle X dimension
				Y_PADDLE_SIZE = 7'd40

)
(
	input clk,
	input resetn,
	input enable,
	input frameTick,

	input done_clearOld1,
	input done_drawNew1,
	input done_clearOld2,
	input done_drawNew2,
	
	output reg clearOld1_pulse,
	output reg drawNew1_pulse,
	output reg clearOld2_pulse,
	output reg drawNew2_pulse
);
	
reg[3:0] current_draw_state, next_draw_state;

	localparam 	S_WAIT = 4'd0,
				S_CLEAROLD_PADDLE1 = 4'd1,
				S_CLEAROLD_PADDLE1_WAIT = 4'd2,
				S_DRAWNEW_PADDLE1 = 4'd3,
				S_DRAWNEW_PADDLE1_WAIT = 4'd4,
				S_CLEAROLD_PADDLE2 = 4'd5,
				S_CLEAROLD_PADDLE2_WAIT = 4'd6,
				S_DRAWNEW_PADDLE2 = 4'd7,
				S_DRAWNEW_PADDLE2_WAIT = 4'd8;

	always@(*)
	begin 
		if(!enable) begin
			// do nothing with states...
		end
		else begin
			case(current_draw_state)
				S_WAIT:begin
					next_draw_state <= (frameTick)?S_CLEAROLD_PADDLE1:S_WAIT;
				end

				//Paddle 1
				S_CLEAROLD_PADDLE1: begin
					next_draw_state <= S_CLEAROLD_PADDLE1_WAIT;
				end
				S_CLEAROLD_PADDLE1_WAIT: begin
					next_draw_state <= (done_clearOld1)?S_DRAWNEW_PADDLE1:S_CLEAROLD_PADDLE1_WAIT;
				end
				S_DRAWNEW_PADDLE1: begin
					next_draw_state <= S_DRAWNEW_PADDLE1_WAIT;
				end
				S_DRAWNEW_PADDLE1_WAIT: begin
					next_draw_state <= (done_drawNew1)?S_CLEAROLD_PADDLE2:S_DRAWNEW_PADDLE1_WAIT;
				end

				//Paddle 2
				S_CLEAROLD_PADDLE2: begin
					next_draw_state <= S_CLEAROLD_PADDLE2_WAIT;
				end
				S_CLEAROLD_PADDLE2_WAIT: begin
					next_draw_state <= (done_clearOld2)?S_DRAWNEW_PADDLE2:S_CLEAROLD_PADDLE2_WAIT;
				end
				S_DRAWNEW_PADDLE2: begin
					next_draw_state <= S_DRAWNEW_PADDLE2_WAIT;
				end
				S_DRAWNEW_PADDLE2_WAIT: begin
					next_draw_state <= (done_drawNew2)?S_WAIT:S_DRAWNEW_PADDLE2_WAIT;
				end

			endcase
		end
	end 

// Output logic aka all of our datapath control signals
	always@(*)
	begin

		drawNew1_pulse <= 0;
		clearOld1_pulse <= 0;
		drawNew2_pulse <= 0;
		clearOld2_pulse <= 0;

		case(current_draw_state)

			//Paddle 1
			S_CLEAROLD_PADDLE1_WAIT: begin
				clearOld1_pulse <= 1'b1;
			end
			S_DRAWNEW_PADDLE1_WAIT: begin
				drawNew1_pulse <= 1'b1;
			end
			//Paddle 2
			S_CLEAROLD_PADDLE2_WAIT: begin
				clearOld2_pulse <= 1'b1;
			end
			S_DRAWNEW_PADDLE2_WAIT: begin
				drawNew2_pulse <= 1'b1;
			end

		endcase
	end

	always@(posedge clk)
	begin 
		if(!resetn) begin
			current_draw_state <= S_WAIT;
		end
		else begin
			current_draw_state <= next_draw_state;
		end
	end

endmodule


// ======================================






/*
STATUS:
mostly functional, minor bugs...
done signal from draw Clear is too soon, doesnt clear out the final pixel...
similarly, done signal from draw box is too soon, doesnt actually draw final pixel
*/
module paddle_physics
#(
parameter 	SCREEN_X = 10'd640,
		SCREEN_Y = 9'd480,
		X_SET = 'd10,
		X_SET2 = 'd625,
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

	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// states
	input [1:0] y_dir,	//stationary = 0, up = 1, down = 2
	input [1:0] y_dir2,	
	 
	// paddle data
	output reg [($clog2(SCREEN_X)):0] paddle_x,
	output reg [($clog2(Y_MAX)):0] paddle_y,
	output reg [($clog2(SCREEN_X)):0] paddle_x2,
	output reg [($clog2(Y_MAX)):0] paddle_y2,

	output reg [($clog2(SCREEN_X)):0] old_paddle_x,
	output reg [($clog2(Y_MAX)):0] old_paddle_y,
	output reg [($clog2(SCREEN_X)):0] old_paddle_x2,
	output reg [($clog2(Y_MAX)):0] old_paddle_y2
);
	
	always@(posedge clk) begin 
  
		if(!resetn) begin	
			old_paddle_x <= paddle_x;
			old_paddle_y <= paddle_y;
			old_paddle_x2 <= paddle_x2;
			old_paddle_y2 <= paddle_y2;

			paddle_x <= X_SET;
			paddle_y <= SCREEN_Y/2;
			paddle_x2 <= X_SET2;
			paddle_y2 <= SCREEN_Y/2;

		end
		else begin
			if(!enable) begin
				// do nothing
			end
			else begin			
				if(frameTick) begin

					old_paddle_x <= paddle_x;
					old_paddle_y <= paddle_y;
					old_paddle_x2 <= paddle_x2;
					old_paddle_y2 <= paddle_y2;

					if(y_dir == 2'b01) paddle_y <= (paddle_y - RATE);
					else if(y_dir == 2'b10) paddle_y <= (paddle_y + RATE);

					if(y_dir2 == 2'b01) paddle_y2 <= (paddle_y2 - RATE);
					else if(y_dir2 == 2'b10) paddle_y2 <= (paddle_y2 + RATE);

				end
			end
		end
	end
	

endmodule

module paddle_render
#(
parameter 	SCREEN_X = 10'd640,
		SCREEN_Y = 9'd480,
		X_SET = 'd10,
		X_SET2 = 'd625,
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
	
	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// need old and new ball positions
	input [($clog2(X_SET)):0] paddle_x,
	input [($clog2(Y_MAX)):0] paddle_y,
	input [($clog2(X_SET2)):0] paddle_x2,
	input [($clog2(Y_MAX)):0] paddle_y2,

	input [($clog2(X_SET)):0] old_paddle_x,
	input [($clog2(Y_MAX)):0] old_paddle_y,
	input [($clog2(X_SET2)):0] old_paddle_x2,
	input[($clog2(Y_MAX)):0] old_paddle_y2,
	
	// draw states and pulses
	input pulse_clear1, pulse_draw1, pulse_clear2, pulse_draw2,
	output done_clear1, done_draw1, done_clear2, done_draw2,
	
	// VGA outputs
	output reg [($clog2(SCREEN_X)):0] render_x,
	output reg [($clog2(SCREEN_Y)):0] render_y,
	output reg [2:0] col_out,
	output reg rendered
);

	// auxilary wires/signals
	// registers for clear box 
	wire [($clog2(X_SET)):0] pt_clear_x1;
	wire [($clog2(SCREEN_Y)):0] pt_clear_y1;
	wire [($clog2(X_SET2)):0] pt_clear_x2;
	wire [($clog2(SCREEN_Y)):0] pt_clear_y2;
		
	// registers for drawing new box
	wire [($clog2(X_SET)):0] pt_draw_x1;
	wire [($clog2(SCREEN_Y)):0] pt_draw_y1;
	wire [($clog2(X_SET2)):0] pt_draw_x2;
	wire [($clog2(SCREEN_Y)):0] pt_draw_y2;
	always@(posedge clk) begin   
		// Active Low Synchronous Reset
		if(!resetn) begin
			render_x <= 'd0;
			render_y <= 'd0;
			col_out <= 3'b0;
			rendered <= 0;
		end
		else begin
			if(!enable) begin
				// dont move the paddle
			end
			else begin
				if(pulse_clear1) begin
					// output the clearOld points
					render_x <= pt_clear_x1;
					render_y <= pt_clear_y1;
					col_out <= 3'b000;
					rendered <= 0;
				end
				else if(pulse_draw1) begin
					// output the drawNew points
					render_x <= pt_draw_x1;
					render_y <= pt_draw_y1;
					col_out <= 3'b111;
					rendered <= 0;
				end
				if(pulse_clear2) begin
					// output the clearOld points
					render_x <= pt_clear_x2;
					render_y <= pt_clear_y2;
					col_out <= 3'b000;
					rendered <= 0;
				end
				else if(pulse_draw2) begin
					// output the drawNew points
					render_x <= pt_draw_x2;
					render_y <= pt_draw_y2;
					col_out <= 3'b111;
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

	// Delete old paddle 1
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_SET,
		Y_MAX,
		X_PADDLE_SIZE,
		Y_PADDLE_SIZE
	) clearOld1 (
		clk,
		resetn,
		pulse_clear1,
		
		old_paddle_x,	
		old_paddle_y,	

		pt_clear_x1,
		pt_clear_y1,
		
		done_clear1
	);

	// use startDraw pulse to kickstart the drawNew cycle for p1
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_SET,
		Y_MAX,
		X_PADDLE_SIZE,
		Y_PADDLE_SIZE
	) drawNew1 (
		clk,
		resetn,
		done_clear1||pulse_draw1,

		paddle_x,
		paddle_y,

		pt_draw_x1,
		pt_draw_y1,
		done_draw1
	);

	//repeat for paddle 2
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_SET2,
		Y_MAX,
		X_PADDLE_SIZE,
		Y_PADDLE_SIZE
	) clearOld2 (
		clk,
		resetn,
		pulse_clear2,
		
		old_paddle_x2,	
		old_paddle_y2,	

		pt_clear_x2,
		pt_clear_y2,
		
		done_clear2
	);

	// use startDraw pulse to kickstart the drawNew cycle for p1
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_SET2,
		Y_MAX,
		X_PADDLE_SIZE,
		Y_PADDLE_SIZE
	) drawNew2 (
		clk,
		resetn,
		done_clear2||pulse_draw2,

		paddle_x2,
		paddle_y2,

		pt_draw_x2,
		pt_draw_y2,
		done_draw2
	);
endmodule


module drawBox_signal
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


