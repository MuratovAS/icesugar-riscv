#ifndef SPIMEMIO_H
#define SPIMEMIO_H

#include <stdint.h>

#define reg_spictrl (*(volatile uint32_t*)0x02000000)

uint8_t cmd_read_flash_reg(uint8_t cmd);
void enable_flash_crm();
void set_flash_mode_qddr();
void set_flash_mode_quad();
void set_flash_mode_dual();
void set_flash_mode_spi();
void set_flash_qspi_flag();
void flashio(uint8_t *data, int len, uint8_t wrencmd);

#endif