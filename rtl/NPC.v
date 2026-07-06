`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// 下一条指令地址生成器。
module NPC(
    input      [31:0] PC,
    input      [2:0]  NPCOp,
    input      [31:0] IMM,
    input      [31:0] aluout,
    output reg [31:0] NPC
);

    always @(*) begin
        case (NPCOp)
            `NPC_BRANCH: NPC = PC + IMM;
            `NPC_JUMP:   NPC = PC + IMM;
            // RISC-V 规定 JALR 的目标地址最低位必须清零。
            `NPC_JALR:   NPC = {aluout[31:1], 1'b0};
            default:     NPC = PC + 32'd4;
        endcase
    end

endmodule
