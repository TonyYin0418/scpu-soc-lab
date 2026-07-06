`timescale 1ns/1ps

// 程序计数器：异步高电平复位，同步更新下一条指令地址。
module PC(
    input             clk,
    input             rst,
    input      [31:0] NPC,
    output reg [31:0] PC
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            PC <= 32'b0;
        else
            PC <= NPC;
    end

endmodule
