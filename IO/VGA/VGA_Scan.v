`timescale 1ns / 1ps

// 640x480@60Hz VGA 扫描时序。
//
// 输入 clk 应为 25 MHz 像素时钟。输出 row/col 只在 Active=1 时表示
// 当前有效显示区域内的像素坐标：col=0..639, row=0..479。
module VGA_Scan(
    input            clk,
    input            rst,
    output     [8:0] row,
    output     [9:0] col,
    output           Active,
    output reg       HSYNC,
    output reg       VSYNC
);

    // 640x480@60Hz 标准时序，总计 800x525。
    localparam [9:0] H_SYNC_END   = 10'd95;
    localparam [9:0] H_ACTIVE_BEG = 10'd144;
    localparam [9:0] H_ACTIVE_END = 10'd783;
    localparam [9:0] H_LINE_END   = 10'd799;

    localparam [9:0] V_SYNC_END   = 10'd1;
    localparam [9:0] V_ACTIVE_BEG = 10'd36;
    localparam [9:0] V_ACTIVE_END = 10'd515;
    localparam [9:0] V_FRAME_END  = 10'd524;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
            HSYNC   <= 1'b0;
            VSYNC   <= 1'b0;
        end else begin
            if (h_count == H_LINE_END) begin
                h_count <= 10'd0;
                if (v_count == V_FRAME_END)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end

            // 老师给的原始模块使用低电平同步脉冲，这里保持同样极性。
            HSYNC <= (h_count > H_SYNC_END);
            VSYNC <= (v_count > V_SYNC_END);
        end
    end

    assign Active = (h_count >= H_ACTIVE_BEG) && (h_count <= H_ACTIVE_END) &&
                    (v_count >= V_ACTIVE_BEG) && (v_count <= V_ACTIVE_END);

    assign col = h_count - H_ACTIVE_BEG;
    assign row = v_count - V_ACTIVE_BEG;

endmodule
