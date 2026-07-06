`timescale 1ns/1ps

// 单周期 CPU 自检测试平台。
// 默认运行 Test-8；添加 +TEST37 参数后运行课程提供的 Test-37。
// 课程 Test-37 未包含 AUIPC，使用 +TEST_AUIPC 运行补充定向测试。
module sccomp_tb;

    reg         clk;
    reg         rstn;
    reg  [4:0]  reg_sel;
    wire [31:0] reg_data;

    integer counter;
    integer errors;
    integer i;
    integer program_words;
    integer test37_mode;
    integer test_auipc_mode;
    integer foutput;
    string  mem_file;

    sccomp U_SCCOMP(
        .clk(clk),
        .rstn(rstn),
        .reg_sel(reg_sel),
        .reg_data(reg_data)
    );

    initial begin
        $dumpfile("build/sccomp_tb.vcd");
        $dumpvars(0, sccomp_tb);
    end

    initial begin
        clk         = 1'b0;
        rstn        = 1'b0;
        reg_sel     = 5'b0;
        counter     = 0;
        errors      = 0;
        test37_mode = $test$plusargs("TEST37");
        test_auipc_mode = $test$plusargs("TEST_AUIPC");

        // 可用 +MEM_FILE=<路径> 和 +WORDS=<数量> 覆盖默认测试文件。
        if (!$value$plusargs("MEM_FILE=%s", mem_file)) begin
            if (test37_mode)
                mem_file = "sim/data/Test_37_Instr8.dat";
            else if (test_auipc_mode)
                mem_file = "sim/data/Test_AUIPC.dat";
            else
                mem_file = "sim/data/Test_8_Instr.dat";
        end
        if (!$value$plusargs("WORDS=%d", program_words)) begin
            if (test37_mode)
                program_words = 71;
            else if (test_auipc_mode)
                program_words = 2;
            else
                program_words = 15;
        end

        // 未装载区域填充 ADDI x0,x0,0（NOP），避免读取到 X。
        for (i = 0; i < 128; i = i + 1) begin
            U_SCCOMP.U_IM.ROM[i] = 32'h00000013;
            U_SCCOMP.U_DM.dmem[i] = 32'b0;
        end
        $readmemh(mem_file, U_SCCOMP.U_IM.ROM, 0, program_words - 1);

        foutput = $fopen("build/results.txt", "w");
        $display("运行测试：%s，共 %0d 条机器指令", mem_file, program_words);

        // 保持两个时钟周期复位，然后开始执行。
        #20 rstn = 1'b1;
    end

    always #5 clk = ~clk;

    // 检查一个通用寄存器。
    task automatic check_reg;
        input integer index;
        input [31:0] expected;
        begin
            if (U_SCCOMP.U_SCPU.U_RF.rf[index] !== expected) begin
                errors = errors + 1;
                $display("[错误] x%0d：实际=%08x，期望=%08x",
                         index, U_SCCOMP.U_SCPU.U_RF.rf[index], expected);
                $fdisplay(foutput, "FAIL x%0d actual=%08x expected=%08x",
                          index, U_SCCOMP.U_SCPU.U_RF.rf[index], expected);
            end
        end
    endtask

    // 检查数据存储器中的一个 32 位字。
    task automatic check_mem;
        input integer index;
        input [31:0] expected;
        begin
            if (U_SCCOMP.U_DM.dmem[index] !== expected) begin
                errors = errors + 1;
                $display("[错误] dmem[%0d]：实际=%08x，期望=%08x",
                         index, U_SCCOMP.U_DM.dmem[index], expected);
                $fdisplay(foutput, "FAIL dmem[%0d] actual=%08x expected=%08x",
                          index, U_SCCOMP.U_DM.dmem[index], expected);
            end
        end
    endtask

    task automatic report_and_finish;
        begin
            if (errors == 0) begin
                $display("[通过] 所有检查均通过");
                $fdisplay(foutput, "PASS");
            end else begin
                $display("[失败] 共发现 %0d 个错误", errors);
                $fdisplay(foutput, "FAIL errors=%0d", errors);
            end
            $fclose(foutput);
            $finish;
        end
    endtask

    // Test-8 的回归检查。
    task automatic check_test8;
        begin
            check_reg(5,  32'h00000456);
            check_reg(6,  32'h00000123);
            check_reg(7,  32'h00000579);
            check_reg(8,  32'h00000123);
            check_reg(9,  32'h00000579);
            check_reg(10, 32'h00000577);
            check_reg(11, 32'h00000456);
            check_reg(29, 32'h0000000c);
            check_mem(0, 32'h00000123);
            check_mem(1, 32'h00000456);
            check_mem(4, 32'h00000579);
        end
    endtask

    // Test-37 在第一次完成 JALR 返回并写回内存后进行检查。
    task automatic check_test37;
        begin
            check_reg(1,  32'h00000108);
            check_reg(3,  32'h00000000);
            check_reg(4,  32'h00000001);
            check_reg(5,  32'h98763bcb);
            check_reg(6,  32'h98765000);
            check_reg(7,  32'h00009876);
            check_reg(8,  32'h0000003b);
            check_reg(9,  32'h0000000e);
            check_reg(10, 32'h000007b2);
            check_reg(18, 32'h00000301);
            check_reg(19, 32'h98763bcb);
            check_reg(20, 32'h00000001);
            check_reg(21, 32'h98765001);
            check_reg(22, 32'h98766437);
            check_reg(23, 32'h00001437);
            check_reg(25, 32'h98767437);
            check_reg(26, 32'h00000437);
            check_reg(27, 32'hcb000000);
            check_reg(28, 32'h098763bc);
            check_reg(29, 32'hf98763bc);

            check_mem(0, 32'h000007b2);
            check_mem(1, 32'hef760437);
            check_mem(2, 32'h3BCBEFEF);
            check_mem(3, 32'h98763bcb);
            check_mem(4, 32'hffff9876);
            check_mem(5, 32'h00009876);
            check_mem(6, 32'hffffff98);
            check_mem(7, 32'h00000098);
            check_mem(8, 32'h0000003b);
        end
    endtask

    // 在非零 PC 上执行 AUIPC，验证结果同时包含 U 型立即数和当前 PC。
    task automatic check_auipc;
        begin
            check_reg(5, 32'h12345004);
        end
    endtask

    always @(posedge clk) begin
        if (rstn) begin
            counter = counter + 1;

            // 在结果被后续指令覆盖前，检查 SLT/SLTU 和寄存器移位指令。
            if (test37_mode && (U_SCCOMP.pc == 32'h00000050)) begin
                check_reg(27, 32'h00000001);
                check_reg(28, 32'h00000000);
            end
            if (test37_mode && (U_SCCOMP.pc == 32'h00000060)) begin
                check_reg(27, 32'h00004370);
                check_reg(28, 32'h09876743);
                check_reg(29, 32'hf9876743);
            end

            if (!test37_mode && !test_auipc_mode &&
                (U_SCCOMP.pc == 32'h00000048)) begin
                check_test8();
                report_and_finish();
            end

            if (test_auipc_mode && (U_SCCOMP.pc == 32'h00000008)) begin
                check_auipc();
                report_and_finish();
            end

            // PC=0x110 且 x10=0x7b2 表示 37 指令程序已完成一次 JALR 返回。
            if (test37_mode &&
                (U_SCCOMP.pc == 32'h00000110) &&
                (U_SCCOMP.U_SCPU.U_RF.rf[10] == 32'h000007b2)) begin
                check_test37();
                report_and_finish();
            end

            if (counter > 400) begin
                errors = errors + 1;
                $display("[错误] 仿真超时，当前 PC=%08x", U_SCCOMP.pc);
                report_and_finish();
            end
        end
    end

endmodule
