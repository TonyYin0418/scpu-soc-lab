`timescale 1ns/1ps

// load-use 冒险检测单元。
// 当 ID 阶段指令马上使用 EX 阶段 load 的 rd 时，暂停 PC 和 IF/ID，
// 并向 ID/EX 插入一个 bubble。
module hazard_unit(
    input            if_id_valid,
    input      [4:0] if_id_rs1,
    input      [4:0] if_id_rs2,
    input            if_id_uses_rs1,
    input            if_id_uses_rs2,

    input            id_ex_valid,
    input            id_ex_mem_read,
    input      [4:0] id_ex_rd,

    output           stall
);

    assign stall = if_id_valid && id_ex_valid && id_ex_mem_read &&
                   (id_ex_rd != 5'b0) &&
                   ((if_id_uses_rs1 && (id_ex_rd == if_id_rs1)) ||
                    (if_id_uses_rs2 && (id_ex_rd == if_id_rs2)));

endmodule
