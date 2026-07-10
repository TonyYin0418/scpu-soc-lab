#include "keyboard.h"

#include "mmio.h"

#define PS2_READY_MASK 0x00000100u
#define PS2_CODE_MASK  0x000000ffu

#define KEY_BREAK 0xf0u
#define KEY_EXT   0xe0u
#define KEY_SPACE 0x29u
#define KEY_W     0x1du
#define KEY_UP    0x75u
#define KEY_R     0x2du
#define KEY_ENTER 0x5au

void keyboard_reset(keyboard_state_t *state)
{
    state->break_pending = 0u;
    state->extended_pending = 0u;
}

uint32_t keyboard_poll(keyboard_state_t *state)
{
    uint32_t action = INPUT_NONE;
    uint32_t switch_button = mmio_read32(MMIO_SWITCH_BUTTON);
    uint32_t ps2 = mmio_read32(MMIO_PS2_KEY);
    uint8_t code;

    if (((switch_button >> 16) & 0x1fu) != 0u) {
        action |= INPUT_JUMP | INPUT_START;
    }

    if ((ps2 & PS2_READY_MASK) == 0u) {
        return action;
    }

    code = (uint8_t)(ps2 & PS2_CODE_MASK);
    if (code == KEY_BREAK) {
        state->break_pending = 1u;
        return action;
    }
    if (code == KEY_EXT) {
        state->extended_pending = 1u;
        return action;
    }

    if (state->break_pending != 0u) {
        state->break_pending = 0u;
        state->extended_pending = 0u;
        return action;
    }

    if ((code == KEY_SPACE) || (code == KEY_W) ||
        ((code == KEY_UP) && (state->extended_pending != 0u))) {
        action |= INPUT_JUMP | INPUT_START;
    }
    if ((code == KEY_R) || (code == KEY_ENTER)) {
        action |= INPUT_RESTART | INPUT_START;
    }

    state->extended_pending = 0u;
    return action;
}
