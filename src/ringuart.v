/*
 * ringuart.v - Ring uart implementation for picorv32. 
 * Copyright (c) 2023 Aleksej Muratov (MuratovAS)
 */

`include "src/ext/uart.v"

module ringuart#(
	parameter integer UART_CLK = 12000000,
	parameter integer BAUD_RATE = 115200,
	parameter integer RING_SIZE_RX = 2,
	parameter integer RING_SIZE_TX = 2
)(
	input clk,
	input resetn,

	output ser_tx,
	input  ser_rx,

	//input         reg_state_we,
	input         reg_state_re,
	//input  [31:0] reg_state_di,
	output [31:0] reg_state_do,
	output        reg_state_wait,

	input         reg_dat_we,
	input         reg_dat_re,
	input  [31:0] reg_dat_di,
	output [31:0] reg_dat_do,
	output        reg_dat_wait
);
	localparam UART_DIV = UART_CLK / (BAUD_RATE*8);

	wire		transmitFlag;
	reg			transmitLoad = 1'b0;
	wire [7:0]	transmitData;
	wire		receiveFlag;
	wire [7:0]	receiveData;

	// ring
	reg	[7:0] ring_RX [2**RING_SIZE_RX-1:0];
	reg	[RING_SIZE_RX-1:0] pointerHead_RX = 0;
	reg	[RING_SIZE_RX-1:0] pointerTail_RX = 0;
	reg	pointerEqualN_RX;
	reg	overflow_RX = 1'b0;
	
	reg	[7:0] ring_TX [2**RING_SIZE_TX-1:0];
	reg	[RING_SIZE_TX-1:0] pointerHead_TX = 0;
	reg	[RING_SIZE_TX-1:0] pointerTail_TX = 0;
	reg	pointerEqualN_TX;
	reg	overflow_TX= 1'b0;

	// pointer inc
	always @(posedge clk)
	begin
		// rx
		if(reg_dat_re)
		begin
			pointerHead_RX <= pointerHead_RX + 1'd1;
			overflow_RX <= 1'b0; // reset overflow_RX
		end

		if(receiveFlag)
		begin
			ring_RX[pointerTail_RX] <= receiveData;
			pointerTail_RX <= pointerTail_RX + 1'd1;

			// detect overflow_RX
			if(pointerTail_RX + 1'd1 == pointerHead_RX)
				overflow_RX <= 1'b1;
		end

		// tx
		if(reg_dat_we && !reg_dat_re)
		begin
			ring_TX[pointerTail_TX] <= reg_dat_di[7:0];
			pointerTail_TX <= pointerTail_TX + 1'd1;

			// detect+reset overflow_TX
			if(pointerTail_TX + 1'd1 == pointerHead_TX) // TODO: test overflow_TX
				overflow_TX <= 1'b1;
			else
				overflow_TX <= 1'b0;
		end
		
		// rst
		if(!resetn)
		begin
			overflow_RX <= 1'b0;
			overflow_TX <= 1'b0;
			pointerHead_RX <= 0;
			pointerTail_RX <= 0;
			pointerTail_TX <= 0;
		end
	end
	
	always @(negedge transmitFlag)
	begin
		if(!transmitFlag)
			pointerHead_TX <= pointerHead_TX + 1'd1;
		if(!resetn)
			pointerHead_TX <= 0;
	end

	// status pointerEqual
	always @(posedge clk)
	begin
		if(pointerHead_RX == pointerTail_RX)
			pointerEqualN_RX <= 1'b0;
		else
			pointerEqualN_RX <= 1'b1;

		if(pointerHead_TX == pointerTail_TX)
			pointerEqualN_TX <= 1'b0;
		else
			pointerEqualN_TX <= 1'b1;
	end

	// auto transmit
	assign transmitData =  ring_TX[pointerHead_TX];
	reg df = 1'b0; // for Delta-function
	always @(posedge clk)
	begin
		if(pointerEqualN_TX == 1'b1 && df == 1'b0)
		begin
			df <= 1'b1;
			transmitLoad <= 1'b1;
		end
		else
			transmitLoad <= 1'b0;

		if(!transmitFlag)
			df <= 1'b0;
	end
	
	// bus 
	// FIXME: *_wait
	assign reg_dat_wait = 1'b0; 
	assign reg_state_wait = 1'b0;

	assign reg_dat_do = ring_RX[pointerHead_RX];
	assign reg_state_do = { 
							overflow_TX,
							overflow_RX,
							pointerEqualN_TX,
							pointerEqualN_RX,
							pointerHead_TX[6:0],
							pointerTail_TX[6:0],
							pointerHead_RX[6:0],
							pointerTail_RX[6:0]
							}; // status /\

	// clock cycle
	wire bitxce;
	reg [log2(UART_DIV)-1:0] bitxcecnt = 0;
	always @(posedge clk)
		bitxcecnt <= (bitxcecnt == UART_DIV-1 ? 0 : bitxcecnt+1);
	assign bitxce = (bitxcecnt == 0 ? 1 : 0); // + LUTs

	// uart unit
	uart uuart(
		.clk			(clk),
		.txpin			(ser_tx),
		.rxpin			(ser_rx),
		// tx
		.txbusy			(transmitFlag), // Status of transmit. When high do not load
		.load			(transmitLoad), // Load transmit buffer
		.d				(transmitData),
		// rx
		.bytercvd		(receiveFlag), // Status receive. True 1 clock cycle only
		.q				(receiveData),
		// debug
		.bitxce			(bitxce) // High 1 clock cycle 8 or 16 times per bit
		//.rxst			(rxst[1:0]),
	);
	
	//** TASKS / FUNCTIONS **************************************** 
	function integer log2(input integer M);
		integer i;
	begin
		log2 = 1;
		for (i = 0; 2**i <= M; i = i + 1)
			log2 = i + 1;
	end endfunction

endmodule
