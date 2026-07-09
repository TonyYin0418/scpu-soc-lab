`timescale 1ns / 1ps

// Nexys A7 板级顶层。
// 本阶段使用老师提供的 SCPU.edf 和外围 EDF，按 schematic.pdf 连接。
module top(
    input             clk,
    input             rstn,
    input      [15:0] sw_i,
    input      [4:0]  btn_i,
    inout             ps2_clk,
    inout             ps2_data,
    output     [3:0]  VGA_R,
    output     [3:0]  VGA_G,
    output     [3:0]  VGA_B,
    output            VGA_HS,
    output            VGA_VS,
    output     [15:0] led_o,
    output     [7:0]  disp_an_o,
    output     [7:0]  disp_seg_o
);

    wire rst = ~rstn;

    // 输入整理。当前老师提供的 Enter 只做直通，后续如有要求再加入去抖。
    wire [4:0]  BTN;
    wire [15:0] SW;

    Enter U10_Enter(
        .clk(clk),
        .BTN(btn_i),
        .SW(sw_i),
        .BTN_out(BTN),
        .SW_out(SW)
    );

    // SW[2] 选择老师给定的快/慢 CPU 时钟。
    wire [31:0] clkdiv;
    wire        Clk_CPU;
    wire        Clk_IO = ~Clk_CPU;
    wire        Clk_RAM = ~clk;

    clk_div U8_clk_div(
        .clk(clk),
        .rst(rst),
        .SW2(SW[2]),
        .clkdiv(clkdiv),
        .Clk_CPU(Clk_CPU)
    );

    // CPU、指令 ROM 与数据总线。
    wire [31:0] inst;
    wire [31:0] PC;
    wire [31:0] addr_bus;
    wire [31:0] Cpu_data2bus;
    wire [31:0] Cpu_data4bus;
    wire [31:0] Data_read;
    wire [2:0]  dm_ctrl;
    wire        mem_w;
    wire        CPU_MIO;

    // 计数器通道 0 按原理图连接到 INT；老师 SCPU 当前可直接使用该接口。
    wire counter0_OUT;
    wire counter1_OUT;
    wire counter2_OUT;

    ROM_D U2_ROMD(
        .a(PC[11:2]),
        .spo(inst)
    );

    SCPU U1_SCPU(
        .clk(Clk_CPU),
        .reset(rst),
        .MIO_ready(CPU_MIO),
        .inst_in(inst),
        .Data_in(Data_read),
        .mem_w(mem_w),
        .PC_out(PC),
        .Addr_out(addr_bus),
        .Data_out(Cpu_data2bus),
        .dm_ctrl(dm_ctrl),
        .CPU_MIO(CPU_MIO),
        .INT(counter0_OUT)
    );

    // MIO_BUS 将 CPU 地址空间划分为数据 RAM、GPIO 和计数器外设。
    wire [31:0] ram_data_in;
    wire [31:0] ram_data_out;
    wire [9:0]  ram_addr;
    wire        data_ram_we;
    wire        GPIOf0000000_we;
    wire        GPIOe0000000_we;
    wire        counter_we;
    wire [31:0] Peripheral_in;
    wire [31:0] counter_out;
    wire [15:0] LED_out;
    wire [7:0]  ps2_key;
    wire [7:0]  ps2_testkey;
    wire [31:0] ps2_scancode;
    wire        ps2_ready;
    wire        ps2_read;

    // PS/2 键盘外设。
    // CPU 读取 0xD0000000 时，MIO_BUS 拉高 ps2_read，读取当前扫描码并清 ready。
    PS2IO U11_PS2IO(
        .io_read_clk(Clk_IO),
        .clk        (clk),
        .rst        (rst),
        .PS2C       (ps2_clk),
        .PS2D       (ps2_data),
        .RD         (ps2_read),
        .testkey    (ps2_testkey),
        .Scancode   (ps2_scancode),
        .key        (ps2_key),
        .PS2Ready   (ps2_ready)
    );

    MIO_BUS U4_MIO_BUS(
        .clk(clk),
        .rst(rst),
        .BTN(BTN),
        .SW(SW),
        .PC(PC),
        .mem_w(mem_w),
        .Cpu_data2bus(Cpu_data2bus),
        .addr_bus(addr_bus),
        .ram_data_out(ram_data_out),
        .led_out(LED_out),
        .counter_out(counter_out),
        .counter0_out(counter0_OUT),
        .counter1_out(counter1_OUT),
        .counter2_out(counter2_OUT),
        .ps2_key(ps2_key),
        .ps2_scancode(ps2_scancode),
        .ps2_ready(ps2_ready),
        .Cpu_data4bus(Cpu_data4bus),
        .ram_data_in(ram_data_in),
        .ram_addr(ram_addr),
        .data_ram_we(data_ram_we),
        .GPIOf0000000_we(GPIOf0000000_we),
        .GPIOe0000000_we(GPIOe0000000_we),
        .counter_we(counter_we),
        .Peripheral_in(Peripheral_in),
        .ps2_read(ps2_read)
    );

    // data_ram_we 是 MIO_BUS 的旧版兼容输出；本原理图由 dm_controller
    // 根据 CPU 的 mem_w 和 dm_ctrl 产生最终四位 RAM 写使能。

    // 外部数据存储器使用 4 路字节写使能，支持 LB/LH/LW/SB/SH/SW。
    wire [31:0] ram_write_data;
    wire [3:0]  ram_wea;

    dm_controller U3_dm_controller(
        .mem_w(mem_w),
        .Addr_in(addr_bus),
        .Data_write(ram_data_in),
        .dm_ctrl(dm_ctrl),
        .Data_read_from_dm(Cpu_data4bus),
        .Data_read(Data_read),
        .Data_write_to_dm(ram_write_data),
        .wea_mem(ram_wea)
    );

    // 老师原理图中 RAM 使用板载 100 MHz 时钟的反相时钟。
    RAM_B U3_RAM_B(
        .addra(ram_addr),
        .clka(Clk_RAM),
        .dina(ram_write_data),
        .wea(ram_wea),
        .douta(ram_data_out)
    );

    // GPIO 和计数器外设。
    wire [1:0]  counter_set;
    wire [13:0] GPIOf0;

    SPIO U7_SPIO(
        .clk(Clk_IO),
        .rst(rst),
        .EN(GPIOf0000000_we),
        .P_Data(Peripheral_in),
        .counter_set(counter_set),
        .LED_out(LED_out),
        .led(led_o),
        .GPIOf0(GPIOf0)
    );

    Counter_x U9_Counter_x(
        .clk(Clk_IO),
        .rst(rst),
        .clk0(clkdiv[6]),
        .clk1(clkdiv[9]),
        .clk2(clkdiv[11]),
        .counter_we(counter_we),
        .counter_val(Peripheral_in),
        .counter_ch(counter_set),
        .counter0_OUT(counter0_OUT),
        .counter1_OUT(counter1_OUT),
        .counter2_OUT(counter2_OUT),
        .counter_out(counter_out)
    );

    // SW[7:5] 选择八组 32 位数据送往数码管。
    // 0: 外设输入，1: 字地址 PC，2: 指令，3: 计数器，
    // 4: 总线地址，5: CPU 写数据，6: CPU 读数据，7: 字节地址 PC。
    wire [31:0] Disp_num;
    wire [7:0]  point_out;
    wire [7:0]  LE_out;

    Multi_8CH32 U5_Multi_8CH32(
        .clk(Clk_IO),
        .rst(rst),
        .EN(GPIOe0000000_we),
        .Switch(SW[7:5]),
        .point_in({clkdiv, clkdiv}),
        .LES(64'hffff_ffff_ffff_ffff),
        .data0(Peripheral_in),
        .data1({2'b0, PC[31:2]}),
        .data2(inst),
        .data3(counter_out),
        .data4(addr_bus),
        .data5(Cpu_data2bus),
        .data6(Cpu_data4bus),
        .data7(PC),
        .point_out(point_out),
        .LE_out(LE_out),
        .Disp_num(Disp_num)
    );

    SSeg7 U6_SSeg7(
        .clk(clk),
        .rst(rst),
        .SW0(SW[0]),
        .flash(clkdiv[10]),
        .Hexs(Disp_num),
        .point(point_out),
        .LES(LE_out),
        .seg_an(disp_an_o),
        .seg_sout(disp_seg_o)
    );

    // VGA 第一阶段只输出固定测试图案，验证显示器、管脚和 25 MHz 扫描时序。
    // 后续应用阶段再把 VGA 接入 CPU 可写显存 / MMIO。
    vga_test_pattern U12_VGA_TEST(
        .clk   (clk),
        .rst   (rst),
        .VGA_R (VGA_R),
        .VGA_G (VGA_G),
        .VGA_B (VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS)
    );

endmodule
