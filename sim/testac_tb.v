`timescale 1ns/1ps

// testac.coe 专用仿真平台。
// 目的：在不依赖 Vivado IP 的情况下，验证 CPU 是否能跑到 testac 的
// 六阶段通过点和 88C6 成功动画。这里把 0xE0000000 作为显示 MMIO，
// 普通地址作为数据 RAM。
module testac_tb;

    reg clk;
    reg rst;

    wire [31:0] inst;
    wire [31:0] pc;
    wire [31:0] addr;
    wire [31:0] wdata;
    wire [31:0] rdata;
    wire [2:0]  dm_ctrl;
    wire        mem_w;
    wire        cpu_mio;

    integer i;
    integer cycle;
    integer saw_1111;
    integer saw_2222;
    integer saw_3333;
    integer saw_4444;
    integer saw_5555;
    integer saw_6666;

    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];
    reg [31:0] mmio_display;

    assign inst = imem[pc[11:2]];

    SCPU U_SCPU(
        .clk(clk),
        .reset(rst),
        .MIO_ready(cpu_mio),
        .inst_in(inst),
        .Data_in(rdata),
        .mem_w(mem_w),
        .PC_out(pc),
        .Addr_out(addr),
        .Data_out(wdata),
        .dm_ctrl(dm_ctrl),
        .CPU_MIO(cpu_mio),
        .INT(1'b0)
    );

    testac_mem_model U_MEM(
        .clk(clk),
        .mem_w(mem_w),
        .addr(addr),
        .wdata(wdata),
        .dm_ctrl(dm_ctrl),
        .rdata(rdata)
    );

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        cycle = 0;
        saw_1111 = 0;
        saw_2222 = 0;
        saw_3333 = 0;
        saw_4444 = 0;
        saw_5555 = 0;
        saw_6666 = 0;
        mmio_display = 32'b0;

        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;
        end

        $readmemh("build/testac.dat", imem);

        $dumpfile("build/testac_tb.vcd");
        $dumpvars(0, testac_tb);

        #20 rst = 1'b0;
    end

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!rst) begin
            cycle = cycle + 1;

            // CPU 写显示 MMIO。testac 的通过/失败信息都从这里观察。
            if (mem_w && (addr == 32'he0000000)) begin
                mmio_display = wdata;
                $display("cycle=%0d pc=%08x display=%08x", cycle, pc, wdata);

                if (wdata == 32'h00111100) saw_1111 = 1;
                if (wdata == 32'h00222200) saw_2222 = 1;
                if (wdata == 32'h00333300) saw_3333 = 1;
                if (wdata == 32'h00444400) saw_4444 = 1;
                if (wdata == 32'h00555500) saw_5555 = 1;
                if (wdata == 32'h00666600) saw_6666 = 1;

                if ((wdata == 32'hff88c6ff) || (wdata == 32'hffff88c6) ||
                    (wdata == 32'hc6ffff88) || (wdata == 32'h88c6ffff)) begin
                    if (saw_1111 && saw_2222 && saw_3333 &&
                        saw_4444 && saw_5555 && saw_6666) begin
                        $display("[通过] testac 进入 88C6 成功动画");
                        $finish;
                    end else begin
                        $display("[错误] 进入成功动画前阶段标记不完整");
                        $finish;
                    end
                end

                if (wdata[31:24] == 8'hfa) begin
                    $display("[错误] testac 失败显示：%08x", wdata);
                    $finish;
                end
            end

            if (cycle > 200000) begin
                $display("[错误] testac 仿真超时，pc=%08x display=%08x", pc, mmio_display);
                $finish;
            end
        end
    end

endmodule

module testac_mem_model(
    input             clk,
    input             mem_w,
    input      [31:0] addr,
    input      [31:0] wdata,
    input      [2:0]  dm_ctrl,
    output reg [31:0] rdata
);

    reg [31:0] dmem [0:1023];
    integer i;
    wire [9:0] word_addr = addr[11:2];
    wire [31:0] current_word = dmem[word_addr];
    reg [7:0] selected_byte;
    reg [15:0] selected_halfword;

    initial begin
        for (i = 0; i < 1024; i = i + 1)
            dmem[i] = 32'b0;
    end

    always @(*) begin
        case (addr[1:0])
            2'b00: selected_byte = current_word[7:0];
            2'b01: selected_byte = current_word[15:8];
            2'b10: selected_byte = current_word[23:16];
            default: selected_byte = current_word[31:24];
        endcase

        selected_halfword = addr[1] ? current_word[31:16] : current_word[15:0];

        case (dm_ctrl)
            3'b011: rdata = {{24{selected_byte[7]}}, selected_byte};
            3'b100: rdata = {24'b0, selected_byte};
            3'b001: rdata = {{16{selected_halfword[15]}}, selected_halfword};
            3'b010: rdata = {16'b0, selected_halfword};
            default: rdata = current_word;
        endcase
    end

    always @(posedge clk) begin
        if (mem_w && (addr[31:28] != 4'he)) begin
            case (dm_ctrl)
                3'b011: begin
                    case (addr[1:0])
                        2'b00: dmem[word_addr][7:0] <= wdata[7:0];
                        2'b01: dmem[word_addr][15:8] <= wdata[7:0];
                        2'b10: dmem[word_addr][23:16] <= wdata[7:0];
                        default: dmem[word_addr][31:24] <= wdata[7:0];
                    endcase
                end
                3'b001: begin
                    if (addr[1])
                        dmem[word_addr][31:16] <= wdata[15:0];
                    else
                        dmem[word_addr][15:0] <= wdata[15:0];
                end
                default: dmem[word_addr] <= wdata;
            endcase
        end
    end

endmodule
