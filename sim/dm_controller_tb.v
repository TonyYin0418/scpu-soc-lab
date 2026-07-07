`timescale 1ns/1ps

module dm_controller_tb;
    localparam [2:0] DM_WORD              = 3'b000;
    localparam [2:0] DM_HALFWORD          = 3'b001;
    localparam [2:0] DM_HALFWORD_UNSIGNED = 3'b010;
    localparam [2:0] DM_BYTE              = 3'b011;
    localparam [2:0] DM_BYTE_UNSIGNED     = 3'b100;

    reg         mem_w;
    reg  [31:0] Addr_in;
    reg  [31:0] Data_write;
    reg  [2:0]  dm_ctrl;
    reg  [31:0] Data_read_from_dm;
    wire [31:0] Data_read;
    wire [31:0] Data_write_to_dm;
    wire [3:0]  wea_mem;

    integer errors;

    dm_controller U_DUT(
        .mem_w(mem_w),
        .Addr_in(Addr_in),
        .Data_write(Data_write),
        .dm_ctrl(dm_ctrl),
        .Data_read_from_dm(Data_read_from_dm),
        .Data_read(Data_read),
        .Data_write_to_dm(Data_write_to_dm),
        .wea_mem(wea_mem)
    );

    task automatic check_read;
        input [31:0] addr;
        input [2:0]  kind;
        input [31:0] expected;
        begin
            mem_w = 1'b0;
            Addr_in = addr;
            dm_ctrl = kind;
            #1;
            if (Data_read !== expected) begin
                errors = errors + 1;
                $display("[错误] read addr=%0d kind=%03b actual=%08x expected=%08x",
                         addr[1:0], kind, Data_read, expected);
            end
        end
    endtask

    task automatic check_write;
        input [31:0] addr;
        input [2:0]  kind;
        input [3:0]  expected_wea;
        input [31:0] expected_data;
        begin
            mem_w = 1'b1;
            Addr_in = addr;
            dm_ctrl = kind;
            #1;
            if (wea_mem !== expected_wea || Data_write_to_dm !== expected_data) begin
                errors = errors + 1;
                $display("[错误] write addr=%0d kind=%03b wea=%04b/%04b data=%08x/%08x",
                         addr[1:0], kind, wea_mem, expected_wea,
                         Data_write_to_dm, expected_data);
            end
        end
    endtask

    initial begin
        errors = 0;
        mem_w = 1'b0;
        Addr_in = 32'b0;
        Data_write = 32'haabb_ccdd;
        dm_ctrl = DM_WORD;
        Data_read_from_dm = 32'h80ff_7f01;

        check_read(32'd0, DM_WORD,              32'h80ff_7f01);
        check_read(32'd0, DM_BYTE,              32'h0000_0001);
        check_read(32'd1, DM_BYTE,              32'h0000_007f);
        check_read(32'd2, DM_BYTE,              32'hffff_ffff);
        check_read(32'd3, DM_BYTE,              32'hffff_ff80);
        check_read(32'd2, DM_BYTE_UNSIGNED,     32'h0000_00ff);
        check_read(32'd0, DM_HALFWORD,          32'h0000_7f01);
        check_read(32'd2, DM_HALFWORD,          32'hffff_80ff);
        check_read(32'd2, DM_HALFWORD_UNSIGNED, 32'h0000_80ff);

        mem_w = 1'b0;
        dm_ctrl = DM_WORD;
        #1;
        if (wea_mem !== 4'b0000) begin
            errors = errors + 1;
            $display("[错误] mem_w=0 时 wea_mem=%04b，期望 0000", wea_mem);
        end

        check_write(32'd0, DM_WORD,     4'b1111, 32'haabb_ccdd);
        check_write(32'd0, DM_BYTE,     4'b0001, 32'h0000_00dd);
        check_write(32'd1, DM_BYTE,     4'b0010, 32'h0000_dd00);
        check_write(32'd2, DM_BYTE,     4'b0100, 32'h00dd_0000);
        check_write(32'd3, DM_BYTE,     4'b1000, 32'hdd00_0000);
        check_write(32'd0, DM_HALFWORD, 4'b0011, 32'h0000_ccdd);
        check_write(32'd2, DM_HALFWORD, 4'b1100, 32'hccdd_0000);

        if (errors == 0) begin
            $display("[通过] dm_controller 自检通过");
            $finish;
        end

        $display("[失败] dm_controller 自检错误数=%0d", errors);
        $finish;
    end
endmodule

