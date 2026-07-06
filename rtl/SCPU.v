`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// RV32I 单周期 CPU 顶层数据通路。
module SCPU(
    input             clk,
    input             reset,
    input      [31:0] inst_in,
    input      [31:0] Data_in,

    output            mem_w,
    output     [2:0]  DMType,
    output     [31:0] PC_out,
    output     [31:0] Addr_out,
    output     [31:0] Data_out,

    input      [4:0]  reg_sel,
    output     [31:0] reg_data
);

    wire        RegWrite;
    wire [5:0]  EXTOp;
    wire [4:0]  ALUOp;
    wire [2:0]  NPCOp;
    wire [1:0]  WDSel;
    wire        ALUSrc;
    wire        Zero;

    wire [31:0] next_pc;
    wire [31:0] immout;
    wire [31:0] aluout;
    wire [31:0] RD1;
    wire [31:0] RD2;
    wire [31:0] alu_b;
    reg  [31:0] write_data;

    wire [6:0] Op     = inst_in[6:0];
    wire [6:0] Funct7 = inst_in[31:25];
    wire [2:0] Funct3 = inst_in[14:12];
    wire [4:0] rs1    = inst_in[19:15];
    wire [4:0] rs2    = inst_in[24:20];
    wire [4:0] rd     = inst_in[11:7];

    // 按各指令格式重排立即数字段。
    wire [4:0]  iimm_shamt = inst_in[24:20];
    wire [11:0] iimm       = inst_in[31:20];
    wire [11:0] simm       = {inst_in[31:25], inst_in[11:7]};
    wire [11:0] bimm       = {inst_in[31], inst_in[7],
                              inst_in[30:25], inst_in[11:8]};
    wire [19:0] uimm       = inst_in[31:12];
    wire [19:0] jimm       = {inst_in[31], inst_in[19:12],
                              inst_in[20], inst_in[30:21]};

    assign alu_b    = ALUSrc ? immout : RD2;
    assign Addr_out = aluout;
    assign Data_out = RD2;

    ctrl U_ctrl(
        .Op(Op),
        .Funct7(Funct7),
        .Funct3(Funct3),
        .Zero(Zero),
        .RegWrite(RegWrite),
        .MemWrite(mem_w),
        .EXTOp(EXTOp),
        .ALUOp(ALUOp),
        .NPCOp(NPCOp),
        .ALUSrc(ALUSrc),
        .WDSel(WDSel),
        .DMType(DMType)
    );

    PC U_PC(
        .clk(clk),
        .rst(reset),
        .NPC(next_pc),
        .PC(PC_out)
    );

    NPC U_NPC(
        .PC(PC_out),
        .NPCOp(NPCOp),
        .IMM(immout),
        .aluout(aluout),
        .NPC(next_pc)
    );

    EXT U_EXT(
        .iimm_shamt(iimm_shamt),
        .iimm(iimm),
        .simm(simm),
        .bimm(bimm),
        .uimm(uimm),
        .jimm(jimm),
        .EXTOp(EXTOp),
        .immout(immout)
    );

    RF U_RF(
        .clk(clk),
        .rst(reset),
        .RFWr(RegWrite),
        .A1(rs1),
        .A2(rs2),
        .A3(rd),
        .WD(write_data),
        .debug_addr(reg_sel),
        .RD1(RD1),
        .RD2(RD2),
        .debug_data(reg_data)
    );

    alu U_alu(
        .A(RD1),
        .B(alu_b),
        .ALUOp(ALUOp),
        .C(aluout),
        .Zero(Zero),
        .PC(PC_out)
    );

    // 选择写回 rd 的数据：ALU、存储器或 PC+4。
    always @(*) begin
        case (WDSel)
            `WDSel_FromMEM: write_data = Data_in;
            `WDSel_FromPC:  write_data = PC_out + 32'd4;
            default:        write_data = aluout;
        endcase
    end

endmodule
