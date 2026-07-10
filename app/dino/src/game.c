#include "game.h"

#include <stdint.h>

#include "keyboard.h"
#include "mmio.h"
#include "vga_text.h"

#define GROUND_ROW         50
#define GROUND_LINE_ROW    51u
#define DINO_COL           10
#define OBSTACLE_START_COL 76
#define SCORE_DIGITS       5u
#define TEST_MODE_SWITCH   0x00004000u

typedef struct {
    int32_t dino_height;
    int32_t dino_velocity;
    int32_t obstacle_col;
    uint32_t obstacle_height;
    uint32_t random;
    uint32_t test_mode;
    uint8_t score[SCORE_DIGITS];
} game_state_t;

static void delay_cycles(volatile uint32_t cycles)
{
    while (cycles != 0u) {
        __asm__ volatile ("nop");
        --cycles;
    }
}

static void score_reset(game_state_t *game)
{
    uint32_t index;

    for (index = 0u; index < SCORE_DIGITS; ++index) {
        game->score[index] = 0u;
    }
}

static void score_increment(game_state_t *game)
{
    int32_t index = (int32_t)SCORE_DIGITS - 1;

    while (index >= 0) {
        game->score[index] = (uint8_t)(game->score[index] + 1u);
        if (game->score[index] < 10u) {
            return;
        }
        game->score[index] = 0u;
        --index;
    }
}

static uint32_t score_bcd(const game_state_t *game)
{
    uint32_t value = 0u;
    uint32_t index;

    for (index = 0u; index < SCORE_DIGITS; ++index) {
        value = (value << 4) | game->score[index];
    }
    return value;
}

static void draw_score(const game_state_t *game)
{
    vga_write_digits(1u, 7u, game->score, SCORE_DIGITS, VGA_ATTR_YELLOW);
    mmio_write32(MMIO_SEG7, score_bcd(game));
}

static uint32_t random_next(uint32_t value)
{
    uint32_t bit = ((value >> 0) ^ (value >> 2) ^
                    (value >> 3) ^ (value >> 5)) & 1u;
    return (value >> 1) | (bit << 15);
}

static void draw_dino(int32_t height, uint8_t attr)
{
    uint32_t foot = (uint32_t)(GROUND_ROW - height);

    vga_put(foot - 2u, (uint32_t)DINO_COL, 'o', attr);
    vga_put(foot - 1u, (uint32_t)DINO_COL, 'D', attr);
    vga_put(foot, (uint32_t)DINO_COL, '/', attr);
    vga_put(foot, (uint32_t)(DINO_COL + 1), '\\', attr);
}

static void erase_dino(int32_t height)
{
    draw_dino(height, VGA_ATTR_BLACK);
}

static void draw_obstacle(int32_t col, uint32_t height, uint8_t attr)
{
    uint32_t offset;

    if ((col < 0) || (col >= (int32_t)VGA_TEXT_COLS)) {
        return;
    }

    for (offset = 0u; offset < height; ++offset) {
        vga_put((uint32_t)GROUND_ROW - offset, (uint32_t)col, '#', attr);
    }
}

static void erase_obstacle(int32_t col, uint32_t height)
{
    draw_obstacle(col, height, VGA_ATTR_BLACK);
}

static uint32_t collision(const game_state_t *game)
{
    int32_t dino_top = GROUND_ROW - game->dino_height - 2;
    int32_t dino_bottom = GROUND_ROW - game->dino_height;
    int32_t obstacle_top = GROUND_ROW - (int32_t)game->obstacle_height + 1;
    uint32_t horizontal = (uint32_t)((game->obstacle_col == DINO_COL) ||
                                     (game->obstacle_col == (DINO_COL + 1)));
    uint32_t vertical = (uint32_t)!((dino_bottom < obstacle_top) ||
                                    (dino_top > GROUND_ROW));
    return horizontal & vertical;
}

static void draw_title(void)
{
    vga_clear(VGA_ATTR_BLACK);
    vga_write_centered(10u, "================================", VGA_ATTR_DIM);
    vga_write_centered(12u, "SCPU DINO RUNNER", VGA_ATTR_CYAN);
    vga_write_centered(14u, "================================", VGA_ATTR_DIM);

    vga_write(20u, 34u, "  __", VGA_ATTR_WHITE);
    vga_write(21u, 34u, " /oo\\", VGA_ATTR_WHITE);
    vga_write(22u, 34u, "/___/", VGA_ATTR_WHITE);
    vga_write(23u, 34u, "  /\\", VGA_ATTR_WHITE);

    vga_write_centered(31u, "SPACE / W / UP : START AND JUMP", VGA_ATTR_WHITE);
    vga_write_centered(33u, "R / ENTER      : RESTART", VGA_ATTR_DIM);
    vga_write_centered(38u, "PRESS SPACE TO START", VGA_ATTR_YELLOW);
    mmio_write32(MMIO_SEG7, 0xd1000000u);
    mmio_write32(MMIO_LED, 0x0001u);
}

static void draw_static_scene(void)
{
    vga_write(1u, 1u, "SCORE:", VGA_ATTR_WHITE);
    vga_write(1u, 61u, "SPACE/W/UP=JUMP", VGA_ATTR_DIM);
    vga_fill_row(GROUND_LINE_ROW, '=', VGA_ATTR_GREEN);
    vga_write_centered(56u, "SCPU RV32I  |  PS/2 + VGA TEXT MODE", VGA_ATTR_DIM);
}

static void game_reset(game_state_t *game)
{
    game->dino_height = 0;
    game->dino_velocity = 0;
    game->test_mode = mmio_read32(MMIO_SWITCH_BUTTON) & TEST_MODE_SWITCH;
    game->obstacle_col = (game->test_mode != 0u) ? 14 : OBSTACLE_START_COL;
    game->obstacle_height = 3u;
    game->random = 0xace1u;
    score_reset(game);
}

static void draw_round(game_state_t *game)
{
    vga_clear(VGA_ATTR_BLACK);
    draw_static_scene();
    draw_score(game);
    draw_dino(game->dino_height, VGA_ATTR_WHITE);
    draw_obstacle(game->obstacle_col, game->obstacle_height, VGA_ATTR_GREEN);
    mmio_write32(MMIO_LED, 0x0002u);
}

static void update_motion(game_state_t *game, uint32_t action)
{
    if (((action & INPUT_JUMP) != 0u) && (game->dino_height == 0)) {
        game->dino_velocity = 3;
    }

    if ((game->dino_height != 0) || (game->dino_velocity != 0)) {
        game->dino_height += game->dino_velocity;
        game->dino_velocity -= 1;
        if (game->dino_height <= 0) {
            game->dino_height = 0;
            game->dino_velocity = 0;
        }
    }

    game->obstacle_col -= 1;
    if (game->obstacle_col < -12) {
        game->random = random_next(game->random);
        game->obstacle_col = OBSTACLE_START_COL;
        game->obstacle_height = 2u + (game->random & 0x3u);
    }
}

static uint32_t frame_delay(const game_state_t *game)
{
    if (game->test_mode != 0u) {
        return 2000u;
    }
    if ((game->score[0] != 0u) || (game->score[1] >= 2u)) {
        return 90000u;
    }
    if ((game->score[1] != 0u) || (game->score[2] >= 5u)) {
        return 125000u;
    }
    return 170000u;
}

static void draw_game_over(const game_state_t *game)
{
    draw_dino(game->dino_height, VGA_ATTR_RED);
    draw_obstacle(game->obstacle_col, game->obstacle_height, VGA_ATTR_RED);
    vga_write_centered(24u, "+--------------------------+", VGA_ATTR_RED);
    vga_write_centered(25u, "|        GAME OVER         |", VGA_ATTR_RED);
    vga_write_centered(26u, "| SPACE/R/ENTER TO RESTART |", VGA_ATTR_RED);
    vga_write_centered(27u, "+--------------------------+", VGA_ATTR_RED);
    vga_write(29u, 34u, "SCORE:", VGA_ATTR_WHITE);
    vga_write_digits(29u, 41u, game->score, SCORE_DIGITS, VGA_ATTR_YELLOW);
    mmio_write32(MMIO_LED, 0xffffu);
}

static void wait_for_start(keyboard_state_t *keyboard)
{
    for (;;) {
        if ((keyboard_poll(keyboard) & INPUT_START) != 0u) {
            return;
        }
        delay_cycles(3000u);
    }
}

static void wait_for_restart(keyboard_state_t *keyboard)
{
    for (;;) {
        uint32_t action = keyboard_poll(keyboard);
        if ((action & (INPUT_START | INPUT_RESTART | INPUT_JUMP)) != 0u) {
            return;
        }
        delay_cycles(5000u);
    }
}

void game_run(void)
{
    game_state_t game;
    keyboard_state_t keyboard;

    keyboard_reset(&keyboard);
    draw_title();
    wait_for_start(&keyboard);

    for (;;) {
        game_reset(&game);
        keyboard_reset(&keyboard);
        draw_round(&game);

        for (;;) {
            int32_t old_dino_height = game.dino_height;
            int32_t old_obstacle_col = game.obstacle_col;
            uint32_t old_obstacle_height = game.obstacle_height;
            uint32_t action = keyboard_poll(&keyboard);

            if ((action & INPUT_RESTART) != 0u) {
                break;
            }

            update_motion(&game, action);
            erase_dino(old_dino_height);
            erase_obstacle(old_obstacle_col, old_obstacle_height);

            if (collision(&game) != 0u) {
                draw_game_over(&game);
                wait_for_restart(&keyboard);
                break;
            }

            draw_dino(game.dino_height, VGA_ATTR_WHITE);
            draw_obstacle(game.obstacle_col, game.obstacle_height, VGA_ATTR_GREEN);
            score_increment(&game);
            draw_score(&game);
            mmio_write32(MMIO_LED, 1u << (game.score[4] & 0xfu));
            delay_cycles(frame_delay(&game));
        }
    }
}
