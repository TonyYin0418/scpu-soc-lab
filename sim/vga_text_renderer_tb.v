`timescale 1ns/1ps

module vga_text_renderer_tb;
    reg  [9:0]  x;
    reg  [9:0]  y;
    reg         active;
    reg  [15:0] cell_data;
    wire [12:0] cell_addr;
    wire [3:0]  red;
    wire [3:0]  green;
    wire [3:0]  blue;

    vga_text_renderer dut(
        .x(x), .y(y), .active(active), .cell_data(cell_data),
        .cell_addr(cell_addr), .red(red), .green(green), .blue(blue)
    );

    task automatic expect_rgb;
        input [7:0] attr;
        input [3:0] expected_r;
        input [3:0] expected_g;
        input [3:0] expected_b;
        begin
            cell_data = {attr, 8'h41}; // 'A', row 0 / column 2 is a set pixel.
            #1;
            if ({red, green, blue} !== {expected_r, expected_g, expected_b}) begin
                $display("[VGA_COLOR][FAIL] attr=%02x rgb=%x%x%x expected=%x%x%x",
                         attr, red, green, blue, expected_r, expected_g, expected_b);
                $fatal(1);
            end
        end
    endtask

    initial begin
        x = 10'd2;
        y = 10'd0;
        active = 1'b1;
        cell_data = 16'h0000;

        expect_rgb(8'h70, 4'h7, 4'h7, 4'h7);
        expect_rgb(8'haa, 4'h2, 4'hd, 4'h4);
        expect_rgb(8'hbb, 4'h2, 4'hc, 4'he);
        expect_rgb(8'hcc, 4'he, 4'h3, 4'h2);
        expect_rgb(8'hee, 4'hf, 4'hc, 4'h2);
        expect_rgb(8'hff, 4'hf, 4'hf, 4'hf);

        active = 1'b0;
        #1;
        if ({red, green, blue} !== 12'h000)
            $fatal(1, "[VGA_COLOR][FAIL] inactive pixel is not black");

        $display("[VGA_COLOR][PASS] text attribute palette");
        $finish;
    end
endmodule
