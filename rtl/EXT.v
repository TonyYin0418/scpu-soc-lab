`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// RV32I 立即数生成器。
// 输入字段由 SCPU 按指令格式重排，本模块负责符号扩展和最低位补零。
module EXT(
    input      [4:0]  iimm_shamt,
    input      [11:0] iimm,
    input      [11:0] simm,
    input      [11:0] bimm,
    input      [19:0] uimm,
    input      [19:0] jimm,
    input      [5:0]  EXTOp,
    output reg [31:0] immout
);

    always @(*) begin
        case (EXTOp)
            `EXT_CTRL_ITYPE_SHAMT: immout = {27'b0, iimm_shamt};
            `EXT_CTRL_ITYPE:       immout = {{20{iimm[11]}}, iimm};
            `EXT_CTRL_STYPE:       immout = {{20{simm[11]}}, simm};
            `EXT_CTRL_BTYPE:       immout = {{19{bimm[11]}}, bimm, 1'b0};
            `EXT_CTRL_UTYPE:       immout = {uimm, 12'b0};
            `EXT_CTRL_JTYPE:       immout = {{11{jimm[19]}}, jimm, 1'b0};
            default:               immout = 32'b0;
        endcase
    end

endmodule
