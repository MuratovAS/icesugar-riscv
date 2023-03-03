
#ifndef UART_H
#define UART_H

#include <stdint.h>

#define reg_uart_data (*(volatile uint32_t*)0x02000008)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)

void putchar(char c);
void print(const char *p);
void print_hex(uint32_t v, int digits);
void print_dec(uint32_t v);
char getchar_prompt(char *prompt);
char getchar();
void print_str(const char *p);
void print_chr(const char p);

#endif