
#ifndef UART_H
#define UART_H

#include <stdint.h>

// registers
#define UART_DATA (*(volatile uint32_t*)0x02000008)
#define UART_STAT (*(volatile uint32_t*)0x02000004)

// bits
#define UART_STAT_TXE 0b00000001
#define UART_STAT_RXF 0b00000010

void putchar(char c);
void print(const char *p);
void print_hex(uint32_t v, int digits);
void print_dec(uint32_t v);
char getchar_prompt(char *prompt);
char getchar();
void print_str(const char *p);
void print_chr(const char p);

#endif