`timescale 1ns/1ps

module game_timer_tb;
    reg clk;
    reg rst;
    reg enable_we;
    reg enable_data;
    wire tick_irq;
    integer cycle;
    integer pulses;

    game_timer #(.PERIOD_CYCLES(4)) dut(
        .clk(clk), .rst(rst), .enable_we(enable_we),
        .enable_data(enable_data), .tick_irq(tick_irq)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (!rst) begin
            cycle = cycle + 1;
            if (tick_irq)
                pulses = pulses + 1;
        end
    end

    initial begin
        cycle = 0;
        pulses = 0;
        rst = 1'b1;
        enable_we = 1'b0;
        enable_data = 1'b0;
        #12 rst = 1'b0;

        repeat (6) @(posedge clk);
        if (pulses != 0)
            $fatal(1, "[GAME_TIMER][FAIL] timer fired while disabled");

        @(negedge clk);
        enable_data = 1'b1;
        enable_we = 1'b1;
        @(negedge clk);
        enable_we = 1'b0;

        repeat (14) @(posedge clk);
        if (pulses != 3)
            $fatal(1, "[GAME_TIMER][FAIL] pulses=%0d expected=3", pulses);

        @(negedge clk);
        enable_data = 1'b0;
        enable_we = 1'b1;
        @(negedge clk);
        enable_we = 1'b0;
        repeat (6) @(posedge clk);
        if (pulses != 3)
            $fatal(1, "[GAME_TIMER][FAIL] disable did not stop timer");

        $display("[GAME_TIMER][PASS] disabled-safe periodic one-cycle tick");
        $finish;
    end
endmodule
