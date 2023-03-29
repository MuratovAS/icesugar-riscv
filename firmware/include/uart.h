
#ifndef UART_H
#define UART_H

#include <stdint.h>

union uart_stat {
	uint32_t value;
	struct { // \/
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

// registers
#define UART_DATA (*(volatile uint32_t*)0x02000008)
#define UART_STAT (*(volatile uint32_t*)0x02000004)

// union
#define UART_STAT_F ((union uart_stat)UART_STAT)

// bits
//#define UART_STAT_TX 0b00000001
//#define UART_STAT_RX 0b00000010

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