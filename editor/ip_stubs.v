`timescale 1ns / 1ps

// 仅供 slang/Icarus 做板级接口检查。
// Vivado 中应通过 IP Catalog 生成同名 ROM_D 和 RAM_B，不要把本文件加入综合源。
module ROM_D(
    input      [9:0]  a,
    output     [31:0] spo
);
endmodule

module RAM_B(
    input             clka,
    input      [3:0]  wea,
    input      [9:0]  addra,
    input      [31:0] dina,
    output     [31:0] douta
);
endmodule

// Vivado 综合时使用 Xilinx 原生 BUFG；这里仅给 slang/Icarus 端口检查提供
// 功能等价直通模型。不要把本文件加入 Vivado Design Sources。
module BUFG(
    input  I,
    output O
);
    assign O = I;
endmodule
