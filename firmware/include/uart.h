
#ifndef UART_H
#define UART_H

#include <stdint.h>

#define RINGUART

// type
#ifdef RINGUART
union uart_stat {
	uint32_t value;
	struct {
		uint32_t pointerTail_RX		:7;
		uint32_t pointerHead_RX		:7;
		uint32_t pointerTail_TX		:7;
		uint32_t pointerHead_TX		:7;
		uint32_t pointerEqualN_RX	:1;
		uint32_t pointerEqualN_TX	:1;
        uint32_t overflow_RX		:1;
		uint32_t overflow_TX		:1;
	};
};
#endif

// registers
#define UART_DATA (*(volatile uint32_t*)0x02000008)
#define UART_STAT (*(volatile uint32_t*)0x02000004)

// bits
#ifdef RINGUART
#define UART_STAT_F ((union uart_stat)UART_STAT)
#else
#define UART_STAT_TX 0b00000001
#define UART_STAT_RX 0b00000010
#endif

// func
void putchar(char c);
void print(const char *p);
void print_hex(uint32_t v, int digits);
void print_dec(uint32_t v);
char getchar_prompt(char *prompt);
char getchar();
void print_str(const char *p);
void print_chr(const char p);

#endif