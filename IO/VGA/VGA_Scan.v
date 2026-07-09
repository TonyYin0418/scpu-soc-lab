`timescale 1ns / 1ps

// 640x480@60Hz VGA 扫描时序。
//
// 输入 clk 使用板载 100 MHz 时钟，pixel_ce 每 4 个 clk 周期拉高一次，
// 等效 25 MHz 像素更新节拍。这里采用最常见的 640x480 VGA 参数：
//   Horizontal: 640 visible + 16 front + 96 sync + 48 back = 800
//   Vertical  : 480 visible + 10 front +  2 sync + 33 back = 525
// HSYNC/VSYNC 均为负极性。输出 row/col 只在 Active=1 时有效。
module VGA_Scan(
    input            clk,
    input            rst,
    input            pixel_ce,
    output     [8:0] row,
    output     [9:0] col,
    output           Active,
    output reg       HSYNC,
    output reg       VSYNC
);

    localparam [9:0] H_VISIBLE    = 10'd640;
    localparam [9:0] H_FRONT      = 10'd16;
    localparam [9:0] H_SYNC       = 10'd96;
    localparam [9:0] H_BACK       = 10'd48;
    localparam [9:0] H_TOTAL      = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;
    localparam [9:0] H_SYNC_START = H_VISIBLE + H_FRONT;
    localparam [9:0] H_SYNC_END   = H_VISIBLE + H_FRONT + H_SYNC;

    localparam [9:0] V_VISIBLE    = 10'd480;
    localparam [9:0] V_FRONT      = 10'd10;
    localparam [9:0] V_SYNC       = 10'd2;
    localparam [9:0] V_BACK       = 10'd33;
    localparam [9:0] V_TOTAL      = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;
    localparam [9:0] V_SYNC_START = V_VISIBLE + V_FRONT;
    localparam [9:0] V_SYNC_END   = V_VISIBLE + V_FRONT + V_SYNC;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
            HSYNC   <= 1'b0;
            VSYNC   <= 1'b0;
        end else if (pixel_ce) begin
            if (h_count == H_TOTAL - 10'd1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 10'd1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end

            HSYNC <= ~((h_count >= H_SYNC_START) && (h_count < H_SYNC_END));
            VSYNC <= ~((v_count >= V_SYNC_START) && (v_count < V_SYNC_END));
        end
    end

    assign Active = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    assign col = h_count;
    assign row = v_count[8:0];

endmodule
