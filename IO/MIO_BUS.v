`timescale 1ns / 1ps

// 板级存储器 / IO 地址译码。
//
// 保持老师原 MIO_BUS 的主要地址行为：
//   RAM          : 其他地址段，读写数据 RAM
//   0xE0000000  : 七段数码管写入口；读 BTN/SW
//   0xF0000000  : LED / SPIO 写入口；读 LED 状态。SPIO 同时把写数据的
//                 低 2 位锁存为 Counter_x 的通道选择（老师 Counter_8253
//                 注释约定：f0000000 bit1 bit0 选通道）
//   0xF0000004  : Counter_x 写入口；数值写入当前通道选择指向的
//                 计数值寄存器（通道 0..2）或控制字（通道 3）
//
// 本工程新增 PS/2 键盘 MMIO：
//   0xD0000000  : 读 {23'b0, ps2_ready, ps2_key}，并产生 ps2_read 脉冲
//   0xD0000004  : 读最近四个键盘扫描码拼成的 ps2_scancode
//
// 本工程新增 VGA 文本显存写地址：
//   0xC0000000  : 文本显存基址，由 board/top.v 直接根据 addr_bus/mem_w 写入。
//                 MIO_BUS 这里只负责把 0xC... 排除出普通 RAM 段，避免误写 RAM。
module MIO_BUS(
    input             clk,
    input             rst,
    input      [4:0]  BTN,
    input      [15:0] SW,
    input      [31:0] PC,
    input             mem_w,
    input      [31:0] Cpu_data2bus,
    input      [31:0] addr_bus,
    input      [31:0] ram_data_out,
    input      [15:0] led_out,
    input      [31:0] counter_out,
    input             counter0_out,
    input             counter1_out,
    input             counter2_out,
    input      [7:0]  ps2_key,
    input      [31:0] ps2_scancode,
    input             ps2_ready,
    output     [31:0] Cpu_data4bus,
    output     [31:0] ram_data_in,
    output     [9:0]  ram_addr,
    output            data_ram_we,
    output            GPIOf0000000_we,
    output            GPIOe0000000_we,
    output            counter_we,
    output     [31:0] Peripheral_in,
    output            ps2_read
);

    wire is_vga      = (addr_bus[31:28] == 4'hc);
    wire is_ps2_key  = (addr_bus == 32'hd000_0000);
    wire is_ps2_scan = (addr_bus == 32'hd000_0004);
    wire is_gpioe    = (addr_bus == 32'he000_0000);
    wire is_gpiof    = (addr_bus == 32'hf000_0000);
    wire is_counter  = (addr_bus == 32'hf000_0004);
    wire is_ram      = !is_vga &&
                       (addr_bus[31:28] != 4'hd) &&
                       (addr_bus[31:28] != 4'he) &&
                       (addr_bus[31:28] != 4'hf);

    // 当前 board/top.v 中 RAM_B.wea 来自 dm_controller(mem_w)，不是 data_ram_we。
    // 因此非 RAM 访问时把 ram_addr 指向保留尾地址，避免 MMIO 写误伤低地址数据区。
    assign ram_addr    = is_ram ? addr_bus[11:2] : 10'h3ff;
    assign ram_data_in = Cpu_data2bus;
    assign data_ram_we = mem_w && is_ram;

    assign GPIOe0000000_we = mem_w && is_gpioe;
    assign GPIOf0000000_we = mem_w && is_gpiof;

    // 计时器写通道。老师参考 MIO_BUS 声明了 counter_we 但未给出译码地址，
    // 这里选用通道选择地址旁边的 0xF0000004 作为写入口。
    assign counter_we = mem_w && is_counter;

    assign Peripheral_in = Cpu_data2bus;

    // CPU 读键盘数据寄存器时向 PS2IO 发出读请求。
    // 只在非写访问时有效，避免软件写 0xD0000000 时误清 ready。
    assign ps2_read = is_ps2_key && !mem_w;

    assign Cpu_data4bus =
        is_ram      ? ram_data_out :
        is_ps2_key  ? {23'b0, ps2_ready, ps2_key} :
        is_ps2_scan ? ps2_scancode :
        is_gpioe    ? {11'b0, BTN, SW} :
        is_gpiof    ? {14'b0, led_out, 2'b00} :
                      32'b0;

    // 未使用输入保留在接口中，是为了和老师原理图/模块端口保持兼容。
    wire unused = clk ^ rst ^ PC[0] ^ counter_out[0] ^
                  counter0_out ^ counter1_out ^ counter2_out;

endmodule
