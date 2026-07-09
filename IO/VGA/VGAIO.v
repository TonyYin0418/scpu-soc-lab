`timescale 1ns / 1ps

// 老师提供的 VGAIO 模块，整理为 UTF-8 注释版本，逻辑尽量保持原样。
//
// 当前工程同时使用两个路径：
// - Test 输入通道：强制输出固定颜色，排查 VGA 线缆、管脚和同步；
// - VRAM/字库路径：显示 CPU 可写文本显存，为后续软件/游戏输出做准备。
module VGAIO(
    input             clk,
    input             rst,
    input      [15:0] VRAMOUT,  // 文本 VRAM 读数据
    input      [12:0] Pixel,    // 图形像素输入：en_RRRR_GGGG_BBBB
    input      [13:0] Test,     // 测试显示输入：enable/control + RGB
    input      [31:0] Din,      // 显示控制寄存器数据
    input      [3:0]  Regaddr,  // 保留：显示寄存器地址
    input      [12:0] Cursor,   // 硬件光标地址
    input             Blink,    // 光标闪烁信号

    output     [8:0]  row,
    output     [9:0]  col,
    output     [3:0]  R,
    output     [3:0]  G,
    output     [3:0]  B,
    output reg        HSYNC,
    output reg        VSYNC,
    output     [12:0] VRAMA,    // 文本 VRAM 地址
    output            rdn       // VRAM 读使能，低有效
);

    wire [11:0] pixel_in = Pixel[11:0];
    wire [11:0] TEST_D   = Test[11:0];
    wire        pixel_en = Pixel[12];
    wire        TESTEN   = Test[12] && Test[13];

    wire        h_sync;
    wire        v_sync;
    wire        read;
    wire [15:0] Font16out;
    wire [7:0]  Font8out;

    reg [11:0] Pixels;
    reg [3:0]  red;
    reg [3:0]  green;
    reg [3:0]  blue;
    reg [15:0] VRAM_BUF;
    reg [31:0] MODE = 32'h4000_0001; // 默认 640x480，8x8 文本模式

    // 当前只保持老师原行为：每周期写入显示模式寄存器。
    // Regaddr 暂未使用，后续若做多个 VGA 寄存器再扩展。
    always @(posedge clk) begin
        if (rst)
            MODE <= 32'h4000_0001;
        else begin
            MODE <= Din;
            if (!rdn)
                VRAM_BUF <= VRAMOUT;
        end
    end

    // 根据当前像素坐标换算字符行列，再映射到文本 VRAM 地址。
    wire [6:0] char_col = (MODE[6:4] == 3'b000) ? col[9:3] : {1'b0, col[9:4]};
    wire [5:0] char_row = (MODE[6:4] == 3'b000) ? row[8:3] : {1'b0, row[8:4]};

    assign VRAMA = (MODE[6:4] == 3'b000) ?
                   ((char_row << 6) + (char_row << 4) + char_col) :
                   ((char_row << 5) + (char_row << 3) + char_col);

    wire vrd = (MODE[6:4] == 3'b000) ? (col[2:0] == 3'b000) :
                                           (col[3:0] == 4'b0000);
    assign rdn = ~(read && vrd);

    // 字库地址合成。8x8 ASCII 文本模式使用 font ROM；16x16 字库接口保留。
    wire [16:0] font_addr = (MODE[6:4] == 3'b000) ?
                             {7'b0, VRAM_BUF[6:0], row[2:0]} :
                             {VRAM_BUF[12:0], row[3:0]};

    font U_FONT8(
        .a  (font_addr[10:0]),
        .spo(Font8out)
    );

    Font1616 U_FONT16(
        .clk (clk),
        .addr(font_addr),
        .dout(Font16out)
    );

    wire Font8dot  = (MODE[6:4] == 3'b000) ? Font8out[~col[2:0]] : 1'b0;
    wire Font16dot = (MODE[6:4] == 3'b010) ? Font16out[~col[3:0]] : 1'b0;

    wire [11:0] Attr8F  = {VRAM_BUF[15:14], VRAM_BUF[15:14], VRAM_BUF[13],
                           VRAM_BUF[13:11], VRAM_BUF[10], VRAM_BUF[10:8]};
    wire [2:0]  Attr16  = VRAM_BUF[15:13];

    wire size     = (MODE[6:4] == 3'b000) ? (row[2:0] > 3'd3) : (row[3:0] > 4'd4);
    wire Blinking = (Cursor[12:7] == char_row) && size && (Cursor[6:0] == char_col);

    assign R = Blinking ? red   ^ {4{Blink}} : red;
    assign G = Blinking ? green ^ {4{Blink}} : green;
    assign B = Blinking ? blue  ^ {4{Blink}} : blue;

    wire Text = MODE[3:0] != 4'b000;

    always @(*) begin
        case (1'b1)
            TESTEN:             Pixels = TEST_D;
            Test[13]:           Pixels = 12'h000;
            Font8dot && Text:   Pixels = Attr8F;
            Font16dot && Text:  Pixels = {3{1'b1, Attr16}};
            pixel_en:           Pixels = pixel_in;
            default:            Pixels = 12'h000;
        endcase
    end

    // 老师原实现：100MHz 内部分频，用 VGACLK[1] 作为约 25MHz VGA 扫描时钟。
    reg [2:0] VGACLK;
    always @(posedge clk or posedge rst) begin
        if (rst)
            VGACLK <= 3'b000;
        else
            VGACLK <= VGACLK + 3'b001;
    end

    VGA_Scan U_SCAN(
        .clk   (VGACLK[1]),
        .rst   (rst),
        .row   (row),
        .col   (col),
        .Active(read),
        .HSYNC (h_sync),
        .VSYNC (v_sync)
    );

    always @(posedge VGACLK[1] or posedge rst) begin
        if (rst) begin
            HSYNC <= 1'b0;
            VSYNC <= 1'b0;
            red   <= 4'h0;
            green <= 4'h0;
            blue  <= 4'h0;
        end else begin
            HSYNC <= h_sync;
            VSYNC <= v_sync;
            red   <= read ? Pixels[11:8] : 4'h0;
            green <= read ? Pixels[7:4]  : 4'h0;
            blue  <= read ? Pixels[3:0]  : 4'h0;
        end
    end

    wire unused = ^Regaddr;

endmodule
