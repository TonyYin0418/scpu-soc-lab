`timescale 1ns/1ps

// Fixed-rate application tick for the dinosaur game.
//
// The timer is disabled after reset, so legacy ROM images see no new
// interrupts. Software writes bit 0 to 0xFFFF_FE00 to enable/disable it.
// At the current 50 MHz Clk_CPU, PERIOD_CYCLES=2,000,000 gives a 25 Hz tick.
module game_timer #(
    parameter integer PERIOD_CYCLES = 2_000_000
)(
    input             clk,
    input             rst,
    input             enable_we,
    input             enable_data,
    output reg        tick_irq
);
    reg        enabled;
    reg [31:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            enabled  <= 1'b0;
            count    <= 32'b0;
            tick_irq <= 1'b0;
        end else begin
            tick_irq <= 1'b0;

            if (enable_we) begin
                enabled <= enable_data;
                count   <= 32'b0;
            end else if (!enabled) begin
                count <= 32'b0;
            end else if (count == PERIOD_CYCLES - 1) begin
                count    <= 32'b0;
                tick_irq <= 1'b1;
            end else begin
                count <= count + 1'b1;
            end
        end
    end
endmodule
