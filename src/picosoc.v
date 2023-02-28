`include "src/ext/picorv32.v"

`include "src/membram.v"
`include "src/memspram.v"

`include "src/spimemio.v"
`include "src/simpleuart.v"
`include "src/gpio.v"

`ifndef PICORV32_REGS
`define PICORV32_REGS picosoc_regs
`endif

module picosoc #(
	//value is set
	parameter ROM_TYPE = 1, // 0: BRAM ; 1: SPI
	parameter integer ROM_WORDS = 8192, //KByte
	parameter [31:0] ROM_ADDR = 32'h0010_0000, // 1 MB into flash

	parameter RAM_TYPE = 1, // 0: BRAM ; 1: SPRAM
	parameter integer RAM_WORDS = 131072, //KByte

	parameter [31:0] IRQ_ADDR = 32'h0000_0000,
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
	reg [31:0] cpu_rdata;

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
	) ucpu (
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


	wire ram_ready;
	wire [31:0] ram_rdata;
	if(RAM_TYPE == 0) begin
	rambram #(
		.WORDS(RAM_WORDS)
	) uram (
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
	) uram (
		.clk(clk),
		.wen((cpu_valid && !cpu_ready && cpu_addr < 4*RAM_WORDS) ? cpu_wstrb : 4'b0),
		.valid(cpu_valid && !cpu_ready && cpu_addr < 4*RAM_WORDS),
		.ready(ram_ready),
		.addr(cpu_addr[23:2]),
		.wdata(cpu_wdata),
		.rdata(ram_rdata)
	);
	end


	wire rom_ready;
	wire [31:0] rom_rdata;
	wire spimemio_cfgreg_sel = cpu_valid && (cpu_addr == 32'h0200_0000);
	wire [31:0] spimemio_cfgreg_do;
	if(ROM_TYPE == 0) begin
	rombram #(
		.WORDS(ROM_WORDS)
	) urom (
		.clk(clk),
		.resetn (resetn),
		.valid(cpu_valid && cpu_addr >= 4*RAM_WORDS && cpu_addr < 32'h0200_0000),
		.ready(rom_ready),
		.addr(cpu_addr[12:0]),
		.rdata(rom_rdata)
	);
	end else if(ROM_TYPE == 1) begin
	spimemio urom (
		.clk    (clk),
		.resetn (resetn),
		.valid  (cpu_valid && cpu_addr >= 4*RAM_WORDS && cpu_addr < 32'h0200_0000),
		.ready  (rom_ready),
		.addr   (cpu_addr[23:0]),
		.rdata  (rom_rdata),

		.flash_csb    (flash_csb   ),
		.flash_clk    (flash_clk   ),

		.flash_oe (flash_oe),
		.flash_do (flash_do),
		.flash_di (flash_di),

		.cfgreg_we(spimemio_cfgreg_sel ? cpu_wstrb : 4'b0000),
		.cfgreg_di(cpu_wdata),
		.cfgreg_do(spimemio_cfgreg_do)
	);
	end


	wire        simpleuart_reg_div_sel = cpu_valid && (cpu_addr == 32'h0200_0004);
	wire [31:0] simpleuart_reg_div_do;

	wire        simpleuart_reg_dat_sel = cpu_valid && (cpu_addr == 32'h0200_0008);
	wire [31:0] simpleuart_reg_dat_do;
	wire        simpleuart_reg_dat_wait;
	simpleuart simpleuart (
		.clk         (clk         ),
		.resetn      (resetn      ),

		.ser_tx      (ser_tx      ),
		.ser_rx      (ser_rx      ),

		.reg_div_we  (simpleuart_reg_div_sel ? cpu_wstrb : 4'b0000),
		.reg_div_di  (cpu_wdata),
		.reg_div_do  (simpleuart_reg_div_do),

		.reg_dat_we  (simpleuart_reg_dat_sel ? cpu_wstrb[0] : 1'b0),
		.reg_dat_re  (simpleuart_reg_dat_sel && !cpu_wstrb),
		.reg_dat_di  (cpu_wdata),
		.reg_dat_do  (simpleuart_reg_dat_do),
		.reg_dat_wait(simpleuart_reg_dat_wait)
	);


	wire gpio_ready;
	wire [31:0] gpio_rdata;
	gpio ugpio (
		.clk(clk),
		.resetn(resetn),
		.valid(cpu_valid && (cpu_addr[31:24] > 8'h01)),
		.ready(gpio_ready),
		.wen(cpu_wstrb),
		.addr (cpu_addr),
		.wdata(cpu_wdata),
		.rdata(gpio_rdata),
		.gpo (gpio)
	);


	assign cpu_ready = gpio_ready || rom_ready || ram_ready || spimemio_cfgreg_sel ||
			simpleuart_reg_div_sel || (simpleuart_reg_dat_sel && !simpleuart_reg_dat_wait);

	// data mux
	reg [5:0] mux_rdata;
	always @(*)
		mux_rdata <= {spimemio_cfgreg_sel,
					  simpleuart_reg_div_sel,
					  simpleuart_reg_dat_sel,
					  gpio_ready,
					  rom_ready,
					  ram_ready};

	always @(*)
		casez(mux_rdata)
			6'b1zzzzz: cpu_rdata <= spimemio_cfgreg_do;
			6'b01zzzz: cpu_rdata <= simpleuart_reg_div_do;
			6'b001zzz: cpu_rdata <= simpleuart_reg_dat_do;
			6'b0001zz: cpu_rdata <= gpio_rdata;
			6'b00001z: cpu_rdata <= rom_rdata;
			6'b000001: cpu_rdata <= ram_rdata;
			default: cpu_rdata <= 32'h0000_0000;
		endcase
endmodule