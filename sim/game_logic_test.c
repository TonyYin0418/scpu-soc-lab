#include <stdio.h>

#include "../game/game_logic.h"

static int failures;

static void check(const char *name, unsigned int actual, unsigned int expected)
{
    if (actual != expected) {
        fprintf(stderr, "[GAME_LOGIC][FAIL] %s actual=%u expected=%u\n",
                name, actual, expected);
        failures++;
    }
}

int main(void)
{
    const int ground = 49;
    const int dino_col = 10;

    check("standing hits cactus",
          game_collides(ground, dino_col, 0, 0, 10, 3, 0), 1);
    check("jump clears cactus",
          game_collides(ground, dino_col, 4, 0, 10, 3, 0), 0);
    check("standing hits low bird",
          game_collides(ground, dino_col, 0, 0, 10, 2, 1), 1);
    check("crouch clears low bird",
          game_collides(ground, dino_col, 0, 1, 10, 2, 1), 0);
    check("crouch still hits cactus",
          game_collides(ground, dino_col, 0, 1, 12, 2, 0), 1);
    check("offscreen obstacle does not hit",
          game_collides(ground, dino_col, 0, 0, 20, 3, 0), 0);

    if (failures != 0)
        return 1;

    puts("[GAME_LOGIC][PASS] standing, crouching, jumping and obstacle boxes");
    return 0;
}
