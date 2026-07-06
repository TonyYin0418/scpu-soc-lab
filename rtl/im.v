`timescale 1ns/1ps

// 指令存储器：128 个 32 位字，按字地址读取。
module im(
    input      [8:2]  addr,
    output     [31:0] dout
);

    reg [31:0] ROM [0:127];

    assign dout = ROM[addr];

endmodule
