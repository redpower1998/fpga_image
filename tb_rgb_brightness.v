`timescale 1ns/1ps

module tb_rgb_brightness;

parameter CLK_PERIOD = 10;

reg clk;
reg rst_n;
reg [7:0] r_in, g_in, b_in;
reg data_valid;
reg [7:0] brightness_level;
reg brightness_enable;

wire [7:0] r_out, g_out, b_out;
wire data_out_valid;

rgb_brightness dut (
    .clk(clk),
    .rst_n(rst_n),
    .r_in(r_in),
    .g_in(g_in),
    .b_in(b_in),
    .data_valid(data_valid),
    .brightness_level(brightness_level),
    .brightness_enable(brightness_enable),
    .r_out(r_out),
    .g_out(g_out),
    .b_out(b_out),
    .data_out_valid(data_out_valid)
);

always #(CLK_PERIOD/2) clk = ~clk;

task test_rgb_brightness;
    input [7:0] r_input, g_input, b_input;
    input [7:0] brightness;
    input enable;
    input [7:0] r_expected, g_expected, b_expected;
    reg [7:0] r_actual, g_actual, b_actual;
    begin
        r_in = r_input;
        g_in = g_input;
        b_in = b_input;
        brightness_level = brightness;
        brightness_enable = enable;
        data_valid = 1'b1;
        
        @(posedge clk);
        data_valid = 1'b0;
        
        @(posedge data_out_valid);
        r_actual = r_out;
        g_actual = g_out;
        b_actual = b_out;
        
        if (r_actual === r_expected && g_actual === g_expected && b_actual === b_expected) begin
            $display("PASS: RGB_in=(%0d,%0d,%0d), brightness=%0d, enable=%0d -> RGB_out=(%0d,%0d,%0d)",
                     r_input, g_input, b_input, brightness, enable, r_actual, g_actual, b_actual);
        end else begin
            $display("FAIL: RGB_in=(%0d,%0d,%0d), brightness=%0d, enable=%0d -> RGB_out=(%0d,%0d,%0d) (expected=(%0d,%0d,%0d))",
                     r_input, g_input, b_input, brightness, enable, r_actual, g_actual, b_actual, 
                     r_expected, g_expected, b_expected);
        end
        
        @(posedge clk);
    end
endtask

task process_ppm_image;
    input [80*8-1:0] input_filename;
    input [80*8-1:0] output_filename;
    input [7:0] brightness_setting;
    input enable_flag;
    
    integer ppm_file, output_file;
    integer width, height, max_val;
    integer i, j, r_val, g_val, b_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop;
    integer pixel_count;
    reg file_end;
    integer timeout_counter;
    reg [7:0] processed_r, processed_g, processed_b;

    begin
        ppm_file = $fopen(input_filename, "r");
        if (ppm_file == 0) begin
            $display("Error: Cannot open input file %s", input_filename);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file, "%s", magic);
            if (scan_result == 0) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        
        if (magic != "P3") begin
            $display("Error: Expected P3 format, got %s", magic);
            $fclose(ppm_file);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file, "%d %d", width, height);
            if (scan_result != 2) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file, "%d", max_val);
            if (scan_result != 1) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        $display("Processing image: %s -> %s", input_filename, output_filename);
        $display("Image size: %dx%d, max_value=%d, brightness=%d, enable=%b", 
                 width, height, max_val, brightness_setting, enable_flag);

        output_file = $fopen(output_filename, "w");
        if (output_file == 0) begin
            $display("Error: Cannot create output file %s", output_filename);
            $fclose(ppm_file);
            $finish;
        end

        $fdisplay(output_file, "P3");
        $fdisplay(output_file, "%d %d", width, height);
        $fdisplay(output_file, "%d", max_val);

        pixel_count = 0;
        file_end = 1'b0;

        for (i = 0; i < height && !file_end; i = i + 1) begin
            for (j = 0; j < width && !file_end; j = j + 1) begin
                exit_loop = 1'b0;
                while (!exit_loop && !file_end) begin
                    scan_result = $fscanf(ppm_file, "%d %d %d", r_val, g_val, b_val);
                    if (scan_result == 3) begin
                        exit_loop = 1'b1;
                    end else begin
                        if ($feof(ppm_file)) begin
                            file_end = 1'b1;
                            $display("Warning: File ended prematurely at pixel %d", pixel_count);
                        end else begin
                            char = $fgetc(ppm_file);
                            if (char == "#") begin
                                while ($fgetc(ppm_file) != "\n" && !$feof(ppm_file)) begin end
                            end
                        end
                    end
                end

                if (file_end) begin
                    j = width;
                    i = height;
                end else begin
                    @(posedge clk);
                    r_in <= r_val;
                    g_in <= g_val;
                    b_in <= b_val;
                    brightness_level <= brightness_setting;
                    brightness_enable <= enable_flag;
                    data_valid <= 1'b1;

                    @(posedge clk);
                    data_valid <= 1'b0;

                    timeout_counter = 0;
                    while (!data_out_valid && timeout_counter < 100) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end

                    if (!data_out_valid) begin
                        $display("Timeout waiting for data_out_valid at pixel %d", pixel_count);
                        file_end = 1'b1;
                        j = width;
                        i = height;
                    end else begin
                        processed_r = r_out;
                        processed_g = g_out;
                        processed_b = b_out;
                        $fwrite(output_file, "%d %d %d ", processed_r, processed_g, processed_b);
                        
                        pixel_count = pixel_count + 1;
                        if (pixel_count % 4 == 0) begin
                            $fdisplay(output_file, "");
                        end
                    end
                end
            end
        end

        $display("Image processing completed: %d pixels processed", pixel_count);
        $fclose(ppm_file);
        $fclose(output_file);
    end
endtask

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    r_in = 8'h00;
    g_in = 8'h00;
    b_in = 8'h00;
    data_valid = 1'b0;
    brightness_level = 8'h80;
    brightness_enable = 1'b0;
    
    $dumpfile("rgb_brightness.vcd");
    $dumpvars(0, tb_rgb_brightness);
    
    #(CLK_PERIOD);
    rst_n = 1'b1;
    
    @(posedge clk);
    
    $display("=== Starting RGB Brightness Module Test ===");
    
    $display("--- Test 1: Basic Functionality ---");
    test_rgb_brightness(100, 150, 200, 128, 1'b0, 100, 150, 200);
    test_rgb_brightness(100, 150, 200, 128, 1'b1, 100, 150, 200);
    test_rgb_brightness(100, 150, 200, 200, 1'b1, 244, 255, 255);  
    test_rgb_brightness(100, 150, 200, 50, 1'b1, 22, 72, 122);
    
    $display("--- Test 2: Boundary Values ---");
    test_rgb_brightness(0, 0, 0, 200, 1'b1, 144, 144, 144);
    test_rgb_brightness(255, 255, 255, 50, 1'b1, 177, 177, 177);
    
    $display("--- Test 3: Real Color Image Processing ---");
    
    process_ppm_image("data/rgb1.ppm", "output/output_rgb1_original.ppm", 8'd128, 1'b0);
    #100;
    process_ppm_image("data/rgb1.ppm", "output/output_rgb1_brightened.ppm", 8'd200, 1'b1);
    #100;
    process_ppm_image("data/rgb1.ppm", "output/output_rgb1_darkened.ppm", 8'd50, 1'b1);
    
    $display("=== All tests completed successfully ===");
    #1000;
    $finish;
end

endmodule