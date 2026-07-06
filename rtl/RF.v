`timescale 1ns/1ps

// 32×32 位通用寄存器堆：双异步读、单同步写。
module RF(
    input             clk,
    input             rst,
    input             RFWr,
    input      [4:0]  A1,
    input      [4:0]  A2,
    input      [4:0]  A3,
    input      [31:0] WD,
    input      [4:0]  debug_addr,
    output     [31:0] RD1,
    output     [31:0] RD2,
    output     [31:0] debug_data
);

    reg [31:0] rf [0:31];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                rf[i] <= 32'b0;
        end else if (RFWr && (A3 != 5'b0)) begin
            // x0 恒为 0，忽略对 x0 的写入。
            rf[A3] <= WD;
        end
    end

    assign RD1 = (A1 == 5'b0) ? 32'b0 : rf[A1];
    assign RD2 = (A2 == 5'b0) ? 32'b0 : rf[A2];
    assign debug_data = (debug_addr == 5'b0) ? 32'b0 : rf[debug_addr];

endmodule
