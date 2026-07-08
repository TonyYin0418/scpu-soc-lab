`timescale 1ns/1ps

// EX 阶段转发选择单元。
//
// 这个模块只做“比较寄存器号并输出选择信号”，不真正搬运 32 位数据。
// 真正的数据选择在 SCPU.v 中根据 forward_a/forward_b 完成。
//
// 为什么只给 EX 阶段转发：
// - ALU 运算、分支比较、store 地址计算都在 EX 阶段使用操作数；
// - store 写数据也在 EX 阶段通过 forwarded rs2 保存到 EX/MEM.store_data；
// - 因此统一把 forwarding 放在 EX 阶段最简单。
//
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
        // 默认不转发，直接使用 ID/EX 中保存的 rs1_data/rs2_data。
        forward_a = 2'b00;
        forward_b = 2'b00;

        // EX/MEM 是最近的结果，优先级高于 MEM/WB。
        // load 在 EX/MEM 时数据尚未成为 ALU 结果，不能从这里转发。
        // ex_mem_rd != 0 用于保护 x0：对 x0 的写入无效，也不应该参与转发。
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

        // 如果 EX/MEM 和 MEM/WB 同时命中同一个源寄存器，选择 EX/MEM。
        // 例：
        //   addi x1,x0,1
        //   addi x1,x1,1
        //   add  x2,x1,x0
        // 第三条应该看到第二条产生的最新 x1，而不是第一条的旧 x1。
    end

endmodule
