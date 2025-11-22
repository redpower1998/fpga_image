`timescale 1ns/1ps

module tb_gray_brightness;

parameter CLK_PERIOD = 10;

reg clk;
reg rst_n;
reg [7:0] gray_in;
reg data_valid;
reg [7:0] brightness_level;
reg brightness_enable;

wire [7:0] gray_out;
wire data_out_valid;

gray_brightness dut (
    .clk(clk),
    .rst_n(rst_n),
    .gray_in(gray_in),
    .data_valid(data_valid),
    .brightness_level(brightness_level),
    .brightness_enable(brightness_enable),
    .gray_out(gray_out),
    .data_out_valid(data_out_valid)
);

always #(CLK_PERIOD/2) clk = ~clk;

task test_brightness;
    input [7:0] input_gray;
    input [7:0] brightness;
    input enable;
    input [7:0] expected_gray;
    reg [7:0] actual_gray;
    begin
        gray_in = input_gray;
        brightness_level = brightness;
        brightness_enable = enable;
        data_valid = 1'b1;
        
        @(posedge clk);
        data_valid = 1'b0;
        
        @(posedge data_out_valid);
        actual_gray = gray_out;
        
        if (actual_gray === expected_gray) begin
            $display("PASS: gray_in=%0d, brightness=%0d, enable=%0d -> gray_out=%0d",
                     input_gray, brightness, enable, actual_gray);
        end else begin
            $display("FAIL: gray_in=%0d, brightness=%0d, enable=%0d -> gray_out=%0d (expected=%0d)",
                     input_gray, brightness, enable, actual_gray, expected_gray);
        end
        
        @(posedge clk);
    end
endtask

task process_pgm_image;
    input [80*8-1:0] input_filename;
    input [80*8-1:0] output_filename;
    input [7:0] brightness_setting;
    input enable_flag;
    
    integer pgm_file, output_file;
    integer width, height, max_val;
    integer i, j, gray_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop;
    integer pixel_count;
    reg file_end;
    integer timeout_counter;
    reg [7:0] processed_gray;

    begin
        pgm_file = $fopen(input_filename, "r");
        if (pgm_file == 0) begin
            $display("Error: Cannot open input file %s", input_filename);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file, "%s", magic);
            if (scan_result == 0) begin
                char = $fgetc(pgm_file);
                if (char == "#") while ($fgetc(pgm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        
        if (magic != "P2") begin
            $display("Error: Expected P2 format, got %s", magic);
            $fclose(pgm_file);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file, "%d %d", width, height);
            if (scan_result != 2) begin
                char = $fgetc(pgm_file);
                if (char == "#") while ($fgetc(pgm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file, "%d", max_val);
            if (scan_result != 1) begin
                char = $fgetc(pgm_file);
                if (char == "#") while ($fgetc(pgm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        $display("Processing image: %s -> %s", input_filename, output_filename);
        $display("Image size: %dx%d, max_value=%d, brightness=%d, enable=%b", 
                 width, height, max_val, brightness_setting, enable_flag);

        output_file = $fopen(output_filename, "w");
        if (output_file == 0) begin
            $display("Error: Cannot create output file %s", output_filename);
            $fclose(pgm_file);
            $finish;
        end

        $fdisplay(output_file, "P2");
        $fdisplay(output_file, "%d %d", width, height);
        $fdisplay(output_file, "%d", max_val);

        pixel_count = 0;
        file_end = 1'b0;

        for (i = 0; i < height && !file_end; i = i + 1) begin
            for (j = 0; j < width && !file_end; j = j + 1) begin
                exit_loop = 1'b0;
                while (!exit_loop && !file_end) begin
                    scan_result = $fscanf(pgm_file, "%d", gray_val);
                    if (scan_result == 1) begin
                        exit_loop = 1'b1;
                    end else begin
                        if ($feof(pgm_file)) begin
                            file_end = 1'b1;
                            $display("Warning: File ended prematurely at pixel %d", pixel_count);
                        end else begin
                            char = $fgetc(pgm_file);
                            if (char == "#") begin
                                while ($fgetc(pgm_file) != "\n" && !$feof(pgm_file)) begin end
                            end
                        end
                    end
                end

                if (file_end) begin
                    j = width;
                    i = height;
                end else begin
                    @(posedge clk);
                    gray_in <= gray_val;
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
                        processed_gray = gray_out;
                        $fwrite(output_file, "%d ", processed_gray);
                        
                        pixel_count = pixel_count + 1;
                        if (pixel_count % width == 0) begin
                            $fdisplay(output_file, "");
                        end
                    end
                end
            end
        end

        $display("Image processing completed: %d pixels processed", pixel_count);
        $fclose(pgm_file);
        $fclose(output_file);
    end
endtask

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    gray_in = 8'h00;
    data_valid = 1'b0;
    brightness_level = 8'h80;
    brightness_enable = 1'b0;
    
    $dumpfile("gray_brightness.vcd");
    $dumpvars(0, tb_gray_brightness);
    
    #(CLK_PERIOD);
    rst_n = 1'b1;
    
    @(posedge clk);
    
    $display("=== Starting Gray Brightness Module Test ===");
    
    $display("--- Test 1: Basic Functionality ---");
    test_brightness(100, 128, 1'b0, 100);
    test_brightness(100, 128, 1'b1, 100);
    test_brightness(100, 200, 1'b1, 244);
    test_brightness(100, 50, 1'b1, 22);
    
    $display("--- Test 2: Boundary Values ---");
    test_brightness(0, 200, 1'b1, 144);
    test_brightness(255, 50, 1'b1, 177);
    
    $display("--- Test 3: Real Image Processing ---");
    
    process_pgm_image("data/gray1.pgm", "output/output_gray1_original.pgm", 8'd128, 1'b0);
    #100;
    process_pgm_image("data/gray1.pgm", "output/output_gray1_brightened.pgm", 8'd200, 1'b1);
    #100;
    process_pgm_image("data/gray1.pgm", "output/output_gray1_darkened.pgm", 8'd50, 1'b1);
    
    $display("=== All tests completed successfully ===");
    #1000;
    $finish;
end

endmodule