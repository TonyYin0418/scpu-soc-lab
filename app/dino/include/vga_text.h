#ifndef DINO_VGA_TEXT_H
#define DINO_VGA_TEXT_H

#include <stdint.h>

#define VGA_TEXT_COLS 80u
#define VGA_TEXT_ROWS 60u

#define VGA_ATTR_BLACK  0x00u
#define VGA_ATTR_DIM    0x70u
#define VGA_ATTR_GREEN  0xaau
#define VGA_ATTR_CYAN   0xbbu
#define VGA_ATTR_RED    0xccu
#define VGA_ATTR_YELLOW 0xeeu
#define VGA_ATTR_WHITE  0xffu

void vga_put(uint32_t row, uint32_t col, char ch, uint8_t attr);
void vga_clear(uint8_t attr);
void vga_fill_row(uint32_t row, char ch, uint8_t attr);
void vga_write(uint32_t row, uint32_t col, const char *text, uint8_t attr);
void vga_write_centered(uint32_t row, const char *text, uint8_t attr);
void vga_write_digits(uint32_t row, uint32_t col, const uint8_t *digits,
                      uint32_t count, uint8_t attr);

#endif
