`timescale 1ns / 1ps

// 老师提供的 VGA_Scan 模块，整理为 UTF-8 注释版本。
//
// 输入 clk 为 25MHz VGA 像素时钟。时序对应 640x480：
// - 水平总计 800 像素周期；
// - 垂直总计 525 行；
// - Active=1 时 row/col 为有效显示区域坐标。
module VGA_Scan(
    input            clk,
    input            rst,
    output     [8:0] row,
    output     [9:0] col,
    output           Active,
    output reg       HSYNC,
    output reg       VSYNC
);

    reg [9:0] HCount;
    reg [9:0] VCount;
    reg       HActive;
    reg       VActive;

    localparam [9:0] HSC  = 10'd95;
    localparam [9:0] HBP  = 10'd143;
    localparam [9:0] HACT = 10'd783;
    localparam [9:0] HFP  = 10'd799;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            HCount  <= 10'd0;
            HSYNC   <= 1'b0;
            HActive <= 1'b0;
        end else begin
            HCount <= HCount + 10'd1;
            case (HCount)
                HSC:  HSYNC   <= 1'b1; // 0-95：水平同步脉冲
                HBP:  HActive <= 1'b1; // 96-143：后沿结束，进入有效区
                HACT: HActive <= 1'b0; // 144-783：有效显示结束
                HFP: begin
                    HCount <= 10'd0;   // 784-799：前沿结束，下一行开始
                    HSYNC  <= 1'b0;
                end
                default: ;
            endcase
        end
    end

    localparam [9:0] VSC  = 10'd1;
    localparam [9:0] VBP  = 10'd35;
    localparam [9:0] VACT = 10'd515;
    localparam [9:0] VFP  = 10'd524;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            VCount  <= 10'd0;
            VSYNC   <= 1'b0;
            VActive <= 1'b0;
        end else begin
            if (HCount == HFP) begin
                if (VCount == VFP)
                    VCount <= 10'd0;
                else
                    VCount <= VCount + 10'd1;

                case (VCount)
                    VSC:  VSYNC   <= 1'b1; // 0-1：垂直同步脉冲
                    VBP:  VActive <= 1'b1; // 2-35：后沿结束，进入有效区
                    VACT: VActive <= 1'b0; // 36-515：有效显示结束
                    VFP:  VSYNC   <= 1'b0; // 516-524：前沿结束，下一帧开始
                    default: ;
                endcase
            end
        end
    end

    assign Active = HActive & VActive;
    assign col    = HCount - 10'd144;
    assign row    = VCount[8:0] - 9'd36;

endmodule
