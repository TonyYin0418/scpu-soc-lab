`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Board-level simulation models.
//
// 这些模块只给 Icarus/top 级仿真使用，不能加入 Vivado 综合源。
// Vivado 下 ROM_D/RAM_B/BUFG 和老师提供的 EDF/IP 由工程或 IP Catalog 提供。
// -----------------------------------------------------------------------------

module BUFG(
    input  I,
    output O
);
    assign O = I;
endmodule

module ROM_D(
    input      [9:0]  a,
    output     [31:0] spo
);
    reg [31:0] ROM [0:1023];
    integer i;

    initial begin
        for (i = 0; i < 1024; i = i + 1)
            ROM[i] = 32'h0000_0013; // addi x0,x0,0
    end

    assign spo = ROM[a];
endmodule

module RAM_B(
    input             clka,
    input      [3:0]  wea,
    input      [9:0]  addra,
    input      [31:0] dina,
    output     [31:0] douta
);
    reg [31:0] RAM [0:1023];
    integer i;

    initial begin
        for (i = 0; i < 1024; i = i + 1)
            RAM[i] = 32'h0000_0000;
    end

    always @(posedge clka) begin
        if (wea[0]) RAM[addra][7:0]   <= dina[7:0];
        if (wea[1]) RAM[addra][15:8]  <= dina[15:8];
        if (wea[2]) RAM[addra][23:16] <= dina[23:16];
        if (wea[3]) RAM[addra][31:24] <= dina[31:24];
    end

    // 仿真中使用异步读，便于观察 CPU/总线功能；真实 Vivado IP 的读延迟
    // 以 IP 配置为准，上板验收仍以 bitstream 为准。
    assign douta = RAM[addra];
endmodule

// MIO_BUS 使用真实 RTL（IO/MIO_BUS.v，见 top_board_sim_files.f）。
// 之前这里有一份行为级副本，与真实译码逐渐脱节（counter_we 常年为 0），
// 仿真验证不到真实地址译码，故删除。
module SPIO(
    input             clk,
    input             rst,
    input             EN,
    input      [31:0] P_Data,
    output reg [1:0]  counter_set,
    output reg [15:0] LED_out,
    output     [15:0] led,
    output reg [13:0] GPIOf0
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            LED_out     <= 16'b0;
            counter_set <= 2'b0;
            GPIOf0      <= 14'b0;
        end else if (EN) begin
            LED_out     <= P_Data[15:0];
            counter_set <= P_Data[1:0];
            GPIOf0      <= P_Data[15:2];
        end
    end

    assign led = LED_out;
endmodule

module Multi_8CH32(
    input             clk,
    input             rst,
    input             EN,
    input      [2:0]  Switch,
    input      [63:0] point_in,
    input      [63:0] LES,
    input      [31:0] data0,
    input      [31:0] data1,
    input      [31:0] data2,
    input      [31:0] data3,
    input      [31:0] data4,
    input      [31:0] data5,
    input      [31:0] data6,
    input      [31:0] data7,
    output reg [7:0]  point_out,
    output reg [7:0]  LE_out,
    output reg [31:0] Disp_num
);
    reg [31:0] data0_latched;

    always @(posedge clk or posedge rst) begin
        if (rst)
            data0_latched <= 32'b0;
        else if (EN)
            data0_latched <= data0;
    end

    always @(*) begin
        point_out = point_in[7:0];
        LE_out    = LES[7:0];
        case (Switch)
            3'b000: Disp_num = data0_latched;
            3'b001: Disp_num = data1;
            3'b010: Disp_num = data2;
            3'b011: Disp_num = data3;
            3'b100: Disp_num = data4;
            3'b101: Disp_num = data5;
            3'b110: Disp_num = data6;
            default: Disp_num = data7;
        endcase
    end
endmodule

module SSeg7(
    input             clk,
    input             rst,
    input             SW0,
    input             flash,
    input      [31:0] Hexs,
    input      [7:0]  point,
    input      [7:0]  LES,
    output reg [7:0]  seg_an,
    output reg [7:0]  seg_sout
);
    reg [2:0] scan;
    reg [3:0] hex;

    function [6:0] seg7_active_low;
        input [3:0] v;
        begin
            case (v)
                4'h0: seg7_active_low = 7'b1000000;
                4'h1: seg7_active_low = 7'b1111001;
                4'h2: seg7_active_low = 7'b0100100;
                4'h3: seg7_active_low = 7'b0110000;
                4'h4: seg7_active_low = 7'b0011001;
                4'h5: seg7_active_low = 7'b0010010;
                4'h6: seg7_active_low = 7'b0000010;
                4'h7: seg7_active_low = 7'b1111000;
                4'h8: seg7_active_low = 7'b0000000;
                4'h9: seg7_active_low = 7'b0010000;
                4'ha: seg7_active_low = 7'b0001000;
                4'hb: seg7_active_low = 7'b0000011;
                4'hc: seg7_active_low = 7'b1000110;
                4'hd: seg7_active_low = 7'b0100001;
                4'he: seg7_active_low = 7'b0000110;
                default: seg7_active_low = 7'b0001110;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst)
            scan <= 3'b0;
        else
            scan <= scan + 3'b1;
    end

    always @(*) begin
        case (scan)
            3'd0: hex = Hexs[3:0];
            3'd1: hex = Hexs[7:4];
            3'd2: hex = Hexs[11:8];
            3'd3: hex = Hexs[15:12];
            3'd4: hex = Hexs[19:16];
            3'd5: hex = Hexs[23:20];
            3'd6: hex = Hexs[27:24];
            default: hex = Hexs[31:28];
        endcase

        seg_an = ~(8'b0000_0001 << scan);
        if (!LES[scan] || (SW0 && flash))
            seg_sout = 8'hff;
        else
            seg_sout = {~point[scan], seg7_active_low(hex)};
    end
endmodule
