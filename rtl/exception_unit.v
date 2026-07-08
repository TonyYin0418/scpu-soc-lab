`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// 单级中断/异常控制单元。
//
// 输入 EX_SCAUSE 表示当前 EX 阶段指令产生的同步异常；
// INT_PEND 表示已经挂起的中断源。STATUS[0] 为 1 时表示正在 trap
// 处理程序中，此时不再响应新的异常/中断。
module exception_unit(
    input      [7:0] STATUS,
    input      [7:0] EX_SCAUSE,
    input      [7:0] INTMASK,
    input      [7:0] INT_PEND,

    output reg       EXL_Set,
    output reg       INT_Signal,
    output reg [2:0] INT_PEND_ID,
    output reg [7:0] TRAP_CAUSE,
    output reg [31:0] TRAP_VECTOR
);

    wire in_trap = STATUS[`STATUS_EXL_BIT];
    wire timer_pending_enabled = INT_PEND[`INT_TIMER_BIT] && INTMASK[`INT_TIMER_BIT];

    always @(*) begin
        EXL_Set     = 1'b0;
        INT_Signal  = 1'b0;
        INT_PEND_ID = 3'b000;
        TRAP_CAUSE  = `SCAUSE_NONE;
        TRAP_VECTOR = 32'b0;

        if (!in_trap) begin
            // 同步异常优先于异步计时中断。
            if (EX_SCAUSE != `SCAUSE_NONE) begin
                EXL_Set    = 1'b1;
                TRAP_CAUSE = EX_SCAUSE;
                case (EX_SCAUSE)
                    `SCAUSE_ILLEGAL: TRAP_VECTOR = `TRAP_VEC_ILLEGAL;
                    `SCAUSE_ECALL:   TRAP_VECTOR = `TRAP_VEC_ECALL;
                    default:         TRAP_VECTOR = `TRAP_VEC_ILLEGAL;
                endcase
            end else if (timer_pending_enabled) begin
                EXL_Set     = 1'b1;
                INT_Signal  = 1'b1;
                INT_PEND_ID = 3'd6;
                TRAP_CAUSE  = `SCAUSE_TIMER;
                TRAP_VECTOR = `TRAP_VEC_TIMER;
            end
        end
    end

endmodule
