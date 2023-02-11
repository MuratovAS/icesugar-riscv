/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Claire Xenia Wolf <claire@yosyshq.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`include "src/ext/picorv32.v"

`include "src/membram.v"
`include "src/memspram.v"

`include "src/spimemio.v"
`include "src/simpleuart.v"

`ifndef PICORV32_REGS
`define PICORV32_REGS picosoc_regs
`endif

module picosoc #(
	parameter ROM_TYPE = 0,
	parameter integer ROM_WORDS = 8192, //KByte
	parameter [31:0] ROM_ADDR = 32'h 0010_0000, // 1 MB into flash

	parameter RAM_TYPE = 1,
	parameter integer RAM_WORDS = 131072, //KByte

	parameter [31:0] IRQ_ADDR = 32'h 0000_0000,
	parameter [31:0] STACK_ADDR = (4*RAM_WORDS)       // end of memory
)(
	input clk,
	input resetn,

	output [31:0] gpio,

	input  irq_5,
	input  irq_6,
	input  irq_7,

	output ser_tx,
	input  ser_rx,

	output flash_csb,
	output flash_clk,

	output [3:0] flash_oe,
	output [3:0] flash_do,
	input  [3:0] flash_di
);
	reg [31:0] irq;
	wire irq_stall = 0;
	wire irq_uart = 0;

	always @* begin
		irq = 0;
		irq[3] = irq_stall;
		irq[4] = irq_uart;
		irq[5] = irq_5;
		irq[6] = irq_6;
		irq[7] = irq_7;
	end

	wire cpu_valid;
	wire cpu_instr;
	wire cpu_ready;
	wire [31:0] cpu_addr;
	wire [31:0] cpu_wdata;
	wire [3:0] cpu_wstrb;
	wire [31:0] cpu_rdata;

	wire rom_ready;
	wire [31:0] rom_rdata;

	reg ram_ready;
	wire [31:0] ram_rdata;

	reg [31:0] 	gpio;
	wire        iomem_valid = cpu_valid && (cpu_addr[31:24] > 8'h 01);
	reg         iomem_ready;
	wire [3:0]  iomem_wstrb = cpu_wstrb;;
	wire [31:0] iomem_addr  = cpu_addr;
	wire [31:0] iomem_wdata = cpu_wdata;
	reg  [31:0] iomem_rdata;

	wire spimemio_cfgreg_sel = cpu_valid && (cpu_addr == 32'h 0200_0000);
	wire [31:0] spimemio_cfgreg_do;

	wire        simpleuart_reg_div_sel = cpu_valid && (cpu_addr == 32'h 0200_0004);
	wire [31:0] simpleuart_reg_div_do;

	wire        simpleuart_reg_dat_sel = cpu_valid && (cpu_addr == 32'h 0200_0008);
	wire [31:0] simpleuart_reg_dat_do;
	wire        simpleuart_reg_dat_wait;

	assign cpu_ready = (iomem_valid && iomem_ready) || rom_ready || ram_ready || spimemio_cfgreg_sel ||
			simpleuart_reg_div_sel || (simpleuart_reg_dat_sel && !simpleuart_reg_dat_wait);

	assign cpu_rdata = (iomem_valid && iomem_ready) ? iomem_rdata : rom_ready ? rom_rdata : ram_ready ? ram_rdata :
			spimemio_cfgreg_sel ? spimemio_cfgreg_do : simpleuart_reg_div_sel ? simpleuart_reg_div_do :
			simpleuart_reg_dat_sel ? simpleuart_reg_dat_do : 32'h 0000_0000;

	picorv32 #(
		.STACKADDR(STACK_ADDR),
		.PROGADDR_RESET(ROM_ADDR),
		.ENABLE_PCPI		(0), //1
		.ENABLE_MUL			(0), //1
		.ENABLE_FAST_MUL	(0), //0
		.ENABLE_DIV			(0), //1
		//.PROGADDR_IRQ		(IRQ_ADDR),
		//.MASKED_IRQ       (MASKED_IRQ          ),
		//.LATCHED_IRQ      (LATCHED_IRQ         ),
		.ENABLE_IRQ			(0), //1
		.ENABLE_IRQ_QREGS	(0), //1
		.ENABLE_IRQ_TIMER   (0), //1
		.BARREL_SHIFTER		(0), //1
		.COMPRESSED_ISA		(0), //1 +
		.ENABLE_COUNTERS	(1), //1 +++
		.ENABLE_COUNTERS64   (0), //1
		.ENABLE_REGS_16_31   (1), //1 ++
		.ENABLE_REGS_DUALPORT(1), //1 +++
		.TWO_STAGE_SHIFT     (0), //1 +
		.TWO_CYCLE_COMPARE   (0), //0
		.TWO_CYCLE_ALU       (0), //0
		.CATCH_MISALIGN      (1), //1 ++
		.CATCH_ILLINSN       (1), //1 ++
		.ENABLE_TRACE        (0), //0
		.REGS_INIT_ZERO      (0)  //0
	) cpu (
		.clk         (clk        ), //i
		.resetn      (resetn     ), //i
		.mem_valid   (cpu_valid  ), //o CPU готов общаться
		.mem_instr   (cpu_instr  ), //o 
		.mem_ready   (cpu_ready  ), //i устройство готово выдать данные
		.mem_addr    (cpu_addr   ), //o адрес
		.mem_wdata   (cpu_wdata  ), //o пишет данные
		.mem_wstrb   (cpu_wstrb  ), //o длинна слова для записи
		.mem_rdata   (cpu_rdata  ), //i читает данные
		.irq         (irq        )  //i
	);

	if(RAM_TYPE == 0) begin
	rambram #(
		.WORDS(RAM_WORDS)
	) ram (
		.clk(clk),
		.wen((cpu_valid && !cpu_ready && cpu_addr < 4*RAM_WORDS) ? cpu_wstrb : 4'b0),
		.valid(cpu_valid && !cpu_ready && cpu_addr < 4*RAM_WORDS),
		.ready(ram_ready),
		.addr(cpu_addr[23:2]),
		.wdata(cpu_wdata),
		.rdata(ram_rdata)
	);
	end else if(RAM_TYPE == 1) begin
	ramspram #(
		.WORDS(RAM_WORDS)
	) ram (
		.clk(clk),
		.wen((cpu_valid && !cpu_ready && cpu_addr < 4*RAM_WORDS) ? cpu_wstrb : 4'b0),
		.valid(cpu_valid && !cpu_ready && cpu_addr < 4*RAM_WORDS),
		.ready(ram_ready),
		.addr(cpu_addr[23:2]),
		.wdata(cpu_wdata),
		.rdata(ram_rdata)
	);
	end

	if(ROM_TYPE == 0) begin
	rombram #(
		.WORDS(ROM_WORDS)
	) rom (
		.clk(clk),
		.resetn (resetn),
		.valid(cpu_valid && cpu_addr >= 4*RAM_WORDS && cpu_addr < 32'h 0200_0000),
		.ready(rom_ready),
		.addr(cpu_addr[12:0]),
		.rdata(rom_rdata)
	);
	end else if(ROM_TYPE == 1) begin
	spimemio rom (
		.clk    (clk),
		.resetn (resetn),
		.valid  (cpu_valid && cpu_addr >= 4*RAM_WORDS && cpu_addr < 32'h 0200_0000),
		.ready  (rom_ready),
		.addr   (cpu_addr[23:0]),
		.rdata  (rom_rdata),

		.flash_csb    (flash_csb   ),
		.flash_clk    (flash_clk   ),

		.flash_io0_oe (flash_oe[0]),
		.flash_io1_oe (flash_oe[1]),
		.flash_io2_oe (flash_oe[2]),
		.flash_io3_oe (flash_oe[3]),

		.flash_io0_do (flash_do[0]),
		.flash_io1_do (flash_do[1]),
		.flash_io2_do (flash_do[2]),
		.flash_io3_do (flash_do[3]),

		.flash_io0_di (flash_di[0]),
		.flash_io1_di (flash_di[1]),
		.flash_io2_di (flash_di[2]),
		.flash_io3_di (flash_di[3]),

		.cfgreg_we(spimemio_cfgreg_sel ? cpu_wstrb : 4'b 0000),
		.cfgreg_di(cpu_wdata),
		.cfgreg_do(spimemio_cfgreg_do)
	);
	end

	simpleuart simpleuart (
		.clk         (clk         ),
		.resetn      (resetn      ),

		.ser_tx      (ser_tx      ),
		.ser_rx      (ser_rx      ),

		.reg_div_we  (simpleuart_reg_div_sel ? cpu_wstrb : 4'b 0000),
		.reg_div_di  (cpu_wdata),
		.reg_div_do  (simpleuart_reg_div_do),

		.reg_dat_we  (simpleuart_reg_dat_sel ? cpu_wstrb[0] : 1'b 0),
		.reg_dat_re  (simpleuart_reg_dat_sel && !cpu_wstrb),
		.reg_dat_di  (cpu_wdata),
		.reg_dat_do  (simpleuart_reg_dat_do),
		.reg_dat_wait(simpleuart_reg_dat_wait)
	);

	always @(posedge clk) begin
		if (!resetn) begin
			gpio <= 0;
		end else begin
			iomem_ready <= 0;
			if (iomem_valid && !iomem_ready && iomem_addr[31:24] == 8'h 03) begin
				iomem_ready <= 1;
				iomem_rdata <= gpio;
				if (iomem_wstrb[0]) gpio[ 7: 0] <= iomem_wdata[ 7: 0];
				if (iomem_wstrb[1]) gpio[15: 8] <= iomem_wdata[15: 8];
				if (iomem_wstrb[2]) gpio[23:16] <= iomem_wdata[23:16];
				if (iomem_wstrb[3]) gpio[31:24] <= iomem_wdata[31:24];
			end
		end
	end

endmodule