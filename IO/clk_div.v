`timescale 1ns / 1ps
module clk_div(input clk,
					input rst,
					input SW2,
					output reg[31:0]clkdiv,
					output Clk_CPU
					);

// Clock divider.
//
// 流水线 CPU 使用 clkdiv[0]，即 100 MHz / 2 = 50 MHz。
// 关键点：clkdiv[x] 不能直接扇出给大量 CPU 触发器做时钟，否则可能走普通
// routing，产生较大的 clock skew。这里显式接 BUFG，让 CPU 时钟走 FPGA
// 全局时钟网络。SW2 端口保留用于兼容原理图接口，当前流水线阶段不再使用
// SW2 做运行时快/慢时钟选择。


	always @ (posedge clk or posedge rst) begin
		if (rst) clkdiv <= 0; else clkdiv <= clkdiv + 1'b1; end

	BUFG U_BUFG_CPU(
		.I(clkdiv[0]),
		.O(Clk_CPU)
	);

endmodule
