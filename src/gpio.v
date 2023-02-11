module gpio 
(
    input  clk,
    input  resetn,
	input   valid,
	output     ready,
	input [3:0]  wen,
	input [31:0] addr,
	input [31:0] wdata,
	output  [31:0] rdata,
    output [31:0] gpo
);
    reg [31:0] 	gpo;
    reg 	ready;
    reg [31:0] 	rdata;

	always @(posedge clk) begin
		if (!resetn) begin
			gpo <= 0;
		end else begin
			ready <= 0;
			if (valid && !ready && addr[31:24] == 8'h 03) begin
				ready <= 1;
				rdata <= gpo;
				if (wen[0]) gpo[ 7: 0] <= wdata[ 7: 0];
				if (wen[1]) gpo[15: 8] <= wdata[15: 8];
				if (wen[2]) gpo[23:16] <= wdata[23:16];
				if (wen[3]) gpo[31:24] <= wdata[31:24];
			end
		end
	end
endmodule
