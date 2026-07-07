`timescale 1ns / 1ps

// 数据存储器访问控制器。
// 作用：
// 1. 根据 CPU 给出的字节地址和 dm_ctrl，对 RAM 读数据做字节/半字选择与符号扩展。
// 2. 根据 store 类型产生 RAM_B 的 4 位字节写使能。
// 3. 将 SB/SH 写数据对齐到目标字节通道。
//
// 接口保持与老师提供的 dm_controller 黑盒一致。
module dm_controller(
    input             mem_w,
    input      [31:0] Addr_in,
    input      [31:0] Data_write,
    input      [2:0]  dm_ctrl,
    input      [31:0] Data_read_from_dm,
    output reg [31:0] Data_read,
    output reg [31:0] Data_write_to_dm,
    output reg [3:0]  wea_mem
);

    localparam [2:0] DM_WORD              = 3'b000;
    localparam [2:0] DM_HALFWORD          = 3'b001;
    localparam [2:0] DM_HALFWORD_UNSIGNED = 3'b010;
    localparam [2:0] DM_BYTE              = 3'b011;
    localparam [2:0] DM_BYTE_UNSIGNED     = 3'b100;

    reg [7:0]  selected_byte;
    reg [15:0] selected_halfword;

    always @(*) begin
        case (Addr_in[1:0])
            2'b00: selected_byte = Data_read_from_dm[7:0];
            2'b01: selected_byte = Data_read_from_dm[15:8];
            2'b10: selected_byte = Data_read_from_dm[23:16];
            default: selected_byte = Data_read_from_dm[31:24];
        endcase

        selected_halfword = Addr_in[1]
                          ? Data_read_from_dm[31:16]
                          : Data_read_from_dm[15:0];

        case (dm_ctrl)
            DM_BYTE:              Data_read = {{24{selected_byte[7]}}, selected_byte};
            DM_BYTE_UNSIGNED:     Data_read = {24'b0, selected_byte};
            DM_HALFWORD:          Data_read = {{16{selected_halfword[15]}}, selected_halfword};
            DM_HALFWORD_UNSIGNED: Data_read = {16'b0, selected_halfword};
            default:              Data_read = Data_read_from_dm;
        endcase
    end

    always @(*) begin
        Data_write_to_dm = Data_write;
        wea_mem = 4'b0000;

        if (mem_w) begin
            case (dm_ctrl)
                DM_BYTE: begin
                    case (Addr_in[1:0])
                        2'b00: begin
                            wea_mem = 4'b0001;
                            Data_write_to_dm = {24'b0, Data_write[7:0]};
                        end
                        2'b01: begin
                            wea_mem = 4'b0010;
                            Data_write_to_dm = {16'b0, Data_write[7:0], 8'b0};
                        end
                        2'b10: begin
                            wea_mem = 4'b0100;
                            Data_write_to_dm = {8'b0, Data_write[7:0], 16'b0};
                        end
                        default: begin
                            wea_mem = 4'b1000;
                            Data_write_to_dm = {Data_write[7:0], 24'b0};
                        end
                    endcase
                end

                DM_HALFWORD: begin
                    if (Addr_in[1]) begin
                        wea_mem = 4'b1100;
                        Data_write_to_dm = {Data_write[15:0], 16'b0};
                    end else begin
                        wea_mem = 4'b0011;
                        Data_write_to_dm = {16'b0, Data_write[15:0]};
                    end
                end

                DM_WORD: begin
                    wea_mem = 4'b1111;
                    Data_write_to_dm = Data_write;
                end

                default: begin
                    wea_mem = 4'b0000;
                    Data_write_to_dm = Data_write;
                end
            endcase
        end
    end

endmodule

