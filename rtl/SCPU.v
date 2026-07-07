`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// RV32I 五级冒险流水线 CPU。
//
// 设计约定：
// 1. IF/ID/EX/MEM/WB 五级，静态预测 PC+4。
// 2. 分支和跳转在 EX 阶段决定；预测错误时清空 IF/ID、ID/EX。
// 3. 流水线寄存器和 PC 在下降沿更新，寄存器堆沿用教材假设在上升沿写回。
// 4. 当前阶段不实现 MIO_ready/INT，中断异常留给后续阶段。
module SCPU(
    input             clk,
    input             reset,
    input             MIO_ready,
    input      [31:0] inst_in,
    input      [31:0] Data_in,

    output            mem_w,
    output     [31:0] PC_out,
    output     [31:0] Addr_out,
    output     [31:0] Data_out,
    output     [2:0]  dm_ctrl,
    output            CPU_MIO,
    input             INT
);

    localparam [31:0] NOP = 32'h0000_0013;

    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_IMM    = 7'b0010011;
    localparam [6:0] OP_AUIPC  = 7'b0010111;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_REG    = 7'b0110011;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_JAL    = 7'b1101111;

    // 当前 37 条指令阶段暂不使用 MIO ready/中断。
    assign CPU_MIO = 1'b0;

    // ---------------------------------------------------------------------
    // IF：PC 寄存器。ROM 地址直接来自 PC_out。
    // ---------------------------------------------------------------------
    reg [31:0] pc_reg;
    assign PC_out = pc_reg;

    // ---------------------------------------------------------------------
    // IF/ID 流水寄存器。
    // ---------------------------------------------------------------------
    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_inst;

    // ---------------------------------------------------------------------
    // ID 阶段译码与寄存器读取。
    // ---------------------------------------------------------------------
    wire [6:0] id_op     = if_id_inst[6:0];
    wire [6:0] id_funct7 = if_id_inst[31:25];
    wire [2:0] id_funct3 = if_id_inst[14:12];
    wire [4:0] id_rs1    = if_id_inst[19:15];
    wire [4:0] id_rs2    = if_id_inst[24:20];
    wire [4:0] id_rd     = if_id_inst[11:7];

    wire [4:0]  id_iimm_shamt = if_id_inst[24:20];
    wire [11:0] id_iimm       = if_id_inst[31:20];
    wire [11:0] id_simm       = {if_id_inst[31:25], if_id_inst[11:7]};
    wire [11:0] id_bimm       = {if_id_inst[31], if_id_inst[7],
                                 if_id_inst[30:25], if_id_inst[11:8]};
    wire [19:0] id_uimm       = if_id_inst[31:12];
    wire [19:0] id_jimm       = {if_id_inst[31], if_id_inst[19:12],
                                 if_id_inst[20], if_id_inst[30:21]};

    wire        id_reg_write;
    wire        id_mem_write;
    wire [5:0]  id_ext_op;
    wire [4:0]  id_alu_op;
    wire [2:0]  id_unused_npc_op;
    wire        id_alu_src;
    wire [1:0]  id_wd_sel;
    wire [2:0]  id_dm_ctrl;
    wire [31:0] id_imm;
    wire [31:0] id_rd1;
    wire [31:0] id_rd2;
    wire [31:0] unused_debug_data;

    // ctrl 中 branch 的 NPCOp 依赖 Zero；流水线在 EX 阶段自行处理 PC，
    // 因此这里给 Zero=0，只复用其 RegWrite/MemWrite/ALU/EXT/DM 控制。
    ctrl U_ctrl(
        .Op(id_op),
        .Funct7(id_funct7),
        .Funct3(id_funct3),
        .Zero(1'b0),
        .RegWrite(id_reg_write),
        .MemWrite(id_mem_write),
        .EXTOp(id_ext_op),
        .ALUOp(id_alu_op),
        .NPCOp(id_unused_npc_op),
        .ALUSrc(id_alu_src),
        .WDSel(id_wd_sel),
        .DMType(id_dm_ctrl)
    );

    EXT U_EXT(
        .iimm_shamt(id_iimm_shamt),
        .iimm(id_iimm),
        .simm(id_simm),
        .bimm(id_bimm),
        .uimm(id_uimm),
        .jimm(id_jimm),
        .EXTOp(id_ext_op),
        .immout(id_imm)
    );

    // WB 阶段写回寄存器堆；读端口服务当前 ID 阶段。
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    RF U_RF(
        .clk(clk),
        .rst(reset),
        .RFWr(wb_reg_write),
        .A1(id_rs1),
        .A2(id_rs2),
        .A3(wb_rd),
        .WD(wb_data),
        .debug_addr(5'b0),
        .RD1(id_rd1),
        .RD2(id_rd2),
        .debug_data(unused_debug_data)
    );

    wire id_is_load   = (id_op == OP_LOAD);
    wire id_is_store  = (id_op == OP_STORE);
    wire id_is_branch = (id_op == OP_BRANCH);
    wire id_is_jal    = (id_op == OP_JAL);
    wire id_is_jalr   = (id_op == OP_JALR);

    wire id_uses_rs1 = (id_op == OP_REG)    ||
                       (id_op == OP_IMM)    ||
                       (id_op == OP_LOAD)   ||
                       (id_op == OP_STORE)  ||
                       (id_op == OP_BRANCH) ||
                       (id_op == OP_JALR);

    wire id_uses_rs2 = (id_op == OP_REG) ||
                       (id_op == OP_STORE) ||
                       (id_op == OP_BRANCH);

    // ---------------------------------------------------------------------
    // ID/EX 流水寄存器。
    // ---------------------------------------------------------------------
    reg        id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg [2:0]  id_ex_funct3;
    reg [4:0]  id_ex_alu_op;
    reg [2:0]  id_ex_dm_ctrl;
    reg [1:0]  id_ex_wd_sel;
    reg        id_ex_reg_write;
    reg        id_ex_mem_write;
    reg        id_ex_mem_read;
    reg        id_ex_alu_src;
    reg        id_ex_branch;
    reg        id_ex_jal;
    reg        id_ex_jalr;

    // ---------------------------------------------------------------------
    // EX/MEM 流水寄存器。
    // ---------------------------------------------------------------------
    reg        ex_mem_valid;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [31:0] ex_mem_pc_plus4;
    reg [4:0]  ex_mem_rd;
    reg [2:0]  ex_mem_dm_ctrl;
    reg [1:0]  ex_mem_wd_sel;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_read;

    // ---------------------------------------------------------------------
    // MEM/WB 流水寄存器。
    // ---------------------------------------------------------------------
    reg        mem_wb_valid;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_pc_plus4;
    reg [4:0]  mem_wb_rd;
    reg [1:0]  mem_wb_wd_sel;
    reg        mem_wb_reg_write;

    // ---------------------------------------------------------------------
    // 冒险处理与转发。
    // ---------------------------------------------------------------------
    wire stall_load_use;
    wire [1:0] forward_a_sel;
    wire [1:0] forward_b_sel;

    hazard_unit U_hazard_unit(
        .if_id_valid(if_id_valid),
        .if_id_rs1(id_rs1),
        .if_id_rs2(id_rs2),
        .if_id_uses_rs1(id_uses_rs1),
        .if_id_uses_rs2(id_uses_rs2),
        .id_ex_valid(id_ex_valid),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_rd(id_ex_rd),
        .stall(stall_load_use)
    );

    forward_unit U_forward_unit(
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .ex_mem_valid(ex_mem_valid),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_rd(ex_mem_rd),
        .mem_wb_valid(mem_wb_valid),
        .mem_wb_reg_write(mem_wb_reg_write),
        .mem_wb_rd(mem_wb_rd),
        .forward_a(forward_a_sel),
        .forward_b(forward_b_sel)
    );

    wire [31:0] ex_mem_forward_data =
        (ex_mem_wd_sel == `WDSel_FromPC) ? ex_mem_pc_plus4 : ex_mem_alu_result;

    wire [31:0] ex_rs1_forwarded =
        (forward_a_sel == 2'b10) ? ex_mem_forward_data :
        (forward_a_sel == 2'b01) ? wb_data :
                                   id_ex_rs1_data;

    wire [31:0] ex_rs2_forwarded =
        (forward_b_sel == 2'b10) ? ex_mem_forward_data :
        (forward_b_sel == 2'b01) ? wb_data :
                                   id_ex_rs2_data;

    wire [31:0] ex_alu_b = id_ex_alu_src ? id_ex_imm : ex_rs2_forwarded;
    wire [31:0] ex_alu_result;
    wire        ex_zero;

    alu U_alu(
        .A(ex_rs1_forwarded),
        .B(ex_alu_b),
        .ALUOp(id_ex_alu_op),
        .C(ex_alu_result),
        .Zero(ex_zero),
        .PC(id_ex_pc)
    );

    wire        ex_branch_taken = id_ex_valid && id_ex_branch && ex_zero;
    wire        ex_jump_taken   = id_ex_valid && (id_ex_jal || id_ex_jalr);
    wire        ex_redirect     = ex_branch_taken || ex_jump_taken;
    wire [31:0] ex_redirect_pc  = id_ex_jalr
                                ? {ex_alu_result[31:1], 1'b0}
                                : (id_ex_pc + id_ex_imm);

    // ---------------------------------------------------------------------
    // MEM 对外接口。所有外部副作用都必须受 valid 控制。
    // ---------------------------------------------------------------------
    assign mem_w    = ex_mem_valid && ex_mem_mem_write;
    assign Addr_out = ex_mem_alu_result;
    assign Data_out = ex_mem_store_data;
    assign dm_ctrl  = ex_mem_dm_ctrl;

    // ---------------------------------------------------------------------
    // WB 阶段写回选择。
    // ---------------------------------------------------------------------
    assign wb_data =
        (mem_wb_wd_sel == `WDSel_FromMEM) ? mem_wb_mem_data :
        (mem_wb_wd_sel == `WDSel_FromPC)  ? mem_wb_pc_plus4 :
                                            mem_wb_alu_result;

    assign wb_rd = mem_wb_rd;
    assign wb_reg_write = mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'b0);

    // ---------------------------------------------------------------------
    // 下降沿推进流水线。flush 优先于普通取指，stall 只冻结 PC 和 IF/ID，
    // 并在 ID/EX 插入 bubble。
    // ---------------------------------------------------------------------
    always @(negedge clk or posedge reset) begin
        if (reset) begin
            pc_reg <= 32'b0;

            if_id_valid <= 1'b0;
            if_id_pc <= 32'b0;
            if_id_inst <= NOP;

            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'b0;
            id_ex_rs1_data <= 32'b0;
            id_ex_rs2_data <= 32'b0;
            id_ex_imm <= 32'b0;
            id_ex_rs1 <= 5'b0;
            id_ex_rs2 <= 5'b0;
            id_ex_rd <= 5'b0;
            id_ex_funct3 <= 3'b0;
            id_ex_alu_op <= `ALUOp_nop;
            id_ex_dm_ctrl <= `dm_word;
            id_ex_wd_sel <= `WDSel_FromALU;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_alu_src <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_jal <= 1'b0;
            id_ex_jalr <= 1'b0;

            ex_mem_valid <= 1'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_pc_plus4 <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_dm_ctrl <= `dm_word;
            ex_mem_wd_sel <= `WDSel_FromALU;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;

            mem_wb_valid <= 1'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data <= 32'b0;
            mem_wb_pc_plus4 <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_wd_sel <= `WDSel_FromALU;
            mem_wb_reg_write <= 1'b0;
        end else begin
            // MEM/WB 每拍接收上一拍 MEM 阶段的结果。
            mem_wb_valid <= ex_mem_valid;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= Data_in;
            mem_wb_pc_plus4 <= ex_mem_pc_plus4;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_wd_sel <= ex_mem_wd_sel;
            mem_wb_reg_write <= ex_mem_reg_write;

            // EX/MEM 接收当前 EX 阶段结果。branch 本身无外部副作用；
            // JAL/JALR 仍需继续流向 WB 写回 PC+4。
            ex_mem_valid <= id_ex_valid;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_store_data <= ex_rs2_forwarded;
            ex_mem_pc_plus4 <= id_ex_pc + 32'd4;
            ex_mem_rd <= id_ex_rd;
            ex_mem_dm_ctrl <= id_ex_dm_ctrl;
            ex_mem_wd_sel <= id_ex_wd_sel;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_read <= id_ex_mem_read;

            if (ex_redirect) begin
                // 预测失败：PC 改为真实目标，清空当前错误路径。
                pc_reg <= ex_redirect_pc;

                if_id_valid <= 1'b0;
                if_id_pc <= 32'b0;
                if_id_inst <= NOP;

                id_ex_valid <= 1'b0;
                id_ex_pc <= 32'b0;
                id_ex_rs1_data <= 32'b0;
                id_ex_rs2_data <= 32'b0;
                id_ex_imm <= 32'b0;
                id_ex_rs1 <= 5'b0;
                id_ex_rs2 <= 5'b0;
                id_ex_rd <= 5'b0;
                id_ex_funct3 <= 3'b0;
                id_ex_alu_op <= `ALUOp_nop;
                id_ex_dm_ctrl <= `dm_word;
                id_ex_wd_sel <= `WDSel_FromALU;
                id_ex_reg_write <= 1'b0;
                id_ex_mem_write <= 1'b0;
                id_ex_mem_read <= 1'b0;
                id_ex_alu_src <= 1'b0;
                id_ex_branch <= 1'b0;
                id_ex_jal <= 1'b0;
                id_ex_jalr <= 1'b0;
            end else if (stall_load_use) begin
                // load-use 冒险：PC 和 IF/ID 保持，ID/EX 插入 bubble。
                pc_reg <= pc_reg;

                if_id_valid <= if_id_valid;
                if_id_pc <= if_id_pc;
                if_id_inst <= if_id_inst;

                id_ex_valid <= 1'b0;
                id_ex_pc <= 32'b0;
                id_ex_rs1_data <= 32'b0;
                id_ex_rs2_data <= 32'b0;
                id_ex_imm <= 32'b0;
                id_ex_rs1 <= 5'b0;
                id_ex_rs2 <= 5'b0;
                id_ex_rd <= 5'b0;
                id_ex_funct3 <= 3'b0;
                id_ex_alu_op <= `ALUOp_nop;
                id_ex_dm_ctrl <= `dm_word;
                id_ex_wd_sel <= `WDSel_FromALU;
                id_ex_reg_write <= 1'b0;
                id_ex_mem_write <= 1'b0;
                id_ex_mem_read <= 1'b0;
                id_ex_alu_src <= 1'b0;
                id_ex_branch <= 1'b0;
                id_ex_jal <= 1'b0;
                id_ex_jalr <= 1'b0;
            end else begin
                // 正常推进。
                pc_reg <= pc_reg + 32'd4;

                if_id_valid <= 1'b1;
                if_id_pc <= pc_reg;
                if_id_inst <= inst_in;

                id_ex_valid <= if_id_valid;
                id_ex_pc <= if_id_pc;
                id_ex_rs1_data <= id_rd1;
                id_ex_rs2_data <= id_rd2;
                id_ex_imm <= id_imm;
                id_ex_rs1 <= id_rs1;
                id_ex_rs2 <= id_rs2;
                id_ex_rd <= id_rd;
                id_ex_funct3 <= id_funct3;
                id_ex_alu_op <= id_alu_op;
                id_ex_dm_ctrl <= id_dm_ctrl;
                id_ex_wd_sel <= id_wd_sel;
                id_ex_reg_write <= id_reg_write;
                id_ex_mem_write <= id_mem_write;
                id_ex_mem_read <= id_is_load;
                id_ex_alu_src <= id_alu_src;
                id_ex_branch <= id_is_branch;
                id_ex_jal <= id_is_jal;
                id_ex_jalr <= id_is_jalr;
            end
        end
    end

endmodule
