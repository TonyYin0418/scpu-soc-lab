`timescale 1ns/1ps

// load-use 冒险检测单元。
//
// forwarding 可以解决大多数“前一条结果还没写回”的问题，但 load 例外：
//
//   lw  x1, 0(x2)
//   add x3, x1, x4
//
// lw 的数据要到 MEM 阶段从 Data_in 得到，再进入 MEM/WB；紧跟的 add 在
// 下一拍就要进入 EX，来不及从 EX/MEM 得到真正的 load 数据。因此必须停一拍。
//
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

    // 判断条件逐项含义：
    // - if_id_valid：ID 阶段确实有指令，bubble 不需要 stall；
    // - id_ex_valid && id_ex_mem_read：EX 阶段这条有效指令是 load；
    // - id_ex_rd != x0：load 写 x0 没有意义，不会产生真实依赖；
    // - if_id_uses_rs1/rs2：当前 ID 指令真的使用对应源寄存器；
    // - rd == rs1/rs2：ID 指令需要的源寄存器正是 load 将要写回的 rd。
    //
    // stall=1 后，SCPU.v 中会：
    // - PC 保持；
    // - IF/ID 保持，让使用者指令留在 ID；
    // - ID/EX 写 bubble，让 load 多走一拍，之后可从 MEM/WB 转发。
    assign stall = if_id_valid && id_ex_valid && id_ex_mem_read &&
                   (id_ex_rd != 5'b0) &&
                   ((if_id_uses_rs1 && (id_ex_rd == if_id_rs1)) ||
                    (if_id_uses_rs2 && (id_ex_rd == if_id_rs2)));

endmodule
