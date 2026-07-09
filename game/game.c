#include <stdint.h>

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
#define KEY_UP        0x75u
#define KEY_R         0x2du
#define KEY_ENTER     0x5au
#define KEY_BREAK     0xf0u
#define KEY_EXT       0xe0u

#define ACTION_JUMP   0x01u
#define ACTION_RESTART 0x02u

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

__attribute__((noinline)) static void delay(volatile unsigned int cycles)
{
    while (cycles != 0) {
        __asm__ volatile ("nop");
        cycles--;
    }
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

static void erase_game_over(void)
{
    unsigned int col;
    for (col = 32; col < 46; col++) {
        vga_blank(12, col);
    }
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

static void draw_dino(int y, unsigned char attr)
{
    int foot = GROUND_ROW - y;

    vga_put((unsigned int)(foot - 2), DINO_COL,     'o', attr);
    vga_put((unsigned int)(foot - 1), DINO_COL,     'D', attr);
    vga_put((unsigned int) foot,      DINO_COL,     '/', attr);
    vga_put((unsigned int) foot,      DINO_COL + 1, '\\', attr);
}

static void erase_dino(int y)
{
    int foot = GROUND_ROW - y;

    vga_blank((unsigned int)(foot - 2), DINO_COL);
    vga_blank((unsigned int)(foot - 1), DINO_COL);
    vga_blank((unsigned int) foot,      DINO_COL);
    vga_blank((unsigned int) foot,      DINO_COL + 1);
}

static void draw_obstacle(int x, int h, unsigned char attr)
{
    int i;

    if (x < 0 || x >= (int)VGA_COLS) {
        return;
    }

    for (i = 0; i < h; i++) {
        vga_put((unsigned int)(GROUND_ROW - i), (unsigned int)x, '#', attr);
    }
}

static void erase_obstacle(int x, int h)
{
    int i;

    if (x < 0 || x >= (int)VGA_COLS) {
        return;
    }

    for (i = 0; i < h; i++) {
        vga_blank((unsigned int)(GROUND_ROW - i), (unsigned int)x);
    }
}

static uint32_t lfsr_next(uint32_t value)
{
    uint32_t bit = ((value >> 0) ^ (value >> 2) ^ (value >> 3) ^ (value >> 5)) & 1u;
    return (value >> 1) | (bit << 15);
}

static unsigned int poll_input(unsigned int *break_pending, unsigned int *ext_pending)
{
    unsigned int action = 0;
    uint32_t sw_btn = mmio_read(MMIO_SW_BTN);
    uint32_t btn = (sw_btn >> 16) & 0x1fu;
    uint32_t ps2 = mmio_read(MMIO_PS2_KEY);

    if (btn != 0u) {
        action |= ACTION_JUMP;
    }

    if (((ps2 >> 8) & 1u) != 0u) {
        uint32_t key = ps2 & 0xffu;

        if (key == KEY_BREAK) {
            *break_pending = 1u;
        } else if (key == KEY_EXT) {
            *ext_pending = 1u;
        } else if (*break_pending != 0u) {
            *break_pending = 0u;
            *ext_pending = 0u;
        } else {
            if (key == KEY_SPACE || key == KEY_W || key == KEY_UP || *ext_pending != 0u) {
                action |= ACTION_JUMP;
            }
            if (key == KEY_R || key == KEY_ENTER) {
                action |= ACTION_RESTART;
            }
            *ext_pending = 0u;
        }
    }

    return action;
}

static unsigned int collides(int dino_y, int obs_x, int obs_h)
{
    int dino_top = GROUND_ROW - dino_y - 2;
    int dino_bottom = GROUND_ROW - dino_y;
    int obs_top = GROUND_ROW - obs_h + 1;
    int horizontal = (obs_x == DINO_COL) || (obs_x == (DINO_COL + 1));
    int vertical = !(dino_bottom < obs_top || dino_top > GROUND_ROW);

    return (unsigned int)(horizontal && vertical);
}

int main(void)
{
    int dino_y = 0;
    int dino_v = 0;
    int jumping = 0;
    int obstacle_x = 74;
    int obstacle_h = 3;
    int prev_dino_y = 0;
    int prev_obstacle_x = 74;
    int prev_obstacle_h = 3;
    unsigned int score0 = 0;
    unsigned int score1 = 0;
    unsigned int score2 = 0;
    unsigned int score3 = 0;
    unsigned int game_over = 0;
    unsigned int break_pending = 0;
    unsigned int ext_pending = 0;
    unsigned int speed_step = 0;
    uint32_t rnd = 0xace1u;

    clear_screen();
    draw_static_scene();
    draw_score(score3, score2, score1, score0);
    draw_dino(dino_y, ATTR_WHITE);
    draw_obstacle(obstacle_x, obstacle_h, ATTR_GREEN);

    for (;;) {
        unsigned int action = poll_input(&break_pending, &ext_pending);

        if (game_over != 0u) {
            if ((action & (ACTION_RESTART | ACTION_JUMP)) != 0u) {
                erase_game_over();
                erase_dino(dino_y);
                erase_obstacle(obstacle_x, obstacle_h);

                dino_y = 0;
                dino_v = 0;
                jumping = 0;
                obstacle_x = 74;
                obstacle_h = 3;
                prev_dino_y = dino_y;
                prev_obstacle_x = obstacle_x;
                prev_obstacle_h = obstacle_h;
                score0 = 0;
                score1 = 0;
                score2 = 0;
                score3 = 0;
                game_over = 0;
                speed_step = 0;

                draw_static_scene();
                draw_score(score3, score2, score1, score0);
                draw_dino(dino_y, ATTR_WHITE);
                draw_obstacle(obstacle_x, obstacle_h, ATTR_GREEN);
            }

            delay(120000u);
            continue;
        }

        if ((action & ACTION_JUMP) != 0u && jumping == 0) {
            jumping = 1;
            dino_v = 5;
        }

        prev_dino_y = dino_y;
        prev_obstacle_x = obstacle_x;
        prev_obstacle_h = obstacle_h;

        if (jumping != 0) {
            dino_y = dino_y + dino_v;
            dino_v = dino_v - 1;

            if (dino_y <= 0) {
                dino_y = 0;
                dino_v = 0;
                jumping = 0;
            }
        }

        obstacle_x = obstacle_x - 1;
        if (obstacle_x < 1) {
            rnd = lfsr_next(rnd);
            obstacle_x = 79;
            obstacle_h = 2 + (int)(rnd & 3u);
        }

        erase_dino(prev_dino_y);
        erase_obstacle(prev_obstacle_x, prev_obstacle_h);

        if (collides(dino_y, obstacle_x, obstacle_h) != 0u) {
            game_over = 1u;
            draw_dino(dino_y, ATTR_RED);
            draw_obstacle(obstacle_x, obstacle_h, ATTR_RED);
            draw_game_over();
            mmio_write(MMIO_LED, 0xffffu);
        } else {
            draw_dino(dino_y, ATTR_WHITE);
            draw_obstacle(obstacle_x, obstacle_h, ATTR_GREEN);
            score_tick(&score3, &score2, &score1, &score0);
            draw_score(score3, score2, score1, score0);
            mmio_write(MMIO_LED, (1u << (score0 & 0xfu)));
        }

        if (score0 == 0u && score1 == 0u) {
            speed_step++;
        }

        if (speed_step < 4u) {
            delay(220000u);
        } else if (speed_step < 8u) {
            delay(170000u);
        } else {
            delay(130000u);
        }
    }
}
