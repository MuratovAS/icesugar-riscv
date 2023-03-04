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
`include "src/picosoc.v"

module top (
	`ifdef SIM
	input clk,
	`endif

	output uart_tx,
	input uart_rx,

	output LED_R,
	output LED_G,
	output LED_B,

	output flash_csb,
	output flash_clk,
	inout  flash_io0,
	inout  flash_io1,
	inout  flash_io2,
	inout  flash_io3
);
	wire clk_48m;
	wire clk_12m;

	`ifndef SIM
	//internal oscillators seen as modules
	//Source = 48MHz, CLKHF_DIV = 2’b00 : 00 = div1, 01 = div2, 10 = div4, 11 = div8 ; Default = “00”
	//SB_HFOSC SB_HFOSC_inst(
	SB_HFOSC #(.CLKHF_DIV("0b10")) SB_HFOSC_inst (
		.CLKHFEN(32'b1),
		.CLKHFPU(32'b1),
		.CLKHF(clk_12m)
	);
	`else
		assign clk_12m = clk;
	`endif

	//10khz used for low power applications (or sleep mode)
	/*SB_LFOSC SB_LFOSC_inst(
		.CLKLFEN(1),
		.CLKLFPU(1),
		.CLKLF(clk_10k)
	);*/
	
	// toolchain-ice40/bin/icepll
	/*SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b0001111),
      .DIVQ(3'b101),
      .FILTER_RANGE(3'b100),
    ) SB_PLL40_CORE_inst (
      .RESETB(1'b1),
      .BYPASS(1'b0),
      .PLLOUTCORE(clk_48m),
      .REFERENCECLK(clk_12m)
   );*/

	// sys
	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;

	always @(posedge clk_12m) begin
		reset_cnt <= reset_cnt + !resetn;
	end

	// gpio
	wire [7:0] leds;
	assign LED_R = leds[1];
	assign LED_G = leds[2];
	assign LED_B = leds[3];

	// spi flash
	wire flash_io0_oe, flash_io0_do, flash_io0_di;
	wire flash_io1_oe, flash_io1_do, flash_io1_di;
	wire flash_io2_oe, flash_io2_do, flash_io2_di;
	wire flash_io3_oe, flash_io3_do, flash_io3_di;

	SB_IO #(
		.PIN_TYPE(6'b 1010_01),
		.PULLUP(1'b 0)
	) flash_io_buf [3:0] (
		.PACKAGE_PIN({flash_io3, flash_io2, flash_io1, flash_io0}),
		.OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
		.D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
		.D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
	);

	// uart
	wire	txpin, rxpin;
	wire	rxpinmeta1,c_rxpinmeta1;
	SB_IO #( .PIN_TYPE(6'b000000)) // NO_OUTPUT/INPUT_REGISTERED
	IO_rx     ( .PACKAGE_PIN(uart_rx), .INPUT_CLK(clk_12m),  .D_IN_0(rxpinmeta1) );
	SB_LUT4 #( .LUT_INIT(16'haaaa))
		cmb( .O(c_rxpinmeta1), .I3(1'b0), .I2(1'b0), .I1(1'b0), .I0(rxpinmeta1));
	SB_DFF metareg( .Q(rxpin), .C(clk_12m), .D(c_rxpinmeta1));
	SB_IO #( .PIN_TYPE(6'b011111)) // OUTPUT_REGISTERED_INVERTED/INPUT_LATCH
		IO_tx( .PACKAGE_PIN(uart_tx), .OUTPUT_CLK(clk_12m), .D_OUT_0(txpin) );

	picosoc soc (
		.clk          (clk_12m         ),
		.resetn       (resetn      ),

		.ser_tx       (txpin      ),
		.ser_rx       (rxpin      ),

		.flash_csb    (flash_csb   ),
		.flash_clk    (flash_clk   ),

		.flash_oe ({flash_io3_oe,flash_io2_oe,flash_io1_oe,flash_io0_oe}),
		.flash_do ({flash_io3_do,flash_io2_do,flash_io1_do,flash_io0_do}),
		.flash_di ({flash_io3_di,flash_io2_di,flash_io1_di,flash_io0_di}),

		.irq_5        (1'b0        ),
		.irq_6        (1'b0        ),
		.irq_7        (1'b0        ),

		.gpio  ({LED_B,LED_G,LED_R})
	);
endmodule
