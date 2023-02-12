// Implementation note:
// Replace the following modules with wrappers for your SRAM cells.

`ifndef FW_IMG_PATH
`define FW_IMG_PATH ""
`endif

module rombram #(
	parameter MEM_HEX = `FW_IMG_PATH,
	parameter integer WORDS = 256
) (
	input clk,
	input resetn,
	input valid,
	output ready,
	input [log2(WORDS-1)-1:0] addr,
	output [31:0] rdata
);
	reg ready;
	reg [31:0] rdata;

	reg [7:0] mem [0:WORDS-1];
	initial begin
        	$readmemh(MEM_HEX,mem); //FIXME:
	end
	reg [2:0] state = 3'd0;
	reg [log2(WORDS-1)-1:0] pointer;

	always @(posedge clk) 
	begin
		if(valid == 1'b1 && ready == 1'b0 && resetn)
		begin
			pointer <= pointer + 1;
			case (state)
				3'd0: pointer <= addr;
				3'd1: rdata[7:0] <= mem[pointer];
				3'd2: rdata[15:8] <= mem[pointer];
				3'd3: rdata[23:16] <= mem[pointer];
				3'd4: rdata[31:24] <= mem[pointer];
				3'd5: ready <= 1'b1;
			endcase
			state <= state + 3'd1;
		end
		else
		begin
			ready=1'b0;
			state=3'd0;
		end
	end
	//** TASKS / FUNCTIONS **************************************** 
	function integer log2(input integer M);
		integer i;
	begin
		log2 = 1;
		for (i = 0; 2**i <= M; i = i + 1)
			log2 = i + 1;
	end endfunction
endmodule

module rambram #(
	parameter integer WORDS = 256
) (
	input clk,
	input [3:0] wen,
	input valid,
	output ready,
	input [log2(WORDS)-1:0] addr,
	input [31:0] wdata,
	output reg [31:0] rdata
);
	reg ready;
	
	reg [31:0] mem [0:WORDS-1];

	always @(posedge clk) 
		ready <= valid;

	always @(posedge clk) begin
		rdata <= mem[addr];
		if (wen[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
		if (wen[1]) mem[addr][15: 8] <= wdata[15: 8];
		if (wen[2]) mem[addr][23:16] <= wdata[23:16];
		if (wen[3]) mem[addr][31:24] <= wdata[31:24];
	end
	//** TASKS / FUNCTIONS **************************************** 
	function integer log2(input integer M);
		integer i;
	begin
		log2 = 1;
		for (i = 0; 2**i <= M; i = i + 1)
			log2 = i + 1;
	end endfunction
endmodule

module picosoc_regs (
	input clk, wen,
	input [5:0] waddr,
	input [5:0] raddr1,
	input [5:0] raddr2,
	input [31:0] wdata,
	output [31:0] rdata1,
	output [31:0] rdata2
);
	reg [31:0] regs [0:31];

	always @(posedge clk)
		if (wen) regs[waddr[4:0]] <= wdata;

	assign rdata1 = regs[raddr1[4:0]];
	assign rdata2 = regs[raddr2[4:0]];
endmodule
