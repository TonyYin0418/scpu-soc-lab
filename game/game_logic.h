#ifndef DINO_GAME_LOGIC_H
#define DINO_GAME_LOGIC_H

static inline unsigned int game_collides(int ground_row, int dino_col,
                                         int dino_y, unsigned int crouching,
                                         int obstacle_x, int obstacle_height,
                                         unsigned int obstacle_is_bird)
{
    int dino_top = ground_row - dino_y - ((crouching != 0u) ? 1 : 2);
    int dino_bottom = ground_row - dino_y;
    int dino_right = dino_col + ((crouching != 0u) ? 2 : 1);
    int obstacle_right = obstacle_x + ((obstacle_is_bird != 0u) ? 1 : 0);
    int obstacle_top = (obstacle_is_bird != 0u) ?
                       (ground_row - 2) : (ground_row - obstacle_height + 1);
    int obstacle_bottom = (obstacle_is_bird != 0u) ?
                          (ground_row - 2) : ground_row;
    int horizontal = !(dino_right < obstacle_x || dino_col > obstacle_right);
    int vertical = !(dino_bottom < obstacle_top || dino_top > obstacle_bottom);

    return (unsigned int)(horizontal && vertical);
}

#endif
