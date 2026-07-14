`timescale 1ns / 1ps

// 文本模式渲染器。
//
// 640x480 显示区按 8x8 字符切成 80x60 文本单元。renderer 根据当前
// 像素坐标生成显存读地址，并把读出的 ASCII/属性通过字库转换成 RGB。
module vga_text_renderer(
    input      [9:0]  x,
    input      [9:0]  y,
    input             active,
    input      [15:0] cell_data,
    output     [12:0] cell_addr,
    output     [3:0]  red,
    output     [3:0]  green,
    output     [3:0]  blue
);

    wire [6:0] char_col = x[9:3];
    wire [5:0] char_row = y[8:3];
    wire [2:0] font_col = x[2:0];
    wire [2:0] font_row = y[2:0];
    wire [12:0] char_col_13 = {6'b0, char_col};
    wire [12:0] char_row_13 = {7'b0, char_row};

    assign cell_addr = (char_row_13 << 6) + (char_row_13 << 4) + char_col_13;

    wire [7:0] ascii = cell_data[7:0];
    wire [7:0] attr  = cell_data[15:8];
    wire [7:0] font_bits;

    vga_font_rom U_FONT(
        .ascii(ascii[6:0]),
        .font_row(font_row),
        .bits(font_bits)
    );

    wire pixel_on = active && font_bits[3'd7 - font_col];

    // 软件沿用一个字节的文本属性。高半字节是前景色编号，低半字节
    // 预留给后续背景色/效果；没有命中调色板的编号退化为同亮度灰色，
    // 因而仍兼容早期只把属性当作亮度使用的程序。
    reg [3:0] foreground_r;
    reg [3:0] foreground_g;
    reg [3:0] foreground_b;

    always @(*) begin
        case (attr[7:4])
            4'h7: begin foreground_r = 4'h7; foreground_g = 4'h7; foreground_b = 4'h7; end // dim
            4'ha: begin foreground_r = 4'h2; foreground_g = 4'hd; foreground_b = 4'h4; end // green
            4'hb: begin foreground_r = 4'h2; foreground_g = 4'hc; foreground_b = 4'he; end // cyan
            4'hc: begin foreground_r = 4'he; foreground_g = 4'h3; foreground_b = 4'h2; end // red
            4'he: begin foreground_r = 4'hf; foreground_g = 4'hc; foreground_b = 4'h2; end // yellow
            4'hf: begin foreground_r = 4'hf; foreground_g = 4'hf; foreground_b = 4'hf; end // white
            default: begin
                foreground_r = attr[7:4];
                foreground_g = attr[7:4];
                foreground_b = attr[7:4];
            end
        endcase
    end

    assign red   = pixel_on ? foreground_r : 4'h0;
    assign green = pixel_on ? foreground_g : 4'h0;
    assign blue  = pixel_on ? foreground_b : 4'h0;

endmodule
