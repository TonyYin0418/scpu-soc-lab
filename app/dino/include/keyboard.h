#ifndef DINO_KEYBOARD_H
#define DINO_KEYBOARD_H

#include <stdint.h>

#define INPUT_NONE    0x00u
#define INPUT_JUMP    0x01u
#define INPUT_RESTART 0x02u
#define INPUT_START   0x04u

typedef struct {
    uint8_t break_pending;
    uint8_t extended_pending;
} keyboard_state_t;

void keyboard_reset(keyboard_state_t *state);
uint32_t keyboard_poll(keyboard_state_t *state);

#endif
