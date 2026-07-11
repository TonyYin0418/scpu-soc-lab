/* VGA 恐龙游戏。
 *
 * 硬件约定（全部为板级系统既有 MMIO，详见 MANUAL.md）：
 *   0xC0000000 + (row*80+col)*4  VGA 文本显存，写 {属性[15:8], ASCII[7:0]}
 *   0xD0000000                   读 {23'b0, ps2_ready, ps2_key}，读后清 ready
 *   0xE0000000                   写数码管 / 读 {11'b0, BTN[4:0], SW[15:0]}
 *   0xF0000000                   SPIO：低 2 位锁存 Counter_x 通道选择
 *   0xF0000004                   Counter_x 写入口（通道 0..2 计数值 / 3 控制字）
 *   0xFFFFFF00                   INTMASK，bit6 = 允许计时中断
 *
 * 帧驱动：Counter_x 通道 0 周期模式产生计时中断，ISR（start.S）只递增
 * ticks；主循环检测 ticks 变化推进一帧，逻辑不放 ISR，画面状态不会被
 * 中断打断在中间态。约束：rv32i 无乘除法器，不使用变量乘除。
 *
 * 玩法：恐龙固定在第 8 列，仙人掌从右往左移动，按任意按钮或 PS/2 空格
 * 起跳（固定跳跃弧线表）。跳过仙人掌 +1 分，撞上显示 GAME OVER，再按
 * 一次跳跃键重新开始。
 */

#define VRAM_BASE    0xC0000000u
#define PS2_ADDR     0xD0000000u
#define SEG7_ADDR    0xE0000000u
#define SWBTN_ADDR   0xE0000000u
#define SPIO_ADDR    0xF0000000u
#define COUNTER_ADDR 0xF0000004u
#define INTMASK_ADDR 0xFFFFFF00u

#define MMIO(addr) (*(volatile unsigned int *)(addr))

#define COLS        80
#define ROWS        60
#define ATTR_WHITE  0xFF00u

#define GROUND_ROW  40
#define DINO_COL    8

#define SCORE_ROW   1
#define SCORE_COL   66
#define SCORE_DIGITS 5

/* 帧率：clk0 = 781.25 kHz。板上 26042 拍 ≈ 30 Hz；
 * 仿真等不起 3.3M 周期一帧，SW[14]=1 时改用 100 拍 ≈ 128 us 一帧
 * （每帧游戏逻辑 + 刷新带重画约 4k CPU 周期，100 拍留足余量）。 */
#define FRAME_TICKS_BOARD 26042u
#define FRAME_TICKS_SIM   100u

volatile unsigned int ticks; /* 由计时中断 ISR 递增（start.S） */

/* ------------------------------------------------------------------ */
/* 游戏状态（全部 .bss，复位为 0）                                       */
/* ------------------------------------------------------------------ */

/* 跳跃弧线：起跳后每帧的离地行数，走完落地。30 Hz 下约 0.5 s 一跳。 */
static const unsigned char jump_arc[] = {
    2, 3, 4, 5, 6, 6, 6, 6, 5, 4, 3, 2, 1, 0
};
#define ARC_LEN ((unsigned int)sizeof(jump_arc))

static unsigned int air_frame;   /* 0 = 在地面；1..ARC_LEN = 弧线第几帧 */

#define MAX_OBS 4
static unsigned char obs_col[MAX_OBS];  /* 仙人掌所在列；0 = 空槽 */
static unsigned char obs_h[MAX_OBS];    /* 高度 1 或 2 */
static unsigned int  spawn_wait;        /* 距下一次生成还差几帧 */
static unsigned int  lfsr;              /* 16 位 Galois LFSR 伪随机 */

static unsigned char score_digits[SCORE_DIGITS];
static unsigned int  ps2_skip;          /* 1 = 上一字节是 0xF0（断码前缀） */
static unsigned int  btn_prev;          /* 按钮上一帧电平，用于取按下沿 */
static unsigned int  prev_off;          /* 恐龙上一帧离地高度，用于增量擦除 */

/* ------------------------------------------------------------------ */
/* 基础输出                                                             */
/* ------------------------------------------------------------------ */

static void vram_put(unsigned int row, unsigned int col, char ch)
{
    MMIO(VRAM_BASE + ((row * COLS + col) << 2)) = ATTR_WHITE | (unsigned char)ch;
}

static void vram_text(unsigned int row, unsigned int col, const char *s)
{
    while (*s)
        vram_put(row, col++, *s++);
}

static void clear_screen(void)
{
    unsigned int cell;

    for (cell = 0; cell < ROWS * COLS; cell++)
        MMIO(VRAM_BASE + (cell << 2)) = ATTR_WHITE | ' ';
}

/* ------------------------------------------------------------------ */
/* 外设                                                                 */
/* ------------------------------------------------------------------ */

/* 按老师 Counter_8253 的两步协议编程通道 0 为周期中断源。 */
static void timer_init(unsigned int period)
{
    MMIO(SPIO_ADDR) = 3u;        /* 通道选择 = 3：控制字 */
    MMIO(COUNTER_ADDR) = 0x2u;   /* 通道 0 模式 01：减到 0 发一拍脉冲并重装 */
    MMIO(SPIO_ADDR) = 0u;        /* 通道选择 = 0：计数值 */
    MMIO(COUNTER_ADDR) = period;
    MMIO(INTMASK_ADDR) = 0x40u;  /* 允许计时中断；写入同时清杂散 pending */
}

/* PS/2 空格按下事件。断码 F0 xx 表示松开：跳过 F0 后的下一个字节。 */
static unsigned int ps2_space_event(void)
{
    unsigned int v = MMIO(PS2_ADDR);
    unsigned int code = v & 0xFFu;

    if (!(v & 0x100u))
        return 0;
    if (ps2_skip) {
        ps2_skip = 0;
        return 0;
    }
    if (code == 0xF0u) {
        ps2_skip = 1;
        return 0;
    }
    return code == 0x29u;        /* 空格通码 */
}

/* 跳跃指令：任一按钮的按下沿，或 PS/2 空格通码事件。 */
static unsigned int jump_pressed(void)
{
    unsigned int btn = (MMIO(SWBTN_ADDR) >> 16) & 0x1Fu;
    unsigned int edge = btn & ~btn_prev;

    btn_prev = btn;
    return (edge != 0) | ps2_space_event();
}

/* ------------------------------------------------------------------ */
/* 计分：手工十进制进位，避免除法                                        */
/* ------------------------------------------------------------------ */

static void score_draw(void)
{
    unsigned int i;

    for (i = 0; i < SCORE_DIGITS; i++)
        vram_put(SCORE_ROW, SCORE_COL + i, (char)('0' + score_digits[i]));
}

static void score_add1(void)
{
    int i;

    for (i = SCORE_DIGITS - 1; i >= 0; i--) {
        if (score_digits[i] < 9) {
            score_digits[i]++;
            break;
        }
        score_digits[i] = 0;
    }
    score_draw();
}

/* ------------------------------------------------------------------ */
/* 世界更新                                                             */
/* ------------------------------------------------------------------ */

/* 增量渲染：每帧只擦/画真正变化的格子（每个仙人掌 4 格、恐龙 4 格），
 * 不整片清屏重画。整带重画会让每帧大部分时间处于"已擦除未重画"状态，
 * 移动物体在屏幕上闪烁。 */
static void obstacle_draw(unsigned int i)
{
    vram_put(GROUND_ROW - 1, obs_col[i], '#');
    if (obs_h[i] == 2)
        vram_put(GROUND_ROW - 2, obs_col[i], '#');
}

static void obstacle_erase(unsigned int i)
{
    vram_put(GROUND_ROW - 1, obs_col[i], ' ');
    vram_put(GROUND_ROW - 2, obs_col[i], ' ');
}

static void obstacles_step(void)
{
    unsigned int i;

    for (i = 0; i < MAX_OBS; i++) {
        if (obs_col[i] == 0)
            continue;
        obstacle_erase(i);
        obs_col[i]--;
        if (obs_col[i] == 0) {
            score_add1();        /* 移出左边界 = 安全跳过 */
            continue;
        }
        obstacle_draw(i);
    }

    if (spawn_wait) {
        spawn_wait--;
        return;
    }
    for (i = 0; i < MAX_OBS; i++) {
        if (obs_col[i] != 0)
            continue;
        /* Galois LFSR，抽头 0xB400（教材标准 16 位最大长度序列） */
        lfsr = (lfsr >> 1) ^ ((0u - (lfsr & 1u)) & 0xB400u);
        obs_col[i] = COLS - 1;
        obs_h[i] = 1 + (lfsr & 1u);
        spawn_wait = 24 + (lfsr & 15u);  /* 间隔 24..39 帧，必大于跳跃时长 */
        obstacle_draw(i);
        break;
    }
}

static unsigned int dino_offset(void)
{
    return air_frame ? jump_arc[air_frame - 1] : 0;
}

static unsigned int collided(void)
{
    unsigned int off = dino_offset();
    unsigned int i;

    /* 恐龙占 {G-2-off, G-1-off} 两行，仙人掌占地面往上 h 行：
     * 同列且离地高度小于仙人掌高度即相撞。 */
    for (i = 0; i < MAX_OBS; i++)
        if ((obs_col[i] == DINO_COL) && (off < obs_h[i]))
            return 1;
    return 0;
}

/* 恐龙：高度变化时擦旧位置，然后总是重画。总是重画是为了盖住仙人掌
 * 擦除路过恐龙所在列时留下的空格。恐龙画在最后，视觉上位于最上层。 */
static void dino_draw(void)
{
    unsigned int off = dino_offset();

    if (off != prev_off) {
        vram_put(GROUND_ROW - 2 - prev_off, DINO_COL, ' ');
        vram_put(GROUND_ROW - 1 - prev_off, DINO_COL, ' ');
        prev_off = off;
    }
    vram_put(GROUND_ROW - 2 - off, DINO_COL, 'D');
    vram_put(GROUND_ROW - 1 - off, DINO_COL, 'D');
}

/* ------------------------------------------------------------------ */
/* 关卡流程                                                             */
/* ------------------------------------------------------------------ */

static void game_reset(void)
{
    unsigned int i;

    for (i = 0; i < MAX_OBS; i++)
        obs_col[i] = 0;
    for (i = 0; i < SCORE_DIGITS; i++)
        score_digits[i] = 0;
    air_frame = 0;
    prev_off = 0;
    spawn_wait = 30;

    clear_screen();
    for (i = 0; i < COLS; i++)
        vram_put(GROUND_ROW, i, '=');
    vram_text(1, 2, "DINO GAME");
    vram_text(SCORE_ROW, SCORE_COL - 6, "SCORE ");
    score_draw();
    dino_draw();
}

static void wait_next_tick(unsigned int *last)
{
    unsigned int now;

    do {
        now = ticks;
    } while (now == *last);
    *last = now;
    MMIO(SEG7_ADDR) = now;       /* 数码管显示帧号，作运行心跳 */
}

int main(void)
{
    unsigned int last_tick = 0;
    unsigned int sw = MMIO(SWBTN_ADDR);

    lfsr = 0xACE1u;
    game_reset();
    timer_init((sw & (1u << 14)) ? FRAME_TICKS_SIM : FRAME_TICKS_BOARD);

    for (;;) {
        wait_next_tick(&last_tick);

        if (jump_pressed() && (air_frame == 0))
            air_frame = 1;       /* 只能在地面起跳 */
        else if (air_frame) {
            air_frame++;
            if (air_frame > ARC_LEN)
                air_frame = 0;   /* 弧线走完，落地 */
        }

        obstacles_step();
        dino_draw();

        if (collided()) {
            vram_text(20, 34, "GAME OVER");
            vram_text(22, 29, "PRESS JUMP TO RESTART");
            do {
                wait_next_tick(&last_tick);
            } while (!jump_pressed());
            game_reset();
        }
    }
    return 0;
}
