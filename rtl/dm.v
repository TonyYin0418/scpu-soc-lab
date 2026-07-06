`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// 数据存储器：128 个 32 位字，共 512 字节。
// 字节地址的低两位选择字内位置，数据采用 RISC-V 小端排列。
module dm(
    input             clk,
    input             DMWr,
    input      [8:0]  addr,
    input      [31:0] din,
    input      [2:0]  DMType,
    output reg [31:0] dout
);

    reg [31:0] dmem [0:127];
    reg [7:0]  selected_byte;
    reg [15:0] selected_halfword;
    wire [31:0] current_word = dmem[addr[8:2]];

    // 异步读：先按地址选择字节/半字，再进行符号或零扩展。
    always @(*) begin
        case (addr[1:0])
            2'b00: selected_byte = current_word[7:0];
            2'b01: selected_byte = current_word[15:8];
            2'b10: selected_byte = current_word[23:16];
            default: selected_byte = current_word[31:24];
        endcase

        selected_halfword = addr[1]
                          ? current_word[31:16]
                          : current_word[15:0];

        case (DMType)
            `dm_byte:              dout = {{24{selected_byte[7]}}, selected_byte};
            `dm_byte_unsigned:     dout = {24'b0, selected_byte};
            `dm_halfword:          dout = {{16{selected_halfword[15]}}, selected_halfword};
            `dm_halfword_unsigned: dout = {16'b0, selected_halfword};
            default:               dout = current_word;
        endcase
    end

    // 同步写：SB/SH 只更新目标字节通道，其余字节保持不变。
    always @(posedge clk) begin
        if (DMWr) begin
            case (DMType)
                `dm_byte: begin
                    case (addr[1:0])
                        2'b00: dmem[addr[8:2]][7:0]   <= din[7:0];
                        2'b01: dmem[addr[8:2]][15:8]  <= din[7:0];
                        2'b10: dmem[addr[8:2]][23:16] <= din[7:0];
                        2'b11: dmem[addr[8:2]][31:24] <= din[7:0];
                    endcase
                end
                `dm_halfword: begin
                    if (addr[1])
                        dmem[addr[8:2]][31:16] <= din[15:0];
                    else
                        dmem[addr[8:2]][15:0] <= din[15:0];
                end
                default: dmem[addr[8:2]] <= din;
            endcase

            $display("dmem[0x%08X] <= 0x%08X", addr, din);
        end
    end

endmodule
