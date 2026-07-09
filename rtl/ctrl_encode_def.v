`ifndef CTRL_ENCODE_DEF_V
`define CTRL_ENCODE_DEF_V

// 下一条 PC 的选择
`define NPC_PLUS4   3'b000
`define NPC_BRANCH  3'b001
`define NPC_JUMP    3'b010
`define NPC_JALR    3'b100

// 立即数类型（独热码）
`define EXT_CTRL_ITYPE_SHAMT 6'b100000
`define EXT_CTRL_ITYPE       6'b010000
`define EXT_CTRL_STYPE       6'b001000
`define EXT_CTRL_BTYPE       6'b000100
`define EXT_CTRL_UTYPE       6'b000010
`define EXT_CTRL_JTYPE       6'b000001

// 寄存器写回数据来源
`define WDSel_FromALU 2'b00
`define WDSel_FromMEM 2'b01
`define WDSel_FromPC  2'b10

// ALU 操作编码
`define ALUOp_nop   5'b00000
`define ALUOp_lui   5'b00001
`define ALUOp_auipc 5'b00010
`define ALUOp_add   5'b00011
`define ALUOp_sub   5'b00100
`define ALUOp_bne   5'b00101
`define ALUOp_blt   5'b00110
`define ALUOp_bge   5'b00111
`define ALUOp_bltu  5'b01000
`define ALUOp_bgeu  5'b01001
`define ALUOp_slt   5'b01010
`define ALUOp_sltu  5'b01011
`define ALUOp_xor   5'b01100
`define ALUOp_or    5'b01101
`define ALUOp_and   5'b01110
`define ALUOp_sll   5'b01111
`define ALUOp_srl   5'b10000
`define ALUOp_sra   5'b10001

// 数据存储器访问类型
`define dm_word              3'b000
`define dm_halfword          3'b001
`define dm_halfword_unsigned 3'b010
`define dm_byte              3'b011
`define dm_byte_unsigned     3'b100

// 单级中断/异常原因码
`define SCAUSE_NONE    8'h00
`define SCAUSE_ILLEGAL 8'h01
`define SCAUSE_ECALL   8'h02
`define SCAUSE_TIMER   8'h06

// 单级中断/异常向量入口
`define TRAP_VEC_ILLEGAL 32'h0000_0300
`define TRAP_VEC_ECALL   32'h0000_0320
`define TRAP_VEC_TIMER   32'h0000_0340

// STATUS / INTMASK 位定义
`define STATUS_EXL_BIT 0
`define INT_TIMER_BIT  6
`define INT_TIMER_MASK 8'b0100_0000
`define MMIO_INTMASK   32'hFFFF_FF00

// 课程自定义返回指令编码
`define INST_ECALL  32'h0000_0073
`define INST_ERET   32'h0010_0073
`define INST_ERETN  32'h0020_0073

`endif
