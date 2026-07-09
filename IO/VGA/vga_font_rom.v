`timescale 1ns / 1ps

// 8x8 ASCII 字库 ROM。
//
// 地址格式：{ascii[6:0], font_row[2:0]}，输出该字符该行的 8 个像素。
// 字库文件来自老师提供的 VGA/font 资源，已转换为 $readmemb 可读格式。
module vga_font_rom(
    input      [6:0] ascii,
    input      [2:0] font_row,
    output     [7:0] bits
);

    reg [7:0] rom [0:1023];

    initial begin
        $readmemb("coe/vga/font_ascii_8_8.mem", rom);
    end

    assign bits = rom[{ascii, font_row}];

endmodule
