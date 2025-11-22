`timescale 1ns/1ps

module tb_ycbcr_accuracy;

    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg rst_n;
    
    reg rgb2ycbcr_data_valid;
    reg [7:0] r_in;
    reg [7:0] g_in;
    reg [7:0] b_in;
    wire rgb2ycbcr_data_out_valid;
    wire [7:0] y_out;
    wire [7:0] cb_out;
    wire [7:0] cr_out;
    
    reg ycbcr2rgb_data_valid;
    reg [7:0] y_in_recon;
    reg [7:0] cb_in_recon;
    reg [7:0] cr_in_recon;
    wire ycbcr2rgb_data_out_valid;
    wire [7:0] r_out_recon;
    wire [7:0] g_out_recon;
    wire [7:0] b_out_recon;
    
    integer error_count;
    integer test_count;
    integer test_case;
    integer tolerance;
    
    rgb2ycbcr dut_rgb2ycbcr (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(rgb2ycbcr_data_valid),
        .r_in(r_in),
        .g_in(g_in),
        .b_in(b_in),
        .data_out_valid(rgb2ycbcr_data_out_valid),
        .y_out(y_out),
        .cb_out(cb_out),
        .cr_out(cr_out)
    );
    
    ycbcr2rgb dut_ycbcr2rgb (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(ycbcr2rgb_data_valid),
        .y_in(y_in_recon),
        .cb_in(cb_in_recon),
        .cr_in(cr_in_recon),
        .data_out_valid(ycbcr2rgb_data_out_valid),
        .r_out(r_out_recon),
        .g_out(g_out_recon),
        .b_out(b_out_recon)
    );
    
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        rgb2ycbcr_data_valid = 1'b0;
        r_in = 8'd0;
        g_in = 8'd0;
        b_in = 8'd0;
        ycbcr2rgb_data_valid = 1'b0;
        y_in_recon = 8'd0;
        cb_in_recon = 8'd0;
        cr_in_recon = 8'd0;
        error_count = 0;
        test_count = 0;
        test_case = 0;
        tolerance = 2;
        
        #100;
        rst_n = 1'b1;
        #100;
        
        $display("=== Starting YCbCr conversion accuracy test ===");
        
        test_case = 1;
        test_color(8'd0, 8'd0, 8'd0, "Pure black");
        
        test_case = 2;
        test_color(8'd255, 8'd255, 8'd255, "Pure white");
        
        test_case = 3;
        test_color(8'd255, 8'd0, 8'd0, "Pure red");
        
        test_case = 4;
        test_color(8'd0, 8'd255, 8'd0, "Pure green");
        
        test_case = 5;
        test_color(8'd0, 8'd0, 8'd255, "Pure blue");
        
        test_case = 6;
        test_color(8'd128, 8'd128, 8'd128, "Gray");
        
        test_case = 7;
        test_color(8'd0, 8'd0, 8'd200, "Dark blue");
        
        test_case = 8;
        test_color(8'd100, 8'd100, 8'd255, "Light blue");
        
        test_case = 9;
        test_color(8'd128, 8'd0, 8'd128, "Purple");
        
        test_case = 10;
        test_color(8'd0, 8'd128, 8'd128, "Cyan");
        
        test_case = 11;
        test_color(8'd255, 8'd255, 8'd0, "Yellow");
        
        test_case = 12;
        test_color(8'd255, 8'd0, 8'd255, "Magenta");
        
        test_case = 13;
        test_color(8'd255, 8'd128, 8'd0, "Orange");
        
        test_case = 14;
        test_color(8'd128, 8'd64, 8'd0, "Brown");
        
        test_case = 15;
        test_color(8'd255, 8'd128, 8'd128, "Pink");
        
        #1000;
        $display("=== All test cases completed ===");
        $display("Total test cases: %d", test_count);
        $display("Error count: %d", error_count);
        
        if (error_count == 0) begin
            $display("All tests passed!");
        end else begin
            $display("Found %d errors, further debugging needed", error_count);
        end
        
        $finish;
    end
    
    task test_color;
        input [7:0] r_test;
        input [7:0] g_test;
        input [7:0] b_test;
        input [255:0] color_name;
        
        reg [7:0] expected_y, expected_cb, expected_cr;
        reg [7:0] actual_y, actual_cb, actual_cr;
        reg [7:0] recon_r, recon_g, recon_b;
        integer y_error, cb_error, cr_error;
        integer rgb_error;
        
        begin
            test_count = test_count + 1;
            $display("--- Test case %0d: %s (R=%0d, G=%0d, B=%0d) ---", 
                     test_case, color_name, r_test, g_test, b_test);
            
            $display("Step 1: RGB to YCbCr conversion");
            rgb2ycbcr_data_valid = 1'b1;
            r_in = r_test;
            g_in = g_test;
            b_in = b_test;
            
            #(CLK_PERIOD * 3);
            rgb2ycbcr_data_valid = 1'b0;
            
            calculate_expected_ycbcr(r_test, g_test, b_test, 
                                   expected_y, expected_cb, expected_cr);
            
            actual_y = y_out;
            actual_cb = cb_out;
            actual_cr = cr_out;
            
            $display("Expected: Y=%0d, Cb=%0d, Cr=%0d", expected_y, expected_cb, expected_cr);
            $display("Actual: Y=%0d, Cb=%0d, Cr=%0d", actual_y, actual_cb, actual_cr);
            
            y_error = (actual_y > expected_y) ? (actual_y - expected_y) : (expected_y - actual_y);
            cb_error = (actual_cb > expected_cb) ? (actual_cb - expected_cb) : (expected_cb - actual_cb);
            cr_error = (actual_cr > expected_cr) ? (actual_cr - expected_cr) : (expected_cr - actual_cr);
            
            if (y_error > tolerance || cb_error > tolerance || cr_error > tolerance) begin
                $display("RGB to YCbCr conversion error too large: Y error=%0d, Cb error=%0d, Cr error=%0d", 
                         y_error, cb_error, cr_error);
                error_count = error_count + 1;
            end else begin
                $display("RGB to YCbCr conversion normal");
            end
            
            $display("Step 2: YCbCr to RGB reconstruction");
            ycbcr2rgb_data_valid = 1'b1;
            y_in_recon = actual_y;
            cb_in_recon = actual_cb;
            cr_in_recon = actual_cr;
            
            #(CLK_PERIOD * 3);
            ycbcr2rgb_data_valid = 1'b0;
            
            recon_r = r_out_recon;
            recon_g = g_out_recon;
            recon_b = b_out_recon;
            
            $display("Original RGB: R=%0d, G=%0d, B=%0d", r_test, g_test, b_test);
            $display("Reconstructed RGB: R=%0d, G=%0d, B=%0d", recon_r, recon_g, recon_b);
            
            rgb_error = 0;
            if (recon_r > r_test) rgb_error = rgb_error + (recon_r - r_test);
            else rgb_error = rgb_error + (r_test - recon_r);
            
            if (recon_g > g_test) rgb_error = rgb_error + (recon_g - g_test);
            else rgb_error = rgb_error + (g_test - recon_g);
            
            if (recon_b > b_test) rgb_error = rgb_error + (recon_b - b_test);
            else rgb_error = rgb_error + (b_test - recon_b);
            
            if (rgb_error > tolerance * 3) begin
                $display("RGB reconstruction error too large: Total error=%0d", rgb_error);
                error_count = error_count + 1;
                
                if ((recon_r > r_test + tolerance) || (recon_r < r_test - tolerance)) begin
                    $display("   R channel abnormal: Original=%0d, Reconstructed=%0d", r_test, recon_r);
                end
                if ((recon_g > g_test + tolerance) || (recon_g < g_test - tolerance)) begin
                    $display("   G channel abnormal: Original=%0d, Reconstructed=%0d", g_test, recon_g);
                end
                if ((recon_b > b_test + tolerance) || (recon_b < b_test - tolerance)) begin
                    $display("   B channel abnormal: Original=%0d, Reconstructed=%0d", b_test, recon_b);
                end
            end else begin
                $display("RGB reconstruction normal");
            end
            
            $display("");
        end
    endtask
    
    task calculate_expected_ycbcr;
        input [7:0] r;
        input [7:0] g;
        input [7:0] b;
        output reg [7:0] y;
        output reg [7:0] cb;
        output reg [7:0] cr;
        
        reg [15:0] r_mult_y, g_mult_y, b_mult_y;
        reg [15:0] r_mult_cb, g_mult_cb, b_mult_cb;
        reg [15:0] r_mult_cr, g_mult_cr, b_mult_cr;
        reg [15:0] y_sum_temp, cb_sum_temp, cr_sum_temp;
        
        begin
            r_mult_y  = r * 8'd77;
            g_mult_y  = g * 8'd150;
            b_mult_y  = b * 8'd29;
            
            r_mult_cb = r * 8'd43;
            g_mult_cb = g * 8'd85;
            b_mult_cb = b * 8'd128;
            
            r_mult_cr = r * 8'd128;
            g_mult_cr = g * 8'd107;
            b_mult_cr = b * 8'd21;
            
            y_sum_temp = r_mult_y + g_mult_y + b_mult_y;
            cb_sum_temp = b_mult_cb - r_mult_cb - g_mult_cb + 16'd32768;
            cr_sum_temp = r_mult_cr - g_mult_cr - b_mult_cr + 16'd32768;
            
            if (y_sum_temp[15:8] > 8'd255) begin
                y = 8'd255;
            end else if (y_sum_temp[15:8] < 8'd0) begin
                y = 8'd0;
            end else begin
                y = y_sum_temp[15:8];
            end
            
            if (cb_sum_temp > 16'd65535) begin
                cb = 8'd255;
            end else if (cb_sum_temp < 16'd0) begin
                cb = 8'd0;
            end else begin
                cb = cb_sum_temp[15:8];
            end
            
            if (cr_sum_temp > 16'd65535) begin
                cr = 8'd255;
            end else if (cr_sum_temp < 16'd0) begin
                cr = 8'd0;
            end else begin
                cr = cr_sum_temp[15:8];
            end
        end
    endtask

endmodule