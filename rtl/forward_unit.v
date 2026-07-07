`timescale 1ns/1ps

// EX 阶段转发选择单元。
// 00：使用 ID/EX 中原始寄存器读数
// 01：使用 MEM/WB 写回数据
// 10：使用 EX/MEM 中较新的 ALU/PC+4 结果
module forward_unit(
    input      [4:0] id_ex_rs1,
    input      [4:0] id_ex_rs2,

    input            ex_mem_valid,
    input            ex_mem_reg_write,
    input            ex_mem_mem_read,
    input      [4:0] ex_mem_rd,

    input            mem_wb_valid,
    input            mem_wb_reg_write,
    input      [4:0] mem_wb_rd,

    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // EX/MEM 是最近的结果，优先级高于 MEM/WB。
        // load 在 EX/MEM 时数据尚未成为 ALU 结果，不能从这里转发。
        if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
            (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a = 2'b10;
        end else if (mem_wb_valid && mem_wb_reg_write &&
                     (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1)) begin
            forward_a = 2'b01;
        end

        if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
            (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b = 2'b10;
        end else if (mem_wb_valid && mem_wb_reg_write &&
                     (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2)) begin
            forward_b = 2'b01;
        end
    end

endmodule
