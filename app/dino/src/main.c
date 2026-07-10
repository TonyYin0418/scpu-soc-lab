#include <stdint.h>

#include "keyboard.h"
#include "mmio.h"
#include "vga_text.h"

static void delay_cycles(volatile uint32_t cycles)
{
    while (cycles != 0u) {
        __asm__ volatile ("nop");
        --cycles;
    }
}

int main(void)
{
    keyboard_state_t keyboard;

    keyboard_reset(&keyboard);
    vga_clear(VGA_ATTR_BLACK);
    vga_write_centered(27u, "SCPU DINO BOOT OK", VGA_ATTR_CYAN);
    vga_write_centered(29u, "PRESS SPACE TO CONTINUE", VGA_ATTR_WHITE);
    mmio_write32(MMIO_SEG7, 0xd1000000u);

    for (;;) {
        if ((keyboard_poll(&keyboard) & INPUT_START) != 0u) {
            vga_write_centered(31u, "INPUT OK", VGA_ATTR_GREEN);
            mmio_write32(MMIO_SEG7, 0xd1000001u);
        }
        delay_cycles(2000u);
    }
}
