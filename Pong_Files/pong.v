module pong_game(
	input wire 	    	iResetn,
	input wire 	    	iClock,
	input wire [2:0] 	iColour,
	input wire			iBlack,
	input wire			iEnable,

	input wire 			iUp,
	input wire			iDown,
	input wire 			iUp2,
	input wire			iDown2,
	
	output wire [($clog2(X_SCREEN_PIXELS)):0] oX,         // VGA pixel coordinates
	output wire [($clog2(Y_SCREEN_PIXELS)):0] oY,

	output wire [2:0] 		oColour,     // VGA pixel colour (0-7)
	output wire 	     	oPlot,       // Pixel drawn enable

	output wire [($clog2(X_MAX)):0] oBall_X,
	output wire [($clog2(Y_MAX)):0] oBall_Y,
	output wire lhs_score,
	output wire rhs_score,
	output wire boundaryHit
);	
	// Declaring Parameters!
	parameter
		// game size parameters
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
		X_SET = X_SCREEN_PIXELS, // was X_SCREEN_PIXEL/32... not sure why***
		X_SET2 = X_SCREEN_PIXELS - X_PADDLE_SIZE,
		PADDLE_MAX_Y = Y_SCREEN_PIXELS - 1 - Y_PADDLE_SIZE,

		
		Y_MIN = Y_MARGIN,
		X_MAX = (X_SCREEN_PIXELS - 1 - X_BOXSIZE - X_PADDLE_SIZE - X_SET2), // 0-based and account for box width
		Y_MAX = (Y_SCREEN_PIXELS - 1 - Y_BOXSIZE - Y_MARGIN),

		PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60;


	/*
	============================
	****************************
	Ball Variables
	****************************
	============================
	*/
	wire[($clog2(X_MAX)):0] ball_x;
	wire[($clog2(Y_MAX)):0] ball_y;

	wire[($clog2(X_MAX)):0] old_ball_x;
	wire[($clog2(Y_MAX)):0] old_ball_y;

	wire[($clog2(FRAMES_PER_UPDATE)):0] frameCount;
	wire frameTick;

	wire x_dir, y_dir;
	wire rendered;
	
	wire clearOld_pulse, drawNew_pulse, cleanScreen_pulse;
	wire done_clearOld, done_drawNew, done_cleanScreen;
	wire [($clog2(MAX_RATE)):0]	actual_rate;

	/*
	============================
	****************************
	Paddle Variables
	****************************
	============================
	*/

	wire[($clog2(X_SCREEN_PIXELS)):0] paddle_x1;
	wire[($clog2(Y_MAX)):0] paddle_y1;
	wire[($clog2(X_SCREEN_PIXELS)):0] paddle_x2;
	wire[($clog2(Y_MAX)):0] paddle_y2;

	wire[($clog2(X_SCREEN_PIXELS)):0] old_paddle_x;
	wire[($clog2(Y_MAX)):0] old_paddle_y;
	wire[($clog2(X_SCREEN_PIXELS)):0] old_paddle_x2;
	wire[($clog2(Y_MAX)):0] old_paddle_y2;
	
	wire [1:0] y_dir_paddle1;
	wire [1:0] y_dir_paddle2;

	wire done_clear1, done_draw1, done_clear2, done_draw2;
	wire pulse_clear1, pulse_draw1, pulse_clear2, pulse_draw2;

	/*
	============================
	****************************
	Ball Modules
	****************************
	============================
	*/

	control_ball_movement #(
				RATE, X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MIN, Y_MAX, X_BOXSIZE, Y_BOXSIZE, MAX_RATE,
				X_PADDLE_SIZE, Y_PADDLE_SIZE, X_PADDLE_SIZE, PADDLE_MAX_Y) 
			c_ball_move
			(iClock, iResetn, iEnable, iBlack, frameTick,
			ball_x, ball_y, actual_rate,
			paddle_y, paddle_y2,
			x_dir, y_dir,
			lhs_score, rhs_score, boundaryHit);

	ball_physics #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MIN, Y_MAX,
				X_BOXSIZE, Y_BOXSIZE, 
				FRAMES_PER_UPDATE, RATE, MAX_RATE)
				ball_phys1
				(iClock, iResetn, iEnable, // testing unique reset method based on scoring***
				frameTick, frameCount,
				x_dir, y_dir, cleanScreen_pulse,
				ball_x, ball_y,
				old_ball_x, old_ball_y,
				actual_rate);

	ball_render #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_MAX, Y_MAX,
				X_BOXSIZE, Y_BOXSIZE, 
				FRAMES_PER_UPDATE, RATE, MAX_RATE)
				ball_rend1
				(iClock, iResetn, iColour, iEnable, //testing unique reset method***
				frameTick, frameCount,
				ball_x, ball_y, old_ball_x, old_ball_y,
				clearOld_pulse, drawNew_pulse, cleanScreen_pulse,
				done_clearOld, done_drawNew, done_cleanScreen,
				oX, oY, oColour, rendered);

	/*
	============================
	****************************
	Paddle Modules
	****************************
	============================
	*/

	//Paddle 1	
	control_paddle_move #(RATE, X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_SET, Y_MAX, X_PADDLE_SIZE, Y_PADDLE_SIZE) 
			c_paddleA_move 
			(iClock, iResetn, 1'b1,
			paddle_x, paddle_y,
			iUp, iDown, y_dir);

	//Paddle 2
	control_paddle_move #(RATE, X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
				X_SET, Y_MAX, X_PADDLE_SIZE, Y_PADDLE_SIZE) 
			c_paddleB_move
			(iClock, iResetn, 1'b1,
			paddle_x2, paddle_y2,
			iUp2, iDown2, y_dir2);

	//Updates Location
	paddle_physics #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
			X_SET, X_SET2, Y_MAX,
			X_PADDLE_SIZE, Y_PADDLE_SIZE, 
			FRAMES_PER_UPDATE, RATE)
			paddle_phys
			(iClock, iResetn, 1'b1,
			frameTick, frameCount, y_dir, y_dir2,
			paddle_x, paddle_y, paddle_x2, paddle_y2,
			old_paddle_x, old_paddle_y, old_paddle_x2, old_paddle_y2);


	//Draws BOTH Paddles
	paddle_render #(X_SCREEN_PIXELS, Y_SCREEN_PIXELS,
			X_SET, X_SET2, Y_MAX,
			X_PADDLE_SIZE, Y_PADDLE_SIZE, 
			FRAMES_PER_UPDATE, RATE)
			paddle_rend
			(iClock, iResetn, 1'b1,
			frameTick, frameCount, paddle_x, paddle_y, paddle_x2,
			paddle_y2, old_paddle_x, old_paddle_y, old_paddle_x2,
			old_paddle_y2, pulse_clear1, pulse_draw1, pulse_clear2, 
			pulse_draw2, done_clear1, done_draw1, done_clear2, 
			done_draw2, oX, oY, oColour, rendered);

	/*
	============================
	****************************
	Overall Variables/Modules
	****************************
	============================
	*/
	
	rateDivider #(CLOCKS_PER_SECOND, 
			FRAMES_PER_UPDATE) 
			frameHandler (iClock, iResetn, iEnable, frameTick, frameCount);
	
	assign oPlot = !rendered;
	assign oBall_X = ball_x;
	assign oBall_Y = ball_y;
endmodule

/*
=============================================
*********************************************
Combined Modules
*********************************************
=============================================
*/


module control_render #(
    parameter   MAX_SCORE = 5,
                WARNING_LEVEL = 3
)
(
    input clk,
	input resetn,
	input enable,
	input frameTick,

    input done_background,
    input done_border,

	input done_clearOld1,
	input done_drawNew1,
	input done_clearOld2,
	input done_drawNew2,
	
    input done_clearOld_ball,
	input done_drawNew_ball,
	input done_blackScreen,
	input scored,

    input [($clog2(MAX_SCORE)):0] rhs_score,
    input [($clog2(MAX_SCORE)):0] lhs_score,

	output reg clearOld1_pulse,
	output reg drawNew1_pulse,
	output reg clearOld2_pulse,
	output reg drawNew2_pulse,

    output reg clearOld_pulse_ball,
	output reg drawNew_pulse_ball,
	output reg blackScreen_pulse,

    output reg draw_background_pulse,
    output reg draw_border_pulse
);

    reg[4:0] current_draw_state, next_draw_state;

    // draw states
	localparam 	S_WAIT =                    5'd0,
                // BACKGROUND
                S_BACKGROUND_START =        5'd1,
                S_BACKGROUND_WAIT =         5'd2,
                // BORDER
                S_BORDER_START =            5'd3,
                S_BORDER_WAIT =             5'd4,
                // PADDLE 1
    	        S_CLEAROLD_PADDLE1 =        5'd5,
				S_CLEAROLD_PADDLE1_WAIT =   5'd6,
				S_DRAWNEW_PADDLE1 =         5'd7,
				S_DRAWNEW_PADDLE1_WAIT =    5'd8,
                // PADDLE 2
				S_CLEAROLD_PADDLE2 =        5'd9,
				S_CLEAROLD_PADDLE2_WAIT =   5'd10,
				S_DRAWNEW_PADDLE2 =         5'd11,
				S_DRAWNEW_PADDLE2_WAIT =    5'd12,
                // BALL
				S_CLEAROLD_BALL_START =    5'd13,
				S_CLEAROLD_BALL_WAIT =     5'd14,
				S_DRAWNEW_BALL_START =     5'd15,
				S_DRAWNEW_BALL_WAIT =      5'd16,

                // CLEAN ENTIRE SCREEN
				S_BLACKSCREEN_START =       5'd17,
				S_BLACKSCREEN_WAIT =        5'd18;

    always@(*)
	begin 
		if(!enable) begin
			// do nothing with states...
		end
		else begin
			case(current_draw_state)
				S_WAIT:begin
                    if(scored) next_draw_state <= S_BLACKSCREEN_START;
					else next_draw_state <= (frameTick)?S_BACKGROUND_START:S_WAIT;
				end
                
                //Background
                S_BACKGROUND_START: begin
                    if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else next_draw_state <= S_BACKGROUND_WAIT;
                end

                S_BACKGROUND_WAIT: begin
                    if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else begin
                        // if anyone's score is above the warning level display the warning!
                        if(rhs_score > WARNING_LEVEL || lhs_score > WARNING_LEVEL) begin
                            next_draw_state <= (done_background)?S_BORDER_START:S_BACKGROUND_WAIT;
                        end    
                        // otherwise, dont
                        else begin
                            next_draw_state <= (done_background)?S_CLEAROLD_PADDLE1:S_BACKGROUND_WAIT;
                        end
                    end
                end

                // BORDER
                S_BORDER_START: begin
                    if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else next_draw_state <= S_BORDER_WAIT;
                end

                S_BORDER_WAIT: begin
                    if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else next_draw_state <= (done_background)?S_CLEAROLD_PADDLE1:S_BORDER_WAIT;
                end

				//Paddle 1
				S_CLEAROLD_PADDLE1: begin
                    if(scored) next_draw_state <= S_BLACKSCREEN_START;
                	else next_draw_state <= S_CLEAROLD_PADDLE1_WAIT;
				end
				S_CLEAROLD_PADDLE1_WAIT: begin
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else next_draw_state <= (done_clearOld1)?S_DRAWNEW_PADDLE1:S_CLEAROLD_PADDLE1_WAIT;
				end
				S_DRAWNEW_PADDLE1: begin
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else next_draw_state <= S_DRAWNEW_PADDLE1_WAIT;
				end
				S_DRAWNEW_PADDLE1_WAIT: begin
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else next_draw_state <= (done_drawNew1)?S_CLEAROLD_PADDLE2:S_DRAWNEW_PADDLE1_WAIT;
				end

				//Paddle 2
				S_CLEAROLD_PADDLE2: begin
                    if(scored) next_draw_state <= S_BLACKSCREEN_START;
					else next_draw_state <= S_CLEAROLD_PADDLE2_WAIT;
				end
				S_CLEAROLD_PADDLE2_WAIT: begin
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else next_draw_state <= (done_clearOld2)?S_DRAWNEW_PADDLE2:S_CLEAROLD_PADDLE2_WAIT;
				end
				S_DRAWNEW_PADDLE2: begin
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
                    else next_draw_state <= S_DRAWNEW_PADDLE2_WAIT;
				end
				S_DRAWNEW_PADDLE2_WAIT: begin
                    if(scored) next_draw_state <= S_BLACKSCREEN_START;
					else next_draw_state <= (done_drawNew2)?S_CLEAROLD_BALL_START:S_DRAWNEW_PADDLE2_WAIT;
				end

                // BALL
                S_CLEAROLD_BALL_START: begin
					// set up pulse to kickstart clear old module
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
					else next_draw_state <= S_CLEAROLD_BALL_WAIT;
				end
				S_CLEAROLD_BALL_WAIT: begin
					// set the pulse to 0, and only go next when the done signal is given
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
					// while clearing, keep clearing until it is done
					else next_draw_state <= (done_clearOld_ball)?S_DRAWNEW_BALL_START:S_CLEAROLD_BALL_WAIT;
				end

				S_DRAWNEW_BALL_START: begin
					// set up pulse to kickstart the draw new module
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
					// start drawing asap
					else next_draw_state <= S_DRAWNEW_BALL_WAIT;
				end

				S_DRAWNEW_BALL_WAIT: begin
					// set the pulse to 0, and only go next when the done signal is given
					if(scored) next_draw_state <= S_BLACKSCREEN_START;
					// keep drawing until it is done. if it is done, go back to waiting till next frame and clear old
					else next_draw_state <= (done_drawNew_ball)?S_WAIT:S_DRAWNEW_BALL_WAIT;
				end


                // on score/reset
				S_BLACKSCREEN_START: begin
					// set pulse to 0
					next_draw_state <= S_BLACKSCREEN_WAIT;
				end

				S_BLACKSCREEN_WAIT: begin
					// clear screen until it is done
					// once it is done, go to normal behaviour!
					/*
					d, r, behaviour
					0, 0, shouldnt occur... if it	 does, reset takes prio, stay here
					0, 1, drawing, stay here
					1, 0, resetting, stay here
					1, 1, done drawing, go next
					*/
					next_draw_state <= (done_blackScreen&&resetn)?S_WAIT:S_BLACKSCREEN_WAIT;
				end
				default: next_draw_state <= S_BLACKSCREEN_START;

			endcase
		end
	end 

    // Output logic aka all of our datapath control signals
	always@(*)
	begin
        // set pulses to 0, before manipulations

		drawNew1_pulse <= 0;
		clearOld1_pulse <= 0;
		drawNew2_pulse <= 0;
		clearOld2_pulse <= 0;

        clearOld_pulse_ball <= 0;
        drawNew_pulse_ball <= 0;
        blackScreen_pulse <= 0;

        draw_background_pulse <= 0;
        draw_border_pulse <= 0;

		case(current_draw_state)

			// background
            S_BACKGROUND_WAIT: begin
                draw_background_pulse <= 1;
            end
            
            // border
            S_BORDER_WAIT: begin
                draw_border_pulse <= 1;
            end
            
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

            // ball
            S_CLEAROLD_BALL_WAIT: begin
                clearOld_pulse_ball <= 1;
            end
            S_DRAWNEW_BALL_WAIT: begin
                drawNew_pulse_ball <= 1;
            end

            // clear screen option
            S_BLACKSCREEN_WAIT: begin
                blackScreen_pulse <= 1;
            end

		endcase
	end

	always@(posedge clk)
	begin 
		if(!resetn) begin
			current_draw_state <= S_BLACKSCREEN_START;
		end
		else begin
			current_draw_state <= next_draw_state;
		end
	end
endmodule

