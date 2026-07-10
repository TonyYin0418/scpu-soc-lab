#include <stdint.h>
#include "game_logic.h"

#define MMIO_VGA      0xC0000000u
#define MMIO_SEG7     0xE0000000u
#define MMIO_SW_BTN   0xE0000000u
#define MMIO_LED      0xF0000000u
#define MMIO_PS2_KEY  0xD0000000u
#define MMIO_PS2_LOG  0xD0000004u

#define VGA_COLS      80u
#define VGA_ROWS      60u
#define GROUND_ROW    49
#define DINO_COL      10
#define ATTR_DIM      0x70u
#define ATTR_WHITE    0xffu
#define ATTR_GREEN    0xaau
#define ATTR_YELLOW   0xeeu
#define ATTR_RED      0xccu
#define ATTR_CYAN     0xbbu

#define KEY_SPACE     0x29u
#define KEY_W         0x1du
#define KEY_S         0x1bu
#define KEY_UP        0x75u
#define KEY_DOWN      0x72u
#define KEY_R         0x2du
#define KEY_P         0x4du
#define KEY_ENTER     0x5au
#define KEY_BREAK     0xf0u
#define KEY_EXT       0xe0u

#define ACTION_JUMP   0x01u
#define ACTION_RESTART 0x02u
#define ACTION_PAUSE  0x04u

#define GLYPH_DINO_TL 0x01u
#define GLYPH_DINO_TR 0x02u
#define GLYPH_DINO_ML 0x03u
#define GLYPH_DINO_MR 0x04u
#define GLYPH_DINO_LL 0x05u
#define GLYPH_DINO_LR 0x06u
#define GLYPH_DUCK_TL 0x07u
#define GLYPH_DUCK_TM 0x08u
#define GLYPH_DUCK_TR 0x09u
#define GLYPH_DUCK_LL 0x0au
#define GLYPH_DUCK_LM 0x0bu
#define GLYPH_DUCK_LR 0x0cu
#define GLYPH_CACTUS_T 0x0du
#define GLYPH_CACTUS_B 0x0eu
#define GLYPH_BIRD_L   0x0fu
#define GLYPH_BIRD_R   0x10u

#define OBSTACLE_CACTUS 0u
#define OBSTACLE_BIRD   1u

#define STATE_READY     0u
#define STATE_RUNNING   1u
#define STATE_PAUSED    2u
#define STATE_GAME_OVER 3u

typedef struct {
    uint32_t scan_log;
    unsigned int break_pending;
    unsigned int ext_pending;
    unsigned int jump_held;
    unsigned int crouch_held;
    unsigned int button_held;
    unsigned int actions;
} InputState;

static InputState input;

static inline void mmio_write(uint32_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

static inline uint32_t mmio_read(uint32_t addr)
{
    return *(volatile uint32_t *)addr;
}

static inline uint32_t vga_cell_addr(unsigned int row, unsigned int col)
{
    uint32_t cell = ((uint32_t)row << 6) + ((uint32_t)row << 4) + (uint32_t)col;
    return MMIO_VGA + (cell << 2);
}

static inline void vga_put(unsigned int row, unsigned int col, unsigned char ch, unsigned char attr)
{
    mmio_write(vga_cell_addr(row, col), ((uint32_t)attr << 8) | (uint32_t)ch);
}

static inline void vga_blank(unsigned int row, unsigned int col)
{
    vga_put(row, col, ' ', 0x00u);
}

static void draw_word_dino(void)
{
    vga_put(2, 31, 'D', ATTR_CYAN);
    vga_put(2, 32, 'I', ATTR_CYAN);
    vga_put(2, 33, 'N', ATTR_CYAN);
    vga_put(2, 34, 'O', ATTR_CYAN);
    vga_put(2, 36, 'R', ATTR_CYAN);
    vga_put(2, 37, 'U', ATTR_CYAN);
    vga_put(2, 38, 'N', ATTR_CYAN);
    vga_put(2, 39, 'N', ATTR_CYAN);
    vga_put(2, 40, 'E', ATTR_CYAN);
    vga_put(2, 41, 'R', ATTR_CYAN);
}

static void draw_instructions(void)
{
    vga_put(4, 21, 'S', ATTR_DIM);
    vga_put(4, 22, 'P', ATTR_DIM);
    vga_put(4, 23, 'A', ATTR_DIM);
    vga_put(4, 24, 'C', ATTR_DIM);
    vga_put(4, 25, 'E', ATTR_DIM);
    vga_put(4, 27, 'J', ATTR_DIM);
    vga_put(4, 28, 'U', ATTR_DIM);
    vga_put(4, 29, 'M', ATTR_DIM);
    vga_put(4, 30, 'P', ATTR_DIM);
    vga_put(4, 34, 'R', ATTR_DIM);
    vga_put(4, 36, 'R', ATTR_DIM);
    vga_put(4, 37, 'E', ATTR_DIM);
    vga_put(4, 38, 'S', ATTR_DIM);
    vga_put(4, 39, 'T', ATTR_DIM);
    vga_put(4, 40, 'A', ATTR_DIM);
    vga_put(4, 41, 'R', ATTR_DIM);
    vga_put(4, 42, 'T', ATTR_DIM);
    vga_put(4, 46, 'S', ATTR_DIM);
    vga_put(4, 48, 'D', ATTR_DIM);
    vga_put(4, 49, 'U', ATTR_DIM);
    vga_put(4, 50, 'C', ATTR_DIM);
    vga_put(4, 51, 'K', ATTR_DIM);
    vga_put(5, 34, 'P', ATTR_DIM);
    vga_put(5, 36, 'P', ATTR_DIM);
    vga_put(5, 37, 'A', ATTR_DIM);
    vga_put(5, 38, 'U', ATTR_DIM);
    vga_put(5, 39, 'S', ATTR_DIM);
    vga_put(5, 40, 'E', ATTR_DIM);
}

static void draw_game_over(void)
{
    vga_put(12, 34, 'G', ATTR_RED);
    vga_put(12, 35, 'A', ATTR_RED);
    vga_put(12, 36, 'M', ATTR_RED);
    vga_put(12, 37, 'E', ATTR_RED);
    vga_put(12, 39, 'O', ATTR_RED);
    vga_put(12, 40, 'V', ATTR_RED);
    vga_put(12, 41, 'E', ATTR_RED);
    vga_put(12, 42, 'R', ATTR_RED);
}

static void clear_state_text(void)
{
    unsigned int col;

    for (col = 33; col < 44; col++) {
        vga_blank(12, col);
    }
}

static void draw_ready(void)
{
    clear_state_text();
    vga_put(12, 35, 'R', ATTR_YELLOW);
    vga_put(12, 36, 'E', ATTR_YELLOW);
    vga_put(12, 37, 'A', ATTR_YELLOW);
    vga_put(12, 38, 'D', ATTR_YELLOW);
    vga_put(12, 39, 'Y', ATTR_YELLOW);
}

static void draw_paused(void)
{
    clear_state_text();
    vga_put(12, 35, 'P', ATTR_CYAN);
    vga_put(12, 36, 'A', ATTR_CYAN);
    vga_put(12, 37, 'U', ATTR_CYAN);
    vga_put(12, 38, 'S', ATTR_CYAN);
    vga_put(12, 39, 'E', ATTR_CYAN);
    vga_put(12, 40, 'D', ATTR_CYAN);
}

static void clear_screen(void)
{
    unsigned int row;
    unsigned int col;

    for (row = 0; row < VGA_ROWS; row++) {
        for (col = 0; col < VGA_COLS; col++) {
            vga_blank(row, col);
        }
    }
}

static void draw_static_scene(void)
{
    unsigned int col;

    draw_word_dino();
    draw_instructions();

    vga_put(0, 2, 'S', ATTR_WHITE);
    vga_put(0, 3, 'C', ATTR_WHITE);
    vga_put(0, 4, 'O', ATTR_WHITE);
    vga_put(0, 5, 'R', ATTR_WHITE);
    vga_put(0, 6, 'E', ATTR_WHITE);
    vga_put(0, 7, ':', ATTR_WHITE);

    for (col = 0; col < VGA_COLS; col++) {
        vga_put(GROUND_ROW + 1, col, '-', ATTR_GREEN);
    }
}

static void draw_score(unsigned int d3, unsigned int d2, unsigned int d1, unsigned int d0)
{
    vga_put(0, 9,  (unsigned char)('0' + d3), ATTR_YELLOW);
    vga_put(0, 10, (unsigned char)('0' + d2), ATTR_YELLOW);
    vga_put(0, 11, (unsigned char)('0' + d1), ATTR_YELLOW);
    vga_put(0, 12, (unsigned char)('0' + d0), ATTR_YELLOW);

    mmio_write(MMIO_SEG7, (d3 << 12) | (d2 << 8) | (d1 << 4) | d0);
}

static void score_tick(unsigned int *d3, unsigned int *d2, unsigned int *d1, unsigned int *d0)
{
    *d0 = *d0 + 1u;
    if (*d0 == 10u) {
        *d0 = 0u;
        *d1 = *d1 + 1u;
        if (*d1 == 10u) {
            *d1 = 0u;
            *d2 = *d2 + 1u;
            if (*d2 == 10u) {
                *d2 = 0u;
                *d3 = *d3 + 1u;
                if (*d3 == 10u) {
                    *d3 = 0u;
                }
            }
        }
    }
}

static void draw_dino(int y, unsigned int crouching, unsigned char attr)
{
    int foot = GROUND_ROW - y;

    if (crouching != 0u) {
        vga_put((unsigned int)(foot - 1), DINO_COL,     GLYPH_DUCK_TL, attr);
        vga_put((unsigned int)(foot - 1), DINO_COL + 1, GLYPH_DUCK_TM, attr);
        vga_put((unsigned int)(foot - 1), DINO_COL + 2, GLYPH_DUCK_TR, attr);
        vga_put((unsigned int) foot,      DINO_COL,     GLYPH_DUCK_LL, attr);
        vga_put((unsigned int) foot,      DINO_COL + 1, GLYPH_DUCK_LM, attr);
        vga_put((unsigned int) foot,      DINO_COL + 2, GLYPH_DUCK_LR, attr);
    } else {
        vga_put((unsigned int)(foot - 2), DINO_COL,     GLYPH_DINO_TL, attr);
        vga_put((unsigned int)(foot - 2), DINO_COL + 1, GLYPH_DINO_TR, attr);
        vga_put((unsigned int)(foot - 1), DINO_COL,     GLYPH_DINO_ML, attr);
        vga_put((unsigned int)(foot - 1), DINO_COL + 1, GLYPH_DINO_MR, attr);
        vga_put((unsigned int) foot,      DINO_COL,     GLYPH_DINO_LL, attr);
        vga_put((unsigned int) foot,      DINO_COL + 1, GLYPH_DINO_LR, attr);
    }
}

static void erase_dino(int y, unsigned int crouching)
{
    int foot = GROUND_ROW - y;
    int rows = (crouching != 0u) ? 2 : 3;
    int cols = (crouching != 0u) ? 3 : 2;
    int row;
    int col;

    for (row = 0; row < rows; row++) {
        for (col = 0; col < cols; col++) {
            vga_blank((unsigned int)(foot - row), (unsigned int)(DINO_COL + col));
        }
    }
}

static void draw_obstacle(int x, int h, unsigned int type, unsigned char attr)
{
    int i;

    if (type == OBSTACLE_BIRD) {
        if (x >= 0 && x < (int)VGA_COLS) {
            vga_put(GROUND_ROW - 2, (unsigned int)x, GLYPH_BIRD_L, attr);
        }
        if (x + 1 >= 0 && x + 1 < (int)VGA_COLS) {
            vga_put(GROUND_ROW - 2, (unsigned int)(x + 1), GLYPH_BIRD_R, attr);
        }
    } else if (x >= 0 && x < (int)VGA_COLS) {
        for (i = 0; i < h; i++) {
            unsigned char glyph = (i == h - 1) ? GLYPH_CACTUS_T : GLYPH_CACTUS_B;
            vga_put((unsigned int)(GROUND_ROW - i), (unsigned int)x, glyph, attr);
        }
    }
}

static void erase_obstacle(int x, int h, unsigned int type)
{
    int i;

    if (type == OBSTACLE_BIRD) {
        if (x >= 0 && x < (int)VGA_COLS) {
            vga_blank(GROUND_ROW - 2, (unsigned int)x);
        }
        if (x + 1 >= 0 && x + 1 < (int)VGA_COLS) {
            vga_blank(GROUND_ROW - 2, (unsigned int)(x + 1));
        }
    } else if (x >= 0 && x < (int)VGA_COLS) {
        for (i = 0; i < h; i++) {
            vga_blank((unsigned int)(GROUND_ROW - i), (unsigned int)x);
        }
    }
}

static uint32_t lfsr_next(uint32_t value)
{
    uint32_t bit = ((value >> 0) ^ (value >> 2) ^ (value >> 3) ^ (value >> 5)) & 1u;
    return (value >> 1) | (bit << 15);
}

static void process_scan_code(InputState *input, unsigned int key)
{
    unsigned int released;
    unsigned int extended;
    unsigned int is_jump;
    unsigned int is_crouch;

    if (key == KEY_EXT) {
        input->ext_pending = 1u;
        return;
    }
    if (key == KEY_BREAK) {
        input->break_pending = 1u;
        return;
    }

    released = input->break_pending;
    extended = input->ext_pending;
    input->break_pending = 0u;
    input->ext_pending = 0u;

    is_jump = ((extended == 0u) && (key == KEY_SPACE || key == KEY_W)) ||
              ((extended != 0u) && key == KEY_UP);
    is_crouch = ((extended == 0u) && key == KEY_S) ||
                ((extended != 0u) && key == KEY_DOWN);

    if (is_jump != 0u) {
        if (released != 0u) {
            input->jump_held = 0u;
        } else if (input->jump_held == 0u) {
            input->jump_held = 1u;
            input->actions |= ACTION_JUMP;
        }
    } else if (is_crouch != 0u) {
        input->crouch_held = (released == 0u);
    } else if (released == 0u && extended == 0u) {
        if (key == KEY_R || key == KEY_ENTER) {
            input->actions |= ACTION_RESTART;
        } else if (key == KEY_P) {
            input->actions |= ACTION_PAUSE;
        }
    }
}

static void poll_input(InputState *input)
{
    uint32_t sw_btn = mmio_read(MMIO_SW_BTN);
    uint32_t btn = (sw_btn >> 16) & 0x1fu;
    uint32_t log;

    (void)mmio_read(MMIO_PS2_KEY);
    log = mmio_read(MMIO_PS2_LOG);

    if (btn != 0u && input->button_held == 0u) {
        input->actions |= ACTION_JUMP;
    }
    input->button_held = (btn != 0u);

    // 读取 KEY 会确认 ready；扫描日志则给每个已确认字节提供稳定的变化标志。
    // 因而同一按键不会因 MMIO 读时序重复处理，未知扫描码也不会触发动作。
    if (log != input->scan_log) {
        input->scan_log = log;
        process_scan_code(input, log & 0xffu);
    }
}

static unsigned int take_actions(InputState *input)
{
    unsigned int actions = input->actions;

    input->actions = 0u;
    return actions;
}

static void wait_for_frame(InputState *input, unsigned int polls)
{
    while (polls != 0u) {
        poll_input(input);
        polls--;
    }
}

int main(void)
{
    int dino_y = 0;
    int dino_v = 0;
    int jumping = 0;
    int obstacle_x = 74;
    int obstacle_h = 3;
    int prev_dino_y = 0;
    int prev_obstacle_x = obstacle_x;
    int prev_obstacle_h = obstacle_h;
    unsigned int crouching = 0;
    unsigned int prev_crouching = 0;
    unsigned int obstacle_type = OBSTACLE_CACTUS;
    unsigned int prev_obstacle_type = OBSTACLE_CACTUS;
    unsigned int score0 = 0;
    unsigned int score1 = 0;
    unsigned int score2 = 0;
    unsigned int score3 = 0;
    unsigned int state = STATE_READY;
    unsigned int speed_step = 0;
    uint32_t rnd = 0xace1u;
    input.scan_log = mmio_read(MMIO_PS2_LOG);

    clear_screen();
    draw_static_scene();
    draw_score(score3, score2, score1, score0);
    draw_dino(dino_y, crouching, ATTR_WHITE);
    draw_obstacle(obstacle_x, obstacle_h, obstacle_type, ATTR_GREEN);
    draw_ready();

    for (;;) {
        unsigned int action;

        poll_input(&input);
        action = take_actions(&input);

        if ((action & ACTION_RESTART) != 0u ||
            (state == STATE_GAME_OVER && (action & ACTION_JUMP) != 0u)) {
            dino_y = 0;
            dino_v = 0;
            jumping = 0;
            crouching = 0u;
            obstacle_x = 74;
            obstacle_h = 3;
            obstacle_type = OBSTACLE_CACTUS;
            score0 = 0;
            score1 = 0;
            score2 = 0;
            score3 = 0;
            state = STATE_READY;
            speed_step = 0;
            input.actions = 0u;

            clear_screen();
            draw_static_scene();
            draw_score(score3, score2, score1, score0);
            draw_dino(dino_y, crouching, ATTR_WHITE);
            draw_obstacle(obstacle_x, obstacle_h, obstacle_type, ATTR_GREEN);
            draw_ready();
            mmio_write(MMIO_LED, 0u);
            wait_for_frame(&input, 10000u);
            continue;
        }

        if (state == STATE_READY) {
            if ((action & ACTION_JUMP) == 0u) {
                wait_for_frame(&input, 10000u);
                continue;
            }
            state = STATE_RUNNING;
            clear_state_text();
        } else if ((action & ACTION_PAUSE) != 0u) {
            if (state == STATE_RUNNING) {
                state = STATE_PAUSED;
                draw_paused();
            } else if (state == STATE_PAUSED) {
                state = STATE_RUNNING;
                clear_state_text();
            }
        }

        if (state == STATE_PAUSED || state == STATE_GAME_OVER) {
            wait_for_frame(&input, 10000u);
            continue;
        }

        if ((action & ACTION_JUMP) != 0u && jumping == 0 && crouching == 0u) {
            jumping = 1;
            dino_v = 5;
        }

        prev_dino_y = dino_y;
        prev_crouching = crouching;
        if (jumping != 0) {
            dino_y = dino_y + dino_v;
            dino_v = dino_v - 1;
            if (input.crouch_held != 0u && dino_y > 0) {
                dino_v = dino_v - 1;
            }

            if (dino_y <= 0) {
                dino_y = 0;
                dino_v = 0;
                jumping = 0;
            }
        }
        crouching = (unsigned int)(jumping == 0 && input.crouch_held != 0u);

        prev_obstacle_x = obstacle_x;
        prev_obstacle_h = obstacle_h;
        prev_obstacle_type = obstacle_type;
        obstacle_x = obstacle_x - 1;
        if (obstacle_x < -1) {
            rnd = lfsr_next(rnd);
            obstacle_x = 79 + (int)(rnd & 15u);
            obstacle_type = (rnd >> 4) & 1u;
            obstacle_h = 2 + (int)((rnd >> 5) & 1u);
        }

        erase_dino(prev_dino_y, prev_crouching);
        erase_obstacle(prev_obstacle_x, prev_obstacle_h, prev_obstacle_type);

        if (game_collides(GROUND_ROW, DINO_COL, dino_y, crouching,
                          obstacle_x, obstacle_h, obstacle_type) != 0u) {
            state = STATE_GAME_OVER;
            draw_dino(dino_y, crouching, ATTR_RED);
            draw_obstacle(obstacle_x, obstacle_h, obstacle_type, ATTR_RED);
            clear_state_text();
            draw_game_over();
            mmio_write(MMIO_LED, 0xffffu);
        } else {
            draw_dino(dino_y, crouching, ATTR_WHITE);
            draw_obstacle(obstacle_x, obstacle_h, obstacle_type,
                          (obstacle_type == OBSTACLE_BIRD) ? ATTR_CYAN : ATTR_GREEN);
            score_tick(&score3, &score2, &score1, &score0);
            draw_score(score3, score2, score1, score0);
            mmio_write(MMIO_LED, (1u << (score0 & 0xfu)));
        }

        if (score0 == 0u && score1 == 0u) {
            speed_step++;
        }

        if (speed_step < 4u) {
            wait_for_frame(&input, 120000u);
        } else if (speed_step < 8u) {
            wait_for_frame(&input, 90000u);
        } else {
            wait_for_frame(&input, 65000u);
        }
    }
}
