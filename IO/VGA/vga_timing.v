`timescale 1ns / 1ps

// 640x480@60Hz VGA 扫描时序。
//
// 输入 clk 为板载 100 MHz。模块内部每 4 个 clk 产生一次 pixel_ce，
// 等效 25 MHz 像素节拍。这样不用把分频计数器输出当作新时钟，避免
// 再引入普通 routing 派生时钟。
module vga_timing(
    input             clk,
    input             rst,
    output reg        pixel_ce,
    output reg [9:0]  x,
    output reg [9:0]  y,
    output            active,
    output            hsync,
    output            vsync
);

    localparam [9:0] H_VISIBLE = 10'd640;
    localparam [9:0] H_FRONT   = 10'd16;
    localparam [9:0] H_SYNC    = 10'd96;
    localparam [9:0] H_BACK    = 10'd48;
    localparam [9:0] H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam [9:0] V_VISIBLE = 10'd480;
    localparam [9:0] V_FRONT   = 10'd10;
    localparam [9:0] V_SYNC    = 10'd2;
    localparam [9:0] V_BACK    = 10'd33;
    localparam [9:0] V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    localparam [9:0] H_SYNC_BEG = H_VISIBLE + H_FRONT;
    localparam [9:0] H_SYNC_END = H_VISIBLE + H_FRONT + H_SYNC;
    localparam [9:0] V_SYNC_BEG = V_VISIBLE + V_FRONT;
    localparam [9:0] V_SYNC_END = V_VISIBLE + V_FRONT + V_SYNC;

    reg [1:0] div4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div4     <= 2'b00;
            pixel_ce <= 1'b0;
            x        <= 10'd0;
            y        <= 10'd0;
        end else begin
            div4     <= div4 + 2'b01;
            pixel_ce <= (div4 == 2'b11);

            if (div4 == 2'b11) begin
                if (x == H_TOTAL - 10'd1) begin
                    x <= 10'd0;
                    if (y == V_TOTAL - 10'd1)
                        y <= 10'd0;
                    else
                        y <= y + 10'd1;
                end else begin
                    x <= x + 10'd1;
                end
            end
        end
    end

    assign active = (x < H_VISIBLE) && (y < V_VISIBLE);

    // VGA 同步脉冲为低有效。
    assign hsync = ~((x >= H_SYNC_BEG) && (x < H_SYNC_END));
    assign vsync = ~((y >= V_SYNC_BEG) && (y < V_SYNC_END));

endmodule
