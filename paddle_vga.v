module paddle_vga
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
		
		KEY,							// On Board Keys
		SW, 							//* on Board Switches

		// Bidirectionals
		PS2_CLK,
		PS2_DAT,
		
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
	// Bidirectionals
	inout				PS2_CLK;
	inout				PS2_DAT;
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
	wire [2:0] y_dir;
	wire [9:0] x;
	wire [8:0] y;
	wire writeEn;
	
	// Internal Wires
	wire		[7:0]	ps2_key_data;
	wire				ps2_key_pressed;
	wire           send_command;

// Internal Registers
	reg			[7:0]	last_data_received;

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
	reg iUp, iDown;
	
	reg escape;
 
	always @(posedge CLOCK_50)
	begin
	if (KEY[0] == 1'b0)
		last_data_received <= 8'b0;
		
	if (ps2_key_pressed == 1'b1 && (ps2_key_data == 8'd29 || ps2_key_data == 8'd27) ) begin
		last_data_received <= ps2_key_data;
		escape <= 1'b0;
	end
	
	else if(ps2_key_data == 8'hF0)
	begin
		escape <= 1'b1;
	end
	
	if(escape == 1'b1)
	begin
		last_data_received <= 8'b0;
	end
	
	
	if(last_data_received == 8'd29)
	begin
		iUp <= 1'b1;
	end
	else begin
		iUp <= 1'b0;
	end	
	
	if(last_data_received == 8'd27)
	begin
		iDown <= 1'b1;
	end
	else begin
		iDown <= 1'b0;
	end
end
	
	

	//module part2(iResetn, iPlotBox, iBlack, iColour, iLoadX, iXY_Coord, iClock,
	//					oX, oY, oColour, oPlot, oDone);
	//***** CHECK PARAMETERS!!!
	paddle #(.X_PADDLE_SIZE('d7), .Y_PADDLE_SIZE('d50), .X_SCREEN_PIXELS('d320), .Y_SCREEN_PIXELS('d240),
				.FRAMES_PER_UPDATE('d30), .RATE('d3)) 
				p1
				(.iResetn(resetn), .iClock(CLOCK_50) , .iUp(iUp), .iDown(iDown), .iUp2(SW[9]), .iDown2(SW[0]),
				.oX(x), .oY(y), .oColour(colour), .oPlot(writeEn), .oNewFrame(LEDR[0]) );
				
	
	//assign LEDR[1] = writeEn;
	assign LEDR[1] = iDown;
	assign LEDR[2] = iUp;
	assign LEDR[3] = SW[0];
	assign LEDR[4] = SW[9];
	assign LEDR[5] = KEY[0];
	
	// Output coordinates
	//hex_decoder hex0(y_dir, HEX0);
	//hex_decoder hex0(x[3:0], HEX0);
	hex_decoder hex0(last_data_received[3:0], HEX0);
	hex_decoder hex1(last_data_received[7:4], HEX1);
	hex_decoder hex2(y[3:0], HEX2);
	hex_decoder hex3(y[7:4], HEX3);

	
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

