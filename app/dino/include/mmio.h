#ifndef DINO_MMIO_H
#define DINO_MMIO_H

#include <stdint.h>

#define MMIO_VGA_BASE      0xc0000000u
#define MMIO_PS2_KEY       0xd0000000u
#define MMIO_PS2_SCANCODE  0xd0000004u
#define MMIO_SEG7          0xe0000000u
#define MMIO_SWITCH_BUTTON 0xe0000000u
#define MMIO_LED           0xf0000000u

static inline void mmio_write32(uint32_t address, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)address = value;
}

static inline uint32_t mmio_read32(uint32_t address)
{
    return *(volatile uint32_t *)(uintptr_t)address;
}

#endif
