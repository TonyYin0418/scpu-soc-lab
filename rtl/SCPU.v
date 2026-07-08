`timescale 1ns/1ps
`include "ctrl_encode_def.v"

// RV32I 五级冒险流水线 CPU。
//
// 设计约定：
// 1. IF/ID/EX/MEM/WB 五级，静态预测 PC+4。
// 2. 分支和跳转在 EX 阶段决定；预测错误时清空 IF/ID、ID/EX。
// 3. 流水线寄存器和 PC 在下降沿更新，寄存器堆沿用教材假设在上升沿写回。
// 4. 支持单级中断/异常：非法指令、ECALL/SYSCALL、计时中断 INT，
//    以及课程自定义返回指令 ERET/ERETN。
//
// 时钟关系：
// - 本模块输入 clk 是板级 Clk_CPU，当前由 clkdiv[0] 经 BUFG 得到 50 MHz。
// - PC 和所有流水线寄存器在 negedge clk 更新，即“阶段推进”发生在下降沿。
// - RF 模块在 posedge clk 写回，读端口是异步组合读。
// - 这样 WB 写 RF 和 ID 读 RF 错开半个周期，便于同周期写回值被 ID 读到。
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

    // RISC-V 标准 NOP：addi x0, x0, 0。
    // flush / bubble 时把指令内容置成 NOP，同时 valid=0 屏蔽副作用。
    localparam [31:0] NOP = 32'h0000_0013;

    // 只用 opcode 快速判断指令大类。具体 ALUOp / WDSel / dm_ctrl
    // 仍由原来的 ctrl.v 统一生成，避免在流水线顶层重复写完整译码。
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_IMM    = 7'b0010011;
    localparam [6:0] OP_AUIPC  = 7'b0010111;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_REG    = 7'b0110011;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_JAL    = 7'b1101111;
    localparam [6:0] OP_SYSTEM = 7'b1110011;

    // 当前阶段不使用 MIO_ready；CPU_MIO 保持为 0 以兼容老师板级接口。
    assign CPU_MIO = 1'b0;

    // ---------------------------------------------------------------------
    // 单级中断/异常状态。
    //
    // SEPC   ：进入 trap 时当前 EX 阶段指令 PC。
    // SCAUSE ：进入 trap 的原因码。
    // STATUS[0]：EXL/in_trap，进入 trap 后置 1，ERET/ERETN 清 0。
    // INTMASK[6]：允许计时中断。软件可向 0xFFFF_FF00 写入低 8 位更新。
    // int_pending[6]：INT 输入锁存的计时中断 pending。
    // ---------------------------------------------------------------------
    reg [31:0] SEPC;
    reg [7:0]  SCAUSE;
    reg [7:0]  STATUS;
    reg [7:0]  INTMASK;
    reg [7:0]  int_pending;

    // ---------------------------------------------------------------------
    // IF：PC 寄存器。ROM 地址直接来自 PC_out。
    //
    // PC_out 接到板级 ROM_D 的地址 PC[11:2]，因此 pc_reg 改变后，
    // 外部指令 ROM 组合输出 inst_in。下一次 negedge 时，inst_in 会被
    // 锁存进 IF/ID，成为 ID 阶段要译码的指令。
    // ---------------------------------------------------------------------
    reg [31:0] pc_reg;
    assign PC_out = pc_reg;

    // ---------------------------------------------------------------------
    // IF/ID 流水寄存器。
    //
    // valid：这一槽里是否真有一条有效指令。flush 后 valid=0，表示 bubble。
    // pc   ：这条指令自己的 PC，后面 branch/jump 目标计算和 AUIPC 需要。
    // inst ：从 ROM 取到的 32 位指令，ID 阶段根据它译码。
    // ---------------------------------------------------------------------
    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_inst;

    // ---------------------------------------------------------------------
    // ID 阶段译码与寄存器读取。
    //
    // ID 的输入来自 IF/ID。这里完成三件事：
    // 1. 从指令字段中拆出 opcode/rs1/rs2/rd/funct/立即数字段；
    // 2. 调用 ctrl/EXT 生成后续阶段需要的控制信号和扩展立即数；
    // 3. 用 rs1/rs2 异步读取寄存器堆，读数在下一次 negedge 写入 ID/EX。
    // ---------------------------------------------------------------------
    wire [6:0] id_op     = if_id_inst[6:0];
    wire [6:0] id_funct7 = if_id_inst[31:25];
    wire [2:0] id_funct3 = if_id_inst[14:12];
    wire [4:0] id_rs1    = if_id_inst[19:15];
    wire [4:0] id_rs2    = if_id_inst[24:20];
    wire [4:0] id_rd     = if_id_inst[11:7];

    // 各类立即数字段先按原始指令位拼好，再交给 EXT 根据 EXTOp 做
    // 符号扩展、零扩展或最低位补 0。
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
    wire        id_alu_src;
    wire [1:0]  id_wd_sel;
    wire [2:0]  id_dm_ctrl;
    wire [31:0] id_imm;
    wire [31:0] id_rd1;
    wire [31:0] id_rd2;
    wire [31:0] unused_debug_data;

    // ctrl 只负责“译码得到控制信号”。
    // PC+4、branch/jal/jalr 的 PC 重定向由本模块 EX 阶段自行处理，
    // 因此 ctrl 不再包含单周期时代的 Zero/NPCOp 接口。
    // id_reg_write/id_mem_write/id_alu_op/id_wd_sel 等随指令一起进入 ID/EX、EX/MEM、MEM/WB，到对应阶段才使用。
    ctrl U_ctrl(
        .Op(id_op),
        .Funct7(id_funct7),
        .Funct3(id_funct3),
        .RegWrite(id_reg_write),
        .MemWrite(id_mem_write),
        .EXTOp(id_ext_op),
        .ALUOp(id_alu_op),
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
    //
    // RF 的 A1/A2 使用当前 ID 指令的 rs1/rs2。
    // RF 的 A3/WD/RFWr 来自当前 WB 阶段。
    // 因为 RF 在 posedge 写、流水线在 negedge 推进，所以 WB 写回后，
    // ID 阶段还有半个周期让异步读输出稳定到 id_rd1/id_rd2。
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

    // 这些布尔信号只用于流水线控制：
    // - load/store/branch/jal/jalr 决定是否需要特殊处理；
    // - id_uses_rs1/rs2 用于 load-use hazard 判断，避免把无关字段误当源寄存器。
    wire id_is_load   = (id_op == OP_LOAD);
    wire id_is_store  = (id_op == OP_STORE);
    wire id_is_branch = (id_op == OP_BRANCH);
    wire id_is_jal    = (id_op == OP_JAL);
    wire id_is_jalr   = (id_op == OP_JALR);
    wire id_is_system = (id_op == OP_SYSTEM);
    wire id_is_ecall  = (if_id_inst == `INST_ECALL);
    wire id_is_eret   = (if_id_inst == `INST_ERET);
    wire id_is_eretn  = (if_id_inst == `INST_ERETN);

    wire id_reg_legal =
        (id_funct3 == 3'b000) ? ((id_funct7 == 7'b0000000) || (id_funct7 == 7'b0100000)) :
        (id_funct3 == 3'b001) ?  (id_funct7 == 7'b0000000) :
        (id_funct3 == 3'b010) ?  (id_funct7 == 7'b0000000) :
        (id_funct3 == 3'b011) ?  (id_funct7 == 7'b0000000) :
        (id_funct3 == 3'b100) ?  (id_funct7 == 7'b0000000) :
        (id_funct3 == 3'b101) ? ((id_funct7 == 7'b0000000) || (id_funct7 == 7'b0100000)) :
        (id_funct3 == 3'b110) ?  (id_funct7 == 7'b0000000) :
        (id_funct3 == 3'b111) ?  (id_funct7 == 7'b0000000) :
                                1'b0;

    wire id_imm_legal =
        (id_funct3 == 3'b001) ? (id_funct7 == 7'b0000000) :
        (id_funct3 == 3'b101) ? ((id_funct7 == 7'b0000000) || (id_funct7 == 7'b0100000)) :
        ((id_funct3 == 3'b000) || (id_funct3 == 3'b010) ||
         (id_funct3 == 3'b011) || (id_funct3 == 3'b100) ||
         (id_funct3 == 3'b110) || (id_funct3 == 3'b111));

    wire id_load_legal   = (id_funct3 == 3'b000) || (id_funct3 == 3'b001) ||
                           (id_funct3 == 3'b010) || (id_funct3 == 3'b100) ||
                           (id_funct3 == 3'b101);
    wire id_store_legal  = (id_funct3 == 3'b000) || (id_funct3 == 3'b001) ||
                           (id_funct3 == 3'b010);
    wire id_branch_legal = (id_funct3 == 3'b000) || (id_funct3 == 3'b001) ||
                           (id_funct3 == 3'b100) || (id_funct3 == 3'b101) ||
                           (id_funct3 == 3'b110) || (id_funct3 == 3'b111);

    wire id_instruction_legal =
        (id_op == OP_REG)    ? id_reg_legal :
        (id_op == OP_IMM)    ? id_imm_legal :
        (id_op == OP_LOAD)   ? id_load_legal :
        (id_op == OP_STORE)  ? id_store_legal :
        (id_op == OP_BRANCH) ? id_branch_legal :
        (id_op == OP_JALR)   ? (id_funct3 == 3'b000) :
        (id_op == OP_AUIPC)  ? 1'b1 :
        (id_op == OP_LUI)    ? 1'b1 :
        (id_op == OP_JAL)    ? 1'b1 :
        (id_op == OP_SYSTEM) ? (id_is_ecall || id_is_eret || id_is_eretn) :
                               1'b0;

    wire        id_exception_valid = if_id_valid && (!id_instruction_legal || id_is_ecall);
    wire [7:0]  id_exception_cause = !id_instruction_legal ? `SCAUSE_ILLEGAL :
                                      id_is_ecall          ? `SCAUSE_ECALL :
                                                             `SCAUSE_NONE;

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
    // - 数据：pc、rs1_data、rs2_data、imm；
    // - 编号：rs1/rs2/rd，用于 forwarding/hazard/writeback；
    // - 控制：ALUOp、ALUSrc、RegWrite、MemWrite、WDSel、dm_ctrl 等。
    //
    // 为什么控制信号也要存：一条指令进入后续阶段后，原始 inst 已经不在
    // 当前 ID 阶段了，后续阶段必须依靠随指令携带的控制信号决定行为。
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
    reg        id_ex_exception_valid;
    reg [7:0]  id_ex_exception_cause;
    reg        id_ex_eret;
    reg        id_ex_eretn;

    // ---------------------------------------------------------------------
    // EX/MEM 流水寄存器。
    // - alu_result：load/store 地址、ALU 指令结果、部分跳转目标计算结果；
    // - store_data：store 指令最终要写到内存/外设的数据，已经做过 forwarding；
    // - pc_plus4：JAL/JALR 写回 rd 的值；
    // - rd 和写回控制继续传给 WB；
    // - MemWrite/dm_ctrl 在 MEM 阶段驱动外部 RAM/MMIO。
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
    //
    // MEM/WB 是“进入 WB 阶段的指令包”：
    // - mem_data：load 从 Data_in 采样到的数据；
    // - alu_result：ALU 类 / LUI / AUIPC 等结果；
    // - pc_plus4：JAL/JALR 写回值；
    // - WDSel：选择最终写回 RF 的来源；
    // - RegWrite/rd：决定是否真的写 RF，以及写哪个寄存器。
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
    //
    // 数据冒险有两类：
    // 1. ALU 类结果已经在 EX/MEM 或 MEM/WB 中，但 RF 还没写回：用 forwarding。
    // 2. load 紧跟使用者：load 数据到 MEM/WB 才可用，必须 stall 一拍。
    //
    // 这里的 stall_load_use 只处理第二类；第一类由 forward_unit 选择操作数来源。
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

    // EX/MEM 可转发的数据只可能来自 ALU 结果或 PC+4。
    // load 数据在 EX/MEM 阶段尚未从 Data_in 采样，所以 forward_unit 会禁止
    // ex_mem_mem_read 的转发，load-use 通过 stall 解决。
    wire [31:0] ex_mem_forward_data =
        (ex_mem_wd_sel == `WDSel_FromPC) ? ex_mem_pc_plus4 : ex_mem_alu_result;

    // EX 阶段真正送入 ALU/分支比较的 rs1/rs2。
    // 优先级：EX/MEM 最新，其次 MEM/WB，最后使用 ID/EX 中保存的原始读数。
    wire [31:0] ex_rs1_forwarded =
        (forward_a_sel == 2'b10) ? ex_mem_forward_data :
        (forward_a_sel == 2'b01) ? wb_data :
                                   id_ex_rs1_data;

    wire [31:0] ex_rs2_forwarded =
        (forward_b_sel == 2'b10) ? ex_mem_forward_data :
        (forward_b_sel == 2'b01) ? wb_data :
                                   id_ex_rs2_data;

    // ALU B 端：I/load/store/jalr 等使用立即数；R/branch 使用 rs2。
    // store_data 不走 ex_alu_b，而是单独把 forwarded rs2 保存到 EX/MEM。
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

    // 分支/跳转在 EX 阶段决定。
    // 静态预测为 not taken，也就是 IF 阶段一直先取 PC+4。
    // 如果 EX 阶段发现 branch taken 或 jal/jalr，就把 PC 改成真实目标，
    // 并清空此时已经错误取到/译码的 IF/ID、ID/EX。
    wire        ex_branch_taken = id_ex_valid && id_ex_branch && ex_zero;
    wire        ex_jump_taken   = id_ex_valid && (id_ex_jal || id_ex_jalr);
    wire        ex_redirect     = ex_branch_taken || ex_jump_taken;
    wire [31:0] ex_redirect_pc  = id_ex_jalr
                                ? {ex_alu_result[31:1], 1'b0}
                                : (id_ex_pc + id_ex_imm);

    // ---------------------------------------------------------------------
    // EX 阶段中断/异常控制。
    //
    // 同步异常由 ID 阶段标记并随指令进入 EX；计时中断由 INT pending
    // 进入 ExceptionUnit。trap 和 ERET/ERETN 的跳转优先级高于 branch/jump。
    // ---------------------------------------------------------------------
    wire [7:0] ex_scause = (id_ex_valid && id_ex_exception_valid)
                         ? id_ex_exception_cause
                         : `SCAUSE_NONE;
    wire       ex_trap_set;
    wire       ex_int_signal;
    wire [2:0] ex_int_pend_id;
    wire [7:0] ex_trap_cause;
    wire [31:0] ex_trap_vector;
    wire [7:0] ex_int_pending_for_unit = id_ex_valid ? int_pending : 8'b0;
    wire       ex_eret  = id_ex_valid && id_ex_eret;
    wire       ex_eretn = id_ex_valid && id_ex_eretn;
    wire       ex_return = ex_eret || ex_eretn;
    wire [31:0] ex_return_pc = ex_eretn ? (SEPC + 32'd4) : SEPC;

    exception_unit U_exception_unit(
        .STATUS(STATUS),
        .EX_SCAUSE(ex_scause),
        .INTMASK(INTMASK),
        .INT_PEND(ex_int_pending_for_unit),
        .EXL_Set(ex_trap_set),
        .INT_Signal(ex_int_signal),
        .INT_PEND_ID(ex_int_pend_id),
        .TRAP_CAUSE(ex_trap_cause),
        .TRAP_VECTOR(ex_trap_vector)
    );

    // ---------------------------------------------------------------------
    // MEM 对外接口。所有外部副作用都必须受 valid 控制。
    //
    // Addr_out/Data_out/dm_ctrl 来自 EX/MEM，表示当前 MEM 阶段指令。
    // mem_w 必须额外与 ex_mem_valid 相与：如果这一级是 bubble 或被 flush，
    // 即使控制信号残留，也不能写 RAM/MMIO。
    // ---------------------------------------------------------------------
    assign mem_w    = ex_mem_valid && ex_mem_mem_write;
    assign Addr_out = ex_mem_alu_result;
    assign Data_out = ex_mem_store_data;
    assign dm_ctrl  = ex_mem_dm_ctrl;

    // ---------------------------------------------------------------------
    // WB 阶段写回选择。
    //
    // WDSel_FromMEM：load 指令写回 Data_in 采样值；
    // WDSel_FromPC ：JAL/JALR 写回 PC+4；
    // 默认 FromALU ：ALU/LUI/AUIPC 等写回 ALU 结果。
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
    //
    // 本 always 块是整个流水线的“写寄存器”位置：
    // - reset：所有 valid 清 0，PC 清 0；
    // - 普通推进：每级接收上一级组合逻辑计算好的结果；
    // - ex_redirect：分支/跳转预测失败，改 PC，并清空错误路径；
    // - stall_load_use：load-use，PC/IF_ID 保持，ID_EX 写 bubble。
    //
    // 这里使用非阻塞赋值 <=，保证同一个 negedge 内所有流水线寄存器
    // 同时基于“边沿前”的旧值更新，不会出现顺序覆盖。
    // ---------------------------------------------------------------------
    always @(negedge clk or posedge reset) begin
        if (reset) begin
            pc_reg <= 32'b0;
            SEPC <= 32'b0;
            SCAUSE <= `SCAUSE_NONE;
            STATUS <= 8'b0;
            INTMASK <= 8'b0;
            int_pending <= 8'b0;

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
            id_ex_exception_valid <= 1'b0;
            id_ex_exception_cause <= `SCAUSE_NONE;
            id_ex_eret <= 1'b0;
            id_ex_eretn <= 1'b0;

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
            if (INT)
                int_pending[`INT_TIMER_BIT] <= 1'b1;

            // MEM/WB 每拍接收上一拍 MEM 阶段的结果。
            // 对 load 来说，Data_in 是板级 dm_controller 处理后的读数据；
            // 对非 load 指令，mem_wb_mem_data 会被写入但最终不会被 WDSel 选中。
            mem_wb_valid <= ex_mem_valid;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= Data_in;
            mem_wb_pc_plus4 <= ex_mem_pc_plus4;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_wd_sel <= ex_mem_wd_sel;
            mem_wb_reg_write <= ex_mem_reg_write;

            if (ex_mem_valid && ex_mem_mem_write &&
                (ex_mem_alu_result == `MMIO_INTMASK)) begin
                INTMASK <= ex_mem_store_data[7:0];
                int_pending <= 8'b0;
            end

            // EX/MEM 接收当前 EX 阶段结果。branch 本身无外部副作用；
            // JAL/JALR 仍需继续流向 WB 写回 PC+4。
            //
            // 注意这里无论后面是否 ex_redirect，当前 ID/EX 中的指令本身已经
            // 到了 EX 阶段，不能被当作错误路径清掉。需要清的是更年轻的
            // IF/ID 和 ID/EX 下一拍内容。
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

            if (ex_return) begin
                // ERET/ERETN：从 trap 返回。返回指令本身没有副作用，
                // 当前 EX/MEM 写 bubble，并清空更年轻的 IF/ID、ID/EX。
                STATUS[`STATUS_EXL_BIT] <= 1'b0;
                pc_reg <= ex_return_pc;

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
                id_ex_exception_valid <= 1'b0;
                id_ex_exception_cause <= `SCAUSE_NONE;
                id_ex_eret <= 1'b0;
                id_ex_eretn <= 1'b0;
            end else if (ex_trap_set) begin
                // 异常/中断：按课件在 EX 阶段响应，SEPC 记录当前 EX PC。
                // 当前 EX 指令不能继续提交，因此 EX/MEM 写 bubble。
                SEPC <= id_ex_pc;
                SCAUSE <= ex_trap_cause;
                STATUS[`STATUS_EXL_BIT] <= 1'b1;
                if (ex_int_signal)
                    int_pending[ex_int_pend_id] <= 1'b0;
                pc_reg <= ex_trap_vector;

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
                id_ex_exception_valid <= 1'b0;
                id_ex_exception_cause <= `SCAUSE_NONE;
                id_ex_eret <= 1'b0;
                id_ex_eretn <= 1'b0;
            end else if (ex_redirect) begin
                // 预测失败：PC 改为真实目标，清空当前错误路径。
                //
                // 此时 IF 阶段已经按 PC+4 取了错误指令，ID 阶段也可能正在译码
                // 错误路径指令，所以 IF/ID 和 ID/EX 都写 bubble。
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
                id_ex_exception_valid <= 1'b0;
                id_ex_exception_cause <= `SCAUSE_NONE;
                id_ex_eret <= 1'b0;
                id_ex_eretn <= 1'b0;
            end else if (stall_load_use) begin
                // load-use 冒险：PC 和 IF/ID 保持，ID/EX 插入 bubble。
                //
                // 例：lw x1,0(x2); add x3,x1,x4
                // add 已经在 IF/ID，但 lw 的数据还没到 WB。保持 IF/ID 可以让
                // add 下一拍重新进入 ID；ID/EX 插入 bubble 给 lw 多一拍到 MEM/WB。
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
                id_ex_exception_valid <= 1'b0;
                id_ex_exception_cause <= `SCAUSE_NONE;
                id_ex_eret <= 1'b0;
                id_ex_eretn <= 1'b0;
            end else begin
                // 正常推进。
                //
                // IF/ID 捕获当前 PC 和 ROM 输出 inst_in；
                // ID/EX 捕获当前 ID 阶段已经译码/读寄存器得到的所有信息。
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
                id_ex_exception_valid <= id_exception_valid;
                id_ex_exception_cause <= id_exception_cause;
                id_ex_eret <= if_id_valid && id_is_eret;
                id_ex_eretn <= if_id_valid && id_is_eretn;
            end
        end
    end

endmodule
