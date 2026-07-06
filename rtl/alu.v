`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// 32 位整数运算单元。
// 分支比较操作在条件成立时输出 0，从而统一使用 Zero 作为“跳转成立”信号。
module alu(
    input      [31:0] A,
    input      [31:0] B,
    input      [4:0]  ALUOp,
    input      [31:0] PC,
    output reg [31:0] C,
    output            Zero
);

    always @(*) begin
        case (ALUOp)
            `ALUOp_nop:   C = A;
            `ALUOp_lui:   C = B;
            `ALUOp_auipc: C = PC + B;
            `ALUOp_add:   C = A + B;
            `ALUOp_sub:   C = A - B;

            // 分支比较：条件成立输出 0，条件不成立输出 1。
            `ALUOp_bne:  C = (A != B)                  ? 32'b0 : 32'b1;
            `ALUOp_blt:  C = ($signed(A) < $signed(B)) ? 32'b0 : 32'b1;
            `ALUOp_bge:  C = ($signed(A) >= $signed(B))? 32'b0 : 32'b1;
            `ALUOp_bltu: C = (A < B)                   ? 32'b0 : 32'b1;
            `ALUOp_bgeu: C = (A >= B)                  ? 32'b0 : 32'b1;

            `ALUOp_slt:  C = {31'b0, ($signed(A) < $signed(B))};
            `ALUOp_sltu: C = {31'b0, (A < B)};
            `ALUOp_xor:  C = A ^ B;
            `ALUOp_or:   C = A | B;
            `ALUOp_and:  C = A & B;
            `ALUOp_sll:  C = A << B[4:0];
            `ALUOp_srl:  C = A >> B[4:0];
            `ALUOp_sra:  C = $signed(A) >>> B[4:0];
            default:     C = 32'b0;
        endcase
    end

    assign Zero = (C == 32'b0);

endmodule
