`timescale 1ns / 1ps

// PS/2 键盘外设包装层。
//
// RD 由 MIO_BUS 在 CPU 读取键盘数据地址时拉高。PS2KB 的 rdn 是低有效
// 读确认：RD 拉高后的下一个周期会清除 ready，表示当前扫描码已被 CPU 取走。
module PS2IO(
    input        io_read_clk, // 兼容老师接口，当前逻辑不使用
    input        clk,
    input        rst,
    inout        PS2C,
    inout        PS2D,
    input        RD,
    output [7:0] testkey,

    output reg [31:0] Scancode,
    output wire [7:0] key,
    output wire       PS2Ready
);

    reg  [1:0] get_RD;
    wire       rdn;
    wire [7:0] ps2_key;

    assign testkey = ps2_key;

    always @(posedge clk or posedge rst) begin
        if (rst)
            get_RD <= 2'b00;
        else
            get_RD <= {get_RD[0], RD};
    end

    // get_RD == 2'b10 时产生一次低有效确认，清除 PS2KB.ready。
    assign rdn = ~get_RD[1] | get_RD[0] | ~PS2Ready;

    always @(posedge clk or posedge rst) begin
        if (rst)
            Scancode <= 32'b0;
        else if (get_RD == 2'b01 && PS2Ready)
            Scancode <= {Scancode[23:0], ps2_key};
    end

    // CPU 读键盘数据寄存器且 ready 有效时返回当前扫描码；否则返回 0xaa，
    // 便于软件区分“没有新键值”的情况。
    assign key = (RD && PS2Ready) ? ps2_key : 8'haa;

    PS2KB U_PS2KB(
        .clk  (clk),
        .rst  (rst),
        .PS2C (PS2C),
        .PS2D (PS2D),
        .rdn  (rdn),
        .data (ps2_key),
        .ready(PS2Ready)
    );

endmodule
