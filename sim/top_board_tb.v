`timescale 1ns/1ps

// 当前工程专用 board/top.v 顶层仿真。
//
// 观察目标：
// 1. CPU 写 0xE0000000 显示 MMIO 时，打印 display_write；
// 2. Multi_8CH32 当前输出变化时，打印 sevenseg_hex；
// 3. dump build/top_board_tb.vcd，可在 GTKWave 中查看 disp_an_o/disp_seg_o。
module top_board_tb;

    reg         clk;
    reg         rstn;
    reg  [15:0] sw_i;
    reg  [4:0]  btn_i;
    tri1        ps2_clk;
    tri1        ps2_data;
    reg         ps2_clk_drive_low;
    reg         ps2_data_drive_low;
    wire [3:0]  VGA_R;
    wire [3:0]  VGA_G;
    wire [3:0]  VGA_B;
    wire        VGA_HS;
    wire        VGA_VS;
    wire [15:0] led_o;
    wire [7:0]  disp_an_o;
    wire [7:0]  disp_seg_o;

    integer i;
    integer cycle;
    integer max_cycles;
    integer imem_words;
    integer dmem_words;
    integer dump_vcd;
    integer force_int_start;
    integer force_int_end;
    integer send_ps2_key;
    integer sw_value;
    integer check_vga;
    integer check_vga_text;
    integer check_dino_ready;
    integer check_dino_tick;
    integer vga_green_samples;
    integer vga_hs_edges;
    integer vga_vs_edges;
    integer saw_vga_o;
    integer saw_vga_k;
    reg [5:0] dino_tiles;
    reg [4:0] ready_letters;
    integer saw_game_timer_enable;
    integer saw_timer_vector;
    integer saw_first_score;
    integer saw_1111;
    integer saw_2222;
    integer saw_3333;
    integer saw_4444;
    integer saw_5555;
    integer saw_6666;
    reg [31:0] last_disp_num;
    reg [31:0] last_display_write;
    reg        last_vga_hs;
    reg        last_vga_vs;
    reg [1023:0] imem_file;
    reg [1023:0] dmem_file;

    assign ps2_clk  = ps2_clk_drive_low  ? 1'b0 : 1'bz;
    assign ps2_data = ps2_data_drive_low ? 1'b0 : 1'bz;

    top U_TOP(
        .clk(clk),
        .rstn(rstn),
        .sw_i(sw_i),
        .btn_i(btn_i),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .led_o(led_o),
        .disp_an_o(disp_an_o),
        .disp_seg_o(disp_seg_o)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100 MHz board clock
    end

    initial begin
        cycle = 0;
        max_cycles = 200000;
        imem_words = 1024;
        dmem_words = 0;
        dump_vcd = 0;
        force_int_start = -1;
        force_int_end = -1;
        send_ps2_key = -1;
        sw_value = 16'h0000; // 默认 SW[7:5]=000，看程序写入的显示通道 data0。
        check_vga = 0;
        check_vga_text = 0;
        check_dino_ready = 0;
        check_dino_tick = 0;
        vga_green_samples = 0;
        vga_hs_edges = 0;
        vga_vs_edges = 0;
        saw_vga_o = 0;
        saw_vga_k = 0;
        dino_tiles = 6'b0;
        ready_letters = 5'b0;
        saw_game_timer_enable = 0;
        saw_timer_vector = 0;
        saw_first_score = 0;
        saw_1111 = 0;
        saw_2222 = 0;
        saw_3333 = 0;
        saw_4444 = 0;
        saw_5555 = 0;
        saw_6666 = 0;
        last_disp_num = 32'hxxxx_xxxx;
        last_display_write = 32'hxxxx_xxxx;
        last_vga_hs = 1'bx;
        last_vga_vs = 1'bx;
        imem_file = "build/top_imem.dat";
        dmem_file = "";

        void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
        void'($value$plusargs("IMEM_WORDS=%d", imem_words));
        void'($value$plusargs("DMEM_WORDS=%d", dmem_words));
        void'($value$plusargs("FORCE_INT_START=%d", force_int_start));
        void'($value$plusargs("FORCE_INT_END=%d", force_int_end));
        void'($value$plusargs("SEND_PS2_KEY=%h", send_ps2_key));
        dump_vcd = $test$plusargs("DUMP_VCD");
        check_vga = $test$plusargs("CHECK_VGA_GREEN");
        check_vga_text = $test$plusargs("CHECK_VGA_TEXT");
        check_dino_ready = $test$plusargs("CHECK_DINO_READY");
        check_dino_tick = $test$plusargs("CHECK_DINO_TICK");
        void'($value$plusargs("SW=%h", sw_value));
        void'($value$plusargs("IMEM=%s", imem_file));
        void'($value$plusargs("DMEM=%s", dmem_file));

        sw_i = sw_value[15:0];
        btn_i = 5'b0;
        ps2_clk_drive_low = 1'b0;
        ps2_data_drive_low = 1'b0;
        rstn = 1'b0;

        for (i = 0; i < 1024; i = i + 1) begin
            U_TOP.U2_ROMD.ROM[i] = 32'h0000_0013;
            U_TOP.U3_RAM_B.RAM[i] = 32'h0000_0000;
        end

        $readmemh(imem_file, U_TOP.U2_ROMD.ROM, 0, imem_words - 1);
        if (dmem_file != "")
            $readmemh(dmem_file, U_TOP.U3_RAM_B.RAM, 0, dmem_words - 1);

        if (dump_vcd) begin
            $dumpfile("build/top_board_tb.vcd");
            $dumpvars(0, top_board_tb);
        end

        $display("[TOP_SIM] imem=%0s dmem=%0s sw=%04h max_cycles=%0d",
                 imem_file, dmem_file, sw_i, max_cycles);
        $display("[TOP_SIM] SW[7:5]=%03b selects Multi_8CH32 display channel", sw_i[7:5]);
        if (check_vga)
            $display("[TOP_SIM] CHECK_VGA enabled: expect SW[15]=1 green test screen");
        if (check_vga_text)
            $display("[TOP_SIM] CHECK_VGA_TEXT enabled: expect writes cell0=ff4f, cell1=ff4b");
        if (check_dino_ready)
            $display("[TOP_SIM] CHECK_DINO_READY enabled: expect custom dino tiles and READY state");
        if (check_dino_tick)
            $display("[TOP_SIM] CHECK_DINO_TICK enabled: expect timer enable, vector 0x340 and score tick");
        if (force_int_start >= 0) begin
            force U_TOP.cpu_timer_irq = 1'b0;
            $display("[TOP_SIM] timer INT held low until cycle %0d", force_int_start);
        end
        #100 rstn = 1'b1;
        if (send_ps2_key >= 0) begin
            #1000;
            send_ps2_byte(send_ps2_key[7:0]);
        end
    end

    task automatic send_ps2_bit;
        input bit_value;
        begin
            ps2_data_drive_low = ~bit_value;
            #20000;
            ps2_clk_drive_low = 1'b1;  // falling edge: PS2KB samples data here
            #20000;
            ps2_clk_drive_low = 1'b0;
            #20000;
        end
    endtask

    task automatic send_ps2_byte;
        input [7:0] code;
        integer bit_idx;
        reg parity_bit;
        begin
            parity_bit = ~^code; // odd parity: data xor parity == 1
            $display("[TOP_SIM] send PS2 scan code=%02x parity=%0b", code, parity_bit);

            send_ps2_bit(1'b0); // start bit
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1)
                send_ps2_bit(code[bit_idx]);
            send_ps2_bit(parity_bit);
            send_ps2_bit(1'b1); // stop bit

            ps2_data_drive_low = 1'b0;
            ps2_clk_drive_low = 1'b0;
        end
    endtask

    task automatic mark_display;
        input [31:0] value;
        begin
            if (value == 32'h00111100) saw_1111 = 1;
            if (value == 32'h00222200) saw_2222 = 1;
            if (value == 32'h00333300) saw_3333 = 1;
            if (value == 32'h00444400) saw_4444 = 1;
            if (value == 32'h00555500) saw_5555 = 1;
            if (value == 32'h00666600) saw_6666 = 1;
        end
    endtask

    task automatic maybe_finish_testac;
        input [31:0] value;
        begin
            if (value[31:24] == 8'hfa) begin
                $display("[TOP_SIM][FAIL] testac failure display=%08x pc=%08x cycle=%0d",
                         value, U_TOP.PC, cycle);
                $finish;
            end

            if ((value == 32'hffff_ffff) || (value == 32'hffef_ffff) ||
                (value == 32'hff88c6ff) || (value == 32'hffff88c6) ||
                (value == 32'hc6ffff88) || (value == 32'h88c6ffff)) begin
                if (saw_1111 && saw_2222 && saw_3333 &&
                    saw_4444 && saw_5555 && saw_6666) begin
                    $display("[TOP_SIM][PASS] testac reached 88C6 success animation at cycle=%0d", cycle);
                    $finish;
                end
            end
        end
    endtask

    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;

            if (U_TOP.mem_w && (U_TOP.addr_bus == 32'hffff_fe00) && U_TOP.Cpu_data2bus[0])
                saw_game_timer_enable = 1;
            if (U_TOP.PC == 32'h0000_0340)
                saw_timer_vector = 1;
            if (U_TOP.mem_w && (U_TOP.addr_bus == 32'he000_0000) &&
                (U_TOP.Cpu_data2bus == 32'h0000_0001))
                saw_first_score = 1;
            if (check_dino_tick && saw_game_timer_enable && saw_timer_vector && saw_first_score) begin
                $display("[TOP_SIM][PASS] dino timer interrupt advanced first frame and score");
                $finish;
            end

            if ((force_int_start >= 0) && (cycle == force_int_start)) begin
                force U_TOP.cpu_timer_irq = 1'b1;
                $display("[TOP_SIM] cycle=%0d force timer INT high", cycle);
            end
            if ((force_int_end >= 0) && (cycle == force_int_end)) begin
                force U_TOP.cpu_timer_irq = 1'b0;
                $display("[TOP_SIM] cycle=%0d force timer INT low", cycle);
            end

            // 程序写显示 MMIO：这是判断“数码管理论显示值”的最可靠事件。
            if (U_TOP.mem_w && (U_TOP.addr_bus == 32'he000_0000) &&
                (U_TOP.Cpu_data2bus !== last_display_write)) begin
                last_display_write = U_TOP.Cpu_data2bus;
                mark_display(U_TOP.Cpu_data2bus);
                $display("[TOP_SIM] cycle=%0d pc=%08x display_write=%08x",
                         cycle, U_TOP.PC, U_TOP.Cpu_data2bus);
                maybe_finish_testac(U_TOP.Cpu_data2bus);
            end

            // 后续 VGA 软件写屏时，用这行确认 CPU 已写入文本显存。
            if (U_TOP.mem_w && (U_TOP.addr_bus[31:16] == 16'hc000)) begin
                $display("[TOP_SIM] cycle=%0d pc=%08x vga_write addr=%08x cell=%0d data=%04x",
                         cycle, U_TOP.PC, U_TOP.addr_bus,
                         U_TOP.addr_bus[14:2], U_TOP.Cpu_data2bus[15:0]);
                if ((U_TOP.addr_bus[14:2] == 13'd0) && (U_TOP.Cpu_data2bus[15:0] == 16'hff4f))
                    saw_vga_o = 1;
                if ((U_TOP.addr_bus[14:2] == 13'd1) && (U_TOP.Cpu_data2bus[15:0] == 16'hff4b))
                    saw_vga_k = 1;
                if (check_vga_text && saw_vga_o && saw_vga_k) begin
                    $display("[TOP_SIM][PASS] VGA text MMIO wrote OK into cells 0 and 1");
                    $finish;
                end
                if ((U_TOP.addr_bus[14:2] == 13'd3770) && (U_TOP.Cpu_data2bus[7:0] == 8'h01)) dino_tiles[0] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd3771) && (U_TOP.Cpu_data2bus[7:0] == 8'h02)) dino_tiles[1] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd3850) && (U_TOP.Cpu_data2bus[7:0] == 8'h03)) dino_tiles[2] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd3851) && (U_TOP.Cpu_data2bus[7:0] == 8'h04)) dino_tiles[3] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd3930) && (U_TOP.Cpu_data2bus[7:0] == 8'h05)) dino_tiles[4] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd3931) && (U_TOP.Cpu_data2bus[7:0] == 8'h06)) dino_tiles[5] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd995) && (U_TOP.Cpu_data2bus[7:0] == 8'h52)) ready_letters[0] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd996) && (U_TOP.Cpu_data2bus[7:0] == 8'h45)) ready_letters[1] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd997) && (U_TOP.Cpu_data2bus[7:0] == 8'h41)) ready_letters[2] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd998) && (U_TOP.Cpu_data2bus[7:0] == 8'h44)) ready_letters[3] = 1'b1;
                if ((U_TOP.addr_bus[14:2] == 13'd999) && (U_TOP.Cpu_data2bus[7:0] == 8'h59)) ready_letters[4] = 1'b1;
                if (check_dino_ready && (&dino_tiles) && (&ready_letters)) begin
                    $display("[TOP_SIM][PASS] dino game reached READY with custom pixel tiles");
                    $finish;
                end
            end

            if (check_vga) begin
                if (last_vga_hs !== 1'bx && (VGA_HS != last_vga_hs))
                    vga_hs_edges = vga_hs_edges + 1;
                if (last_vga_vs !== 1'bx && (VGA_VS != last_vga_vs))
                    vga_vs_edges = vga_vs_edges + 1;
                last_vga_hs = VGA_HS;
                last_vga_vs = VGA_VS;

                if ((VGA_R == 4'h0) && (VGA_G == 4'hf) && (VGA_B == 4'h0))
                    vga_green_samples = vga_green_samples + 1;

                if ((vga_hs_edges >= 4) && (vga_green_samples >= 1000)) begin
                    $display("[TOP_SIM][PASS] VGA green test active: hs_edges=%0d vs_edges=%0d green_samples=%0d",
                             vga_hs_edges, vga_vs_edges, vga_green_samples);
                    $finish;
                end
            end

            // Multi_8CH32 当前选中通道送给 SSeg7 的 8 位十六进制值。
            if (U_TOP.Disp_num !== last_disp_num) begin
                last_disp_num = U_TOP.Disp_num;
                $display("[TOP_SIM] cycle=%0d pc=%08x sevenseg_hex=%08x an=%02x seg=%02x",
                         cycle, U_TOP.PC, U_TOP.Disp_num, disp_an_o, disp_seg_o);
            end

            if (cycle > max_cycles) begin
                $display("[TOP_SIM][TIMEOUT] cycle=%0d pc=%08x display=%08x disp_num=%08x",
                         cycle, U_TOP.PC, last_display_write, U_TOP.Disp_num);
                $finish;
            end
        end
    end

endmodule
