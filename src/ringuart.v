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
		
	wire [7:0] status = 
	{
		1'b0,				// bit 7 
		1'b0,				// bit 6 
		1'b0,				// bit 5 
		1'b0,				// bit 4 
		1'b0,				// bit 3 
		1'b0,				// bit 2 
		pointerEqualN_RX,	// bit 1 
		transmitFlag		// bit 0 
	};

	// ring
	reg	[7:0] ring_RX [2**RING_SIZE_RX-1:0];
	reg	[RING_SIZE_RX-1:0] pointerHead_RX = 0;
	reg	[RING_SIZE_RX-1:0] pointerTail_RX = 0;
	reg	pointerEqualN_RX;

	always @(posedge clk)
	begin
		if(reg_dat_re)
			pointerHead_RX <= pointerHead_RX + 1'd1;

		if(receiveFlag)
		begin
			ring_RX[pointerTail_RX] <= receiveData;
			pointerTail_RX <= pointerTail_RX + 1'd1;
		end

		if(!resetn)
		begin
			pointerHead_RX <= 0;
			pointerTail_RX <= 0;
		end
	end
	
	// status pointerEqual
	always @(posedge clk)
	begin
		if(pointerHead_RX == pointerTail_RX)
			pointerEqualN_RX <= 1'b0;
		else
			pointerEqualN_RX <= 1'b1;
	end

	// auto transmit
	assign transmitData = reg_dat_di[7:0];
	always @(posedge clk)
		if(reg_dat_we && !reg_dat_re)
			transmitLoad <= 1'b1;
		else
			transmitLoad <= 1'b0;

	// bus 
	// FIXME: *_wait
	assign reg_dat_wait = 1'b0; 
	assign reg_state_wait = 1'b0;

	assign reg_dat_do = ring_RX[pointerHead_RX];
	assign reg_state_do = {pointerTail_RX[7:0], pointerHead_RX[7:0], status};

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
