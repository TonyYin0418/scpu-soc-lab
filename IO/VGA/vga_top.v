`timescale 1ns / 1ps

// VGA 文本显示顶层。
//
// 对 CPU 暴露一个 80x60 文本显存写口，对外输出 Nexys A7 VGA 信号。
// SW[15] 接到 test_green 时可强制绿色全屏，用于优先排查管脚和同步。
module vga_top(
    input             clk,
    input             rst,
    input             cpu_clk,
    input             cpu_we,
    input      [12:0] cpu_waddr,
    input      [15:0] cpu_wdata,
    input             test_green,

    output reg [3:0]  VGA_R,
    output reg [3:0]  VGA_G,
    output reg [3:0]  VGA_B,
    output            VGA_HS,
    output            VGA_VS
);

    wire        pixel_ce;
    wire [9:0]  x;
    wire [9:0]  y;
    wire        active;
    wire        hsync;
    wire        vsync;

    vga_timing U_TIMING(
        .clk(clk),
        .rst(rst),
        .pixel_ce(pixel_ce),
        .x(x),
        .y(y),
        .active(active),
        .hsync(hsync),
        .vsync(vsync)
    );

    wire [12:0] text_raddr;
    wire [15:0] text_rdata;

    vga_text_ram U_TEXT_RAM(
        .cpu_clk(cpu_clk),
        .cpu_we(cpu_we),
        .cpu_waddr(cpu_waddr),
        .cpu_wdata(cpu_wdata),
        .vga_raddr(text_raddr),
        .vga_rdata(text_rdata)
    );

    wire [3:0] text_r;
    wire [3:0] text_g;
    wire [3:0] text_b;

    vga_text_renderer U_RENDERER(
        .x(x),
        .y(y),
        .active(active),
        .cell_data(text_rdata),
        .cell_addr(text_raddr),
        .red(text_r),
        .green(text_g),
        .blue(text_b)
    );

    assign VGA_HS = hsync;
    assign VGA_VS = vsync;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            VGA_R <= 4'h0;
            VGA_G <= 4'h0;
            VGA_B <= 4'h0;
        end else if (pixel_ce) begin
            if (!active) begin
                VGA_R <= 4'h0;
                VGA_G <= 4'h0;
                VGA_B <= 4'h0;
            end else if (test_green) begin
                VGA_R <= 4'h0;
                VGA_G <= 4'hf;
                VGA_B <= 4'h0;
            end else begin
                VGA_R <= text_r;
                VGA_G <= text_g;
                VGA_B <= text_b;
            end
        end
    end

endmodule
