/* 恐龙游戏（骨架阶段）。
 *
 * 硬件约定（全部为板级系统既有 MMIO，详见 MANUAL.md）：
 *   0xC0000000 + (row*80+col)*4  VGA 文本显存，写 {属性[15:8], ASCII[7:0]}
 *   0xE0000000                   写数码管 / 读 {11'b0, BTN[4:0], SW[15:0]}
 *   0xF0000000                   SPIO：低 2 位锁存 Counter_x 通道选择
 *   0xF0000004                   Counter_x 写入口（通道 0..2 计数值 / 3 控制字）
 *   0xFFFFFF00                   INTMASK，bit6 = 允许计时中断
 *
 * 帧驱动：Counter_x 通道 0 周期模式产生计时中断，ISR（start.S）只递增
 * ticks；主循环检测 ticks 变化推进一帧。约束：rv32i 无乘除法器，代码中
 * 不使用变量乘除（常量乘法由编译器转成移位加法）。
 */

#define VRAM_BASE   0xC0000000u
#define SEG7_ADDR   0xE0000000u
#define SWBTN_ADDR  0xE0000000u
#define SPIO_ADDR   0xF0000000u
#define COUNTER_ADDR 0xF0000004u
#define INTMASK_ADDR 0xFFFFFF00u

#define MMIO(addr) (*(volatile unsigned int *)(addr))

#define COLS        80
#define ROWS        60
#define ATTR_WHITE  0xFF00u

#define GROUND_ROW  40
#define DINO_COL    8

/* 帧率：clk0 = 781.25 kHz。板上 26042 拍 ≈ 30 Hz；
 * 仿真等不起 3.3M 周期一帧，SW[14]=1 时改用 40 拍 ≈ 51.2 us 一帧。 */
#define FRAME_TICKS_BOARD 26042u
#define FRAME_TICKS_SIM   40u

volatile unsigned int ticks; /* 由计时中断 ISR 递增（start.S） */

static void vram_put(unsigned int row, unsigned int col, char ch)
{
    MMIO(VRAM_BASE + ((row * COLS + col) << 2)) = ATTR_WHITE | (unsigned char)ch;
}

static void vram_text(unsigned int row, unsigned int col, const char *s)
{
    while (*s)
        vram_put(row, col++, *s++);
}

static unsigned int read_swbtn(void)
{
    return MMIO(SWBTN_ADDR);
}

/* 按老师 Counter_8253 的两步协议编程通道 0 为周期中断源。 */
static void timer_init(unsigned int period)
{
    MMIO(SPIO_ADDR) = 3u;        /* 通道选择 = 3：控制字 */
    MMIO(COUNTER_ADDR) = 0x2u;   /* 通道 0 模式 01：减到 0 发一拍脉冲并重装 */
    MMIO(SPIO_ADDR) = 0u;        /* 通道选择 = 0：计数值 */
    MMIO(COUNTER_ADDR) = period;
    MMIO(INTMASK_ADDR) = 0x40u;  /* 允许计时中断；写入同时清杂散 pending */
}

static void clear_screen(void)
{
    unsigned int cell;

    for (cell = 0; cell < ROWS * COLS; cell++)
        MMIO(VRAM_BASE + (cell << 2)) = ATTR_WHITE | ' ';
}

static void draw_static_screen(void)
{
    unsigned int col;

    clear_screen();
    for (col = 0; col < COLS; col++)
        vram_put(GROUND_ROW, col, '=');

    vram_text(1, 2, "DINO GAME");
    vram_text(1, 60, "SCORE 00000");

    /* 骨架阶段的恐龙：站在地面上的两格占位 */
    vram_put(GROUND_ROW - 2, DINO_COL, 'D');
    vram_put(GROUND_ROW - 1, DINO_COL, 'D');
}

int main(void)
{
    static const char spinner[4] = {'|', '/', '-', '\\'};
    unsigned int last_tick = 0;
    unsigned int sw = read_swbtn();

    draw_static_screen();
    timer_init((sw & (1u << 14)) ? FRAME_TICKS_SIM : FRAME_TICKS_BOARD);

    for (;;) {
        unsigned int now = ticks;
        if (now == last_tick)
            continue;
        last_tick = now;

        /* 帧心跳：数码管显示 tick 数，屏幕右上角转一个字符 */
        MMIO(SEG7_ADDR) = now;
        vram_put(1, 78, spinner[now & 3u]);
    }
    return 0;
}
