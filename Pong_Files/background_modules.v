// ctrl module for the background only, to be ignored...
/*
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
		X_SIZE, Y_SIZE, 1'b1
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
	*
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
*/

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
			Y_SIZE = 240,
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


// basically a rate divider?
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