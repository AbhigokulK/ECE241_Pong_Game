
module PS2_Demo (
	// Inputs
	CLOCK_50,
	KEY,

	// Bidirectionals
	PS2_CLK,
	PS2_DAT,
	
	// Outputs
	HEX0,
	HEX1,
	HEX2,
	HEX3,
	HEX4,
	HEX5,
	HEX6,
	HEX7,
	LEDR
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/

// Inputs
input				CLOCK_50;
input		[3:0]	KEY;

// Bidirectionals
inout				PS2_CLK;
inout				PS2_DAT;

// Outputs
output		[6:0]	HEX0;
output		[6:0]	HEX1;
output		[6:0]	HEX2;
output		[6:0]	HEX3;
output		[6:0]	HEX4;
output		[6:0]	HEX5;
output		[6:0]	HEX6;
output		[6:0]	HEX7;
output reg	[9:0]	LEDR;

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/

// Internal Wires
wire		[7:0]	ps2_key_data;
wire				ps2_key_pressed;
wire           send_command;

// State Machine Registers

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/
/*
remember the bit pattern fsm example
if we get a break signal on clock tick X then our desired key on clock tick X+1, we "let go" of our key input!
*/

/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/

 	reg	[7:0]	last_data_received_p1;
	reg	[7:0]	last_data_received_p2;
	

	reg[2:0] current_key_state;
	reg[2:0] key_state;
	
	localparam S_WAIT = 3'd0,
		   S_INPUT = 3'd1,
		   S_BREAK = 3'd2;
 
always@(posedge CLOCK_50)
	begin
		if (!KEY[0]) begin
			last_data_received_p1 <= 8'b0;
			last_data_received_p2 <= 8'b0;
		end

		//Paddle 1
		if(last_data_received_p1 == 8'd29)
		begin
			LEDR[9] <= 1'b1;
		end
		else begin
			LEDR[9] <= 1'b0;
		end	
	
		if(last_data_received_p1 == 8'd27)
		begin
			LEDR[8] <= 1'b1;
		end
		else begin
			LEDR[8] <= 1'b0;
		end

		//Paddle 2
		if(last_data_received_p2 == 8'd68)
		begin
			LEDR[7] <= 1'b1;
		end
		else begin
			LEDR[7] <= 1'b0;
		end
	
		if(last_data_received_p2 == 8'd75)
		begin
			LEDR[6] <= 1'b1;
		end
		else begin
			LEDR[6] <= 1'b0;
		end

		case(current_key_state)	
			S_WAIT: begin
				if (ps2_key_data == 8'hF0) key_state <= S_BREAK;
            else if (ps2_key_pressed) key_state <= S_INPUT;
				else key_state <= S_WAIT;				
			end
			S_INPUT: begin
				if (ps2_key_data == 8'hF0) key_state <= S_BREAK;
				else if ( (ps2_key_data == 8'd29 || ps2_key_data == 8'd27) ) begin
					last_data_received_p1 <= ps2_key_data;
				end
				else if ( (ps2_key_data == 8'd68 || ps2_key_data == 8'd75) ) begin
					last_data_received_p2 <= ps2_key_data;
				end
				key_state <= S_WAIT;
			end
			S_BREAK: begin 
				if ( (ps2_key_data == 8'd29 || ps2_key_data == 8'd27) ) begin
					last_data_received_p1 <= 8'd0;
				end
				else if ( (ps2_key_data == 8'd68 || ps2_key_data == 8'd75) ) begin
					last_data_received_p2 <= 8'd0;
				end
				key_state <= S_WAIT;
			end

			default: key_state <= S_WAIT;

		endcase

	end
	
	always@(posedge CLOCK_50)
	begin 
		if(!KEY[0]) begin
			current_key_state <= S_WAIT;
		end
		else begin
			current_key_state <= key_state;
		end
	end


/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/

assign HEX2 = 7'h7F;
assign HEX3 = 7'h7F;
assign HEX4 = 7'h7F;
assign HEX5 = 7'h7F;
assign HEX6 = 7'h7F;
assign HEX7 = 7'h7F;

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

PS2_Controller PS2 (
	// Inputs
	.CLOCK_50				(CLOCK_50),
	.reset				(~KEY[0]),

	// Bidirectionals
	.PS2_CLK			(PS2_CLK),
 	.PS2_DAT			(PS2_DAT),

	// Outputs
	.received_data		(ps2_key_data),
	.received_data_en	(ps2_key_pressed)
);

Hexadecimal_To_Seven_Segment Segment0 (
	// Inputs
	.hex_number			(last_data_received_p1[3:0]),

	// Bidirectional

	// Outputs
	.seven_seg_display	(HEX0)
);

Hexadecimal_To_Seven_Segment Segment1 (
	// Inputs
	.hex_number			(last_data_received_p1[7:4]),

	// Bidirectional

	// Outputs
	.seven_seg_display	(HEX1)
);


endmodule
