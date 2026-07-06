`timescale 1ns/1ps

// 单周期 CPU 的仿真系统顶层：连接 CPU、指令存储器和数据存储器。
module sccomp(
    input             clk,
    input             rstn,
    input      [4:0]  reg_sel,
    output     [31:0] reg_data
);

    wire        reset = ~rstn;
    wire [31:0] instr;
    wire [31:0] pc;
    wire        mem_write;
    wire [2:0]  dm_type;
    wire [31:0] dm_addr;
    wire [31:0] dm_write_data;
    wire [31:0] dm_read_data;

    SCPU U_SCPU(
        .clk(clk),
        .reset(reset),
        .inst_in(instr),
        .Data_in(dm_read_data),
        .mem_w(mem_write),
        .DMType(dm_type),
        .PC_out(pc),
        .Addr_out(dm_addr),
        .Data_out(dm_write_data),
        .reg_sel(reg_sel),
        .reg_data(reg_data)
    );

    dm U_DM(
        .clk(clk),
        .DMWr(mem_write),
        .addr(dm_addr[8:0]),
        .din(dm_write_data),
        .DMType(dm_type),
        .dout(dm_read_data)
    );

    im U_IM(
        .addr(pc[8:2]),
        .dout(instr)
    );

endmodule
