`timescale 1ns / 1ps

// Nexys A7 板级顶层。
// Dinosaur 中断版必须绑定 rtl/SCPU.v；老师 SCPU.edf 的中断向量和返回
// 语义不属于当前软件契约，不能与 rtl/SCPU.v 同时加入 Vivado 工程。
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

    // 计数器通道 0 保留老师原接口；游戏定时器复位后默认关闭，软件向
    // 0xFFFF_FE00 写 bit0=1 后产生稳定的 25 Hz 单周期中断脉冲。
    wire counter0_OUT;
    wire counter1_OUT;
    wire counter2_OUT;
    wire game_tick_irq;
    wire game_timer_we = mem_w && (addr_bus == 32'hffff_fe00);
    reg  legacy_timer_armed;
    wire cpu_timer_irq = game_tick_irq | (legacy_timer_armed & counter0_OUT);

    game_timer U_GAME_TIMER(
        .clk(Clk_CPU),
        .rst(rst),
        .enable_we(game_timer_we),
        .enable_data(Cpu_data2bus[0]),
        .tick_irq(game_tick_irq)
    );

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
        .INT(cpu_timer_irq)
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
    wire [3:0]  ram_wea_gated = data_ram_we ? ram_wea : 4'b0000;

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
    // RAM 写使能必须由 MIO_BUS 的 data_ram_we 再门控，否则写外设 MMIO
    // 时 dm_controller 仍可能产生字节写使能，误写数据 RAM。
    RAM_B U3_RAM_B(
        .addra(ram_addr),
        .clka(Clk_RAM),
        .dina(ram_write_data),
        .wea(ram_wea_gated),
        .douta(ram_data_out)
    );

    // GPIO 和计数器外设。
    wire [1:0]  counter_set;
    wire [13:0] GPIOf0;

    // Counter_x 上电从 0 下溢后 counter0_OUT 会保持为 1；只有软件真正
    // 写过通道 0 后才允许它进入 CPU，避免未配置计数器制造中断风暴。
    always @(posedge Clk_IO or posedge rst) begin
        if (rst)
            legacy_timer_armed <= 1'b0;
        else if (counter_we && (counter_set == 2'b00))
            legacy_timer_armed <= 1'b1;
    end

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

    // VGA 文本显示。
    // 软件写 0xC0000000 + (row * 80 + col) * 4 更新一个 16 位文本单元：
    // {颜色属性[15:8], ASCII[7:0]}。SW[15]=1 强制绿色全屏，优先用于
    // 排查 VGA 管脚、线缆和同步；SW[15]=0 显示 CPU 可写文本显存。
    wire        vga_text_we = mem_w && (addr_bus[31:16] == 16'hc000);
    wire [12:0] vga_text_addr = addr_bus[14:2];

    vga_top U12_VGA_TOP(
        .clk       (clk),
        .rst       (rst),
        .cpu_clk   (Clk_IO),
        .cpu_we    (vga_text_we),
        .cpu_waddr (vga_text_addr),
        .cpu_wdata (Cpu_data2bus[15:0]),
        .test_green(SW[15]),
        .VGA_R     (VGA_R),
        .VGA_G     (VGA_G),
        .VGA_B     (VGA_B),
        .VGA_HS    (VGA_HS),
        .VGA_VS    (VGA_VS)
    );

endmodule
