`timescale 1ns / 1ps

// VGA 文本显存。
//
// 地址模型面向后续软件：
//   0xC0000000 + (row * 80 + col) * 4
//
// CPU 每次写入一个 16 位字符单元：
//   [7:0]   ASCII 字符码
//   [15:8]  颜色属性，8'hFF 可作为白色前景
//
// VGAIO 使用 VRAMA 顺序读取字符单元，80x60 文本模式共 4800 个单元。
module vga_text_ram(
    input             cpu_clk,
    input             cpu_we,
    input      [12:0] cpu_waddr,
    input      [15:0] cpu_wdata,

    input      [12:0] vga_raddr,
    output     [15:0] vga_rdata
);

    localparam integer COLS  = 80;
    localparam integer ROWS  = 60;
    localparam integer CELLS = COLS * ROWS;
    localparam [12:0] CELLS_13 = 13'd4800;

    reg [15:0] mem [0:CELLS-1];
    integer i;

    initial begin
        for (i = 0; i < CELLS; i = i + 1)
            mem[i] = 16'h0020; // 默认空格

        // 上电默认画面，便于在不写软件时确认文本模式也正常。
        mem[0]  = 16'hff53; // S
        mem[1]  = 16'hff43; // C
        mem[2]  = 16'hff50; // P
        mem[3]  = 16'hff55; // U
        mem[4]  = 16'hff20; // space
        mem[5]  = 16'hff56; // V
        mem[6]  = 16'hff47; // G
        mem[7]  = 16'hff41; // A
        mem[8]  = 16'hff20; // space
        mem[9]  = 16'hff52; // R
        mem[10] = 16'hff45; // E
        mem[11] = 16'hff41; // A
        mem[12] = 16'hff44; // D
        mem[13] = 16'hff59; // Y
    end

    always @(posedge cpu_clk) begin
        if (cpu_we && (cpu_waddr < CELLS_13))
            mem[cpu_waddr] <= cpu_wdata;
    end

    assign vga_rdata = (vga_raddr < CELLS_13) ? mem[vga_raddr] : 16'h0020;

endmodule
