#define SPIROM
#define MEM_TOTAL 0x20000 /* 128 KB */

#ifdef SPIROM
	#include "spimem.h"
#endif
#include "main.h"
#include "uart.h"
//#include "irq.h"

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_leds (*(volatile uint32_t*)0x03000000)

uint32_t xorshift32(uint32_t *state)
{
	/* Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs" */
	uint32_t x = *state;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	*state = x;

	return x;
}

void cmd_memtest()
{
	int cyc_count = 5;
	int stride = 256;
	uint32_t state;

	volatile uint32_t *base_word = (uint32_t *) 0;
	volatile uint8_t *base_byte = (uint8_t *) 0;

	print("Running memtest ");

	// Walk in stride increments, word access
	for (int i = 1; i <= cyc_count; i++) {
		state = i;

		for (int word = 0; word < MEM_TOTAL / sizeof(int); word += stride) {
			*(base_word + word) = xorshift32(&state);
		}

		state = i;

		for (int word = 0; word < MEM_TOTAL / sizeof(int); word += stride) {
			if (*(base_word + word) != xorshift32(&state)) {
				print(" ***FAILED WORD*** at ");
				print_hex(4*word, 4);
				print("\n\r");
				return;
			}
		}

		print(".");
	}

	// Byte access
	for (int byte = 0; byte < 128; byte++) {
		*(base_byte + byte) = (uint8_t) byte;
	}

	for (int byte = 0; byte < 128; byte++) {
		if (*(base_byte + byte) != (uint8_t) byte) {
			print(" ***FAILED BYTE*** at ");
			print_hex(byte, 4);
			print("\n\r");
			return;
		}
	}
	print(" passed\n\r");
}

uint32_t cmd_benchmark(bool verbose, uint32_t *instns_p)
{
	uint8_t data[256];
	uint32_t *words = (void*)data;

	uint32_t x32 = 314159265;

	uint32_t cycles_begin, cycles_end;
	uint32_t instns_begin, instns_end;
	__asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));
	__asm__ volatile ("rdinstret %0" : "=r"(instns_begin));

	for (int i = 0; i < 20; i++)
	{
		for (int k = 0; k < 256; k++)
		{
			x32 ^= x32 << 13;
			x32 ^= x32 >> 17;
			x32 ^= x32 << 5;
			data[k] = x32;
		}

		for (int k = 0, p = 0; k < 256; k++)
		{
			if (data[k])
				data[p++] = k;
		}

		for (int k = 0, p = 0; k < 64; k++)
		{
			x32 = x32 ^ words[k];
		}
	}

	__asm__ volatile ("rdcycle %0" : "=r"(cycles_end));
	__asm__ volatile ("rdinstret %0" : "=r"(instns_end));

	if (verbose)
	{
		print("Cycles: 0x");
		print_hex(cycles_end - cycles_begin, 8);
		print("\n\r");

		print("Instns: 0x");
		print_hex(instns_end - instns_begin, 8);
		print("\n\r");

		print("Chksum: 0x");
		print_hex(x32, 8);
		print("\n\r");
	}

	if (instns_p)
		*instns_p = instns_end - instns_begin;

	return cycles_end - cycles_begin;
}

#ifdef SPIROM
void cmd_read_flash_id()
{
	uint8_t buffer[17] = { 0x9F, /* zeros */ };
	flashio(buffer, 17, 0);

	for (int i = 1; i <= 16; i++) {
		putchar(' ');
		print_hex(buffer[i], 2);
	}
	print("\n\r");
}

void cmd_print_spi_state()
{
	print("SPI State:\n\r");

	print("  LATENCY ");
	print_dec((reg_spictrl >> 16) & 15);
	print("\n\r");

	print("  DDR ");
	if ((reg_spictrl & (1 << 22)) != 0)
		print("ON\n\r");
	else
		print("OFF\n\r");

	print("  QSPI ");
	if ((reg_spictrl & (1 << 21)) != 0)
		print("ON\n\r");
	else
		print("OFF\n\r");

	print("  CRM ");
	if ((reg_spictrl & (1 << 20)) != 0)
		print("ON\n\r");
	else
		print("OFF\n\r");
}

void print_reg_bit(int val, const char *name)
{
	for (int i = 0; i < 12; i++) {
		if (*name == 0)
			putchar(' ');
		else
			putchar(*(name++));
	}

	putchar(val ? '1' : '0');
	print("\n\r");
}

void cmd_read_flash_regs()
{
	print("\n\r");

	uint8_t sr1 = cmd_read_flash_reg(0x05);
	uint8_t sr2 = cmd_read_flash_reg(0x35);
	uint8_t sr3 = cmd_read_flash_reg(0x15);

	print_reg_bit(sr1 & 0x01, "S0  (BUSY)");
	print_reg_bit(sr1 & 0x02, "S1  (WEL)");
	print_reg_bit(sr1 & 0x04, "S2  (BP0)");
	print_reg_bit(sr1 & 0x08, "S3  (BP1)");
	print_reg_bit(sr1 & 0x10, "S4  (BP2)");
	print_reg_bit(sr1 & 0x20, "S5  (TB)");
	print_reg_bit(sr1 & 0x40, "S6  (SEC)");
	print_reg_bit(sr1 & 0x80, "S7  (SRP)");
	print("\n\r");

	print_reg_bit(sr2 & 0x01, "S8  (SRL)");
	print_reg_bit(sr2 & 0x02, "S9  (QE)");
	print_reg_bit(sr2 & 0x04, "S10 ----");
	print_reg_bit(sr2 & 0x08, "S11 (LB1)");
	print_reg_bit(sr2 & 0x10, "S12 (LB2)");
	print_reg_bit(sr2 & 0x20, "S13 (LB3)");
	print_reg_bit(sr2 & 0x40, "S14 (CMP)");
	print_reg_bit(sr2 & 0x80, "S15 (SUS)");
	print("\n\r");

	print_reg_bit(sr3 & 0x01, "S16 ----");
	print_reg_bit(sr3 & 0x02, "S17 ----");
	print_reg_bit(sr3 & 0x04, "S18 (WPS)");
	print_reg_bit(sr3 & 0x08, "S19 ----");
	print_reg_bit(sr3 & 0x10, "S20 ----");
	print_reg_bit(sr3 & 0x20, "S21 (DRV0)");
	print_reg_bit(sr3 & 0x40, "S22 (DRV1)");
	print_reg_bit(sr3 & 0x80, "S23 (HOLD)");
	print("\n\r");
}
#endif

static void stats_print_dec(unsigned int val, int digits, bool zero_pad)
{
	char buffer[32];
	char *p = buffer;
	while (val || digits > 0) {
		if (val)
			*(p++) = '0' + val % 10;
		else
			*(p++) = zero_pad ? '0' : ' ';
		val = val / 10;
		digits--;
	}
	while (p != buffer) {
		if (p[-1] == ' ' && p[-2] == ' ') p[-1] = '.';
		putchar(*(--p));
	}
}

void stats(void)
{
	unsigned int num_cycles, num_instr;
	__asm__ volatile ("rdcycle %0; rdinstret %1;" : "=r"(num_cycles), "=r"(num_instr));
	print("Cycle counter ........");
	stats_print_dec(num_cycles, 8, false);
	print("\n\rInstruction counter ..");
	stats_print_dec(num_instr, 8, false);
	print("\n\rCPI: ");
	stats_print_dec((num_cycles / num_instr), 0, false);
	print(".");
	stats_print_dec(((100 * num_cycles) / num_instr) % 100, 2, true);
	print("\n\r");

}

void cmd_echo()
{
	print("Return to menu by sending '!'\n\r\n\r");
	char c;
	while ((c = getchar()) != '!')
		putchar(c);
}

void main()
{
	reg_leds = 0b0000000000000001;

	print("Booting..\n\r");

	reg_leds = 0b0000000000000010;

	#ifdef SPIROM
	set_flash_qspi_flag();
	#endif

	while(1)
	{
		print_dec(UART_STAT_F.pointerTail_RX);putchar('/');
		print_dec(UART_STAT_F.pointerHead_RX);putchar('/');
		print_dec(UART_STAT_F.pointerTail_TX);putchar('/');
		print_dec(UART_STAT_F.pointerHead_TX);putchar('/');
		print_dec(UART_STAT_F.pointerEqualN_RX);putchar('/');
		print_dec(UART_STAT_F.pointerEqualN_TX);putchar('/');
		print_dec(UART_STAT_F.overflow_RX);putchar('/');
		print_dec(UART_STAT_F.overflow_TX);putchar('/');
		putchar(getchar());putchar('\n');
	}

	char tmp;
	while (print("Press ENTER to continue..\n\r"), tmp = getchar(), tmp != '\n') 
	/*{
		putchar(tmp); putchar(' '); 
		print_dec(UART_STAT_RING_HEAD); putchar(' '); 
		print_dec(UART_STAT_RING_TAIL); putchar(' '); 
	}*/
	
	reg_leds = 0b0000000000000100;

	print("\n\r");
	print("  ____  _          ____         ____\n\r");
	print(" |  _ \\(_) ___ ___/ ___|  ___  / ___|\n\r");
	print(" | |_) | |/ __/ _ \\___ \\ / _ \\| |\n\r");
	print(" |  __/| | (_| (_) |__) | (_) | |___\n\r");
	print(" |_|   |_|\\___\\___/____/ \\___/ \\____|\n\r");
	print("\n\r");

	print("Total memory: ");
	print_dec(MEM_TOTAL / 1024);
	print(" KiB\n\r");
	print("\n\r");

	while (1)
	{
		print("\n\r");

		print("Select an action:\n\r");
		print("\n\r");

		#ifdef SPIROM
		print("   [1] Read SPI Flash ID\n\r");
		print("   [2] Read SPI Config Regs\n\r");
		print("   [3] Switch to default mode\n\r");
		print("   [4] Switch to Dual I/O mode\n\r");
		print("   [5] Switch to Quad I/O mode\n\r");
		print("   [6] Switch to Quad DDR mode\n\r");
		print("   [7] Toggle continuous read mode\n\r");
		print("   [S] Print SPI state\n\r");
		#endif
		print("   [b] Run benchmark\n\r");
		print("   [m] Run Memtest\n\r");
		print("   [e] Echo UART\n\r");
		print("   [s] Stats\n\r");
		print("\n\r");

		for (int rep = 10; rep > 0; rep--)
		{
			print("Command> ");
			char cmd = getchar();
			if (cmd > 32 && cmd < 127)
				putchar(cmd);
			print("\n\r");

			switch (cmd)
			{
		#ifdef SPIROM
			case '1':
				cmd_read_flash_id();
				break;
			case '2':
				cmd_read_flash_regs();
				break;
			case '3':
				set_flash_mode_spi();
				break;
			case '4':
				set_flash_mode_dual();
				break;
			case '5':
				set_flash_mode_quad();
				break;
			case '6':
				set_flash_mode_qddr();
				break;
			case '7':
				reg_spictrl = reg_spictrl ^ 0x00100000;
				break;
			case 'S':
				cmd_print_spi_state();
				break;
		#endif
			case 'b':
				cmd_benchmark(true, 0);
				break;
			case 'm':
				cmd_memtest();
				break;
			case 'e':
				cmd_echo();
				break;
			case 's':
				stats();
				break;
			default:
				continue;
			}
			break;
		}
	}
}
