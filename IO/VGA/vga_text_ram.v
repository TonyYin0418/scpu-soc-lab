`timescale 1ns / 1ps

// CPU 可写 VGA 文本显存。
//
// 软件地址模型：
//   0xC0000000 + (row * 80 + col) * 4
//
// 每个单元 16 位：
//   [7:0]   ASCII 字符码
//   [15:8]  前景颜色属性。当前 renderer 取 attr[7:4] 作为 4-bit 灰度，
//           同时送到 RGB 三通道，因此 8'hff 显示白色。
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
            mem[i] = 16'h0020;

        // 默认画面用于确认文本路径：左上角显示 SCPU VGA READY。
        mem[0]  = 16'hff53;
        mem[1]  = 16'hff43;
        mem[2]  = 16'hff50;
        mem[3]  = 16'hff55;
        mem[4]  = 16'hff20;
        mem[5]  = 16'hff56;
        mem[6]  = 16'hff47;
        mem[7]  = 16'hff41;
        mem[8]  = 16'hff20;
        mem[9]  = 16'hff52;
        mem[10] = 16'hff45;
        mem[11] = 16'hff41;
        mem[12] = 16'hff44;
        mem[13] = 16'hff59;
    end

    always @(posedge cpu_clk) begin
        if (cpu_we && (cpu_waddr < CELLS_13))
            mem[cpu_waddr] <= cpu_wdata;
    end

    assign vga_rdata = (vga_raddr < CELLS_13) ? mem[vga_raddr] : 16'h0020;

endmodule
