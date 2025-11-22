`timescale 1ns/1ps

module tb_threshold;

parameter CLK_PERIOD = 10;
parameter IMAGE_WIDTH = 320;
parameter IMAGE_HEIGHT = 464;
parameter IMAGE_SIZE = IMAGE_WIDTH * IMAGE_HEIGHT;

reg clk;
reg rst_n;

reg data_valid;
reg [7:0] pixel_in;
reg [7:0] threshold_val;

wire data_out_valid;
wire [7:0] pixel_out;

integer pgm_file_in;
integer pgm_file_out;

integer input_pixel_count;
integer output_pixel_count;
integer timeout_counter;
parameter TIMEOUT_LIMIT = 1000000;

reg [7:0] source_image [0:IMAGE_SIZE-1];
reg [7:0] output_image [0:IMAGE_SIZE-1];

threshold #(
    .DATA_WIDTH(8)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .data_valid(data_valid),
    .pixel_in(pixel_in),
    .threshold_val(threshold_val),
    .data_out_valid(data_out_valid),
    .pixel_out(pixel_out)
);

initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

initial begin
    $dumpfile("tb_threshold.vcd");
    $dumpvars(0, tb_threshold);
    
    rst_n = 1'b0;
    data_valid = 1'b0;
    pixel_in = 8'd0;
    threshold_val = 8'd128;
    input_pixel_count = 0;
    output_pixel_count = 0;
    timeout_counter = 0;
    
    #10;
    $display("Clock signal check: clk=%0d", clk);
    
    #100;
    rst_n = 1'b1;
    #100;
    
    repeat(5) @(posedge clk);
    
    $display("=== Starting threshold module test ===");
    
    test_basic_function();
    #100;
    
    threshold_val = 8'd128;
    $display("Reset threshold to: %0d", threshold_val);
    test_pgm_image("data/gray1.pgm", "output/threshold_output.pgm");
    #100;
    
    $display("=== All tests completed ===");
    #1000;
    $finish;
end

task test_basic_function;
    integer i;
    begin
        $display("=== Starting basic function test ===");
        
        test_threshold_value(8'd0);
        test_threshold_value(8'd128);
        test_threshold_value(8'd255);
        
        $display("=== Basic function test completed ===");
    end
endtask

task test_threshold_value;
    input [7:0] test_threshold;
    integer test_pixels [0:9];
    integer expected_output [0:9];
    integer i;
    begin
        threshold_val = test_threshold;
        $display("Test threshold: %0d", test_threshold);
        
        test_pixels[0] = 0;    test_pixels[1] = 50;   test_pixels[2] = 100;
        test_pixels[3] = 127; test_pixels[4] = 128;  test_pixels[5] = 129;
        test_pixels[6] = 150; test_pixels[7] = 200;  test_pixels[8] = 254;
        test_pixels[9] = 255;
        
        for (i = 0; i < 10; i = i + 1) begin
            if (test_pixels[i] >= test_threshold) begin
                expected_output[i] = 255;
            end else begin
                expected_output[i] = 0;
            end
        end
        
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            data_valid = 1'b1;
            pixel_in = test_pixels[i];
            $display("  Cycle 0: Set data_valid=1, pixel_in=%0d", test_pixels[i]);
            
            @(posedge clk);
            @(posedge clk);
            $display("  Cycle 1: Immediate output verification");
            
            $display("  Cycle 1: data_out_valid=%0d, pixel_out=%0d", data_out_valid, pixel_out);
            
            if (data_out_valid) begin
                if (pixel_out == expected_output[i]) begin
                    $display("  Pixel %0d: Input=%0d, Output=%0d ", i, test_pixels[i], pixel_out);
                end else begin
                    $display("  Pixel %0d: Input=%0d, Expected=%0d, Actual=%0d ", 
                             i, test_pixels[i], expected_output[i], pixel_out);
                end
            end else begin
                $display("  Pixel %0d: Input=%0d, Expected=%0d, Actual=%0d  (data_out_valid is 0)", 
                         i, test_pixels[i], expected_output[i], pixel_out);
            end
            
            data_valid = 1'b0;
            pixel_in = 8'd0;
            $display("  Cycle 1: Set data_valid=0");
            
            @(posedge clk);
        end
    end
endtask

task test_pgm_image;
    input [1023:0] input_filename;
    input [1023:0] output_filename;
    integer width, height, max_val;
    integer i, j, pixel_val;
    integer scan_result;
    integer actual_image_size;
    reg [1023:0] line_buffer;
    reg [15:0] magic;
    reg exit_loop;
    reg [7:0] char;
    begin
        $display("=== Starting image file processing: %s ===", input_filename);
        $display("Current threshold: %0d", threshold_val);
        
        pgm_file_in = $fopen(input_filename, "r");
        if (pgm_file_in == 0) begin
            $display("Error: Cannot open input file %s", input_filename);
            $fclose(pgm_file_in);
        end else begin
            exit_loop = 1'b0;
            while (!exit_loop) begin
                scan_result = $fscanf(pgm_file_in, "%s", magic);
                if (scan_result == 0) begin
                    char = $fgetc(pgm_file_in);
                    if (char == "#") while ($fgetc(pgm_file_in) != "\n") begin end
                end else exit_loop = 1'b1;
            end
            
            if (magic != "P2") begin
                $display("Error: File expected P2 format, got %s", magic);
                $fclose(pgm_file_in);
            end else begin
                $display("Detected PGM format: %s", magic);
                
                exit_loop = 1'b0;
                while (!exit_loop) begin
                    scan_result = $fscanf(pgm_file_in, "%d %d", width, height);
                    if (scan_result != 2) begin
                        char = $fgetc(pgm_file_in);
                        if (char == "#") while ($fgetc(pgm_file_in) != "\n") begin end
                    end else exit_loop = 1'b1;
                end

                exit_loop = 1'b0;
                while (!exit_loop) begin
                    scan_result = $fscanf(pgm_file_in, "%d", max_val);
                    if (scan_result != 1) begin
                        char = $fgetc(pgm_file_in);
                        if (char == "#") while ($fgetc(pgm_file_in) != "\n") begin end
                    end else exit_loop = 1'b1;
                end
                
                $display("Image dimensions: %0d x %0d, Max value: %0d", width, height, max_val);
                
                actual_image_size = width * height;
                
                for (i = 0; i < actual_image_size; i = i + 1) begin
                    scan_result = $fscanf(pgm_file_in, "%d", pixel_val);
                    if (scan_result != 1) begin
                        $display("Error: Failed to read pixel data");
                        $fclose(pgm_file_in);
                        disable test_pgm_image;
                    end
                    source_image[i] = pixel_val;
                end
                
                $fclose(pgm_file_in);
                
                process_image_data(width, height, output_filename);
                
                $display("=== Image processing completed: %s ===", output_filename);
            end
        end
    end
endtask

task process_image_data;
    input integer width;
    input integer height;
    input [1023:0] output_filename;
    integer i;
    integer actual_image_size;
    begin
        actual_image_size = width * height;
        
        pgm_file_out = $fopen(output_filename, "w");
        if (pgm_file_out == 0) begin
            $display("Error: Cannot create output file %s", output_filename);
            $fclose(pgm_file_out);
        end else begin
            $fdisplay(pgm_file_out, "P2");
            $fdisplay(pgm_file_out, "%0d %0d", width, height);
            $fdisplay(pgm_file_out, "255");
            
            input_pixel_count = 0;
            output_pixel_count = 0;
            timeout_counter = 0;
            
            fork
                begin
                    for (i = 0; i < actual_image_size; i = i + 1) begin
                        @(posedge clk);
                        data_valid = 1'b1;
                        pixel_in = source_image[i];
                        input_pixel_count = input_pixel_count + 1;
                        
                        @(posedge clk);
                        data_valid = 1'b0;
                        
                        #(CLK_PERIOD * 2);
                    end
                    $display("Input pixel transmission completed: %0d", input_pixel_count);
                end
                
                begin
                    while (output_pixel_count < actual_image_size && timeout_counter < TIMEOUT_LIMIT) begin
                        @(posedge clk);
                        if (data_out_valid) begin
                            output_image[output_pixel_count] = pixel_out;
                            output_pixel_count = output_pixel_count + 1;
                            
                            if (output_pixel_count % 5000 == 0) begin
                                $display("Processing progress: %0d/%0d", output_pixel_count, actual_image_size);
                            end
                        end
                        timeout_counter = timeout_counter + 1;
                    end
                    
                    if (timeout_counter >= TIMEOUT_LIMIT) begin
                        $display("Error: Processing timeout");
                    end else begin
                        $display("Output pixel reception completed: %0d", output_pixel_count);
                    end
                end
            join
            
            for (i = 0; i < actual_image_size; i = i + 1) begin
                $fwrite(pgm_file_out, "%0d\n", output_image[i]);
                
                if ((i+1) % 10 == 0) begin
                    $fdisplay(pgm_file_out, "");
                end
            end
            
            $fclose(pgm_file_out);
            $display("Output file saved: %s", output_filename);
        end
    end
endtask

always @(posedge clk) begin
    if (timeout_counter >= TIMEOUT_LIMIT) begin
        $display("Error: Test timeout");
        if (pgm_file_in) $fclose(pgm_file_in);
        if (pgm_file_out) $fclose(pgm_file_out);
        $finish;
    end
end

endmodule