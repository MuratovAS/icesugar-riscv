/*
 * miniuart.v - Minimal uart implementation for picorv32. 
 * Copyright (c) 2023 Aleksej Muratov (MuratovAS)
 */

`include "src/ext/uart.v"

module miniuart#(
	parameter integer UART_CLK = 12000000,
	parameter integer BAUD_RATE = 115200
)(
	input clk,
	input resetn,

	output ser_tx,
	input  ser_rx,

	input         reg_state_we,
	input         reg_state_re,
	input  [31:0] reg_state_di,
	output [31:0] reg_state_do,
	output        reg_state_wait,

	input         reg_dat_we,
	input         reg_dat_re,
	input  [31:0] reg_dat_di,
	output [31:0] reg_dat_do,
	output        reg_dat_wait
);	
	`define TRUE 1'b1
	`define FALSE 1'b0
	
	localparam UART_DIV = UART_CLK / (BAUD_RATE*8);

	// reg
	reg	receiveFlag = `FALSE;
	reg	load = `FALSE;

	// wire
	wire	bytercvd;
	wire	transmitFlag;
	wire [7:0] q;
	
	// assign FIXME:
	assign reg_dat_wait = `FALSE;
	assign reg_dat_do = q;
	assign reg_state_wait = `FALSE;
	assign reg_state_do = status;

	wire [7:0] status = 
	{
		`FALSE,			// bit 7 
		`FALSE,			// bit 6 
		`FALSE,			// bit 5 
		`FALSE,			// bit 4 
		`FALSE,			// bit 3 
		`FALSE,			// bit 2 
		receiveFlag,	// bit 1 
		transmitFlag	// bit 0 
	};

	// reset receive flag
	always @(posedge clk)
	begin
		if(reg_dat_re || !resetn)
			receiveFlag <= `FALSE;
		if(bytercvd)
			receiveFlag <= `TRUE;

	end

	// auto transmit
	always @(posedge clk)
		if(reg_dat_we && !reg_dat_re)
			load <= `TRUE;
		else
			load <= `FALSE;

	//clock cycle
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
		.load			(load), // Load transmit buffer
		.d				(reg_dat_di[7:0]),
		// rx
		.bytercvd		(bytercvd), // Status receive. True 1 clock cycle only
		.q				(q),
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
