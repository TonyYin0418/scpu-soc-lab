`timescale 1ns / 1ps

// VGA 固定测试图案。
//
// 这是 VGA 阶段的第一步硬件验证模块：不依赖 CPU、MIO_BUS、显存或字库。
// 只要管脚和时钟正确，显示器应看到横向彩条、顶部/底部渐变和中心白框。
module vga_test_pattern(
    input            clk,
    input            rst,
    output     [3:0] VGA_R,
    output     [3:0] VGA_G,
    output     [3:0] VGA_B,
    output           VGA_HS,
    output           VGA_VS
);

    reg [1:0] pixel_div;
    wire      pixel_clk_raw;
    wire      pixel_clk;

    always @(posedge clk or posedge rst) begin
        if (rst)
            pixel_div <= 2'b00;
        else
            pixel_div <= pixel_div + 2'b01;
    end

    // 100 MHz / 4 = 25 MHz。用 BUFG 把派生像素时钟送入全局时钟网络。
    assign pixel_clk_raw = pixel_div[1];
    BUFG U_VGA_CLK_BUFG(
        .I(pixel_clk_raw),
        .O(pixel_clk)
    );

    wire [8:0] row;
    wire [9:0] col;
    wire       active;

    VGA_Scan U_VGA_SCAN(
        .clk   (pixel_clk),
        .rst   (rst),
        .row   (row),
        .col   (col),
        .Active(active),
        .HSYNC (VGA_HS),
        .VSYNC (VGA_VS)
    );

    wire border = (row < 9'd8) || (row > 9'd471) ||
                  (col < 10'd8) || (col > 10'd631);
    wire center_box = (row >= 9'd180) && (row <= 9'd300) &&
                      (col >= 10'd260) && (col <= 10'd380);

    reg [11:0] rgb;

    always @(*) begin
        if (!active) begin
            rgb = 12'h000;
        end else if (border) begin
            rgb = 12'hfff;
        end else if (center_box) begin
            rgb = 12'hfff;
        end else begin
            case (col[9:7])
                3'd0: rgb = 12'hf00; // 红
                3'd1: rgb = 12'h0f0; // 绿
                3'd2: rgb = 12'h00f; // 蓝
                3'd3: rgb = 12'hff0; // 黄
                3'd4: rgb = 12'h0ff; // 青
                3'd5: rgb = 12'hf0f; // 紫
                3'd6: rgb = {row[7:4], col[7:4], 4'hf}; // 渐变
                default: rgb = 12'h888; // 灰
            endcase
        end
    end

    assign VGA_R = rgb[11:8];
    assign VGA_G = rgb[7:4];
    assign VGA_B = rgb[3:0];

endmodule
