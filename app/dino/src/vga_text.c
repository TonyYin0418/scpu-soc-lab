#include "vga_text.h"

#include "mmio.h"

static uint32_t vga_cell_address(uint32_t row, uint32_t col)
{
    /* row * 80 = row * 64 + row * 16，避免依赖 M 扩展。 */
    uint32_t cell = (row << 6) + (row << 4) + col;
    return MMIO_VGA_BASE + (cell << 2);
}

void vga_put(uint32_t row, uint32_t col, char ch, uint8_t attr)
{
    uint32_t value;

    if ((row >= VGA_TEXT_ROWS) || (col >= VGA_TEXT_COLS)) {
        return;
    }

    value = ((uint32_t)attr << 8) | (uint32_t)(uint8_t)ch;
    mmio_write32(vga_cell_address(row, col), value);
}

void vga_clear(uint8_t attr)
{
    uint32_t row;
    uint32_t col;

    for (row = 0u; row < VGA_TEXT_ROWS; ++row) {
        for (col = 0u; col < VGA_TEXT_COLS; ++col) {
            vga_put(row, col, ' ', attr);
        }
    }
}

void vga_fill_row(uint32_t row, char ch, uint8_t attr)
{
    uint32_t col;

    for (col = 0u; col < VGA_TEXT_COLS; ++col) {
        vga_put(row, col, ch, attr);
    }
}

void vga_write(uint32_t row, uint32_t col, const char *text, uint8_t attr)
{
    while ((*text != '\0') && (col < VGA_TEXT_COLS)) {
        vga_put(row, col, *text, attr);
        ++text;
        ++col;
    }
}

void vga_write_centered(uint32_t row, const char *text, uint8_t attr)
{
    uint32_t length = 0u;
    uint32_t col;

    while ((text[length] != '\0') && (length < VGA_TEXT_COLS)) {
        ++length;
    }

    col = (VGA_TEXT_COLS - length) >> 1;
    vga_write(row, col, text, attr);
}

void vga_write_digits(uint32_t row, uint32_t col, const uint8_t *digits,
                      uint32_t count, uint8_t attr)
{
    uint32_t index;

    for (index = 0u; index < count; ++index) {
        vga_put(row, col + index, (char)('0' + digits[index]), attr);
    }
}
