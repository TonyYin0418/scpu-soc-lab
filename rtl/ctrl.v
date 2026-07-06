`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// RV32I 单周期控制器。
// 根据 opcode、funct3 和 funct7 生成数据通路控制信号。
module ctrl(
    input      [6:0] Op,
    input      [6:0] Funct7,
    input      [2:0] Funct3,
    input            Zero,

    output reg       RegWrite,
    output reg       MemWrite,
    output reg [5:0] EXTOp,
    output reg [4:0] ALUOp,
    output reg [2:0] NPCOp,
    output reg       ALUSrc,
    output reg [1:0] WDSel,
    output reg [2:0] DMType
);

    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_IMM    = 7'b0010011;
    localparam [6:0] OP_AUIPC  = 7'b0010111;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_REG    = 7'b0110011;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_JAL    = 7'b1101111;

    always @(*) begin
        // 默认值对应无副作用的 NOP，非法编码不会写寄存器或存储器。
        RegWrite = 1'b0;
        MemWrite = 1'b0;
        EXTOp    = `EXT_CTRL_ITYPE;
        ALUOp    = `ALUOp_nop;
        NPCOp    = `NPC_PLUS4;
        ALUSrc   = 1'b0;
        WDSel    = `WDSel_FromALU;
        DMType   = `dm_word;

        case (Op)
            OP_REG: begin
                // R 型：第二操作数来自 rs2。
                case (Funct3)
                    3'b000: begin
                        RegWrite = 1'b1;
                        ALUOp = (Funct7 == 7'b0100000) ? `ALUOp_sub : `ALUOp_add;
                    end
                    3'b001: begin RegWrite = 1'b1; ALUOp = `ALUOp_sll;  end
                    3'b010: begin RegWrite = 1'b1; ALUOp = `ALUOp_slt;  end
                    3'b011: begin RegWrite = 1'b1; ALUOp = `ALUOp_sltu; end
                    3'b100: begin RegWrite = 1'b1; ALUOp = `ALUOp_xor;  end
                    3'b101: begin
                        RegWrite = 1'b1;
                        ALUOp = (Funct7 == 7'b0100000) ? `ALUOp_sra : `ALUOp_srl;
                    end
                    3'b110: begin RegWrite = 1'b1; ALUOp = `ALUOp_or;   end
                    3'b111: begin RegWrite = 1'b1; ALUOp = `ALUOp_and;  end
                    default: begin RegWrite = 1'b0; ALUOp = `ALUOp_nop; end
                endcase
            end

            OP_IMM: begin
                // I 型整数运算：第二操作数来自符号扩展立即数。
                ALUSrc = 1'b1;
                EXTOp  = `EXT_CTRL_ITYPE;
                case (Funct3)
                    3'b000: begin RegWrite = 1'b1; ALUOp = `ALUOp_add;  end // ADDI
                    3'b010: begin RegWrite = 1'b1; ALUOp = `ALUOp_slt;  end // SLTI
                    3'b011: begin RegWrite = 1'b1; ALUOp = `ALUOp_sltu; end // SLTIU
                    3'b100: begin RegWrite = 1'b1; ALUOp = `ALUOp_xor;  end // XORI
                    3'b110: begin RegWrite = 1'b1; ALUOp = `ALUOp_or;   end // ORI
                    3'b111: begin RegWrite = 1'b1; ALUOp = `ALUOp_and;  end // ANDI
                    3'b001: begin
                        RegWrite = 1'b1;
                        EXTOp = `EXT_CTRL_ITYPE_SHAMT;
                        ALUOp = `ALUOp_sll; // SLLI
                    end
                    3'b101: begin
                        RegWrite = 1'b1;
                        EXTOp = `EXT_CTRL_ITYPE_SHAMT;
                        ALUOp = (Funct7 == 7'b0100000) ? `ALUOp_sra : `ALUOp_srl;
                    end
                    default: begin RegWrite = 1'b0; ALUOp = `ALUOp_nop; end
                endcase
            end

            OP_LOAD: begin
                // 访存地址 = rs1 + 符号扩展偏移量。
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                EXTOp    = `EXT_CTRL_ITYPE;
                ALUOp    = `ALUOp_add;
                WDSel    = `WDSel_FromMEM;
                case (Funct3)
                    3'b000: DMType = `dm_byte;              // LB
                    3'b001: DMType = `dm_halfword;          // LH
                    3'b010: DMType = `dm_word;              // LW
                    3'b100: DMType = `dm_byte_unsigned;     // LBU
                    3'b101: DMType = `dm_halfword_unsigned; // LHU
                    default: begin RegWrite = 1'b0; DMType = `dm_word; end
                endcase
            end

            OP_STORE: begin
                ALUSrc = 1'b1;
                EXTOp  = `EXT_CTRL_STYPE;
                ALUOp  = `ALUOp_add;
                case (Funct3)
                    3'b000: begin MemWrite = 1'b1; DMType = `dm_byte;     end // SB
                    3'b001: begin MemWrite = 1'b1; DMType = `dm_halfword; end // SH
                    3'b010: begin MemWrite = 1'b1; DMType = `dm_word;     end // SW
                    default: begin MemWrite = 1'b0; DMType = `dm_word; end
                endcase
            end

            OP_BRANCH: begin
                // ALU 将“分支条件成立”统一编码为 Zero=1。
                EXTOp = `EXT_CTRL_BTYPE;
                case (Funct3)
                    3'b000: ALUOp = `ALUOp_sub;  // BEQ
                    3'b001: ALUOp = `ALUOp_bne;  // BNE
                    3'b100: ALUOp = `ALUOp_blt;  // BLT
                    3'b101: ALUOp = `ALUOp_bge;  // BGE
                    3'b110: ALUOp = `ALUOp_bltu; // BLTU
                    3'b111: ALUOp = `ALUOp_bgeu; // BGEU
                    default: ALUOp = `ALUOp_nop;
                endcase
                if (Zero)
                    NPCOp = `NPC_BRANCH;
            end

            OP_LUI: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                EXTOp    = `EXT_CTRL_UTYPE;
                ALUOp    = `ALUOp_lui;
            end

            OP_AUIPC: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                EXTOp    = `EXT_CTRL_UTYPE;
                ALUOp    = `ALUOp_auipc;
            end

            OP_JAL: begin
                RegWrite = 1'b1;
                EXTOp    = `EXT_CTRL_JTYPE;
                NPCOp    = `NPC_JUMP;
                WDSel    = `WDSel_FromPC;
            end

            OP_JALR: begin
                if (Funct3 == 3'b000) begin
                    RegWrite = 1'b1;
                    ALUSrc   = 1'b1;
                    EXTOp    = `EXT_CTRL_ITYPE;
                    ALUOp    = `ALUOp_add;
                    NPCOp    = `NPC_JALR;
                    WDSel    = `WDSel_FromPC;
                end
            end

            default: begin
                // 保持默认 NOP 控制信号。
            end
        endcase
    end

endmodule
