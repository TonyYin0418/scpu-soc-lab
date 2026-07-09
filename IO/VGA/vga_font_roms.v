`timescale 1ns / 1ps

// 字库 ROM 模块。
//
// 老师 VGAIO 会例化 font 和 Font1616。当前先把 8x8 ASCII 字库接成
// 可综合 ROM，供 80x60 文本模式使用；16x16 中文字库接口保留为空，
// 后续如果应用需要中文，再把 coe/vga/Hzk16.coe 转成同步 ROM。

module font(
    input      [10:0] a,
    output     [7:0]  spo
);
    reg [7:0] rom [0:1023];

    initial begin
        $readmemb("coe/vga/font_ascii_8_8.mem", rom);
    end

    assign spo = rom[a];
endmodule

module Font1616(
    input             clk,
    input      [16:0] addr,
    output reg [15:0] dout
);
    always @(posedge clk)
        dout <= 16'h0000;

    wire unused = addr[0];
endmodule
