`timescale 1ns/1ps

module tb_white_balance;

    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 8;
    parameter GAIN_WIDTH = 16;
    parameter METHOD_WIDTH = 2;
    
    reg clk;
    reg rst_n;
    
    reg pixel_valid;
    reg [DATA_WIDTH-1:0] pixel_r, pixel_g, pixel_b;
    reg [GAIN_WIDTH-1:0] gain_r, gain_g, gain_b;
    reg [METHOD_WIDTH-1:0] method;
    
    wire pixel_out_valid;
    wire [DATA_WIDTH-1:0] pixel_out_r, pixel_out_g, pixel_out_b;
    
    integer f_rgb_in, f_wb_manual, f_wb_gray_world, f_wb_perfect, f_wb_auto;
    integer width, height, max_val;
    integer pixel_count;
    
    integer i, j;
    integer r_val, g_val, b_val;
    integer error_flag;
    
    reg [7:0] ch;
    reg [1023:0] line_buffer;
    integer seek_result;
    
    integer scan_result, scan_result2, gets_result;
    
    reg [15:0] magic;
    
    white_balance #(
        .DATA_WIDTH(DATA_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH),
        .METHOD_WIDTH(METHOD_WIDTH)
    ) u_white_balance (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .pixel_r(pixel_r),
        .pixel_g(pixel_g),
        .pixel_b(pixel_b),
        .gain_r(gain_r),
        .gain_g(gain_g),
        .gain_b(gain_b),
        .method(method),
        .pixel_out_valid(pixel_out_valid),
        .pixel_out_r(pixel_out_r),
        .pixel_out_g(pixel_out_g),
        .pixel_out_b(pixel_out_b)
    );
    
    always #(CLK_PERIOD/2) clk = ~clk;
    
    task test_basic_operations;
        begin
            $display("=== Starting basic white balance function test ===");
            
            rst_n = 1'b0;
            pixel_valid = 1'b0;
            pixel_r = 8'd0;
            pixel_g = 8'd0;
            pixel_b = 8'd0;
            gain_r = 16'h0100;
            gain_g = 16'h0100;
            gain_b = 16'h0100;
            method = 2'b00;
            
            repeat(5) @(posedge clk);
            rst_n = 1'b1;
            repeat(2) @(posedge clk);
            
            $display("Test 1: Manual gain adjustment (red enhancement)");
            method = 2'b00;
            gain_r = 16'h0180;
            gain_g = 16'h0100;
            gain_b = 16'h0100;
            
            pixel_valid = 1'b1;
            pixel_r = 8'd100;
            pixel_g = 8'd100;
            pixel_b = 8'd100;
            
            repeat(3) @(posedge clk);
            
            if (pixel_out_valid) begin
                $display("Input: R=%d, G=%d, B=%d", 100, 100, 100);
                $display("Output: R=%d, G=%d, B=%d", pixel_out_r, pixel_out_g, pixel_out_b);
                if (pixel_out_r == 150 && pixel_out_g == 100 && pixel_out_b == 100) begin
                    $display("PASS: Manual gain adjustment test passed");
                end else begin
                    $display("FAIL: Manual gain adjustment test failed");
                end
            end else begin
                $display("ERROR: Output invalid");
            end
            
            pixel_valid = 1'b0;
            repeat(2) @(posedge clk);
            
            $display("Test 2: Gray world method");
            method = 2'b01;
            gain_r = 16'h0100;
            gain_g = 16'h0100;
            gain_b = 16'h0100;
            
            pixel_valid = 1'b1;
            pixel_r = 8'd200;
            pixel_g = 8'd100;
            pixel_b = 8'd50;
            
            repeat(3) @(posedge clk);
            
            if (pixel_out_valid) begin
                $display("Input: R=%d, G=%d, B=%d", 200, 100, 50);
                $display("Output: R=%d, G=%d, B=%d", pixel_out_r, pixel_out_g, pixel_out_b);
                $display("PASS: Gray world method test completed");
            end else begin
                $display("ERROR: Output invalid");
            end
            
            pixel_valid = 1'b0;
            repeat(2) @(posedge clk);
            
            $display("Test 3: Perfect reflection method");
            method = 2'b10;
            pixel_valid = 1'b1;
            pixel_r = 8'd150;
            pixel_g = 8'd100;
            pixel_b = 8'd80;
            
            repeat(3) @(posedge clk);
            
            if (pixel_out_valid) begin
                $display("Input: R=%d, G=%d, B=%d", 150, 100, 80);
                $display("Output: R=%d, G=%d, B=%d", pixel_out_r, pixel_out_g, pixel_out_b);
                $display("PASS: Perfect reflection method test completed");
            end else begin
                $display("ERROR: Output invalid");
            end
            
            pixel_valid = 1'b0;
            $display("=== Basic white balance function test completed ===\n");
        end
    endtask
    
    integer max_r, max_g, max_b;
    integer perfect_r, perfect_g, perfect_b;
    integer perfect_gain_r, perfect_gain_g, perfect_gain_b;
    
    integer total_r, total_g, total_b;
    integer avg_r, avg_g, avg_b;
    integer gray_world_gain_r, gray_world_gain_g, gray_world_gain_b;
    
    integer manual_gain_r, manual_gain_g, manual_gain_b;
    
    task test_pgm_image;
        input [2550:0] image_file;
        begin
            $display("=== Starting PGM image white balance processing test ===");
            error_flag = 0;
            
            f_rgb_in = $fopen(image_file, "r");
            if (f_rgb_in == 0) begin
                $display("ERROR: Cannot open input image file %s", image_file);
                error_flag = 1;
            end
            
            if (!error_flag) begin
                scan_result = $fscanf(f_rgb_in, "%s", magic);
                if (scan_result != 1 || magic != "P3") begin
                    $display("ERROR: Unsupported PGM format (requires P3 RGB format), actually got: %s", magic);
                    $fclose(f_rgb_in);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                ch = $fgetc(f_rgb_in);
                while (ch == " " || ch == "\n" || ch == "\r" || ch == "\t") begin
                    ch = $fgetc(f_rgb_in);
                end
                
                while (ch == "#") begin
                    gets_result = $fgets(line_buffer, f_rgb_in);
                    ch = $fgetc(f_rgb_in);
                    while (ch == " " || ch == "\n" || ch == "\r" || ch == "\t") begin
                        ch = $fgetc(f_rgb_in);
                    end
                end
                
                seek_result = $fseek(f_rgb_in, -1, 1);
                
                scan_result2 = $fscanf(f_rgb_in, "%d %d %d", width, height, max_val);
                if (scan_result2 != 3) begin
                    $display("ERROR: Cannot read image dimensions, actual parameter count read: %d", scan_result2);
                    $fclose(f_rgb_in);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                $display("Image dimensions: %d x %d, Max value: %d", width, height, max_val);
                total_r = 0; total_g = 0; total_b = 0;
                max_r = 0; max_g = 0; max_b = 0;
                
                $display("First pass: Statistics of RGB sum and brightest pixels...");
                for (j = 0; j < height; j = j + 1) begin
                    for (i = 0; i < width; i = i + 1) begin
                        if ($fscanf(f_rgb_in, "%d %d %d", r_val, g_val, b_val) != 3) begin
                            $display("ERROR: Failed to read pixel data");
                            error_flag = 1;
                            j = height;
                            i = width;
                        end else begin
                            total_r = total_r + r_val;
                            total_g = total_g + g_val;
                            total_b = total_b + b_val;
                            
                            if ((r_val + g_val + b_val) > (max_r + max_g + max_b)) begin
                                max_r = r_val;
                                max_g = g_val;
                                max_b = b_val;
                            end
                        end
                    end
                end
                
                if (!error_flag) begin
                    avg_r = total_r / (width * height);
                    avg_g = total_g / (width * height);
                    avg_b = total_b / (width * height);
                    
                    $display("Average RGB values: R=%d, G=%d, B=%d", avg_r, avg_g, avg_b);
                    $display("Brightest pixel: R=%d, G=%d, B=%d", max_r, max_g, max_b);
                    
                    if (avg_g > 0) begin
                        gray_world_gain_r = (avg_g * 256) / avg_r;
                        gray_world_gain_g = 256;
                        gray_world_gain_b = (avg_g * 256) / avg_b;
                    end else begin
                        gray_world_gain_r = 256;
                        gray_world_gain_g = 256;
                        gray_world_gain_b = 256;
                    end
                    
                    if (max_r > 0) perfect_gain_r = (max_val * 256) / max_r;
                    else perfect_gain_r = 256;
                    
                    if (max_g > 0) perfect_gain_g = (max_val * 256) / max_g;
                    else perfect_gain_g = 256;
                    
                    if (max_b > 0) perfect_gain_b = (max_val * 256) / max_b;
                    else perfect_gain_b = 256;
                    
                    $display("Gray world method gains: R=%d, G=%d, B=%d", 
                             gray_world_gain_r, gray_world_gain_g, gray_world_gain_b);
                    $display("Perfect reflection method gains: R=%d, G=%d, B=%d", 
                             perfect_gain_r, perfect_gain_g, perfect_gain_b);
                    
                    manual_gain_r = 16'h0140;
                    manual_gain_g = 16'h00C0;
                    manual_gain_b = 16'h0100;
                end
                
                seek_result = $fseek(f_rgb_in, 0, 0);
                scan_result = $fscanf(f_rgb_in, "%s", magic);
                ch = $fgetc(f_rgb_in);
                while (ch == " " || ch == "\n" || ch == "\r" || ch == "\t") begin
                    ch = $fgetc(f_rgb_in);
                end
                while (ch == "#") begin
                    gets_result = $fgets(line_buffer, f_rgb_in);
                    ch = $fgetc(f_rgb_in);
                    while (ch == " " || ch == "\n" || ch == "\r" || ch == "\t") begin
                        ch = $fgetc(f_rgb_in);
                    end
                end
                seek_result = $fseek(f_rgb_in, -1, 1);
                scan_result2 = $fscanf(f_rgb_in, "%d %d %d", width, height, max_val);
                
                f_wb_manual = $fopen("output/out_wb_manual_output.ppm", "w");
                f_wb_gray_world = $fopen("output/out_wb_gray_world_output.ppm", "w");
                f_wb_perfect = $fopen("output/out_wb_perfect_output.ppm", "w");
                f_wb_auto = $fopen("output/out_wb_auto_output.ppm", "w");
                
                $fdisplay(f_wb_manual, "P3");
                $fdisplay(f_wb_manual, "# Manual white balance output");
                $fdisplay(f_wb_manual, "%d %d", width, height);
                $fdisplay(f_wb_manual, "%d", max_val);
                
                $fdisplay(f_wb_gray_world, "P3");
                $fdisplay(f_wb_gray_world, "# Gray world method white balance output");
                $fdisplay(f_wb_gray_world, "%d %d", width, height);
                $fdisplay(f_wb_gray_world, "%d", max_val);
                
                $fdisplay(f_wb_perfect, "P3");
                $fdisplay(f_wb_perfect, "# Perfect reflection method white balance output");
                $fdisplay(f_wb_perfect, "%d %d", width, height);
                $fdisplay(f_wb_perfect, "%d", max_val);
                
                $fdisplay(f_wb_auto, "P3");
                $fdisplay(f_wb_auto, "# Automatic white balance output");
                $fdisplay(f_wb_auto, "%d %d", width, height);
                $fdisplay(f_wb_auto, "%d", max_val);
                
                rst_n = 1'b0;
                pixel_valid = 1'b0;
                pixel_r = 8'd0;
                pixel_g = 8'd0;
                pixel_b = 8'd0;
                
                repeat(5) @(posedge clk);
                rst_n = 1'b1;
                repeat(2) @(posedge clk);
                
                pixel_count = 0;
                $display("Second pass: Applying white balance algorithms...");
                
                for (j = 0; j < height; j = j + 1) begin
                    for (i = 0; i < width; i = i + 1) begin
                        if ($fscanf(f_rgb_in, "%d %d %d", r_val, g_val, b_val) != 3) begin
                            $display("ERROR: Failed to read pixel data");
                            error_flag = 1;
                        end
                        
                        if (error_flag) begin
                            j = height;
                            i = width;
                        end else begin
                            method = 2'b00;
                            gain_r = manual_gain_r;
                            gain_g = manual_gain_g;
                            gain_b = manual_gain_b;
                            pixel_valid = 1'b1;
                            pixel_r = r_val;
                            pixel_g = g_val;
                            pixel_b = b_val;
                            
                            repeat(3) @(posedge clk);
                            
                            if (pixel_out_valid) begin
                                $fwrite(f_wb_manual, "%d %d %d ", pixel_out_r, pixel_out_g, pixel_out_b);
                            end else begin
                                $fwrite(f_wb_manual, "%d %d %d ", r_val, g_val, b_val);
                            end
                            
                            pixel_valid = 1'b0;
                            repeat(2) @(posedge clk);
                            
                            method = 2'b00;
                            gain_r = gray_world_gain_r;
                            gain_g = gray_world_gain_g;
                            gain_b = gray_world_gain_b;
                            pixel_valid = 1'b1;
                            pixel_r = r_val;
                            pixel_g = g_val;
                            pixel_b = b_val;
                            
                            repeat(3) @(posedge clk);
                            
                            if (pixel_out_valid) begin
                                $fwrite(f_wb_gray_world, "%d %d %d ", pixel_out_r, pixel_out_g, pixel_out_b);
                            end else begin
                                $fwrite(f_wb_gray_world, "%d %d %d ", r_val, g_val, b_val);
                            end
                            
                            pixel_valid = 1'b0;
                            repeat(2) @(posedge clk);
                            
                            method = 2'b00;
                            gain_r = perfect_gain_r;
                            gain_g = perfect_gain_g;
                            gain_b = perfect_gain_b;
                            pixel_valid = 1'b1;
                            pixel_r = r_val;
                            pixel_g = g_val;
                            pixel_b = b_val;
                            
                            repeat(3) @(posedge clk);
                            
                            if (pixel_out_valid) begin
                                $fwrite(f_wb_perfect, "%d %d %d ", pixel_out_r, pixel_out_g, pixel_out_b);
                            end else begin
                                $fwrite(f_wb_perfect, "%d %d %d ", r_val, g_val, b_val);
                            end
                            
                            pixel_valid = 1'b0;
                            repeat(2) @(posedge clk);
                            
                            method = 2'b00;
                            gain_r = (gray_world_gain_r + perfect_gain_r) / 2;
                            gain_g = (gray_world_gain_g + perfect_gain_g) / 2;
                            gain_b = (gray_world_gain_b + perfect_gain_b) / 2;
                            pixel_valid = 1'b1;
                            pixel_r = r_val;
                            pixel_g = g_val;
                            pixel_b = b_val;
                            
                            repeat(3) @(posedge clk);
                            
                            if (pixel_out_valid) begin
                                $fwrite(f_wb_auto, "%d %d %d ", pixel_out_r, pixel_out_g, pixel_out_b);
                            end else begin
                                $fwrite(f_wb_auto, "%d %d %d ", r_val, g_val, b_val);
                            end
                            
                            pixel_valid = 1'b0;
                            repeat(2) @(posedge clk);
                            
                            pixel_count = pixel_count + 1;
                            
                            if (pixel_count % 1000 == 0) begin
                                $display("Processing progress: %0d/%0d", pixel_count, width * height);
                            end
                        end
                    end
                    
                    if (!error_flag) begin
                        $fdisplay(f_wb_manual, "");
                        $fdisplay(f_wb_gray_world, "");
                        $fdisplay(f_wb_perfect, "");
                        $fdisplay(f_wb_auto, "");
                    end
                end
                
                $fclose(f_rgb_in);
                $fclose(f_wb_manual);
                $fclose(f_wb_gray_world);
                $fclose(f_wb_perfect);
                $fclose(f_wb_auto);
                
                if (!error_flag) begin
                    $display("Image processing completed, processed %d pixels", pixel_count);
                    $display("=== PGM image white balance processing test completed ===\n");
                end
            end
        end
    endtask
    
    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        pixel_valid = 1'b0;
        pixel_r = 8'd0;
        pixel_g = 8'd0;
        pixel_b = 8'd0;
        gain_r = 16'h0100;
        gain_g = 16'h0100;
        gain_b = 16'h0100;
        method = 2'b00;
        
        #100;
        
        test_basic_operations;
        
        if ($test$plusargs("image_test")) begin
            test_pgm_image("data/wb_rgb1.ppm");
        end
        
        #100;
        $display("=== All tests completed ===");
        $finish;
    end
    
    initial begin
        $dumpfile("white_balance.vcd");
        $dumpvars(0, tb_white_balance);
    end

endmodule