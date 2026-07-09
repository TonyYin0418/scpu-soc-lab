`timescale 1ns / 1ps

// PS/2 键盘接收器。
//
// PS/2 每帧 11 位：起始位 0、8 位数据、奇校验位、停止位 1。
// 本模块在 PS2C 下降沿采样 PS2D，收到合法帧后置 ready=1。
// rdn 为 CPU 读确认，低有效；确认后 ready 清零，等待下一帧。
module PS2KB(
    input            clk,
    input            rst,
    inout            PS2C,
    inout            PS2D,
    input            rdn,
    output reg [7:0] data,
    output reg       ready
);

    localparam ST_IDLE = 1'b0;
    localparam ST_RECV = 1'b1;

    reg [9:0] shift_reg;
    reg       state;
    reg [1:0] ps2c_sync;

    // 当前只接收键盘发送给 FPGA 的数据，不主动向键盘发送命令，因此总线保持高阻。
    assign PS2C = 1'bz;
    assign PS2D = 1'bz;

    always @(posedge clk or posedge rst) begin
        if (rst)
            ps2c_sync <= 2'b11;
        else
            ps2c_sync <= {ps2c_sync[0], PS2C};
    end

    wire ps2c_falling = (ps2c_sync == 2'b10);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            shift_reg <= 10'b1000000000;
            state     <= ST_IDLE;
            data      <= 8'b0;
            ready     <= 1'b0;
        end else begin
            if (!rdn && ready)
                ready <= 1'b0;

            case (state)
                ST_IDLE: begin
                    shift_reg <= 10'b1000000000;
                    if (ps2c_falling && !PS2D)
                        state <= ST_RECV; // 检测到起始位
                end

                ST_RECV: begin
                    if (ps2c_falling) begin
                        if (shift_reg[0] && PS2D) begin
                            // shift_reg[8:1] 是 8 位扫描码；shift_reg[9] 是校验位。
                            // PS/2 使用奇校验，data+parity 的异或值为 1 才认为有效。
                            ready <= ^shift_reg[9:1];
                            data  <= shift_reg[8:1];
                            state <= ST_IDLE;
                        end else begin
                            shift_reg <= {PS2D, shift_reg[9:1]};
                        end
                    end
                end
            endcase
        end
    end

endmodule
